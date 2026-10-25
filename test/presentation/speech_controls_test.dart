import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_speech_controller.dart';
import 'package:godsense/domain/native_speech_settings.dart';
import 'package:godsense/infrastructure/speech/microphone_test_service.dart';
import 'package:godsense/presentation/coach/live/voice_coach_card.dart';
import 'package:godsense/presentation/shared/confirm_hud_reset.dart';
import 'package:godsense/presentation/shared/microphone_test_panel.dart';
import 'package:godsense/presentation/shared/speech_readiness.dart';

void main() {
  testWidgets('microphone test exposes start, level, cancellation and retry', (
    tester,
  ) async {
    var starts = 0;
    var cancels = 0;
    Future<void> show(MicrophoneTestState state) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MicrophoneTestPanel(
            state: state,
            onStart: () => starts++,
            onCancel: () => cancels++,
          ),
        ),
      ),
    );
    await show(const MicrophoneTestState());
    await tester.tap(find.text('Probar micrófono'));
    expect(starts, 1);
    await show(
      const MicrophoneTestState(
        phase: MicrophoneTestPhase.recording,
        level: .5,
      ),
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .5,
    );
    await tester.tap(find.text('Cancelar prueba'));
    expect(cancels, 1);
    await tester.tap(find.text('Probar micrófono'));
    expect(starts, 1);
    await show(
      const MicrophoneTestState(
        phase: MicrophoneTestPhase.error,
        permissionDenied: true,
      ),
    );
    expect(find.textContaining('Windows no permite'), findsOneWidget);
    await tester.tap(find.text('Probar micrófono'));
    expect(starts, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stop speaking is separate from requesting another advice', (
    tester,
  ) async {
    var stops = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceCoachCard(
            processing: false,
            history: const [],
            speaking: true,
            onStopSpeaking: () => stops++,
            statusMessage: 'La voz está desactivada en Ajustes.',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Detener voz'));
    expect(stops, 1);
    expect(find.text('La voz está desactivada en Ajustes.'), findsOneWidget);
  });

  testWidgets(
    'HUD reset requires explicit confirmation and cancel preserves it',
    (tester) async {
      var resets = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  if (await confirmHudReset(context)) resets++;
                },
                child: const Text('Restablecer HUD'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Restablecer HUD'));
      await tester.pumpAndSettle();
      expect(resets, 0);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(resets, 0);
      await tester.tap(find.text('Restablecer HUD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restablecer'));
      await tester.pumpAndSettle();
      expect(resets, 1);
    },
  );

  test('readiness does not claim that missing or disabled voice is active', () {
    const ready = NativeSpeechState(
      settings: NativeSpeechSettings(pushToTalkEnabled: true),
      loading: false,
      modelsChecked: true,
      speechModelInstalled: true,
    );
    expect(speechReadiness(ready).ready, isTrue);
    expect(
      speechReadiness(ready.copyWith(speechModelInstalled: false)).ready,
      isFalse,
    );
    expect(
      speechReadiness(
        ready.copyWith(
          settings: const NativeSpeechSettings(pushToTalkEnabled: false),
        ),
      ).status,
      'Desactivadas',
    );
    expect(
      speechReadiness(
        ready.copyWith(modelsChecked: false, error: 'unavailable'),
      ).status,
      'Revisa la voz',
    );
    expect(
      speechReadiness(
        ready.copyWith(
          microphoneTest: const MicrophoneTestState(
            phase: MicrophoneTestPhase.recording,
          ),
        ),
      ).ready,
      isFalse,
    );
  });
}
