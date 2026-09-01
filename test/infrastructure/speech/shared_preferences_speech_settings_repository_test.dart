import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/native_speech_settings.dart';
import 'package:godsense/infrastructure/speech/shared_preferences_speech_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('round-trips native PTT, STT, and TTS settings', () async {
    final repository = SharedPreferencesSpeechSettingsRepository();
    const expected = NativeSpeechSettings(
      pushToTalkEnabled: true,
      pushToTalkKey: 'f9',
      sttLanguage: 'es',
      sttDenoise: false,
      ttsEnabled: true,
      ttsModelId: 'piper-es-mx-claude-high-int8',
      ttsVoice: 'claude',
      ttsLanguage: 'es-MX',
      ttsSpeed: 1.2,
      ttsSteps: 5,
    );

    await repository.save(expected);
    final restored = await repository.load();

    expect(restored.toJson(), expected.toJson());
  });

  test('uses safe defaults for corrupt persisted settings', () async {
    SharedPreferences.setMockInitialValues({
      'native_speech_settings_v1': '{invalid',
    });

    final restored = await SharedPreferencesSpeechSettingsRepository().load();

    expect(restored.pushToTalkEnabled, isFalse);
    expect(restored.ttsEnabled, isFalse);
    expect(restored.sttDenoise, isTrue);
  });
}
