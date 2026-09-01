enum TtsModelFamily {
  supertonic,
  vits,
  matcha,
  kokoro,
  kitten,
  zipvoice,
  pocket,
}

enum TtsReferenceMode { none, audio, audioAndText }

class TtsVoiceOption {
  final String id;
  final String label;
  final int speakerId;
  final String? referenceAudio;
  final String referenceText;

  const TtsVoiceOption(
    this.id,
    this.label,
    this.speakerId, {
    this.referenceAudio,
    this.referenceText = '',
  });
}

class TtsLanguageOption {
  final String code;
  final String label;
  const TtsLanguageOption(this.code, this.label);
}

class TtsModelDownload {
  final Uri uri;
  final String fileName;
  final int bytes;
  final String sha256;
  final bool isArchive;
  final String? targetPath;

  const TtsModelDownload({
    required this.uri,
    required this.fileName,
    required this.bytes,
    required this.sha256,
    this.isArchive = false,
    this.targetPath,
  });
}

class TtsModelDefinition {
  final String id;
  final String version;
  final String name;
  final String description;
  final TtsModelFamily family;
  final List<TtsModelDownload> downloads;
  final int installedBytes;
  final String archiveRoot;
  final List<String> requiredFiles;
  final List<String> removeAfterExtract;
  final Map<String, String> modelFiles;
  final List<TtsLanguageOption> languages;
  final List<TtsVoiceOption> voices;
  final TtsReferenceMode referenceMode;
  final int defaultSteps;
  final int maxSentences;
  final double silenceScale;
  final String licenseName;
  final Uri licenseUri;
  final String? licenseNotice;

  const TtsModelDefinition({
    required this.id,
    required this.version,
    required this.name,
    required this.description,
    required this.family,
    required this.downloads,
    required this.installedBytes,
    required this.archiveRoot,
    required this.requiredFiles,
    required this.modelFiles,
    required this.languages,
    required this.voices,
    required this.licenseName,
    required this.licenseUri,
    this.removeAfterExtract = const [],
    this.referenceMode = TtsReferenceMode.none,
    this.defaultSteps = 5,
    this.maxSentences = 1,
    this.silenceScale = 0.2,
    this.licenseNotice,
  });

  String get storageKey => '$id-$version';
  int get downloadBytes =>
      downloads.fold(0, (total, download) => total + download.bytes);
  int get downloadFiles => downloads.length;
  String get integrityKey => downloads
      .map((download) => '${download.fileName}:${download.sha256}')
      .join('|');
  bool get needsReferenceAudio => referenceMode != TtsReferenceMode.none;
  bool get needsReferenceText => referenceMode == TtsReferenceMode.audioAndText;

  bool supportsLanguage(String code) =>
      languages.any((language) => language.code == code);

  TtsVoiceOption voice(String id) =>
      voices.firstWhere((voice) => voice.id == id, orElse: () => voices.first);
}

const _supertonicLanguages = <TtsLanguageOption>[
  TtsLanguageOption('es', 'Español'),
  TtsLanguageOption('en', 'English'),
  TtsLanguageOption('pt', 'Português'),
  TtsLanguageOption('fr', 'Français'),
  TtsLanguageOption('de', 'Deutsch'),
  TtsLanguageOption('it', 'Italiano'),
  TtsLanguageOption('nl', 'Nederlands'),
  TtsLanguageOption('pl', 'Polski'),
  TtsLanguageOption('tr', 'Türkçe'),
  TtsLanguageOption('sv', 'Svenska'),
  TtsLanguageOption('da', 'Dansk'),
  TtsLanguageOption('fi', 'Suomi'),
  TtsLanguageOption('cs', 'Čeština'),
  TtsLanguageOption('hu', 'Magyar'),
  TtsLanguageOption('ro', 'Română'),
  TtsLanguageOption('bg', 'Български'),
  TtsLanguageOption('el', 'Ελληνικά'),
  TtsLanguageOption('uk', 'Українська'),
  TtsLanguageOption('vi', 'Tiếng Việt'),
  TtsLanguageOption('hi', 'हिन्दी'),
  TtsLanguageOption('id', 'Bahasa Indonesia'),
  TtsLanguageOption('hr', 'Hrvatski'),
  TtsLanguageOption('et', 'Eesti'),
  TtsLanguageOption('ja', '日本語'),
  TtsLanguageOption('ko', '한국어'),
  TtsLanguageOption('ar', 'العربية'),
  TtsLanguageOption('ru', 'Русский'),
  TtsLanguageOption('lt', 'Lietuvių'),
  TtsLanguageOption('lv', 'Latviešu'),
  TtsLanguageOption('sk', 'Slovenčina'),
  TtsLanguageOption('sl', 'Slovenščina'),
];

