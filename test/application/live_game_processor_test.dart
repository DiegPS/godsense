import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/live_game_processor.dart';

void main() {
  group('LiveGameProcessor', () {
    late LiveGameProcessor processor;

    setUp(() => processor = LiveGameProcessor());

    test(
      'soul switches dragon timer to Elder without counting Elder as a drake',
      () {
        final result = processor.process(
          _snapshot(
            gameTime: 2050,
            events: [
              for (var i = 0; i < 4; i++)
                {
                  'EventID': i,
                  'EventName': 'DragonKill',
                  'EventTime': 400 + i * 300,
                  'KillerName': 'Local',
                  'DragonType': 'Infernal',
                },
              {
                'EventID': 5,
                'EventName': 'DragonKill',
                'EventTime': 2000,
                'KillerName': 'Local',
                'DragonType': 'Elder',
              },
            ],
          ),
          itemCatalog: _items,
          gameId: 'elder-game',
        );
        final derived = result.snapshot['derived'] as Map;
        final dragon = (derived['objectives'] as Map)['dragon'] as Map;
        expect((derived['dragon_kills'] as Map)['ally'], 4);
        expect(dragon['elder_expected'], isTrue);
        expect(dragon['respawn_in'], 310);
      },
    );

    test('builds enriched game state, timeline, and objective timers', () {
      final result = processor.process(
        _snapshot(gameTime: 400),
        itemCatalog: _items,
        championAbilities: _abilities,
        gameId: 'game-1',
        observedAt: DateTime.utc(2026),
      );

      expect(result.sessionId, 'game-1');
      expect(result.snapshot['phase'], 'EARLY');
      expect(result.snapshot['game_mode'], 'CLASSIC');
      expect(result.snapshot['map_number'], 11);
      expect(result.snapshot['_game_ended'], isFalse);
      expect(result.snapshot['active_player'], isA<Map>());
      expect(
        (result.snapshot['active_player'] as Map)['abilities'],
        isNotEmpty,
      );
      expect((result.snapshot['allies'] as List), hasLength(1));
      expect((result.snapshot['enemies'] as List), hasLength(1));
      expect(
        ((result.snapshot['enemies'] as List).single as Map)['abilities'],
        hasLength(5),
      );

      final derived = result.snapshot['derived'] as Map;
      final objectives = derived['objectives'] as Map;
      expect((objectives['dragon'] as Map)['status'], 'respawning');
      expect((objectives['dragon'] as Map)['respawn_in'], 210);
      expect((objectives['baron'] as Map)['status'], 'spawning');
      expect((derived['dragon_kills'] as Map)['ally'], 1);
      expect((derived['structures'] as Map)['enemy_turrets_destroyed'], 1);

      final laneStates = result.snapshot['lane_states'] as Map;
      expect(laneStates['MIDDLE'], isA<Map>());
      expect((laneStates['MIDDLE'] as Map)['evaluator_version'], 2);
      expect(
        (laneStates['MIDDLE'] as Map)['power_basis'],
        'purchased_inventory_and_level',
      );
      expect((result.snapshot['active_player'] as Map)['health_ratio'], .9);
      expect(result.timeline['gold_points'], hasLength(1));
      expect(result.timeline['events'], hasLength(3));
      expect(
        (result.timeline['events'] as List).first['game_time_fmt'],
        '5:20',
      );
    });

    test('deduplicates events and samples gold at most once per second', () {
      final first = processor.process(
        _snapshot(gameTime: 400),
        itemCatalog: _items,
        gameId: 'game-1',
      );
      final tooSoon = processor.process(
        _snapshot(gameTime: 400.5),
        itemCatalog: _items,
        gameId: 'game-1',
      );
      final next = processor.process(
        _snapshot(gameTime: 401.5),
        itemCatalog: _items,
        gameId: 'game-1',
      );

      expect(first.timeline['events'], hasLength(3));
      expect(tooSoon.timeline['events'], hasLength(3));
      expect(tooSoon.timeline['gold_points'], hasLength(1));
      expect(next.timeline['gold_points'], hasLength(2));
    });

    test('resets temporal state for a new game and marks completion', () {
      processor.process(
        _snapshot(gameTime: 400),
        itemCatalog: _items,
        gameId: 'game-1',
      );
      final completed = processor.completeLast(endedAt: DateTime.utc(2026));
      expect(completed?['_game_ended'], isTrue);

      final next = processor.process(
        _snapshot(gameTime: 10, events: const []),
        itemCatalog: _items,
        gameId: 'game-2',
      );
      expect(next.sessionId, 'game-2');
      expect(next.snapshot['_game_ended'], isFalse);
      expect(next.timeline['events'], isEmpty);
      expect(next.timeline['gold_points'], hasLength(1));
    });

    test('does not count CS and kills twice in lane combat power', () {
      final baseline = processor.process(
        _snapshot(gameTime: 400),
        itemCatalog: _items,
        gameId: 'game-1',
      );
      final changed = _snapshot(gameTime: 401);
      final enemy = (changed['allPlayers'] as List).last as Map;
      enemy['scores'] = {
        'kills': 20,
        'deaths': 0,
        'assists': 15,
        'creepScore': 300,
      };
      final afterStats = processor.process(
        changed,
        itemCatalog: _items,
        gameId: 'game-1',
      );

      final beforeLane =
          (baseline.snapshot['lane_states'] as Map)['MIDDLE'] as Map;
      final afterLane =
          (afterStats.snapshot['lane_states'] as Map)['MIDDLE'] as Map;
      expect(afterLane['advantage_score'], beforeLane['advantage_score']);
      expect(afterLane['relative_advantage'], beforeLane['relative_advantage']);
    });

    test('marks critical local health as vulnerable instead of ahead', () {
      final raw = _snapshot(gameTime: 400);
      (raw['activePlayer'] as Map)['championStats'] = {
        'currentHealth': 100,
        'maxHealth': 1000,
        'resourceValue': 50,
        'resourceMax': 500,
      };
      final result = processor.process(
        raw,
        itemCatalog: _items,
        gameId: 'game-1',
      );

      final lane = (result.snapshot['lane_states'] as Map)['MIDDLE'] as Map;
      expect(lane['state'], 'VULNERABLE');
      expect(lane['health_applied'], isTrue);
    });
  });
}

