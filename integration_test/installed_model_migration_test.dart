import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/speech/speech/speech_model_catalog.dart';
import 'package:godsense/infrastructure/speech/tts/tts_model_catalog.dart';
import 'package:godsense/infrastructure/speech/tts_model_cache.dart';

void main() {
  final modelRoot = Platform.environment['GODSENSE_MIGRATED_MODELS_DIR'];
  test(
    'recognizes real models migrated from Airstream',
    () async {
      final cache = TtsModelCache(rootDirectory: Directory(modelRoot!));
      expect(
        await cache.installed(SpeechModelCatalog.canary.package),
        isNotNull,
      );
      expect(await cache.installed(TtsModelCatalog.supertonic), isNotNull);
    },
    skip: modelRoot == null
        ? 'Set GODSENSE_MIGRATED_MODELS_DIR to the installed model cache.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