const _supertonicVoices = <TtsVoiceOption>[
  TtsVoiceOption('F1', 'F1 · Femenina 1', 0),
  TtsVoiceOption('F2', 'F2 · Femenina 2', 1),
  TtsVoiceOption('F3', 'F3 · Femenina 3', 2),
  TtsVoiceOption('F4', 'F4 · Femenina 4', 3),
  TtsVoiceOption('F5', 'F5 · Femenina 5', 4),
  TtsVoiceOption('M1', 'M1 · Masculina 1', 5),
  TtsVoiceOption('M2', 'M2 · Masculina 2', 6),
  TtsVoiceOption('M3', 'M3 · Masculina 3', 7),
  TtsVoiceOption('M4', 'M4 · Masculina 4', 8),
  TtsVoiceOption('M5', 'M5 · Masculina 5', 9),
];

const _kokoroVoices = <TtsVoiceOption>[
  TtsVoiceOption('af', 'American Female', 0),
  TtsVoiceOption('af_bella', 'Bella · US', 1),
  TtsVoiceOption('af_nicole', 'Nicole · US', 2),
  TtsVoiceOption('af_sarah', 'Sarah · US', 3),
  TtsVoiceOption('af_sky', 'Sky · US', 4),
  TtsVoiceOption('am_adam', 'Adam · US', 5),
  TtsVoiceOption('am_michael', 'Michael · US', 6),
  TtsVoiceOption('bf_emma', 'Emma · UK', 7),
  TtsVoiceOption('bf_isabella', 'Isabella · UK', 8),
  TtsVoiceOption('bm_george', 'George · UK', 9),
  TtsVoiceOption('bm_lewis', 'Lewis · UK', 10),
];

const _kittenVoices = <TtsVoiceOption>[
  TtsVoiceOption('female-1', 'Female 1', 0),
  TtsVoiceOption('male-1', 'Male 1', 1),
  TtsVoiceOption('female-2', 'Female 2', 2),
  TtsVoiceOption('male-2', 'Male 2', 3),
  TtsVoiceOption('female-3', 'Female 3', 4),
  TtsVoiceOption('male-3', 'Male 3', 5),
  TtsVoiceOption('female-4', 'Female 4', 6),
  TtsVoiceOption('male-4', 'Male 4', 7),
];

Uri _ttsAsset(String name) => Uri.parse(
  'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/$name',
);

class TtsModelCatalog {
  static final TtsModelDefinition supertonic = TtsModelDefinition(
    id: 'supertonic-3-hybrid',
    version: '2026-05-11-v1',
    name: 'Supertonic',
    description: '31 languages, 10 voices, hybrid quantization',
    family: TtsModelFamily.supertonic,
    downloads: [
      TtsModelDownload(
        uri: _ttsAsset('sherpa-onnx-supertonic-3-tts-int8-2026-05-11.tar.bz2'),
        fileName: 'sherpa-onnx-supertonic-3-tts-int8-2026-05-11.tar.bz2',
        bytes: 128774318,
        sha256:
            '82fa96f91c4ef8abaae3a14a3f4153facf88bed821d1f7331cec2700f432c427',
        isArchive: true,
      ),
      TtsModelDownload(
        uri: Uri.parse(
          'https://huggingface.co/Supertone/supertonic-3/resolve/main/onnx/vocoder.onnx',
        ),
        fileName: 'supertonic-3-vocoder-fp32.onnx',
        targetPath: 'vocoder.fp32.onnx',
        bytes: 101424195,
        sha256:
            '085de76dd8e8d5836d6ca66826601f615939218f90e519f70ee8a36ed2a4c4ba',
      ),
    ],
    installedBytes: 220749478,
    archiveRoot: 'sherpa-onnx-supertonic-3-tts-int8-2026-05-11',
    requiredFiles: const [
      'duration_predictor.int8.onnx',
      'text_encoder.int8.onnx',
      'vector_estimator.int8.onnx',
      'vocoder.fp32.onnx',
      'tts.json',
      'unicode_indexer.bin',
      'voice.bin',
    ],
    removeAfterExtract: const ['vocoder.int8.onnx'],
    modelFiles: const {
      'durationPredictor': 'duration_predictor.int8.onnx',
      'textEncoder': 'text_encoder.int8.onnx',
      'vectorEstimator': 'vector_estimator.int8.onnx',
      'vocoder': 'vocoder.fp32.onnx',
      'ttsJson': 'tts.json',
      'unicodeIndexer': 'unicode_indexer.bin',
      'voiceStyle': 'voice.bin',
    },
    languages: _supertonicLanguages,
    voices: _supertonicVoices,
    licenseName: 'OpenRAIL-M',
    licenseUri: Uri.parse(
      'https://huggingface.co/Supertone/supertonic-3/blob/main/LICENSE',
    ),
  );

