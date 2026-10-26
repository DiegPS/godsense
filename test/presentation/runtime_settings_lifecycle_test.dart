import 'dart:async';
import 'dart:io';

import 'package:dart_ai_runtime/dart_ai_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/infrastructure/ai/shared_preferences_ai_runtime_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/ai_models.dart';
import '../application/ai/ai_conversation_controller_test.dart'
    show FakeSupervisor;

void main() {
  late Directory root;
  late _Supervisor supervisor;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('godsense-runtime-controls-');
    supervisor = _Supervisor();
  });
  tearDown(() async {
    await supervisor.dispose();
    await root.delete(recursive: true);
  });
  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiRuntimeSupervisorProvider.overrideWithValue(supervisor),
          aiRuntimeSupervisorStateProvider.overrideWith(
            (_) => supervisor.states,
          ),
          aiModelSelectionProvider.overrideWith((_) => ReadyModelSelection()),
          aiRuntimeStorageProvider.overrideWithValue(
            AiRuntimeStorage(
              sharedStoreRoot: Directory('${root.path}/shared'),
              applicationDataRoot: Directory('${root.path}/private'),
              applicationId: 'runtime-controls-test',
            ),
          ),
        ],
        child: MaterialApp(
          theme: godsenseTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(child: CoachingSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'runtime start and stop persist the selected engine and auto-start preference',
    (tester) async {
      await show(tester);
      await tester.tap(find.text('Iniciar Kilo Code'));
      await tester.pumpAndSettle();
      expect(find.text('Kilo Code iniciado y disponible.'), findsOneWidget);
      final started = await const SharedPreferencesAiRuntimeSettings().load();
      expect(started.preferredKind, AiRuntimeKind.kilo);
      expect(started.autoStart, isTrue);
      await tester.tap(find.text('Detener Kilo Code'));
      await tester.pumpAndSettle();
      expect(supervisor.stops, 1);
      expect(find.text('Kilo Code detenido.'), findsOneWidget);
      expect(
        (await const SharedPreferencesAiRuntimeSettings().load()).autoStart,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending startup disables both engines and closing the panel tolerates its late result',
    (tester) async {
      supervisor.gate = Completer<void>();
      await show(tester);
      await tester.tap(find.text('Iniciar Kilo Code'));
      await tester.pump();
      for (final label in ['Iniciar Kilo Code', 'Iniciar OpenCode']) {
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, label))
              .onPressed,
          isNull,
        );
      }
      expect(supervisor.starts, 1);
      await tester.pumpWidget(const SizedBox());
      supervisor.gate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed startup displays its cause and permits a successful retry',
    (tester) async {
      supervisor.failStart = true;
      await show(tester);
      await tester.tap(find.text('Iniciar Kilo Code'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Synthetic runtime start failure'),
        findsOneWidget,
      );
      supervisor.failStart = false;
      await tester.tap(find.text('Iniciar Kilo Code'));
      await tester.pumpAndSettle();
      expect(supervisor.starts, 2);
      expect(find.text('Kilo Code iniciado y disponible.'), findsOneWidget);
      expect(
        find.textContaining('Synthetic runtime start failure'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed installation lookup can be checked again without downloading',
    (tester) async {
      supervisor.failCheck = true;
      await show(tester);
      expect(find.text('No se pudo comprobar la instalación'), findsOneWidget);
      supervisor.failCheck = false;
      await tester.tap(find.text('Volver a comprobar'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo comprobar la instalación'), findsNothing);
      expect(find.text('Iniciar Kilo Code'), findsOneWidget);
      expect(supervisor.starts, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Supervisor extends FakeSupervisor {
  final _events = StreamController<AiRuntimeSupervisorState>.broadcast();
  AiRuntimeSupervisorState current = const AiRuntimeSupervisorState();
  bool failCheck = false;
  bool failStart = false;
  int starts = 0;
  int stops = 0;
  Completer<void>? gate;
  @override
  AiRuntimeSupervisorState get state => current;
  @override
  Stream<AiRuntimeSupervisorState> get states => _events.stream;
  void emit(AiRuntimeSupervisorState value) {
    current = value;
    _events.add(value);
  }

  @override
  AiRuntimeDefinition definition(AiRuntimeKind kind) =>
      const PinnedAiRuntimeCatalog().definition(kind);
  @override
  Future<bool> isInstalled(AiRuntimeKind kind) async {
    if (failCheck && kind == AiRuntimeKind.kilo) {
      throw StateError('Synthetic storage error');
    }
    return true;
  }

  @override
  Future<AiRuntimeEndpoint> start(AiRuntimeKind kind) async {
    starts++;
    emit(
      AiRuntimeSupervisorState(
        kind: kind,
        lifecycle: AiRuntimeLifecycle.starting,
      ),
    );
    await gate?.future;
    if (failStart) {
      emit(
        AiRuntimeSupervisorState(
          kind: kind,
          lifecycle: AiRuntimeLifecycle.crashed,
          error: 'Synthetic runtime start failure',
        ),
      );
      throw StateError('Synthetic runtime start failure');
    }
    final endpoint = AiRuntimeEndpoint(
      kind: kind,
      baseUri: Uri.parse('http://127.0.0.1:1234'),
      username: 'synthetic',
      password: 'synthetic-only',
      pid: 1,
    );
    emit(
      AiRuntimeSupervisorState(
        kind: kind,
        lifecycle: AiRuntimeLifecycle.ready,
        endpoint: endpoint,
        version: definition(kind).version,
      ),
    );
    return endpoint;
  }

  @override
  Future<void> stop() async {
    stops++;
    emit(
      AiRuntimeSupervisorState(
        kind: current.kind,
        lifecycle: AiRuntimeLifecycle.stopped,
      ),
    );
  }

  @override
  Future<void> dispose() => _events.close();
}
