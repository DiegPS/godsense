import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/speech/tts/tts_model_catalog.dart';

import '../../support/voice_model_cases.dart';

void main() {
  test('every advertised voice model has a native integration fixture', () {
    expect(
      voiceModelCases.map((item) => item.model.id).toSet(),
      TtsModelCatalog.models.map((model) => model.id).toSet(),
    );
    expect(
      voiceModelCases.map((item) => item.environmentKey).toSet().length,
      voiceModelCases.length,
    );
    expect(
      voiceModelManifest().map((item) => item['key']).toSet().length,
      voiceModelCases.length,
    );
  });
}
