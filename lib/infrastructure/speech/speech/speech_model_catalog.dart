import '../tts/tts_model_catalog.dart';

class SpeechLanguageOption {
  const SpeechLanguageOption(this.code, this.label);

  final String code;
  final String label;
}

class SpeechModelDefinition {
  const SpeechModelDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.package,
    required this.languages,
    required this.modelFiles,
    required this.licenseNotice,
  });

  final String id;
  final String name;
  final String description;

  /// Reuses the same verified, resumable Sherpa package installer as TTS.
  /// The TTS-only metadata on this private package is never exposed in UI.
  final TtsModelDefinition package;
  final List<SpeechLanguageOption> languages;
  final Map<String, String> modelFiles;
  final String licenseNotice;

  bool supportsLanguage(String code) =>
      languages.any((language) => language.code == code);

  List<SpeechLanguageOption> targetsFor(String sourceLanguage) {
    if (sourceLanguage == 'en') return languages;
    return languages
        .where(
          (language) =>
              language.code == sourceLanguage || language.code == 'en',
        )
        .toList(growable: false);
  }

  bool supportsDirection(String sourceLanguage, String targetLanguage) =>
      targetsFor(sourceLanguage)
          .any((language) => language.code == targetLanguage);
}

class SpeechModelCatalog {
  static final canary = SpeechModelDefinition(
    id: 'canary-180m-int8',
    name: 'Canary 180M INT8',
    description: 'Offline captions and translation · EN/ES/DE/FR',
    package: TtsModelDefinition(
      id: 'speech-canary-180m-int8',
      version: '2025-07-07-v1',
      name: 'Canary 180M INT8 + Silero VAD',
      description: 'Offline speech recognition package',
      family: TtsModelFamily.vits,
      downloads: [
        TtsModelDownload(
          uri: Uri.parse(
            'https://github.com/k2-fsa/sherpa-onnx/releases/download/'
            'asr-models/sherpa-onnx-nemo-canary-180m-flash-en-es-de-fr-int8.tar.bz2',
          ),
          fileName:
              'sherpa-onnx-nemo-canary-180m-flash-en-es-de-fr-int8.tar.bz2',
          bytes: 153692328,
          sha256: '7a38ed8b13f014ad632b09ff8d22e0c6f1359dd046af9235d281dfae841b9ab9',
          isArchive: true,
        ),
        TtsModelDownload(
          uri: Uri.parse(
            'https://github.com/k2-fsa/sherpa-onnx/releases/download/'
            'asr-models/silero_vad.onnx',
          ),
          fileName: 'silero_vad.onnx',
          targetPath: 'silero_vad.onnx',
          bytes: 643854,
          sha256: '9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6',
        ),
        TtsModelDownload(
          uri: Uri.parse(
            'https://github.com/k2-fsa/sherpa-onnx/releases/download/'
            'speech-enhancement-models/gtcrn_simple.onnx',
          ),
          fileName: 'gtcrn_simple.onnx',
          targetPath: 'gtcrn_simple.onnx',
          bytes: 535638,
          sha256: 'e77603ac0c23dac3227dd2d7135b3a585cbee2679048aecfa886657d3ae1b534',
        ),
      ],
      installedBytes: 208000000,
      archiveRoot: 'sherpa-onnx-nemo-canary-180m-flash-en-es-de-fr-int8',
      requiredFiles: const [
        'encoder.int8.onnx',
        'decoder.int8.onnx',
        'tokens.txt',
        'silero_vad.onnx',
        'gtcrn_simple.onnx',
      ],
      modelFiles: const {},
      languages: const [TtsLanguageOption('es', 'Español')],
      voices: const [TtsVoiceOption('speech', 'Speech', 0)],
      licenseName: 'CC BY 4.0 model / MIT Silero VAD',
      licenseUri: Uri.parse('https://huggingface.co/nvidia/canary-180m-flash'),
    ),
    languages: const [
      SpeechLanguageOption('es', 'Español'),
      SpeechLanguageOption('en', 'English'),
      SpeechLanguageOption('fr', 'Français'),
      SpeechLanguageOption('de', 'Deutsch'),
    ],
    modelFiles: const {
      'encoder': 'encoder.int8.onnx',
      'decoder': 'decoder.int8.onnx',
      'tokens': 'tokens.txt',
      'vad': 'silero_vad.onnx',
      'denoiser': 'gtcrn_simple.onnx',
    },
    licenseNotice:
        'Canary model: CC BY 4.0. Silero VAD: MIT. Runs fully offline.',
  );

  static final models = [canary];

  static SpeechModelDefinition byId(String id) =>
      models.firstWhere((model) => model.id == id, orElse: () => canary);
}
