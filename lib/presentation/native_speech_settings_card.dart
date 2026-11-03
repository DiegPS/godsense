import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_consistent_ui/flutter_consistent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/godsense_app.dart';
import '../application/native_speech_controller.dart';
import '../infrastructure/speech/speech/live_captions_service.dart';
import '../infrastructure/speech/speech/speech_model_catalog.dart';
import '../infrastructure/speech/tts_service.dart';
import '../infrastructure/speech/tts/tts_model_catalog.dart';
import 'shared/gs_slider.dart';
import 'shared/microphone_test_panel.dart';
import 'shared/speech_readiness.dart';

class NativeSpeechSettingsCard extends ConsumerWidget {
  const NativeSpeechSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nativeSpeechProvider);
    final settings = state.settings;
    final controller = ref.read(nativeSpeechProvider.notifier);
    final selectedModel = TtsModelCatalog.byId(settings.ttsModelId);

    Future<void> update(dynamic next) => controller.updateSettings(next);

    final inputEnabled = settings.pushToTalkEnabled && !state.loading;
    final outputEnabled =
        settings.ttsEnabled && !state.loading && !state.tts.isLoading;

    Future<void> removeVoice() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Eliminar esta voz del equipo?'),
          content: Text(
            'Se eliminará la descarga de ${selectedModel.name}. '
            'Podrás descargarla de nuevo. No se borrarán tus partidas ni tus ajustes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: GsColors.dangerAction,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar descarga'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        await controller.removeTtsModel(selectedModel.id);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Dos funciones independientes: tu micrófono convierte lo que dices en una pregunta; '
            'la voz del coach lee su respuesta. Puedes activar una, ambas o ninguna. '
            'El audio se procesa en este equipo; al consultar IA, la pregunta en texto y el contexto '
            'necesario se envían al proveedor elegido.',
          ),
        ),
        UiSplitView(
          breakpoint: 1000,
          primaryFraction: .5,
          spacing: 20,
          primary: GsCard(
            title: 'Tu micrófono',
            subtitle: 'Lo que tú le dices al coach.',
            icon: Icons.mic_none_rounded,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GsToggleSwitch(
                  title: 'Hablar con el coach',
                  subtitle: _speechStatus(state),
                  icon: Icons.record_voice_over_outlined,
                  value: settings.pushToTalkEnabled,
                  onChanged: state.loading
                      ? null
                      : (value) =>
                            update(settings.copyWith(pushToTalkEnabled: value)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: UiFormFields(
                    children: [
                      _AudioSetupStatus(
                        checking: !state.modelsChecked,
                        installed: state.speechModelInstalled,
                        readyText: 'Reconocimiento instalado en este equipo',
                        missingText: 'Falta descargar el reconocimiento para entender tus preguntas.',
                      ),
                      if (state.modelsChecked && !state.speechModelInstalled)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GsButton(
                            label:
                                'Descargar reconocimiento (${_megabytes(SpeechModelCatalog.canary.package.downloadBytes)})',
                            icon: Icons.download_rounded,
                            loading:
                                state.speech.phase ==
                                LiveCaptionsPhase.downloading,
                            onPressed:
                                !inputEnabled ||
                                    state.speech.phase ==
                                        LiveCaptionsPhase.downloading
                                ? null
                                : controller.downloadSpeechModel,
                          ),
                        ),
                      if (!settings.pushToTalkEnabled)
                        const Text(
                          'Activa “Hablar con el coach” para cambiar la tecla y el idioma. La prueba de micrófono funciona por separado.',
                        ),
                      GsSelect<String>(
                        key: const Key('speech-input-device'),
                        label: 'Micrófono de entrada',
                        value: settings.inputDeviceId,
                        items: {
                          '': 'Predeterminado de Windows',
                          for (final device in state.inputDevices)
                            device.id: device.label,
                          if (settings.inputDeviceId.isNotEmpty &&
                              !state.inputDevices.any(
                                (d) => d.id == settings.inputDeviceId,
                              ))
                            settings.inputDeviceId:
                                'Micrófono guardado (no disponible)',
                        },
                        onChanged:
                            state.loading ||
                                state.microphoneTest.active ||
                                state.speech.isListening ||
                                state.pushToTalkPressed
                            ? null
                            : (id) =>
                                  update(settings.copyWith(inputDeviceId: id)),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed:
                              state.loadingInputDevices ||
                                  state.microphoneTest.active ||
                                  state.speech.isListening ||
                                  state.pushToTalkPressed
                              ? null
                              : controller.refreshInputDevices,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(
                            state.loadingInputDevices
                                ? 'Buscando micrófonos…'
                                : 'Actualizar micrófonos',
                          ),
                        ),
                      ),
                      if (state.inputDevicesError != null)
                        Text(state.inputDevicesError!),
                      UiFormGrid(
                        children: [
                          GsSelect<String>(
                            key: const Key('speech-hotkey'),
                            label: 'Tecla que mantienes al hablar',
                            value: settings.pushToTalkKey,
                            items: const {
                              'delete': 'Delete',
                              'space': 'Space',
                              'f8': 'F8',
                              'f9': 'F9',
                              'f10': 'F10',
                              'f11': 'F11',
                              'f12': 'F12',
                            },
                            onChanged: inputEnabled
                                ? (value) => update(
                                    settings.copyWith(pushToTalkKey: value),
                                  )
                                : null,
                          ),
                          GsSelect<String>(
                            label: 'Idioma de tu pregunta',
                            value: settings.sttLanguage,
                            items: {
                              for (final language
                                  in SpeechModelCatalog.canary.languages)
                                language.code: language.label,
                            },
                            onChanged: inputEnabled
                                ? (value) => update(
                                    settings.copyWith(sttLanguage: value),
                                  )
                                : null,
                          ),
                        ],
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Reducir ruido de fondo'),
                        subtitle: const Text(
                          'Ayuda a reconocer tu voz cuando hay sonido ambiente.',
                        ),
                        value: settings.sttDenoise,
                        onChanged: inputEnabled
                            ? (value) =>
                                  update(settings.copyWith(sttDenoise: value))
                            : null,
                      ),
                      if (state.speech.phase == LiveCaptionsPhase.downloading)
                        _AudioDownloadProgress(
                          label: 'Descargando reconocimiento…',
                          progress: state.speech.progress,
                        ),
                      if (state.transcript.isNotEmpty)
                        SelectableText(
                          'Última transcripción: "${state.transcript}"',
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    'Comprueba tu equipo',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                MicrophoneTestPanel(
                  state: state.microphoneTest,
                  enabled:
                      !state.loading &&
                      !state.pushToTalkPressed &&
                      !state.speech.isListening,
                  onStart: controller.testMicrophone,
                  onCancel: controller.cancelMicrophoneTest,
                ),
              ],
            ),
          ),
          secondary: GsCard(
            title: 'Voz del coach',
            subtitle: 'Cómo escuchas las respuestas que recibes.',
            icon: Icons.volume_up_outlined,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GsToggleSwitch(
                  title: 'Escuchar las respuestas',
                  subtitle: _ttsStatus(state),
                  icon: Icons.headphones_outlined,
                  value: settings.ttsEnabled,
                  onChanged: state.loading
                      ? null
                      : (value) => update(settings.copyWith(ttsEnabled: value)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: UiFormFields(
                    children: [
                      _AudioSetupStatus(
                        checking: !state.modelsChecked,
                        installed: state.ttsModelInstalled,
                        readyText: 'Voz descargada · ${selectedModel.name}',
                        missingText: 'Descarga la voz seleccionada para escuchar al coach.',
                      ),
                      if (!settings.ttsEnabled)
                        const Text(
                          'Activa “Escuchar las respuestas” para cambiar o probar la voz. Tus preferencias se conservan.',
                        ),
                      UiFormGrid(
                        children: [
                          GsSelect<String>(
                            label: 'Idioma de respuesta',
                            value:
                                selectedModel.supportsLanguage(
                                  settings.ttsLanguage,
                                )
                                ? settings.ttsLanguage
                                : selectedModel.languages.first.code,
                            items: {
                              for (final language in selectedModel.languages)
                                language.code: language.label,
                            },
                            onChanged: outputEnabled
                                ? (value) => update(
                                    settings.copyWith(ttsLanguage: value),
                                  )
                                : null,
                          ),
                          GsSelect<String>(
                            label: 'Voz',
                            value: selectedModel.voice(settings.ttsVoice).id,
                            items: {
                              for (final voice in selectedModel.voices)
                                voice.id: voice.label,
                            },
                            onChanged: outputEnabled
                                ? (value) =>
                                      update(settings.copyWith(ttsVoice: value))
                                : null,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              const Text(
                                'Velocidad de lectura',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${settings.ttsSpeed.toStringAsFixed(2)}x',
                                style: const TextStyle(
                                  color: GsColors.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text('1.00x es la velocidad normal.'),
                            ],
                          ),
                          GsSlider(
                            value: settings.ttsSpeed,
                            min: .6,
                            max: 1.6,
                            divisions: 20,
                            label: 'Velocidad de voz',
                            onChanged: outputEnabled
                                ? (value) =>
                                      update(settings.copyWith(ttsSpeed: value))
                                : null,
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (state.modelsChecked && !state.ttsModelInstalled)
                            GsButton(
                              label:
                                  'Descargar voz (${_megabytes(selectedModel.downloadBytes)})',
                              icon: Icons.download_rounded,
                              loading: state.tts.isLoading,
                              onPressed: outputEnabled
                                  ? controller.downloadTtsModel
                                  : null,
                            ),
                          if (state.ttsModelInstalled)
                            GsButton(
                              label: 'Probar voz',
                              icon: Icons.volume_up_rounded,
                              variant: GsButtonVariant.secondary,
                              onPressed:
                                  !outputEnabled ||
                                      state.ttsBusy ||
                                      state.microphoneTest.active
                                  ? null
                                  : controller.testTts,
                            ),
                          if (state.ttsBusy)
                            GsButton(
                              label: 'Detener voz',
                              icon: Icons.stop_circle_outlined,
                              variant: GsButtonVariant.secondary,
                              onPressed: controller.stopSpeaking,
                            ),
                        ],
                      ),
                      if (state.tts.isLoading)
                        _AudioDownloadProgress(
                          label: state.tts.phase == TtsLoadPhase.downloading
                              ? 'Descargando modelo de voz…'
                              : 'Preparando voz…',
                          progress: state.tts.progress,
                        ),
                    ],
                  ),
                ),
                UiDisclosure(
                  key: const ValueKey('voice-advanced'),
                  maintainState: true,
                  title: const Text('Opciones avanzadas de voz'),
                  subtitle: const Text(
                    'Motor de síntesis, muestra de voz y descargas.',
                  ),
                  childrenPadding: const EdgeInsets.all(20),
                  children: [
                    UiFormFields(
                      children: [
                        GsSelect<String>(
                          label: 'Motor de voz',
                          value: selectedModel.id,
                          items: {
                            for (final model in TtsModelCatalog.models)
                              model.id: model.family == TtsModelFamily.vits
                                  ? '${model.name} · ${model.voices.first.label}'
                                  : model.name,
                          },
                          onChanged: !outputEnabled || state.ttsBusy
                              ? null
                              : (value) {
                                  final model = TtsModelCatalog.byId(value);
                                  unawaited(
                                    update(
                                      settings.copyWith(
                                        ttsModelId: model.id,
                                        ttsVoice: model.voices.first.id,
                                        ttsLanguage: model.languages.first.code,
                                        ttsSteps: model.defaultSteps,
                                      ),
                                    ),
                                  );
                                },
                        ),
                        Text(
                          '${selectedModel.voices.length} voces y ${selectedModel.languages.length} idiomas disponibles en este motor.',
                        ),
                        const Text(
                          'Cambiar de motor puede requerir otra descarga. No necesitas modificarlo para usar la voz actual.',
                        ),
                        if (selectedModel.needsReferenceAudio) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GsButton(
                              label: 'Elegir WAV autorizado',
                              icon: Icons.audio_file_outlined,
                              variant: GsButtonVariant.secondary,
                              onPressed: outputEnabled
                                  ? () async {
                                      const typeGroup = XTypeGroup(
                                        label: 'WAV',
                                        extensions: ['wav'],
                                      );
                                      final file = await openFile(
                                        acceptedTypeGroups: const [typeGroup],
                                      );
                                      if (file != null && context.mounted) {
                                        await update(
                                          settings.copyWith(
                                            referenceAudioPath: file.path,
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                            ),
                          ),
                          SelectableText(
                            settings.referenceAudioPath.isEmpty
                                ? 'Se usará la muestra incluida del modelo.'
                                : settings.referenceAudioPath,
                          ),
                          if (selectedModel.needsReferenceText)
                            UiControls.formInput(
                              key: ValueKey(
                                'voice-reference-${selectedModel.id}',
                              ),
                              initialValue: settings.referenceText,
                              enabled: outputEnabled,
                              decoration: const InputDecoration(
                                labelText: 'Transcripción exacta del WAV',
                                helperText: 'Escribe lo que dice la muestra y pulsa Enter para guardar.',
                              ),
                              onFieldSubmitted: (value) => update(
                                settings.copyWith(referenceText: value),
                              ),
                            ),
                        ],
                        if (state.ttsModelInstalled)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GsButton(
                              label: 'Eliminar voz descargada',
                              icon: Icons.delete_outline_rounded,
                              variant: GsButtonVariant.danger,
                              onPressed:
                                  state.loading ||
                                      state.tts.isLoading ||
                                      state.ttsBusy
                                  ? null
                                  : removeVoice,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (state.error != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: GsColors.crimsonGlow,
                borderRadius: BorderRadius.circular(GsSizes.radius),
              ),
              child: const Text(
                'No pudimos preparar el audio. Vuelve a intentarlo o elige otra voz.',
                style: TextStyle(color: GsColors.crimson),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _speechStatus(NativeSpeechState state) {
    final readiness = speechReadiness(state);
    if (!readiness.ready) return readiness.detail;
    if (state.pushToTalkPressed) return 'Suelta la tecla para transcribir.';
    return switch (state.speech.phase) {
      LiveCaptionsPhase.missingModel =>
        'Descarga el reconocimiento de voz para comenzar.',
      LiveCaptionsPhase.downloading => 'Descargando reconocimiento de voz…',
      LiveCaptionsPhase.loading => 'Preparando el micrófono…',
      LiveCaptionsPhase.listening => 'Escuchando mientras mantienes la tecla.',
      LiveCaptionsPhase.transcribing => 'Entendiendo tu pregunta…',
      LiveCaptionsPhase.error =>
        'No pudimos preparar el micrófono. Vuelve a intentarlo.',
      _ => 'Mantén ${state.settings.pushToTalkKey.toUpperCase()} para hablar.',
    };
  }

  String _ttsStatus(NativeSpeechState state) {
    if (!state.settings.ttsEnabled) {
      return 'Las respuestas habladas están desactivadas.';
    }
    if (!state.modelsChecked) return 'Comprobando las voces disponibles…';
    if (!state.ttsModelInstalled) {
      return 'Descarga esta voz para escuchar las respuestas.';
    }
    return switch (state.tts.phase) {
      TtsLoadPhase.idle =>
        state.settings.ttsEnabled
            ? 'La voz se preparará cuando la necesites.'
            : 'Actívala para escuchar las respuestas.',
      TtsLoadPhase.checking || TtsLoadPhase.loading => 'Preparando la voz…',
      TtsLoadPhase.downloading => 'Descargando la voz…',
      TtsLoadPhase.ready => 'Lista para responder.',
      TtsLoadPhase.error => 'La voz necesita atención.',
    };
  }

  String _megabytes(int bytes) => '${(bytes / 1024 / 1024).round()} MB';
}

class _AudioSetupStatus extends StatelessWidget {
  const _AudioSetupStatus({
    required this.checking,
    required this.installed,
    required this.readyText,
    required this.missingText,
  });
  final bool checking, installed;
  final String readyText, missingText;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        checking
            ? Icons.hourglass_top_rounded
            : installed
            ? Icons.check_circle_outline
            : Icons.download_outlined,
        size: 18,
        color: installed ? GsColors.emerald : GsColors.textSecondary,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          checking
              ? 'Comprobando archivos del equipo…'
              : installed
              ? readyText
              : missingText,
          style: TextStyle(
            color: installed ? GsColors.emerald : GsColors.textSecondary,
          ),
        ),
      ),
    ],
  );
}

class _AudioDownloadProgress extends StatelessWidget {
  const _AudioDownloadProgress({required this.label, this.progress});
  final String label;
  final double? progress;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(label),
            if (progress != null) Text('${(progress! * 100).toInt()}%'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress, semanticsLabel: label),
      ],
    ),
  );
}