  static final TtsModelDefinition piperMexico = TtsModelDefinition(
    id: 'piper-es-mx-claude-high-int8',
    version: '2025-12-05',
    name: 'Piper',
    description: 'Mexican Spanish, high-quality Claude voice',
    family: TtsModelFamily.vits,
    downloads: [
      TtsModelDownload(
        uri: _ttsAsset('vits-piper-es_MX-claude-high-int8.tar.bz2'),
        fileName: 'vits-piper-es_MX-claude-high-int8.tar.bz2',
        bytes: 21216685,
        sha256:
            '0f9fc9c07d2e17bdc0f5f33a657addae92085da85704cb86a861e59d32f3bbfa',
        isArchive: true,
      ),
    ],
    installedBytes: 36302418,
    archiveRoot: 'vits-piper-es_MX-claude-high-int8',
    requiredFiles: const [
      'es_MX-claude-high.onnx',
      'tokens.txt',
      'espeak-ng-data',
    ],
    modelFiles: const {
      'model': 'es_MX-claude-high.onnx',
      'tokens': 'tokens.txt',
      'dataDir': 'espeak-ng-data',
    },
    languages: const [TtsLanguageOption('es-MX', 'Español (México)')],
    voices: const [TtsVoiceOption('claude', 'Claude · Masculina', 0)],
    licenseName: 'Apache-2.0',
    licenseUri: Uri.parse(
      'https://huggingface.co/spaces/HirCoir/Piper-TTS-Spanish',
    ),
  );

  static final TtsModelDefinition piperSpain = TtsModelDefinition(
    id: 'piper-es-es-davefx-medium-int8',
    version: '2025-12-05',
    name: 'Piper',
    description: 'European Spanish, medium-quality DaveFX voice',
    family: TtsModelFamily.vits,
    downloads: [
      TtsModelDownload(
        uri: _ttsAsset('vits-piper-es_ES-davefx-medium-int8.tar.bz2'),
        fileName: 'vits-piper-es_ES-davefx-medium-int8.tar.bz2',
        bytes: 21171632,
        sha256:
            '8bb8ac1cefb727caec9bd9c6c3185c673c8b42c53bd29bb25d5a7715dac37125',
        isArchive: true,
      ),
    ],
    installedBytes: 36300000,
    archiveRoot: 'vits-piper-es_ES-davefx-medium-int8',
    requiredFiles: const [
      'es_ES-davefx-medium.onnx',
      'tokens.txt',
      'espeak-ng-data',
    ],
    modelFiles: const {
      'model': 'es_ES-davefx-medium.onnx',
      'tokens': 'tokens.txt',
      'dataDir': 'espeak-ng-data',
    },
    languages: const [TtsLanguageOption('es-ES', 'Español (España)')],
    voices: const [TtsVoiceOption('davefx', 'DaveFX · Masculina', 0)],
    licenseName: 'Model-specific Piper license',
    licenseUri: Uri.parse('https://github.com/rhasspy/piper'),
  );

  static final TtsModelDefinition kitten = TtsModelDefinition(
    id: 'kitten-nano-en-v0-8-int8',
    version: '2026-05-12',
    name: 'KittenTTS',
    description: 'Compact English model with 8 voices',
    family: TtsModelFamily.kitten,
    downloads: [
      TtsModelDownload(
        uri: _ttsAsset('kitten-nano-en-v0_8-int8.tar.bz2'),
        fileName: 'kitten-nano-en-v0_8-int8.tar.bz2',
        bytes: 31220690,
        sha256:
            '6fa5be852612ce761094ba74ee6123b4fc4acfefa79bf64dc63acae4a83af2fd',
        isArchive: true,
      ),
    ],
    installedBytes: 45652547,
    archiveRoot: 'kitten-nano-en-v0_8-int8',
    requiredFiles: const [
      'model.int8.onnx',
      'voices.bin',
      'tokens.txt',
      'espeak-ng-data',
    ],
    modelFiles: const {
      'model': 'model.int8.onnx',
      'voices': 'voices.bin',
      'tokens': 'tokens.txt',
      'dataDir': 'espeak-ng-data',
    },
    languages: const [TtsLanguageOption('en', 'English')],
    voices: _kittenVoices,
    licenseName: 'Apache-2.0',
    licenseUri: Uri.parse('https://github.com/KittenML/KittenTTS'),
  );

