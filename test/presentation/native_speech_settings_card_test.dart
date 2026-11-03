import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:godsense/infrastructure/speech/microphone_test_service.dart';
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
  Future<void> boot(
    WidgetTester tester, {
    double width = 1400,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    controller = _Speech();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [nativeSpeechProvider.overrideWith((_) => controller)],
        child: MaterialApp(
          theme: godsenseTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: NativeSpeechSettingsCard()),
          ),
        ),
      ),
    );
  }

  for (final setup in [(360.0, 1.5), (900.0, 2.0)]) {
    testWidgets(
      'audio settings remain readable with advanced options at $setup',
      (tester) async {
        await boot(tester, width: setup.$1, scale: setup.$2);
        await tester.ensureVisible(find.text('Opciones avanzadas de voz'));
        await tester.tap(find.text('Opciones avanzadas de voz'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Motor de voz'));
        await tester.pumpAndSettle();
        expect(find.text('Tu micrófono'), findsOneWidget);
        expect(find.text('Voz del coach'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'selects an input even with coach disabled and retains a missing device',
    (tester) async {
      await boot(tester);
      controller.publish(
        controller.state.copyWith(
          inputDevices: const [
            InputDevice(id: 'usb-mic', label: 'USB microphone'),
          ],
          settings: controller.state.settings.copyWith(
            pushToTalkEnabled: false,
          ),
        ),
      );
      await tester.pump();
      final finder = find.byKey(const Key('speech-input-device'));
      tester.widget<GsSelect<String>>(finder).onChanged!('usb-mic');
      await tester.pump();
      expect(controller.state.settings.inputDeviceId, 'usb-mic');
      controller.publish(controller.state.copyWith(inputDevices: []));
      await tester.pump();
      expect(find.text('Micrófono guardado (no disponible)'), findsOneWidget);
      controller.publish(
        controller.state.copyWith(
          microphoneTest: const MicrophoneTestState(
            phase: MicrophoneTestPhase.recording,
          ),
        ),
      );
      await tester.pump();
      expect(tester.widget<GsSelect<String>>(finder).onChanged, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disabled functions retain preferences and block only their settings',
    (tester) async {
      await boot(tester);
      final saved = controller.state.settings;
      controller.publish(
        controller.state.copyWith(
          settings: saved.copyWith(pushToTalkEnabled: false, ttsEnabled: false),
        ),
      );
      await tester.pump();
      for (final field in tester.widgetList<GsSelect<String>>(
        find.byType(GsSelect<String>),
      )) {
        expect(
          field.onChanged,
          field.key == const Key('speech-input-device') ? isNotNull : isNull,
        );
      }
      expect(
        find.textContaining('Tus preferencias se conservan.'),
        findsOneWidget,
      );
      final noise = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Reducir ruido de fondo'),
      );
      expect(noise.onChanged, isNull);
      expect(controller.state.settings.pushToTalkKey, saved.pushToTalkKey);
      expect(controller.state.settings.ttsVoice, saved.ttsVoice);
      await tester.tap(find.text('Hablar con el coach'));
      await tester.pump();
      expect(
        tester
            .widget<GsSelect<String>>(find.byKey(const Key('speech-hotkey')))
            .onChanged,
        isNotNull,
      );
      expect(controller.state.settings.ttsEnabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'deleting a downloaded voice is advanced and requires confirmation',
    (tester) async {
      await boot(tester);
      controller.publish(controller.state.copyWith(ttsModelInstalled: true));
      await tester.pump();
      expect(find.text('Eliminar voz descargada').hitTestable(), findsNothing);
      await tester.ensureVisible(find.text('Opciones avanzadas de voz'));
      await tester.tap(find.text('Opciones avanzadas de voz'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Eliminar voz descargada'));
      await tester.tap(find.text('Eliminar voz descargada'));
      await tester.pumpAndSettle();
      expect(controller.removals, 0);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(controller.removals, 0);
      await tester.tap(find.text('Eliminar voz descargada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar descarga'));
      await tester.pumpAndSettle();
      expect(controller.removals, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'voice controls update settings and reset defaults when changing engines',
    (tester) async {
      await boot(tester);
      final wasEnabled = controller.state.settings.ttsEnabled;
      await tester.tap(find.text('Escuchar las respuestas'));
      await tester.pump();
      expect(controller.state.settings.ttsEnabled, !wasEnabled);
      await tester.tap(find.text('Escuchar las respuestas'));
      await tester.pump();
      final denoise = controller.state.settings.sttDenoise;
      await tester.tap(find.text('Reducir ruido de fondo'));
      await tester.pump();
      expect(controller.state.settings.sttDenoise, !denoise);
      await tester.ensureVisible(find.text('Opciones avanzadas de voz'));
      await tester.tap(find.text('Opciones avanzadas de voz'));
      await tester.pumpAndSettle();
      for (final model in TtsModelCatalog.models) {
        final select = find.byWidgetPredicate(
          (widget) =>
              widget is GsSelect<String> && widget.label == 'Motor de voz',
        );
        await tester.tap(
          find.descendant(
            of: select,
            matching: find.byType(DropdownButtonFormField<String>),
          ),
        );
        await tester.pumpAndSettle();
        final label = model.family == TtsModelFamily.vits
            ? '${model.name} · ${model.voices.first.label}'
            : model.name;
        final option = find.text(label).last;
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
    state = const NativeSpeechState(
      loading: false,
      modelsChecked: true,
      settings: NativeSpeechSettings(pushToTalkEnabled: true, ttsEnabled: true),
    );
  }
  int stops = 0;
  int removals = 0;
  @override
  Future<void> removeTtsModel(String modelId) async {
    removals++;
  }

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
