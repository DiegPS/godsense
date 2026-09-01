import 'dart:io';

import 'package:godsense/infrastructure/speech/speech/live_captions_service.dart';
import 'package:godsense/infrastructure/speech/speech/speech_model_catalog.dart';
import 'package:godsense/infrastructure/speech/tts_model_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'enabling captions never downloads without explicit user action',
    () async {
      final root = await Directory.systemTemp.createTemp('godsense-captions-');
      var requests = 0;
      final service = LiveCaptionsService(
        modelCache: TtsModelCache(
          rootDirectory: root,
          client: MockClient((request) async {
            requests++;
            return http.Response('unexpected', 500);
          }),
        ),
      );
      try {
        await service.updateConfig(
          enabled: true,
          sourceLanguage: 'es',
          targetLanguage: 'en',
          denoise: true,
        );

        expect(requests, 0);
        expect(service.currentState.phase, LiveCaptionsPhase.missingModel);
        expect(
          service.currentState.totalBytes,
          SpeechModelCatalog.canary.package.downloadBytes,
        );
      } finally {
        await service.dispose();
        if (await root.exists()) await root.delete(recursive: true);
      }
    },
  );

  test('caption model package has verified ASR and VAD artifacts', () {
    final model = SpeechModelCatalog.canary;

    expect(model.package.downloads, hasLength(3));
    expect(
      model.package.downloads.every((item) => item.sha256.length == 64),
      isTrue,
    );
    expect(model.package.requiredFiles, contains('silero_vad.onnx'));
    expect(model.package.requiredFiles, contains('gtcrn_simple.onnx'));
    expect(
      model.languages.map((item) => item.code),
      containsAll(['es', 'en', 'de', 'fr']),
    );
    expect(model.targetsFor('es').map((item) => item.code), ['es', 'en']);
    expect(model.supportsDirection('es', 'fr'), isFalse);
  });
}
