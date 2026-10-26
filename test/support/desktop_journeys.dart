import 'dart:convert';
import 'dart:io';

import 'package:dart_ai_runtime/dart_ai_runtime.dart' as runtime;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/application/native_calibration_controller.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/application/native_league_foundation.dart';
import 'package:godsense/application/native_speech_controller.dart';
import 'package:godsense/application/vision_session_coordinator.dart';
import 'package:godsense/infrastructure/league/lcu_probe_transport.dart';
import 'package:godsense/infrastructure/native_vision/shared_preferences_calibration_repository.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';
import 'package:godsense/infrastructure/speech/shared_preferences_speech_settings_repository.dart';
import 'package:godsense/presentation/shared/getting_started_guide.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:multiview_desktop/multiview_desktop.dart';

// Shared journeys for the Windows engine and the production multiwindow host.
// External League transport is unavailable, preferences and SQLite are in
// memory, and optional AI files are confined to a unique temporary directory.
void desktopJourneys({bool nativeWindow = false, bool realAi = false}) {
  late ProviderContainer container;
  late _JourneyLeague league;
  late Directory temporary;
  late NativeLeagueFoundation foundation;
  Object? exportFailure;
  bool cancelExport = false;
  runtime.AiRuntimeSupervisor? liveSupervisor;
  runtime.AiRuntimeHealthClient? liveHealth;
  runtime.HttpArtifactDownloader? liveDownloader;
  final kiloExecutable = Platform.environment['GODSENSE_TEST_KILO_EXE'];
  final freeInference =
      Platform.environment['GODSENSE_TEST_KILO_AUTO_FREE'] == 'true';

  void journey(String description, Future<void> Function(WidgetTester) body) {
    if (realAi != description.startsWith('real chat')) return;
    if (nativeWindow && !description.startsWith('all six pages')) return;
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        if (liveSupervisor != null) {
          await tester.runAsync(() => liveSupervisor!.dispose());
          liveHealth!.dispose();
          liveDownloader!.dispose();
          liveSupervisor = null;
        }
        var closed = false;
        final closing = foundation.dispose().whenComplete(() => closed = true);
        for (var attempt = 0; attempt < 150 && !closed; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(
          closed,
          isTrue,
          reason: 'Isolated database must close without hanging',
        );
        await closing;
        await tester.runAsync(() async {
          if (await temporary.exists()) await temporary.delete(recursive: true);
        });
      }
    }, skip: realAi && (kiloExecutable == null || !freeInference));
  }

  Future<void> boot(WidgetTester tester, {bool firstLaunch = false}) async {
    exportFailure = null;
    cancelExport = false;
    SharedPreferences.setMockInitialValues({
      gettingStartedSeenKey: !firstLaunch,
      'godsense.overlay.enabled.v1': false,
    });
    temporary = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('godsense-desktop-journey-'),
    ))!;
    foundation = NativeLeagueFoundation(
      client: _DisconnectedLeague(),
      databaseFactory: () async => GodSenseDatabase.inMemory(),
    );
    league = _JourneyLeague(foundation);
    container = ProviderContainer(
      overrides: [
        if (realAi)
          aiRuntimeSupervisorProvider.overrideWith((ref) {
            liveDownloader = runtime.HttpArtifactDownloader();
            liveHealth = runtime.AiRuntimeHealthClient();
            return liveSupervisor = runtime.AiRuntimeSupervisor(
              installer: runtime.PinnedAiRuntimeInstaller(
                storage: ref.watch(aiRuntimeStorageProvider),
                downloader: liveDownloader!,
                developmentExecutables: {
                  runtime.AiRuntimeKind.kilo: kiloExecutable,
                },
              ),
              processes: ref.watch(aiRuntimeProcessServiceProvider),
              health: liveHealth!,
              allowDownloads: false,
            );
          }),
        overlayWindowManagerProvider.overrideWith(
          (_) => OverlayWindowManager(container),
        ),
        nativeLeagueProvider.overrideWith((_) => league),
        nativeCalibrationProvider.overrideWith((_) => _JourneyCalibration()),
        nativeSpeechProvider.overrideWith((_) => _JourneySpeech()),
        visionSessionCoordinatorProvider.overrideWith(
          (ref) => VisionSessionCoordinator(ref),
        ),
        overlayWindowVisibleProvider.overrideWithValue(false),
        aiRuntimeBootstrapProvider.overrideWith((_) async {}),
        localDataExportDestinationProvider.overrideWithValue((name) async {
          if (exportFailure != null) throw exportFailure!;
          return cancelExport ? null : File('${temporary.path}/$name');
        }),
        coachGameAssetsProvider.overrideWith((_) async => null),
        aiRuntimeStorageProvider.overrideWithValue(
          runtime.AiRuntimeStorage(
            sharedStoreRoot: Directory('${temporary.path}/shared'),
            applicationDataRoot: Directory('${temporary.path}/private'),
            applicationId: 'desktop-test',
          ),
        ),
      ],
    );
    if (realAi) {
      container.listen(aiRuntimeSupervisorStateProvider, (_, _) {});
      await tester.runAsync(
        () => container
            .read(aiRuntimeSupervisorProvider)
            .start(runtime.AiRuntimeKind.kilo),
      );
    }
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (nativeWindow) {
      runGodSense(container: container);
      for (
        var attempt = 0;
        attempt < 250 && find.byType(GodSenseHome).evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.byType(GodSenseHome), findsOneWidget);
    } else {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const GodSenseApp(),
        ),
      );
    }
    await tester.pumpAndSettle();
    if (nativeWindow) {
      expect(MultiViewDesktop.allWindowViewIds, isNotEmpty);
    }
    expect(tester.takeException(), isNull);
  }

  Future<void> navigate(WidgetTester tester, String label, int index) async {
    await tester.tap(
      find.descendant(
        of: find.byType(GodSenseTitleBar),
        matching: find.byTooltip(label),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedPageProvider), index);
    expect(tester.takeException(), isNull, reason: 'Navigation to $label');
  }

  Future<void> nativeAction(WidgetTester tester, Future<void> operation) async {
    var completed = false;
    Object? failure;
    operation.then<void>(
      (_) => completed = true,
      onError: (Object error) {
        failure = error;
        completed = true;
      },
    );
    for (var attempt = 0; attempt < 500 && !completed; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(completed, true, reason: 'Native window operation timed out');
    expect(failure, isNull, reason: 'Native window operation failed');
    await tester.pumpAndSettle();
  }

  Future<void> waitForAi(
    WidgetTester tester,
    bool Function() complete, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!complete() && DateTime.now().isBefore(deadline)) {
      final conversation = container.read(aiConversationProvider);
      expect(conversation.errorMessage, isNull);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(complete(), true, reason: 'Real AI UI operation timed out');
    expect(tester.takeException(), isNull);
  }

  journey(
    'real chat sends from Coach UI, keeps its reply across tabs and clears history',
    (tester) async {
      await boot(tester);
      await navigate(tester, 'Coach', 3);
      await waitForAi(
        tester,
        () => container.read(aiModelSelectionProvider).providers.isNotEmpty,
      );
      final free = container
          .read(aiModelSelectionProvider)
          .providers
          .expand((provider) => provider.models)
          .singleWhere(
            (model) =>
                model.providerId == 'kilo' && model.id == 'kilo-auto/free',
          );
      expect(free.isFree, true);
      await tester.runAsync(
        () =>
            container.read(aiModelSelectionProvider.notifier).select(free.key),
      );
      await tester.pumpAndSettle();
      final input = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.hintText?.startsWith('Pregunta al coach') ??
                false),
      );
      await tester.ensureVisible(input);
      await tester.enterText(
        input,
        'Responde brevemente: ¿qué rol juega Ahri en League of Legends?',
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      await navigate(tester, 'Inicio', 0);
      await waitForAi(tester, () {
        final state = container.read(aiConversationProvider);
        return !state.isBusy &&
            state.messages.length == 2 &&
            state.messages.last.role == 'assistant';
      }, timeout: const Duration(seconds: 220));
      final answer = container
          .read(aiConversationProvider)
          .messages
          .last
          .content;
      expect(answer.trim(), isNotEmpty);
      await navigate(tester, 'Coach', 3);
      expect(
        container.read(aiConversationProvider).messages.last.content,
        answer,
      );
      final clear = find.byTooltip('Limpiar chat');
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      await waitForAi(
        tester,
        () => container.read(aiConversationProvider).messages.isEmpty,
      );
      expect(container.read(aiConversationProvider).sessionId, isNull);
    },
  );

  journey('first launch guide completes and help opens it again', (
    tester,
  ) async {
    await boot(tester, firstLaunch: true);
    expect(find.text('Primeros pasos con GodSense'), findsOneWidget);
    await tester.tap(find.text('Configurar voz'));
    await tester.pumpAndSettle();
    expect(container.read(selectedPageProvider), 5);
    expect(
      (await SharedPreferences.getInstance()).getBool(gettingStartedSeenKey),
      true,
    );
    await tester.tap(find.byTooltip('Guía y atajos'));
    await tester.pumpAndSettle();
    expect(find.text('Primeros pasos con GodSense'), findsOneWidget);
    await tester.tap(find.text('Abrir Mapa'));
    await tester.pumpAndSettle();
    expect(container.read(selectedPageProvider), 2);
    expect(tester.takeException(), isNull);
  });

  journey('all six pages navigate repeatedly and retain Scout input', (
    tester,
  ) async {
    await boot(tester);
    for (var round = 0; round < 3; round++) {
      for (final destination in [
        ('En vivo', 1),
        ('Mapa', 2),
        ('Coach', 3),
        ('Scout', 4),
        ('Ajustes', 5),
        ('Inicio', 0),
      ]) {
        await navigate(tester, destination.$1, destination.$2);
      }
    }
    await navigate(tester, 'Scout', 4);
    final name = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Nombre de Riot',
    );
    await tester.enterText(name, 'Hide on bush');
    await navigate(tester, 'Coach', 3);
    await navigate(tester, 'Scout', 4);
    expect(tester.widget<TextField>(name).controller?.text, 'Hide on bush');
    if (nativeWindow) {
      final manager = container.read(overlayWindowManagerProvider);
      final owner = tester.element(find.byType(GodSenseHome));
      final originalWindows = MultiViewDesktop.allWindowViewIds.length;
      try {
        await nativeAction(tester, manager.prewarm(owner).then<void>((_) {}));
        final id = manager.viewId;
        expect(id, isNotNull);
        expect(MultiViewDesktop.allWindowViewIds.length, originalWindows + 1);
        expect(manager.isOpen, false);
        await nativeAction(tester, manager.show(owner));
        expect(manager.isOpen, true);
        expect(
          await tester.runAsync(() => MultiViewDesktop.fromId(id!).isVisible()),
          true,
        );
        for (var round = 0; round < 5; round++) {
          await nativeAction(
            tester,
            Future.wait([
              manager.show(owner),
              manager.hide(),
              manager.show(owner),
              manager.hide(),
            ]).then<void>((_) {}),
          );
          expect(manager.isOpen, false);
          expect(manager.viewId, id);
          expect(MultiViewDesktop.allWindowViewIds.length, originalWindows + 1);
        }
        expect(
          await tester.runAsync(() => MultiViewDesktop.fromId(id!).isVisible()),
          false,
        );
      } finally {
        final id = manager.viewId;
        if (id != null && MultiViewDesktop.allWindowViewIds.contains(id)) {
          await nativeAction(tester, MultiViewDesktop.fromId(id).closeWindow());
        }
      }
      expect(manager.viewId, isNull);
      expect(manager.isOpen, false);
      expect(MultiViewDesktop.allWindowViewIds.length, originalWindows);
    }
    expect(tester.takeException(), isNull);
  });

  journey('all pages remain operable at small windows and large text scales', (
    tester,
  ) async {
    await boot(tester);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final configuration in [
      (const Size(900, 600), 1.0),
      (const Size(1200, 760), 1.5),
      (const Size(1920, 1080), 2.0),
    ]) {
      tester.view.physicalSize = configuration.$1;
      tester.platformDispatcher.textScaleFactorTestValue = configuration.$2;
      await tester.pumpAndSettle();
      for (final destination in [
        ('En vivo', 1),
        ('Mapa', 2),
        ('Coach', 3),
        ('Scout', 4),
        ('Ajustes', 5),
        ('Inicio', 0),
      ]) {
        await navigate(tester, destination.$1, destination.$2);
      }
    }
  });

  journey('coach follows game lifecycle and manual phase controls', (
    tester,
  ) async {
    await boot(tester);
    await navigate(tester, 'Coach', 3);
    league.publish(
      const NativeLeagueState(lcuConnected: true, gameflowPhase: 'ChampSelect'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Auto · Selección'), findsOneWidget);
    league.publish(
      const NativeLeagueState(
        lcuConnected: true,
        gameflowPhase: 'InProgress',
        liveGame: {
          'game_time': 900.0,
          'team_gold_diff': 1250,
          'allies': <Map<String, dynamic>>[],
          'enemies': <Map<String, dynamic>>[],
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Auto · En partida'), findsOneWidget);
    await tester.tap(find.text('Postpartida'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Resumen'), findsWidgets);
    await tester.tap(find.text('Auto · En partida'));
    await tester.pumpAndSettle();
    expect(find.text('Recomendaciones tácticas'), findsOneWidget);
    league.publish(const NativeLeagueState(gameflowPhase: 'NO_LCU'));
    await tester.pumpAndSettle();
    expect(find.text('Auto · Inactivo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  journey(
    'live page preserves stale telemetry and renders objectives and events',
    (tester) async {
      await boot(tester);
      await navigate(tester, 'En vivo', 1);
      expect(find.text('Esperando a que empiece la partida…'), findsOneWidget);
      final game = <String, dynamic>{
        'game_time': 900.0,
        'phase': 'mid',
        'team_state': 'ahead',
        'team_gold_diff': 1250,
        'allies': <Map<String, dynamic>>[],
        'enemies': <Map<String, dynamic>>[],
        'derived': {
          'objectives': {
            'dragon': {'respawn_in': 45},
            'baron': {'respawn_in': 0},
          },
        },
      };
      league.publish(
        NativeLeagueState(
          lcuConnected: true,
          liveApiConnected: true,
          gameflowPhase: 'InProgress',
          liveGame: game,
          timeline: const {
            'gold_points': [
              [300, -100],
              [900, 1250],
            ],
            'events': [
              {
                'game_time': 890,
                'type': 'ChampionKill',
                'message': 'Synthetic event',
              },
            ],
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('15:00'), findsWidgets);
      expect(find.text('OBJETIVOS DE MAPA'), findsOneWidget);
      league.publish(league.state.copyWith(liveApiConnected: false));
      await tester.pumpAndSettle();
      expect(
        find.text('Actualización de partida interrumpida'),
        findsOneWidget,
      );
      expect(find.text('15:00'), findsWidgets);
      league.publish(
        league.state.copyWith(
          liveApiConnected: true,
          liveGame: {...game, '_game_ended': true},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('FINALIZADA'), findsOneWidget);
      expect(find.text('Actualización de partida interrumpida'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  journey(
    'live roster, opponent abilities, gold chart and event history can be explored',
    (tester) async {
      await boot(tester);
      final ally = <String, dynamic>{
        'champion_name': 'Ahri',
        'summoner_name': 'Hide on bush',
        'tag_line': 'DEMO',
        'role': 'MIDDLE',
        'level': 10,
        'kda': [4, 1, 2],
        'cs': 110,
        'gold_total': 7000,
        'health_ratio': .8,
        'items': [
          {'displayName': 'Synthetic boots', 'item_id': 1001},
        ],
        'spell_icons': <String>[],
      };
      final enemy = <String, dynamic>{
        ...ally,
        'champion_name': 'Vex',
        'summoner_name': 'Opponent',
        'kda': [1, 4, 0],
        'is_dead': true,
        'respawn_timer': 24.0,
        'gold_total': 5800,
        'abilities': [
          {
            'slot': 'Q',
            'name': 'Synthetic ability',
            'cooldown': 8,
            'cost': 50,
            'range': 800,
            'description': 'Synthetic ability description.',
          },
        ],
      };
      league.publish(
        NativeLeagueState(
          lcuConnected: true,
          liveApiConnected: true,
          gameflowPhase: 'InProgress',
          liveGame: {
            'game_time': 950.0,
            'phase': 'in_progress',
            'team_state': 'AHEAD',
            'team_gold_diff': 1200,
            'active_player': ally,
            'allies': [ally],
            'enemies': [enemy],
            'derived': {
              'objectives': {
                'dragon': {'respawn_in': 25, 'status': 'respawning'},
                'baron': {'status': 'alive'},
              },
            },
          },
          timeline: {
            'gold_points': [
              [900, -100],
              [925, 0],
              [950, 1200],
            ],
            'events': [
              {'EventName': 'DragonKill', 'game_time_fmt': '15:20'},
              {'EventName': 'TurretKilled', 'game_time_fmt': '15:40'},
            ],
          },
        ),
      );
      await navigate(tester, 'En vivo', 1);
      final scrolling = find
          .descendant(
            of: find.byType(LivePage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Ahri · MIDDLE'),
        250,
        scrollable: scrolling,
      );
      await tester.tap(find.text('Ahri · MIDDLE'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Synthetic boots'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Q · Synthetic ability'),
        250,
        scrollable: scrolling,
      );
      await tester.tap(find.text('Q · Synthetic ability'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic ability description.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('REGISTRO DE EVENTOS'),
        250,
        scrollable: scrolling,
      );
      await tester.pumpAndSettle();
      expect(find.text('Dragón eliminado'), findsOneWidget);
      expect(find.text('Torre destruida'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  journey('local data retention and deletion operate on an isolated database', (
    tester,
  ) async {
    await boot(tester);
    await navigate(tester, 'Ajustes', 5);
    await tester.scrollUntilVisible(
      find.text('Aplicar retención'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.runAsync(() => tester.tap(find.text('Aplicar retención')));
    await _waitForText(tester, 'No había datos vencidos para eliminar.');
    await tester.tap(find.text('Borrar datos locales'));
    await tester.pumpAndSettle();
    expect(find.text('¿Borrar los datos locales?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Borrar los datos locales?'), findsNothing);
    await tester.tap(find.text('Borrar datos locales'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => tester.tap(find.text('Borrar definitivamente')),
    );
    await _waitForText(tester, 'Los datos locales de League se borraron.');
    expect(league.deletions, 1);
    expect(tester.takeException(), isNull);
  });

  journey('export writes valid JSON and cancellation leaves the app usable', (
    tester,
  ) async {
    await boot(tester);
    await navigate(tester, 'Ajustes', 5);
    await tester.scrollUntilVisible(
      find.text('Exportar mis datos'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    cancelExport = true;
    await tester.tap(find.text('Exportar mis datos'));
    await tester.pumpAndSettle();
    expect(temporary.listSync().whereType<File>(), isEmpty);
    cancelExport = false;
    await tester.runAsync(() => tester.tap(find.text('Exportar mis datos')));
    for (var attempt = 0; attempt < 150; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (find.textContaining('Datos exportados en').evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.textContaining('Datos exportados en'), findsOneWidget);
    final exports = temporary.listSync().whereType<File>().toList();
    expect(exports, hasLength(1));
    expect(jsonDecode(exports.single.readAsStringSync()), isA<Map>());
    expect(tester.takeException(), isNull);
  });

  journey('native save dialog failure is reported and can be retried', (
    tester,
  ) async {
    await boot(tester);
    await navigate(tester, 'Ajustes', 5);
    await tester.scrollUntilVisible(
      find.text('Exportar mis datos'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    exportFailure = StateError('Synthetic unavailable file dialog');
    await tester.tap(find.text('Exportar mis datos'));
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudo completar la operación. Revisa el registro local.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    exportFailure = null;
    cancelExport = true;
    await tester.tap(find.text('Exportar mis datos'));
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudo completar la operación. Revisa el registro local.'),
      findsNothing,
    );
  });
}

Future<void> _waitForText(WidgetTester tester, String text) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (find.text(text).evaluate().isNotEmpty) return;
  }
  expect(find.text(text), findsOneWidget);
}

class _JourneyLeague extends NativeLeagueController {
  _JourneyLeague(NativeLeagueFoundation foundation)
    : super(foundation: foundation);
  var deletions = 0;
  void publish(NativeLeagueState value) => state = value;
  @override
  void dispose() {
    // The fixture awaits disposal itself, avoiding concurrent close calls.
    foundation = null;
    super.dispose();
  }

  @override
  Future<void> deleteAllLocalData() async {
    await super.deleteAllLocalData();
    deletions++;
  }
}

class _JourneyCalibration extends NativeCalibrationController {
  _JourneyCalibration()
    : super(
        SharedPreferencesCalibrationRepository(contextReader: () async => {}),
      ) {
    state = const NativeCalibrationState(loading: false);
  }
}

class _JourneySpeech extends NativeSpeechController {
  _JourneySpeech()
    : super(repository: SharedPreferencesSpeechSettingsRepository()) {
    state = const NativeSpeechState(loading: false, modelsChecked: true);
  }
}

class _DisconnectedLeague implements LcuReadTransport {
  @override
  Future<Object?> get(String path) async => null;
  @override
  Future<LcuProbeResponse> getDetailed(String path) async =>
      const LcuProbeResponse.failure(
        failureKind: LcuProbeFailureKind.disconnected,
      );
}
