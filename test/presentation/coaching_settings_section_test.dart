import 'dart:async';

import '../support/ai_models.dart';

import 'package:dart_ai_runtime/dart_ai_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/application/dependencies.dart';

import '../application/ai/ai_conversation_controller_test.dart'
    show FakeSupervisor;

void main() {
  for (final width in [620.0, 1100.0]) {
    testWidgets('coaching settings preview adapts at $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final supervisor = _DownloadSupervisor();
      addTearDown(supervisor.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiModelSelectionProvider.overrideWith(
              (ref) => ReadyModelSelection(),
            ),
            aiRuntimeSupervisorProvider.overrideWithValue(supervisor),
            aiRuntimeSupervisorStateProvider.overrideWith(
              (ref) => supervisor.states,
            ),
          ],
          child: MaterialApp(
            theme: godsenseTheme(),
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: CoachingSettingsSection(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Proveedor del coach'), findsOneWidget);
      expect(find.text('OpenCode'), findsOneWidget);
      expect(find.text('Kilo Code'), findsOneWidget);
      expect(find.text('Modelo y respuestas'), findsOneWidget);
      expect(find.text('Contexto y privacidad'), findsOneWidget);
      expect(find.text('Sin instalar'), findsNWidgets(2));
      expect(find.text('Descargar e instalar'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('downloads, shows progress, then starts the chosen runtime', (
    tester,
  ) async {
    final supervisor = _DownloadSupervisor();
    addTearDown(supervisor.dispose);
    await _show(tester, supervisor);
    await tester.tap(find.text('Descargar e instalar').first);
    await tester.pump();
    expect(find.text('Descargando…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Cancelar instalación'), findsOneWidget);
    supervisor.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Iniciar Kilo Code'), findsOneWidget);
    expect(supervisor.started, isNull);
    await tester.tap(find.text('Iniciar Kilo Code'));
    await tester.pumpAndSettle();
    expect(supervisor.started, AiRuntimeKind.kilo);
    expect(find.text('Detener Kilo Code'), findsOneWidget);
  });

  testWidgets('OpenCode download can be cancelled and retried', (tester) async {
    final supervisor = _DownloadSupervisor();
    addTearDown(supervisor.dispose);
    await _show(tester, supervisor);
    await tester.tap(find.text('Descargar e instalar').last);
    await tester.pump();
    expect(supervisor.state.kind, AiRuntimeKind.openCode);
    await tester.tap(find.text('Cancelar instalación'));
    await tester.pumpAndSettle();
    expect(
      find.text('Instalación cancelada. Puedes volver a intentarlo.'),
      findsOneWidget,
    );
    expect(find.text('Descargar e instalar'), findsNWidgets(2));
    await tester.tap(find.text('Descargar e instalar').last);
    await tester.pump();
    supervisor.pending!.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar OpenCode'));
    await tester.pumpAndSettle();
    expect(supervisor.started, AiRuntimeKind.openCode);
    expect(find.text('Detener OpenCode'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _show(WidgetTester tester, _DownloadSupervisor supervisor) async {
  tester.view.physicalSize = const Size(1200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiModelSelectionProvider.overrideWith((ref) => ReadyModelSelection()),
        aiRuntimeSupervisorProvider.overrideWithValue(supervisor),
        aiRuntimeSupervisorStateProvider.overrideWith(
          (ref) => supervisor.states,
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

class _DownloadSupervisor extends FakeSupervisor {
  final _events = StreamController<AiRuntimeSupervisorState>.broadcast();
  final _installed = <AiRuntimeKind>{};
  AiRuntimeSupervisorState _state = const AiRuntimeSupervisorState();
  Completer<void>? pending;
  AiRuntimeKind? started;

  @override
  AiRuntimeSupervisorState get state => _state;
  @override
  Stream<AiRuntimeSupervisorState> get states => _events.stream;
  @override
  AiRuntimeDefinition definition(AiRuntimeKind kind) =>
      const PinnedAiRuntimeCatalog().definition(kind);
  @override
  Future<bool> isInstalled(AiRuntimeKind kind) async =>
      _installed.contains(kind);
  void emit(AiRuntimeSupervisorState value) {
    _state = value;
    _events.add(value);
  }

  @override
  Future<AiRuntimeInstallation> install(AiRuntimeKind kind) async {
    pending = Completer<void>();
    emit(
      AiRuntimeSupervisorState(
        kind: kind,
        lifecycle: AiRuntimeLifecycle.installing,
        installProgress: const ArtifactInstallProgress(
          phase: ArtifactInstallPhase.downloading,
          message: 'download',
          receivedBytes: 50,
          totalBytes: 100,
        ),
      ),
    );
    try {
      await pending!.future;
      _installed.add(kind);
      return AiRuntimeInstallation(
        definition: definition(kind),
        directoryPath: 'private',
      );
    } finally {
      emit(
        AiRuntimeSupervisorState(
          kind: kind,
          lifecycle: AiRuntimeLifecycle.stopped,
        ),
      );
    }
  }

  @override
  void cancelInstallation() =>
      pending!.completeError(const ArtifactDownloadCancelledException());
  @override
  Future<AiRuntimeEndpoint> start(AiRuntimeKind kind) async {
    started = kind;
    final endpoint = AiRuntimeEndpoint(
      kind: kind,
      baseUri: Uri.parse('http://127.0.0.1:1234'),
      username: kind.id,
      password: 'test',
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
  Future<void> dispose() => _events.close();
}
