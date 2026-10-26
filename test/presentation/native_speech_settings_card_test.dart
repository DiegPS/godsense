import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/application/native_speech_controller.dart';
import 'package:godsense/domain/native_speech_settings.dart';
import 'package:godsense/infrastructure/speech/shared_preferences_speech_settings_repository.dart';
import 'package:godsense/infrastructure/speech/speech/live_captions_service.dart';
import 'package:godsense/infrastructure/speech/tts/tts_model_catalog.dart';
import 'package:godsense/infrastructure/speech/tts_service.dart';
import 'package:godsense/presentation/native_speech_settings_card.dart';

void main() {
  late _Speech controller;
  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    controller = _Speech();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [nativeSpeechProvider.overrideWith((_) => controller)],
        child: MaterialApp(
          theme: godsenseTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(child: NativeSpeechSettingsCard()),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'voice controls update settings and reset defaults when changing engines',
    (tester) async {
      await boot(tester);
      final wasEnabled = controller.state.settings.ttsEnabled;
      await tester.tap(find.text('Escuchar las respuestas'));
      await tester.pump();
      expect(controller.state.settings.ttsEnabled, !wasEnabled);
      final denoise = controller.state.settings.sttDenoise;
      await tester.tap(find.text('Reducir ruido de fondo'));
      await tester.pump();
      expect(controller.state.settings.sttDenoise, !denoise);
      for (final model in TtsModelCatalog.models) {
        final select = find.byWidgetPredicate(
          (widget) =>
              widget is GsSelect<String> && widget.label == 'Tipo de voz',
        );
        await tester.tap(
          find.descendant(
            of: select,
            matching: find.byType(DropdownButtonFormField<String>),
          ),
        );
        await tester.pumpAndSettle();
        final option = find.text('${model.name} · ${model.description}').last;
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        await tester.tap(option);
        await tester.pumpAndSettle();
        final settings = controller.state.settings;
        expect(settings.ttsModelId, model.id);
        expect(settings.ttsVoice, model.voices.first.id);
        expect(settings.ttsLanguage, model.languages.first.code);
        expect(settings.ttsSteps, model.defaultSteps);
        expect(
          find.text('Elegir WAV autorizado'),
          model.needsReferenceAudio ? findsOneWidget : findsNothing,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'voice download progress and errors remain visible and recoverable',
    (tester) async {
      await boot(tester);
      controller.publish(
        const NativeSpeechState(
          loading: false,
          modelsChecked: true,
          speech: LiveCaptionsState(
            phase: LiveCaptionsPhase.downloading,
            receivedBytes: 25,
            totalBytes: 100,
          ),
          tts: TtsLoadState(
            phase: TtsLoadPhase.downloading,
            loadedBytes: 50,
            totalBytes: 100,
          ),
          transcript: 'Pregunta sintética',
          error: 'Synthetic internal failure',
        ),
      );
      await tester.pump();
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.textContaining('Última transcripción:'), findsOneWidget);
      expect(
        find.textContaining('No pudimos preparar el audio.'),
        findsOneWidget,
      );
      expect(find.text('Synthetic internal failure'), findsNothing);
      controller.publish(
        const NativeSpeechState(
          loading: false,
          modelsChecked: true,
          ttsModelInstalled: true,
          speechModelInstalled: true,
          ttsBusy: true,
          tts: TtsLoadState(phase: TtsLoadPhase.ready),
        ),
      );
      await tester.pump();
      expect(find.text('25%'), findsNothing);
      expect(
        find.textContaining('No pudimos preparar el audio.'),
        findsNothing,
      );
      await tester.tap(find.text('Detener voz'));
      await tester.pump();
      expect(controller.stops, 1);
      expect(find.text('Detener voz'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _Speech extends NativeSpeechController {
  _Speech() : super(repository: SharedPreferencesSpeechSettingsRepository()) {
    state = const NativeSpeechState(loading: false, modelsChecked: true);
  }
  int stops = 0;
  void publish(NativeSpeechState next) => state = next;
  @override
  Future<void> updateSettings(NativeSpeechSettings settings) async {
    state = state.copyWith(settings: settings);
  }

  @override
  Future<void> stopSpeaking() async {
    stops++;
    state = state.copyWith(ttsBusy: false);
  }
}
