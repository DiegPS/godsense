import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/speech/speech/speech_model_catalog.dart';
import 'package:godsense/infrastructure/speech/tts/tts_model_catalog.dart';
import 'package:godsense/infrastructure/speech/tts_model_cache.dart';

void main() {
  test('recognizes models migrated from Airstream', () async {
    final root = Directory(
      r'C:\Users\dpahu\AppData\Roaming\com.godsense\godsense\tts\models',
    );
    final cache = TtsModelCache(rootDirectory: root);

    expect(await cache.installed(SpeechModelCatalog.canary.package), isNotNull);
    expect(await cache.installed(TtsModelCatalog.supertonic), isNotNull);
  });
}
