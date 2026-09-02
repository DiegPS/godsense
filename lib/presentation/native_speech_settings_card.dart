import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/godsense_app.dart';
import '../application/native_speech_controller.dart';
import '../infrastructure/speech/speech/live_captions_service.dart';
import '../infrastructure/speech/speech/speech_model_catalog.dart';
import '../infrastructure/speech/tts/tts_model_catalog.dart';

class NativeSpeechSettingsCard extends ConsumerWidget {
  const NativeSpeechSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nativeSpeechProvider);
    final settings = state.settings;
    final controller = ref.read(nativeSpeechProvider.notifier);
    final selectedModel = TtsModelCatalog.byId(settings.ttsModelId);

    Future<void> update(dynamic next) => controller.updateSettings(next);

    return GsCard(
      title: 'Voz local · Sherpa-ONNX',
      subtitle: 'Push-to-Talk, transcripción y síntesis ejecutados 100% en proceso sin dependencias de red.',
      icon: Icons.mic_external_on_rounded,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GsToggleSwitch(
            title: 'Push-to-Talk local',
            subtitle: _speechStatus(state),
            icon: Icons.mic_none_rounded,
            value: settings.pushToTalkEnabled,
            onChanged: state.loading
                ? null
                : (value) =>
                      update(settings.copyWith(pushToTalkEnabled: value)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                GsSelect<String>(
                  label: 'Tecla global',
                  value: settings.pushToTalkKey,
                  width: 110,
                  items: const {
                    'delete': 'Delete',
                    'space': 'Space',
                    'f8': 'F8',
                    'f9': 'F9',
                    'f10': 'F10',
                    'f11': 'F11',
                    'f12': 'F12',
                  },
                  onChanged: (value) =>
                      update(settings.copyWith(pushToTalkKey: value)),
                ),
                GsSelect<String>(
                  label: 'Idioma STT',
                  value: settings.sttLanguage,
                  width: 120,
                  items: {
                    for (final language in SpeechModelCatalog.canary.languages)
                      language.code: language.label,
                  },
                  onChanged: (value) =>
                      update(settings.copyWith(sttLanguage: value)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Filtro de audio',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: GsColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GsPillToggle(
                      label: 'Reducción de ruido GTCRN',
                      icon: Icons.graphic_eq_rounded,
                      selected: settings.sttDenoise,
                      onToggle: (value) =>
                          update(settings.copyWith(sttDenoise: value)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Modelo de voz',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: GsColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GsButton(
                      label:
                          'Descargar STT (${_megabytes(SpeechModelCatalog.canary.package.downloadBytes)})',
                      icon: Icons.download_rounded,
                      variant: GsButtonVariant.secondary,
                      compact: true,
                      loading:
                          state.speech.phase == LiveCaptionsPhase.downloading,
                      onPressed:
                          state.speech.phase == LiveCaptionsPhase.downloading
                          ? null
                          : controller.downloadSpeechModel,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (state.speech.progress case final progress?) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: GsColors.surfaceElevated,
                color: GsColors.cyan,
              ),
            ),
          ],
          if (state.transcript.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GsColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.record_voice_over_outlined,
                    size: 16,
                    color: GsColors.cyan,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      'Última transcripción: "${state.transcript}"',
                      style: const TextStyle(
                        fontSize: 11,
                        color: GsColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 1, color: Color(0x14FFFFFF)),
          GsToggleSwitch(
            title: 'Respuesta hablada local (TTS)',
            subtitle: state.tts.message,
            icon: Icons.volume_up_outlined,
            value: settings.ttsEnabled,
            onChanged: state.loading
                ? null
                : (value) => update(settings.copyWith(ttsEnabled: value)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                GsSelect<String>(
                  label: 'Modelo TTS',
                  value: selectedModel.id,
                  width: 200,
                  items: {
                    for (final model in TtsModelCatalog.models)
                      model.id: '${model.name} · ${model.description}',
                  },
                  onChanged: (value) {
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
                GsSelect<String>(
                  label: 'Voz',
                  value: selectedModel.voice(settings.ttsVoice).id,
                  width: 140,
                  items: {
                    for (final voice in selectedModel.voices)
                      voice.id: voice.label,
                  },
                  onChanged: (value) =>
                      update(settings.copyWith(ttsVoice: value)),
                ),
                GsSelect<String>(
                  label: 'Idioma TTS',
                  value: selectedModel.supportsLanguage(settings.ttsLanguage)
                      ? settings.ttsLanguage
                      : selectedModel.languages.first.code,
                  width: 120,
                  items: {
                    for (final language in selectedModel.languages)
                      language.code: language.label,
                  },
                  onChanged: (value) =>
                      update(settings.copyWith(ttsLanguage: value)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                const SizedBox(
                  width: 80,
                  child: Text(
                    'Velocidad',
                    style: TextStyle(
                      fontSize: 12,
                      color: GsColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: settings.ttsSpeed,
                    min: 0.6,
                    max: 1.6,
                    divisions: 20,
                    activeColor: GsColors.cyan,
                    inactiveColor: GsColors.surfaceElevated,
                    label: settings.ttsSpeed.toStringAsFixed(2),
                    onChanged: (value) =>
                        update(settings.copyWith(ttsSpeed: value)),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${settings.ttsSpeed.toStringAsFixed(2)}x',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: GsColors.cyan,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (selectedModel.needsReferenceAudio) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  GsButton(
                    label: 'Elegir WAV autorizado',
                    icon: Icons.audio_file_outlined,
                    variant: GsButtonVariant.secondary,
                    compact: true,
                    onPressed: () async {
                      const typeGroup = XTypeGroup(
                        label: 'WAV',
                        extensions: ['wav'],
                      );
                      final file = await openFile(
                        acceptedTypeGroups: const [typeGroup],
                      );
                      if (file != null) {
                        await update(
                          settings.copyWith(referenceAudioPath: file.path),
                        );
                      }
                    },
                  ),
                  SizedBox(
                    width: 300,
                    child: Text(
                      settings.referenceAudioPath.isEmpty
                          ? 'Usará la muestra incluida del modelo'
                          : settings.referenceAudioPath,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: GsColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (selectedModel.needsReferenceText)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: TextFormField(
                  initialValue: settings.referenceText,
                  decoration: const InputDecoration(
                    labelText: 'Transcripción exacta del WAV',
                  ),
                  onFieldSubmitted: (value) =>
                      update(settings.copyWith(referenceText: value)),
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GsButton(
                  label:
                      'Descargar ${selectedModel.name} (${_megabytes(selectedModel.downloadBytes)})',
                  icon: Icons.download_rounded,
                  compact: true,
                  loading: state.tts.isLoading,
                  onPressed: state.tts.isLoading
                      ? null
                      : controller.downloadTtsModel,
                ),
                GsButton(
                  label: 'Probar voz',
                  icon: Icons.volume_up_rounded,
                  variant: GsButtonVariant.secondary,
                  compact: true,
                  onPressed: state.tts.isLoading || state.ttsBusy
                      ? null
                      : controller.testTts,
                ),
                GsButton(
                  label: 'Borrar modelo',
                  icon: Icons.delete_outline_rounded,
                  variant: GsButtonVariant.ghost,
                  compact: true,
                  onPressed: state.tts.isLoading
                      ? null
                      : () => controller.removeTtsModel(selectedModel.id),
                ),
              ],
            ),
          ),
          if (state.tts.progress case final progress?) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: GsColors.surfaceElevated,
                color: GsColors.cyan,
              ),
            ),
          ],
          if (state.error case final error?) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GsColors.crimsonGlow,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                error,
                style: const TextStyle(color: GsColors.crimson, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _speechStatus(NativeSpeechState state) {
    if (state.pushToTalkPressed) return 'Suelta la tecla para transcribir.';
    return switch (state.speech.phase) {
      LiveCaptionsPhase.missingModel => 'Falta descargar Canary 180M.',
      LiveCaptionsPhase.downloading => state.speech.message,
      LiveCaptionsPhase.loading => state.speech.message,
      LiveCaptionsPhase.listening => 'Escuchando mientras mantienes la tecla.',
      LiveCaptionsPhase.transcribing => 'Transcribiendo localmente…',
      LiveCaptionsPhase.error => state.speech.error ?? state.speech.message,
      _ => 'Mantén ${state.settings.pushToTalkKey.toUpperCase()} para hablar.',
    };
  }

  String _megabytes(int bytes) => '${(bytes / 1024 / 1024).round()} MB';
}
