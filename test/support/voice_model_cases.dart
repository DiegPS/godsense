import 'package:godsense/infrastructure/speech/tts/tts_model_catalog.dart';

class VoiceModelCase {
  const VoiceModelCase({
    required this.environmentKey,
    required this.model,
    required this.text,
    this.language,
  });
  final String environmentKey;
  final TtsModelDefinition model;
  final String text;
  final String? language;
}

final voiceModelCases = [
  VoiceModelCase(
    environmentKey: 'GODSENSE_SUPERTONIC_MODEL_DIR',
    model: TtsModelCatalog.supertonic,
    text: 'Hola, GodSense está listo.',
    language: 'es',
  ),
  VoiceModelCase(
    environmentKey: 'GODSENSE_PIPER_MX_MODEL_DIR',
    model: TtsModelCatalog.piperMexico,
    text: 'Hola, esta es la voz mexicana de GodSense.',
  ),
  VoiceModelCase(
    environmentKey: 'GODSENSE_PIPER_ES_MODEL_DIR',
    model: TtsModelCatalog.piperSpain,
    text: 'Hola, esta es la voz española de GodSense.',
  ),
  VoiceModelCase(
    environmentKey: 'GODSENSE_KITTEN_MODEL_DIR',
    model: TtsModelCatalog.kitten,
    text: 'GodSense is ready for your next live stream.',
  ),
  VoiceModelCase(
    environmentKey: 'GODSENSE_KOKORO_MODEL_DIR',
    model: TtsModelCatalog.kokoro,
    text: 'GodSense is ready for your next live stream.',
  ),
  VoiceModelCase(
    environmentKey: 'GODSENSE_MATCHA_MODEL_DIR',
    model: TtsModelCatalog.matcha,
    text: 'GodSense is ready for your next live stream.',
  ),
  VoiceModelCase(
    environmentKey: 'GODSENSE_POCKET_MODEL_DIR',
    model: TtsModelCatalog.pocket,
    text: 'GodSense is ready for your next live stream.',
  ),
  VoiceModelCase(
    environmentKey: 'GODSENSE_ZIPVOICE_MODEL_DIR',
    model: TtsModelCatalog.zipVoice,
    text: 'GodSense is ready for your next live stream.',
    language: 'en',
  ),
];

List<Map<String, Object>> voiceModelManifest() => [
  for (final item in voiceModelCases)
    {
      'environment': item.environmentKey,
      'id': item.model.id,
      'key': item.model.storageKey,
      'downloads': [
        for (final download in item.model.downloads)
          {
            'file': download.fileName,
            'url': download.uri.toString(),
            'bytes': download.bytes,
            'sha256': download.sha256,
          },
      ],
    },
];
