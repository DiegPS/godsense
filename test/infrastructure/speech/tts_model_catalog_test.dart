import 'package:godsense/infrastructure/speech/tts/tts_model_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog identifiers and storage keys are unique', () {
    final models = TtsModelCatalog.models;
    expect(models.map((model) => model.id).toSet(), hasLength(models.length));
    expect(
      models.map((model) => model.storageKey).toSet(),
      hasLength(models.length),
    );
  });

  test('every download is pinned and uses HTTPS', () {
    for (final model in TtsModelCatalog.models) {
      expect(model.downloads, isNotEmpty, reason: model.id);
      for (final download in model.downloads) {
        expect(download.uri.scheme, 'https', reason: model.id);
        expect(download.bytes, greaterThan(0), reason: download.fileName);
        expect(
          download.sha256,
          matches(RegExp(r'^[a-f0-9]{64}$')),
          reason: download.fileName,
        );
      }
    }
  });

  test('model-weight licenses are not confused with runtime licenses', () {
    expect(TtsModelCatalog.supertonic.licenseName, 'OpenRAIL-M');
    expect(TtsModelCatalog.supertonic.licenseUri.host, 'huggingface.co');
    expect(TtsModelCatalog.pocket.licenseName, 'CC BY 4.0 model weights');
  });

  test('Piper locale variants stay explicit', () {
    expect(TtsModelCatalog.piperMexico.languages.single.code, 'es-MX');
    expect(TtsModelCatalog.piperSpain.languages.single.code, 'es-ES');
    expect(TtsModelCatalog.piperMexico.voices.single.id, 'claude');
    expect(TtsModelCatalog.piperSpain.voices.single.id, 'davefx');
  });
}
