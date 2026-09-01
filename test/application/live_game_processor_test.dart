import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/live_game_processor.dart';

void main() {
  group('LiveGameProcessor', () {
    late LiveGameProcessor processor;

    setUp(() => processor = LiveGameProcessor());

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
      'championStats': {'abilityPower': 100},
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
