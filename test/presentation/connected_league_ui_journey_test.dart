import 'dart:async';
import 'dart:io';

import 'package:dart_ai_runtime/dart_ai_runtime.dart' as ai;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/application/coach_controller.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/application/native_calibration_controller.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/application/native_league_foundation.dart';
import 'package:godsense/application/native_speech_controller.dart';
import 'package:godsense/infrastructure/league/lcu_event_stream.dart';
import 'package:godsense/infrastructure/league/lcu_probe_transport.dart';
import 'package:godsense/infrastructure/league/league_clients.dart';
import 'package:godsense/infrastructure/native_vision/shared_preferences_calibration_repository.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';
import 'package:godsense/infrastructure/speech/shared_preferences_speech_settings_repository.dart';
import 'package:godsense/presentation/shared/getting_started_guide.dart';
import 'package:godsense/presentation/coach/live/gold_timeline_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'real League controller updates Coach and Live UI through draft, outage and postgame',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        gettingStartedSeenKey: true,
        'godsense.overlay.enabled.v1': false,
      });
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('godsense-connected-ui-'),
      ))!;
      final lcu = _League();
      final live = _Live();
      final events = _Events();
      final database = GodSenseDatabase.inMemory();
      final foundation = NativeLeagueFoundation(
        client: lcu,
        databaseFactory: () async => database,
      );
      final controller = NativeLeagueController(
        lcu: lcu,
        live: live,
        lcuEvents: events,
        foundation: foundation,
      );
      late ProviderContainer container;
      container = ProviderContainer(
        overrides: [
          nativeLeagueProvider.overrideWith((_) => controller),
          nativeCalibrationProvider.overrideWith((_) => _Calibration()),
          nativeSpeechProvider.overrideWith((_) => _Speech()),
          aiRuntimeBootstrapProvider.overrideWith((_) async {}),
          overlayWindowVisibleProvider.overrideWithValue(false),
          overlayWindowManagerProvider.overrideWith(
            (_) => OverlayWindowManager(container),
          ),
          coachGameAssetsProvider.overrideWith((_) async => null),
          aiRuntimeStorageProvider.overrideWithValue(
            ai.AiRuntimeStorage(
              sharedStoreRoot: Directory('${root.path}/shared'),
              applicationDataRoot: Directory('${root.path}/private'),
              applicationId: 'connected-ui-test',
            ),
          ),
        ],
      );
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> waitFor(bool Function() ready) async {
        final completed = await tester.runAsync(() async {
          final timer = Stopwatch()..start();
          while (!ready() && timer.elapsed < const Duration(seconds: 8)) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          return ready();
        });
        expect(completed, isTrue, reason: 'Connected UI transition timed out');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      Future<void> signal() async {
        await tester.runAsync(() async {
          events.changed();
        });
      }

      Future<void> tab(String name) async {
        await tester.tap(
          find.descendant(
            of: find.byType(GodSenseTitleBar),
            matching: find.byTooltip(name),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const GodSenseApp(),
          ),
        );
        await tester.runAsync(() async {
          controller.start();
        });
        await waitFor(() => controller.state.lcuConnected);
        await tab('Coach');
        expect(
          container.read(coachControllerProvider).phase,
          CoachPhase.inactive,
        );

        lcu.phase = 'ChampSelect';
        await signal();
        await waitFor(() => controller.state.lobby.isNotEmpty);
        expect(
          container.read(coachControllerProvider).phase,
          CoachPhase.champSelect,
        );
        expect(find.textContaining('Ahri'), findsWidgets);

        live.data = _game(400);
        lcu.phase = 'InProgress';
        await signal();
        await waitFor(() => controller.state.inGame);
        expect(
          container.read(coachControllerProvider).phase,
          CoachPhase.inGame,
        );
        await tab('En vivo');
        expect(find.textContaining('Ahri'), findsWidgets);
        expect(container.read(effectiveGameProvider)?.gameTime, 400);

        live.data = null;
        await signal();
        await waitFor(() => controller.state.consecutiveLiveFailures > 0);
        expect(controller.state.inGame, isTrue);
        expect(controller.state.liveApiConnected, isFalse);
        expect(container.read(effectiveGameProvider)?.gameTime, 400);
        await tab('Coach');
        expect(
          container.read(coachControllerProvider).phase,
          CoachPhase.inGame,
        );

        live.data = _game(410);
        await signal();
        await waitFor(() => controller.state.liveApiConnected);
        expect(container.read(effectiveGameProvider)?.gameTime, 410);
        expect(
          tester
              .widget<GoldTimelineCard>(find.byType(GoldTimelineCard))
              .points
              .map((point) => point.gameTime),
          [400.0, 410.0],
        );

        lcu.phase = 'EndOfGame';
        live.data = null;
        for (var failure = 1; failure <= 3; failure++) {
          await signal();
          await waitFor(
            () => controller.state.consecutiveLiveFailures >= failure,
          );
        }
        expect(controller.state.inGame, isFalse);
        expect(
          container.read(coachControllerProvider).phase,
          CoachPhase.postGame,
        );
        expect(
          await tester.runAsync(
            () => database.select(database.sourceRecords).get(),
          ),
          isNotEmpty,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        controller.foundation = null;
        container.dispose();
        await tester.runAsync(() async {
          await foundation.dispose();
          await root.delete(recursive: true);
        });
      }
    },
  );
}

class _Calibration extends NativeCalibrationController {
  _Calibration()
    : super(
        SharedPreferencesCalibrationRepository(contextReader: () async => {}),
      ) {
    state = const NativeCalibrationState(loading: false);
  }
}

class _Speech extends NativeSpeechController {
  _Speech() : super(repository: SharedPreferencesSpeechSettingsRepository()) {
    state = const NativeSpeechState(loading: false, modelsChecked: true);
  }
  @override
  void speak(String text) {}
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
