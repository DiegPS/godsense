import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voz local · Sherpa-ONNX',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Push-to-Talk, transcripción y síntesis funcionan dentro de '
              'GodSense. El audio no se sube a ningún servidor.',
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Push-to-Talk local'),
              subtitle: Text(_speechStatus(state)),
              value: settings.pushToTalkEnabled,
              onChanged: state.loading
                  ? null
                  : (value) =>
                        update(settings.copyWith(pushToTalkEnabled: value)),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _DropdownField<String>(
                  label: 'Tecla global',
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
                  onChanged: (value) =>
                      update(settings.copyWith(pushToTalkKey: value)),
                ),
                _DropdownField<String>(
                  label: 'Idioma STT',
                  value: settings.sttLanguage,
                  items: {
                    for (final language in SpeechModelCatalog.canary.languages)
                      language.code: language.label,
                  },
                  onChanged: (value) =>
                      update(settings.copyWith(sttLanguage: value)),
                ),
                FilterChip(
                  label: const Text('Reducción de ruido GTCRN'),
                  selected: settings.sttDenoise,
                  onSelected: (value) =>
                      update(settings.copyWith(sttDenoise: value)),
                ),
                FilledButton.icon(
                  onPressed: state.speech.phase == LiveCaptionsPhase.downloading
                      ? null
                      : controller.downloadSpeechModel,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(
                    'Descargar STT '
                    '(${_megabytes(SpeechModelCatalog.canary.package.downloadBytes)})',
                  ),
                ),
              ],
            ),
            if (state.speech.progress case final progress?) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
            ],
            if (state.transcript.isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText('Última transcripción: ${state.transcript}'),
            ],
            const Divider(height: 32),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Respuesta hablada local'),
              subtitle: Text(state.tts.message),
              value: settings.ttsEnabled,
              onChanged: state.loading
                  ? null
                  : (value) => update(settings.copyWith(ttsEnabled: value)),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _DropdownField<String>(
                  label: 'Modelo TTS',
                  value: selectedModel.id,
                  width: 240,
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
                _DropdownField<String>(
                  label: 'Voz',
                  value: selectedModel.voice(settings.ttsVoice).id,
                  width: 190,
                  items: {
                    for (final voice in selectedModel.voices)
                      voice.id: voice.label,
                  },
                  onChanged: (value) =>
                      update(settings.copyWith(ttsVoice: value)),
                ),
                _DropdownField<String>(
                  label: 'Idioma TTS',
                  value: selectedModel.supportsLanguage(settings.ttsLanguage)
                      ? settings.ttsLanguage
                      : selectedModel.languages.first.code,
                  items: {
                    for (final language in selectedModel.languages)
                      language.code: language.label,
                  },
                  onChanged: (value) =>
                      update(settings.copyWith(ttsLanguage: value)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 90, child: Text('Velocidad')),
                Expanded(
                  child: Slider(
                    value: settings.ttsSpeed,
                    min: 0.6,
                    max: 1.6,
                    divisions: 20,
                    label: settings.ttsSpeed.toStringAsFixed(2),
                    onChanged: (value) =>
                        update(settings.copyWith(ttsSpeed: value)),
                  ),
                ),
              ],
            ),
            if (selectedModel.needsReferenceAudio) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
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
                    icon: const Icon(Icons.audio_file_outlined),
                    label: const Text('Elegir WAV autorizado'),
                  ),
                  SizedBox(
                    width: 320,
                    child: Text(
                      settings.referenceAudioPath.isEmpty
                          ? 'Usará la muestra incluida del modelo'
                          : settings.referenceAudioPath,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (selectedModel.needsReferenceText)
                TextFormField(
                  initialValue: settings.referenceText,
                  decoration: const InputDecoration(
                    labelText: 'Transcripción exacta del WAV',
                  ),
                  onFieldSubmitted: (value) =>
                      update(settings.copyWith(referenceText: value)),
                ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: state.tts.isLoading
                      ? null
                      : controller.downloadTtsModel,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(
                    'Descargar ${selectedModel.name} '
                    '(${_megabytes(selectedModel.downloadBytes)})',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: state.tts.isLoading || state.ttsBusy
                      ? null
                      : controller.testTts,
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('Probar voz'),
                ),
                TextButton.icon(
                  onPressed: state.tts.isLoading
                      ? null
                      : () => controller.removeTtsModel(selectedModel.id),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Borrar modelo'),
                ),
              ],
            ),
            if (state.tts.progress case final progress?) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
            ],
            if (state.error case final error?) ...[
              const SizedBox(height: 12),
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
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

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 170,
  });

  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items.entries
          .map(
            (entry) => DropdownMenuItem<T>(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    ),
  );
}
