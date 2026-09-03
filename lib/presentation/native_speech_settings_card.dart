import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/godsense_app.dart';
import '../application/native_speech_controller.dart';
import '../infrastructure/speech/speech/live_captions_service.dart';
import '../infrastructure/speech/speech/speech_model_catalog.dart';
import '../infrastructure/speech/tts_service.dart';
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
      title: 'Voz y atajo para hablar',
      subtitle: 'Habla con el coach y escucha sus respuestas. Tu voz se procesa en este equipo.',
      icon: Icons.mic_external_on_rounded,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GsToggleSwitch(
            title: 'Hablar con el coach',
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
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                GsSelect<String>(
                  compact: true,
                  label: 'Tecla para hablar',
                  value: settings.pushToTalkKey,
                  width: 140,
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
                  compact: true,
                  label: 'Idioma que hablas',
                  value: settings.sttLanguage,
                  width: 170,
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
                      'Claridad del micrófono',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: GsColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GsPillToggle(
                      label: 'Reducir ruido de fondo',
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
                      'Reconocimiento de voz',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: GsColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (!state.modelsChecked)
                      const _ModelAvailability(checking: true)
                    else if (state.speechModelInstalled)
                      const _ModelAvailability()
                    else
                      GsButton(
                        label:
                            'Descargar (${_megabytes(SpeechModelCatalog.canary.package.downloadBytes)})',
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
          if (state.speech.phase == LiveCaptionsPhase.downloading)
            if (state.speech.progress case final progress?) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Descargando modelo de reconocimiento…',
                        style: TextStyle(
                          fontSize: 12,
                          color: GsColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: GsColors.cyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: GsColors.surfaceElevated,
                    color: GsColors.cyan,
                  ),
                ],
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
                        fontSize: 13,
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
            title: 'Escuchar las respuestas',
            subtitle: _ttsStatus(state),
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
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                GsSelect<String>(
                  compact: true,
                  label: 'Tipo de voz',
                  value: selectedModel.id,
                  width: 280,
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
                  compact: true,
                  label: 'Voz',
                  value: selectedModel.voice(settings.ttsVoice).id,
                  width: 170,
                  items: {
                    for (final voice in selectedModel.voices)
                      voice.id: voice.label,
                  },
                  onChanged: (value) =>
                      update(settings.copyWith(ttsVoice: value)),
                ),
                GsSelect<String>(
                  compact: true,
                  label: 'Idioma de respuesta',
                  value: selectedModel.supportsLanguage(settings.ttsLanguage)
                      ? settings.ttsLanguage
                      : selectedModel.languages.first.code,
                  width: 160,
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
                      fontSize: 13,
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
                  width: 56,
                  child: Text(
                    '${settings.ttsSpeed.toStringAsFixed(2)}x',
                    style: const TextStyle(
                      fontSize: 13,
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
                crossAxisAlignment: WrapCrossAlignment.start,
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
                        fontSize: 13,
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
                if (!state.modelsChecked)
                  const _ModelAvailability(checking: true)
                else if (!state.ttsModelInstalled)
                  GsButton(
                    label:
                        'Descargar voz (${_megabytes(selectedModel.downloadBytes)})',
                    icon: Icons.download_rounded,
                    compact: true,
                    loading: state.tts.isLoading,
                    onPressed: state.tts.isLoading
                        ? null
                        : controller.downloadTtsModel,
                  )
                else ...[
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
                    label: 'Eliminar voz descargada',
                    icon: Icons.delete_outline_rounded,
                    variant: GsButtonVariant.ghost,
                    compact: true,
                    onPressed: state.tts.isLoading
                        ? null
                        : () => controller.removeTtsModel(selectedModel.id),
                  ),
                ],
              ],
            ),
          ),
          if (state.tts.isLoading)
            if (state.tts.progress case final progress?) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.tts.phase == TtsLoadPhase.downloading
                            ? 'Descargando modelo de voz…'
                            : 'Preparando voz…',
                        style: const TextStyle(
                          fontSize: 12,
                          color: GsColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: GsColors.cyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: GsColors.surfaceElevated,
                    color: GsColors.cyan,
                  ),
                ],
              ),
            ),
          ],
          if (state.error != null) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GsColors.crimsonGlow,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'No pudimos preparar el audio. Vuelve a intentarlo o elige otra voz.',
                style: const TextStyle(color: GsColors.crimson, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _speechStatus(NativeSpeechState state) {
    if (!state.modelsChecked) return 'Comprobando el reconocimiento de voz…';
    if (!state.speechModelInstalled) {
      return 'Necesita una descarga antes de poder escucharte.';
    }
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

class _ModelAvailability extends StatelessWidget {
  const _ModelAvailability({this.checking = false});

  final bool checking;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (checking)
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      else
        const Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: GsColors.emerald,
        ),
      const SizedBox(width: 6),
      Text(
        checking ? 'Comprobando…' : 'Instalado',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: checking ? GsColors.textSecondary : GsColors.emerald,
        ),
      ),
    ],
  );
}
