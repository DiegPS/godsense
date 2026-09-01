class NativeSpeechSettings {
  const NativeSpeechSettings({
    this.pushToTalkEnabled = false,
    this.pushToTalkKey = 'delete',
    this.sttLanguage = 'es',
    this.sttDenoise = true,
    this.ttsEnabled = false,
    this.ttsModelId = 'supertonic-3-hybrid',
    this.ttsVoice = 'M1',
    this.ttsLanguage = 'es',
    this.ttsSpeed = 1.05,
    this.ttsSteps = 8,
    this.referenceAudioPath = '',
    this.referenceText = '',
  });

  final bool pushToTalkEnabled;
  final String pushToTalkKey;
  final String sttLanguage;
  final bool sttDenoise;
  final bool ttsEnabled;
  final String ttsModelId;
  final String ttsVoice;
  final String ttsLanguage;
  final double ttsSpeed;
  final int ttsSteps;
  final String referenceAudioPath;
  final String referenceText;

  NativeSpeechSettings copyWith({
    bool? pushToTalkEnabled,
    String? pushToTalkKey,
    String? sttLanguage,
    bool? sttDenoise,
    bool? ttsEnabled,
    String? ttsModelId,
    String? ttsVoice,
    String? ttsLanguage,
    double? ttsSpeed,
    int? ttsSteps,
    String? referenceAudioPath,
    String? referenceText,
  }) => NativeSpeechSettings(
    pushToTalkEnabled: pushToTalkEnabled ?? this.pushToTalkEnabled,
    pushToTalkKey: pushToTalkKey ?? this.pushToTalkKey,
    sttLanguage: sttLanguage ?? this.sttLanguage,
    sttDenoise: sttDenoise ?? this.sttDenoise,
    ttsEnabled: ttsEnabled ?? this.ttsEnabled,
    ttsModelId: ttsModelId ?? this.ttsModelId,
    ttsVoice: ttsVoice ?? this.ttsVoice,
    ttsLanguage: ttsLanguage ?? this.ttsLanguage,
    ttsSpeed: ttsSpeed ?? this.ttsSpeed,
    ttsSteps: ttsSteps ?? this.ttsSteps,
    referenceAudioPath: referenceAudioPath ?? this.referenceAudioPath,
    referenceText: referenceText ?? this.referenceText,
  );

  factory NativeSpeechSettings.fromJson(Map<String, dynamic> json) =>
      NativeSpeechSettings(
        pushToTalkEnabled: json['push_to_talk_enabled'] == true,
        pushToTalkKey: json['push_to_talk_key']?.toString() ?? 'delete',
        sttLanguage: json['stt_language']?.toString() ?? 'es',
        sttDenoise: json['stt_denoise'] != false,
        ttsEnabled: json['tts_enabled'] == true,
        ttsModelId: json['tts_model_id']?.toString() ?? 'supertonic-3-hybrid',
        ttsVoice: json['tts_voice']?.toString() ?? 'M1',
        ttsLanguage: json['tts_language']?.toString() ?? 'es',
        ttsSpeed: (json['tts_speed'] as num?)?.toDouble() ?? 1.05,
        ttsSteps: (json['tts_steps'] as num?)?.toInt() ?? 8,
        referenceAudioPath: json['reference_audio_path']?.toString() ?? '',
        referenceText: json['reference_text']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
    'push_to_talk_enabled': pushToTalkEnabled,
    'push_to_talk_key': pushToTalkKey,
    'stt_language': sttLanguage,
    'stt_denoise': sttDenoise,
    'tts_enabled': ttsEnabled,
    'tts_model_id': ttsModelId,
    'tts_voice': ttsVoice,
    'tts_language': ttsLanguage,
    'tts_speed': ttsSpeed,
    'tts_steps': ttsSteps,
    'reference_audio_path': referenceAudioPath,
    'reference_text': referenceText,
  };
}

abstract interface class NativeSpeechSettingsRepository {
  Future<NativeSpeechSettings> load();
  Future<void> save(NativeSpeechSettings settings);
}
