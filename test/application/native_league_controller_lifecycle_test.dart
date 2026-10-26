import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/application/native_league_foundation.dart';
import 'package:godsense/infrastructure/league/lcu_event_stream.dart';
import 'package:godsense/infrastructure/league/lcu_probe_transport.dart';
import 'package:godsense/infrastructure/league/league_clients.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';

Future<void> _until(bool Function() completed) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (!completed() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(completed(), isTrue, reason: 'League state transition timed out');
  await Future<void>.delayed(const Duration(milliseconds: 10));
}

void main() {
  test(
    'draft, live outage, recovery, postgame and reconnect share one lifecycle',
    () async {
      final lcu = _League();
      final live = _Live();
      final events = _Events();
      final database = GodSenseDatabase.inMemory();
      final foundation = NativeLeagueFoundation(
        client: lcu,
        databaseFactory: () async => database,
        captureEpochId: 'synthetic-lifecycle',
      );
      final controller = NativeLeagueController(
        lcu: lcu,
        live: live,
        lcuEvents: events,
        foundation: foundation,
      );
      try {
        controller.start();
        controller.start();
        await _until(() => controller.state.lcuConnected);
        expect(controller.state.gameflowPhase, 'None');

        lcu.phase = 'ChampSelect';
        events.changed();
        await _until(() => controller.state.lobby.isNotEmpty);
        final draft = controller.state.lobby['snapshot'] as Map;
        expect((draft['my_team'] as List).single['is_local'], true);
        expect((draft['my_team'] as List).single['champion_name'], 'Ahri');
        expect(controller.localSummonerId, 7);

        final personalSet = {'title': 'My personal build', 'uid': 'personal'};
        lcu.itemSets = {
          'accountId': 7,
          'customMetadata': 'preserve',
          'itemSets': [
            personalSet,
            {'title': 'GodSense Recommended', 'uid': 'old-godsense'},
          ],
        };
        final recommendedBuild = {
          'champion_id': 103,
          'map_id': 11,
          'items': [
            {
              'category': 'Starting items',
              'items': [
                {'item_id': 1056},
                {'item_id': 2003, 'count': 2},
              ],
            },
          ],
        };
        lcu.rejectItemWrite = true;
        await controller.importRecommendedSetup(recommendedBuild);
        expect(
          controller.state.lastOperationResult['build_error'],
          contains('rejected'),
        );
        expect((lcu.itemSets!['itemSets'] as List).first, personalSet);
        expect(controller.state.operationInProgress, false);
        lcu.rejectItemWrite = false;
        await controller.importRecommendedSetup({'matchup': recommendedBuild});
        expect(controller.state.lastOperationResult['build'], isNotNull);
        expect(controller.state.lastOperationResult['build_error'], isNull);
        final imported = lcu.itemSets!;
        expect(imported['customMetadata'], 'preserve');
        final sets = imported['itemSets'] as List;
        expect(sets, hasLength(2));
        expect(sets.first, personalSet);
        final generated = sets.last as Map;
        expect(generated['associatedChampions'], [103]);
        expect(generated['associatedMaps'], [11]);
        expect((generated['blocks'] as List).single['items'], [
          {'id': '1056', 'count': 1},
          {'id': '2003', 'count': 2},
        ]);

        live.data = _game(400);
        lcu.phase = 'InProgress';
        events.changed();
        await _until(() => controller.state.inGame);
        expect(controller.state.sessionId, '42');
        expect(controller.state.liveApiConnected, true);
        expect(controller.state.timeline['gold_points'], isNotEmpty);

        live.data = null;
        for (var failure = 1; failure <= 2; failure++) {
          events.changed();
          await _until(
            () => controller.state.consecutiveLiveFailures >= failure,
          );
          expect(controller.state.inGame, true);
          expect(controller.state.liveApiConnected, false);
          expect(controller.state.liveGame?['active_player'], isNotEmpty);
        }

        live.data = _game(410);
        events.changed();
        await _until(() => controller.state.liveApiConnected);
        expect(controller.state.consecutiveLiveFailures, 0);
        expect(controller.state.timeline['gold_points'], hasLength(2));

        lcu.phase = 'EndOfGame';
        live.data = null;
        for (var failure = 1; failure <= 3; failure++) {
          events.changed();
          await _until(
            () => controller.state.consecutiveLiveFailures >= failure,
          );
        }
        expect(controller.state.inGame, false);
        expect(controller.state.liveGame?['_game_ended'], true);
        expect(controller.state.timeline['gold_points'], hasLength(2));

        lcu.connected = false;
        events.changed();
        await _until(() => !controller.state.lcuConnected);
        expect(controller.state.gameflowPhase, 'NO_LCU');
        lcu.connected = true;
        lcu.phase = 'None';
        events.changed();
        await _until(() => controller.state.lcuConnected);
        expect(controller.state.lastError, isNull);
        expect(await database.select(database.sourceRecords).get(), isNotEmpty);
      } finally {
        // Await SQLite shutdown ourselves; the controller's synchronous dispose
        // deliberately does not await its owned foundation.
        controller.foundation = null;
        controller.dispose();
        await foundation.dispose();
      }
    },
  );

  test('event bursts do not overlap a pending reconciliation', () async {
    final lcu = _League()..pendingPhase = Completer<Object?>();
    final events = _Events();
    final database = GodSenseDatabase.inMemory();
    final foundation = NativeLeagueFoundation(
      client: lcu,
      databaseFactory: () async => database,
    );
    final controller = NativeLeagueController(
      lcu: lcu,
      live: _Live(),
      lcuEvents: events,
      foundation: foundation,
    );
    try {
      controller.start();
      await _until(() => lcu.phaseReads == 1);
      for (var index = 0; index < 30; index++) {
        events.changed();
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(lcu.phaseReads, 1);
      lcu.pendingPhase!.complete('None');
      await _until(() => controller.state.lcuConnected);
      expect(controller.state.lastError, isNull);
    } finally {
      controller.foundation = null;
      controller.dispose();
      await foundation.dispose();
    }
  });
}

class _League extends LcuClient {
  String phase = 'None';
  bool connected = true;
  int phaseReads = 0;
  Completer<Object?>? pendingPhase;
  Map<String, dynamic>? itemSets;
  bool rejectItemWrite = false;

  @override
  Future<Object?> put(String path, Object? body) async {
    if (path != '/lol-item-sets/v1/item-sets/7/sets') {
      throw StateError('Unexpected write: $path');
    }
    if (rejectItemWrite) throw StateError('Synthetic item write rejected');
    itemSets = Map<String, dynamic>.from(body as Map);
    return itemSets;
  }

  @override
  Future<LcuCredentials?> discover() async => !connected
      ? null
      : const LcuCredentials(
          port: 1,
          password: 'synthetic-only',
          protocol: 'https',
          lockfilePath: 'synthetic',
        );
  @override
  Future<LcuProbeResponse> getDetailed(String path) async =>
      const LcuProbeResponse.failure(
        failureKind: LcuProbeFailureKind.clientError,
        statusCode: 404,
      );
  @override
  Future<Object?> get(String path) async {
    if (path == '/lol-gameflow/v1/gameflow-phase') {
      phaseReads++;
      return pendingPhase?.future ?? phase;
    }
    return switch (path) {
      '/lol-item-sets/v1/item-sets/7/sets' => itemSets,
      '/lol-summoner/v1/current-summoner' => {
        'summonerId': 7,
        'puuid': 'synthetic-player',
      },
      '/lol-gameflow/v1/session' => {
        'gameData': {'gameId': 42},
      },
      '/lol-game-data/assets/v1/champions/103.json' => {
        'name': 'Ahri',
        'alias': 'Ahri',
      },
      '/lol-champ-select/v1/session' => {
        'localPlayerCellId': 0,
        'myTeam': [
          {'cellId': 0, 'championId': 103, 'assignedPosition': 'MIDDLE'},
        ],
        'theirTeam': <Object?>[],
      },
      _ => null,
    };
  }
}

class _Live extends LiveClientApi {
  Map<String, dynamic>? data;
  @override
  Future<Map<String, dynamic>?> allGameData() async => data;
}

class _Events extends LcuEventStream {
  _Events() : super(credentialsProvider: () => null);
  final _changes = StreamController<LcuApiEvent>.broadcast();
  @override
  Stream<LcuApiEvent> get events => _changes.stream;
  @override
  void start() {}
  void changed() => _changes.add(
    const LcuApiEvent(
      uri: '/lol-gameflow/v1/gameflow-phase',
      eventType: 'Update',
      data: null,
    ),
  );
  @override
  Future<void> dispose() async {
    await _changes.close();
    await super.dispose();
  }
}

Map<String, dynamic> _game(double time) => {
  'gameData': {'gameTime': time, 'gameMode': 'CLASSIC', 'mapNumber': 11},
  'activePlayer': {
    'summonerName': 'Hide on bush#DEMO',
    'currentGold': 800,
    'championStats': {'currentHealth': 900, 'maxHealth': 1000},
  },
  'allPlayers': [
    for (final team in ['ORDER', 'CHAOS'])
      {
        'summonerName': team == 'ORDER' ? 'Hide on bush#DEMO' : 'Opponent#DEMO',
        'championName': team == 'ORDER' ? 'Ahri' : 'Vex',
        'team': team,
        'position': 'MIDDLE',
        'level': 8,
        'scores': {'kills': 1, 'deaths': 1, 'assists': 1, 'creepScore': 80},
        'items': <Object?>[],
      },
  ],
  'events': {'Events': <Object?>[]},
};