  static final TtsModelDefinition kokoro = TtsModelDefinition(
    id: 'kokoro-en-v0-19-int8',
    version: '2025-08-10',
    name: 'Kokoro',
    description: 'English model with 11 US and UK voices',
    family: TtsModelFamily.kokoro,
    downloads: [
      TtsModelDownload(
        uri: _ttsAsset('kokoro-int8-en-v0_19.tar.bz2'),
        fileName: 'kokoro-int8-en-v0_19.tar.bz2',
        bytes: 103248205,
        sha256:
            'c9f0dd393615805b0bab050c340834d5e684e732aec91c0e860cd30e982c08bd',
        isArchive: true,
      ),
    ],
    installedBytes: 157947103,
    archiveRoot: 'kokoro-int8-en-v0_19',
    requiredFiles: const [
      'model.int8.onnx',
      'voices.bin',
      'tokens.txt',
      'espeak-ng-data',
    ],
    modelFiles: const {
      'model': 'model.int8.onnx',
      'voices': 'voices.bin',
      'tokens': 'tokens.txt',
      'dataDir': 'espeak-ng-data',
    },
    languages: const [TtsLanguageOption('en', 'English')],
    voices: _kokoroVoices,
    licenseName: 'Apache-2.0',
    licenseUri: Uri.parse('https://huggingface.co/hexgrad/Kokoro-82M'),
  );

  static final TtsModelDefinition matcha = TtsModelDefinition(
    id: 'matcha-ljspeech-en',
    version: '2026-07-16',
    name: 'Matcha-TTS',
    description: 'English LJSpeech acoustic model with Vocos vocoder',
    family: TtsModelFamily.matcha,
    downloads: [
      TtsModelDownload(
        uri: _ttsAsset('matcha-icefall-en_US-ljspeech.tar.bz2'),
        fileName: 'matcha-icefall-en_US-ljspeech.tar.bz2',
        bytes: 76741121,
        sha256:
            'ea75702da7456a8b1874728278a835220dc8a26f4e8bd93c83bf53dc27679845',
        isArchive: true,
      ),
      TtsModelDownload(
        uri: Uri.parse(
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/vocoder-models/vocos-22khz-univ.onnx',
        ),
        fileName: 'vocos-22khz-univ.onnx',
        targetPath: 'vocos-22khz-univ.onnx',
        bytes: 53884024,
        sha256:
            '0574a135aa1db2de6e181050db2ec528496cacd4a4701fc5d7faf9f9804c0081',
      ),
    ],
    installedBytes: 146034137,
    archiveRoot: 'matcha-icefall-en_US-ljspeech',
    requiredFiles: const [
      'model-steps-3.onnx',
      'vocos-22khz-univ.onnx',
      'tokens.txt',
      'espeak-ng-data',
    ],
    modelFiles: const {
      'acousticModel': 'model-steps-3.onnx',
      'vocoder': 'vocos-22khz-univ.onnx',
      'tokens': 'tokens.txt',
      'dataDir': 'espeak-ng-data',
    },
    languages: const [TtsLanguageOption('en', 'English')],
    voices: const [TtsVoiceOption('ljspeech', 'LJSpeech · Female', 0)],
    defaultSteps: 3,
    licenseName: 'Apache-2.0 / LJSpeech public domain',
    licenseUri: Uri.parse('https://keithito.com/LJ-Speech-Dataset/'),
  );