const _items = <int, Map<String, dynamic>>{
  1001: {
    'name': 'Boots',
    'gold': {'total': 300},
    '_version': '1.0.0',
  },
};

const _abilities = <String, List<Map<String, dynamic>>>{
  'vex': [
    {'slot': 'P', 'name': 'Doom n Gloom'},
    {'slot': 'Q', 'name': 'Mistral Bolt'},
    {'slot': 'W', 'name': 'Personal Space'},
    {'slot': 'E', 'name': 'Looming Darkness'},
    {'slot': 'R', 'name': 'Shadow Surge'},
  ],
};

Map<String, dynamic> _snapshot({
  required double gameTime,
  List<Map<String, dynamic>>? events,
}) {
  return {
    'gameData': {
      'gameTime': gameTime,
      'gameMode': 'CLASSIC',
      'mapName': 'Map11',
      'mapNumber': 11,
    },
    'activePlayer': {
      'summonerName': 'Local#LAN',
      'currentGold': 900,
      'abilities': {
        'Q': {'displayName': 'Spell'},
      },
      'championStats': {
        'abilityPower': 100,
        'currentHealth': 900,
        'maxHealth': 1000,
        'resourceValue': 400,
        'resourceMax': 500,
      },
    },
    'allPlayers': [
      {
        'summonerName': '',
        'riotIdGameName': 'Local',
        'riotIdTagLine': 'LAN',
        'championName': 'Ahri',
        'team': 'ORDER',
        'position': 'MIDDLE',
        'level': 8,
        'scores': {'kills': 3, 'deaths': 1, 'assists': 2, 'creepScore': 80},
        'items': [
          {'itemID': 1001, 'count': 1},
        ],
        'summonerSpells': {
          'summonerSpellOne': {'displayName': 'Flash'},
        },
      },
      {
        'summonerName': 'Enemy',
        'championName': 'Vex',
        'team': 'CHAOS',
        'position': 'MIDDLE',
        'level': 7,
        'scores': {'kills': 0, 'deaths': 3, 'assists': 1, 'creepScore': 60},
        'items': [
          {'itemID': 1001, 'count': 1},
        ],
        'summonerSpells': const {},
      },
    ],
    'events': {
      'Events':
          events ??
          [
            {
              'EventID': 1,
              'EventName': 'ChampionKill',
              'EventTime': 300,
              'KillerName': 'Local',
              'VictimName': 'Enemy',
            },
            {
              'EventID': 2,
              'EventName': 'DragonKill',
              'EventTime': 310,
              'KillerName': 'Local',
              'DragonType': 'Infernal',
            },
            {
              'EventID': 3,
              'EventName': 'TurretKilled',
              'EventTime': 320,
              'KillerName': 'Local',
            },
          ],
    },
  };
}
