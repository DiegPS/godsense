import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/speech/microphone_test_service.dart';
import 'package:godsense/presentation/shared/microphone_test_panel.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    MicrophoneTestState state, {
    bool enabled = true,
    VoidCallback? start,
    VoidCallback? cancel,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MicrophoneTestPanel(
          state: state,
          enabled: enabled,
          onStart: start ?? () {},
          onCancel: cancel ?? () {},
        ),
      ),
    ),
  );

  testWidgets(
    'idle start works and PTT ownership disables the microphone test',
    (tester) async {
      var starts = 0;
      await show(tester, const MicrophoneTestState(), start: () => starts++);
      await tester.tap(find.text('Probar micrófono'));
      expect(starts, 1);
      await show(
        tester,
        const MicrophoneTestState(),
        enabled: false,
        start: () => starts++,
      );
      expect(
        find.textContaining('Termina de hablar con el coach'),
        findsOneWidget,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Probar micrófono'));
      expect(starts, 1);
    },
  );

  for (final phase in [
    MicrophoneTestPhase.preparing,
    MicrophoneTestPhase.recording,
    MicrophoneTestPhase.playing,
  ]) {
    testWidgets('$phase allows cancel while blocking a duplicate start', (
      tester,
    ) async {
      var cancelled = 0;
      await show(
        tester,
        MicrophoneTestState(phase: phase, level: .5),
        cancel: () => cancelled++,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Cancelar prueba'));
      expect(cancelled, 1);
      if (phase == MicrophoneTestPhase.recording) {
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          .5,
        );
        expect(find.text('Nivel de entrada'), findsOneWidget);
      } else {
        expect(find.byType(LinearProgressIndicator), findsNothing);
      }
    });
  }

  testWidgets('cancelling blocks both buttons until resources are released', (
    tester,
  ) async {
    await show(
      tester,
      const MicrophoneTestState(phase: MicrophoneTestPhase.cancelling),
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
    expect(find.textContaining('liberando el micrófono'), findsOneWidget);
  });

  final results = [
    (
      state: const MicrophoneTestState(phase: MicrophoneTestPhase.completed),
      text: 'Prueba completada.',
    ),
    (
      state: const MicrophoneTestState(
        phase: MicrophoneTestPhase.completed,
        silent: true,
      ),
      text: 'No detectamos señal audible.',
    ),
    (
      state: const MicrophoneTestState(
        phase: MicrophoneTestPhase.error,
        permissionDenied: true,
      ),
      text: 'Windows no permite usar el micrófono.',
    ),
    (
      state: const MicrophoneTestState(
        phase: MicrophoneTestPhase.error,
        cleanupFailed: true,
      ),
      text: 'no se pudo limpiar la carpeta temporal',
    ),
    (
      state: const MicrophoneTestState(phase: MicrophoneTestPhase.error),
      text: 'No pudimos completar la prueba.',
    ),
  ];
  for (final result in results) {
    testWidgets('result explains ${result.text} and permits retry', (
      tester,
    ) async {
      var starts = 0;
      await show(tester, result.state, start: () => starts++);
      expect(find.textContaining(result.text), findsOneWidget);
      expect(find.text('Cancelar prueba'), findsNothing);
      await tester.tap(find.text('Probar micrófono'));
      expect(starts, 1);
    });
  }

  testWidgets(
    'recording and permission errors fit a narrow panel with large text',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final state in [
        const MicrophoneTestState(
          phase: MicrophoneTestPhase.recording,
          level: .75,
        ),
        const MicrophoneTestState(
          phase: MicrophoneTestPhase.error,
          permissionDenied: true,
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: MicrophoneTestPanel(
                    state: state,
                    onStart: () {},
                    onCancel: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