  static final TtsModelDefinition pocket = TtsModelDefinition(
    id: 'pocket-tts-int8',
    version: '2026-01-26',
    name: 'Pocket TTS',
    description: 'English zero-shot voice cloning from a reference WAV',
    family: TtsModelFamily.pocket,
    downloads: [
      TtsModelDownload(
        uri: _ttsAsset('sherpa-onnx-pocket-tts-int8-2026-01-26.tar.bz2'),
        fileName: 'sherpa-onnx-pocket-tts-int8-2026-01-26.tar.bz2',
        bytes: 98336520,
        sha256:
            '2f3b88823cbbb9bf0b2477ec8ae7b3fec417b3a87b6bb5f256dba66f2ad967cb',
        isArchive: true,
      ),
    ],
    installedBytes: 203216103,
    archiveRoot: 'sherpa-onnx-pocket-tts-int8-2026-01-26',
    requiredFiles: const [
      'lm_flow.int8.onnx',
      'lm_main.int8.onnx',
      'encoder.onnx',
      'decoder.int8.onnx',
      'tokens.txt',
      'espeak-ng-data',
      'test_wavs/bria.wav',
    ],
    modelFiles: const {
      'lmFlow': 'lm_flow.int8.onnx',
      'lmMain': 'lm_main.int8.onnx',
      'encoder': 'encoder.onnx',
      'decoder': 'decoder.int8.onnx',
      'tokens': 'tokens.txt',
      'dataDir': 'espeak-ng-data',
    },
    languages: const [TtsLanguageOption('en', 'English')],
    voices: const [
      TtsVoiceOption(
        'bria',
        'Bria · Sample',
        0,
        referenceAudio: 'test_wavs/bria.wav',
      ),
    ],
    referenceMode: TtsReferenceMode.audio,
    defaultSteps: 4,
    licenseName: 'CC BY 4.0 model weights',
    licenseUri: Uri.parse('https://huggingface.co/kyutai/pocket-tts'),
  );

  static final TtsModelDefinition zipVoice = TtsModelDefinition(
    id: 'zipvoice-distill-int8-zh-en',
    version: '2026-06-18',
    name: 'ZipVoice',
    description: 'Chinese and English voice cloning with a transcript',
    family: TtsModelFamily.zipvoice,
    downloads: [
      TtsModelDownload(
        uri: _ttsAsset(
          'sherpa-onnx-zipvoice-distill-int8-zh-en-emilia.tar.bz2',
        ),
        fileName: 'sherpa-onnx-zipvoice-distill-int8-zh-en-emilia.tar.bz2',
        bytes: 147573432,
        sha256:
            '6be8482431cb7f1bfa9bf17b6a1209b5526d17dfd1ec676be981d39235cb994f',
        isArchive: true,
      ),
      TtsModelDownload(
        uri: Uri.parse(
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/vocoder-models/vocos_24khz.onnx',
        ),
        fileName: 'vocos_24khz.onnx',
        targetPath: 'vocos_24khz.onnx',
        bytes: 54157409,
        sha256:
            'bcb3b970e384161c4d634f0bb9e999ff1c471b34c9bc0b1049a5014065ed3cc0',
      ),
    ],
    installedBytes: 205150124,
    archiveRoot: 'sherpa-onnx-zipvoice-distill-int8-zh-en-emilia',
    requiredFiles: const [
      'encoder.int8.onnx',
      'decoder.int8.onnx',
      'vocos_24khz.onnx',
      'tokens.txt',
      'lexicon.txt',
      'espeak-ng-data',
      'test_wavs/news-female.wav',
    ],
    modelFiles: const {
      'encoder': 'encoder.int8.onnx',
      'decoder': 'decoder.int8.onnx',
      'vocoder': 'vocos_24khz.onnx',
      'tokens': 'tokens.txt',
      'lexicon': 'lexicon.txt',
      'dataDir': 'espeak-ng-data',
    },
    languages: const [
      TtsLanguageOption('en', 'English'),
      TtsLanguageOption('zh', '中文'),
    ],
    voices: const [
      TtsVoiceOption(
        'news-female',
        'News Female · Sample',
        0,
        referenceAudio: 'test_wavs/news-female.wav',
        referenceText: '各位村民, 大家新年好! 近期, 湖北省武汉市等多个地区',
      ),
      TtsVoiceOption(
        'news-female-2',
        'News Female 2 · Sample',
        0,
        referenceAudio: 'test_wavs/news-female-2.wav',
        referenceText: '本台消息, 中共中央国务院, 近日印发关于构建数据基础制度, 更好发挥数据要素作用的意见.',
      ),
      TtsVoiceOption(
        'leijun',
        'Lei Jun · Sample',
        0,
        referenceAudio: 'test_wavs/leijun-1.wav',
        referenceText: '那还是36年前, 1987年. 我呢考上了武汉大学的计算机系.',
      ),
    ],
    referenceMode: TtsReferenceMode.audioAndText,
    defaultSteps: 4,
    licenseName: 'Apache-2.0 model package',
    licenseUri: Uri.parse('https://github.com/k2-fsa/ZipVoice'),
  );

  static final List<TtsModelDefinition> models = [
    supertonic,
    piperMexico,
    piperSpain,
    kitten,
    kokoro,
    matcha,
    pocket,
    zipVoice,
  ];

  static TtsModelDefinition byId(String id) =>
      models.firstWhere((model) => model.id == id, orElse: () => supertonic);
}
