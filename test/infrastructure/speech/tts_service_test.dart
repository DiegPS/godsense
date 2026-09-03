import 'dart:io';
import 'dart:async';

import 'package:godsense/application/artifacts/artifact_downloader.dart';
import 'package:godsense/infrastructure/speech/tts_service.dart';
import 'package:godsense/infrastructure/speech/tts/sherpa_tts_engine.dart';
import 'package:godsense/infrastructure/speech/tts_model_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes URLs and caps speech by Unicode code points', () {
    expect(
      TtsService.prepareTextForSpeech('  Hola   https://example.com mundo  '),
      'Hola mundo',
    );
    final longEmojiText = List.filled(300, '🟢').join();
    final prepared = TtsService.prepareTextForSpeech(longEmojiText);
    expect(prepared.runes.length, 261);
    expect(prepared.endsWith('…'), isTrue);
  });

  test('enabled TTS never downloads without an explicit user action', () async {
    final root = await Directory.systemTemp.createTemp('godsense-tts-lazy-');
    var requests = 0;
    final cache = TtsModelCache(
      rootDirectory: root,
      downloader: _CountingDownloader(() => requests++),
    );
    final service = TtsService(modelCache: cache);
    try {
      await service.updateConfig(
        enabled: true,
        modelId: 'supertonic-3-hybrid',
        voice: 'M1',
        language: 'es',
        speed: 1.05,
        steps: 8,
        referenceAudioPath: '',
        referenceText: '',
      );
      service.speak('Este mensaje no debe iniciar una descarga.');
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(requests, 0);
      expect(service.currentLoadState.phase, TtsLoadPhase.idle);
      expect(service.currentLoadState.message, contains('not downloaded'));
    } finally {
      await service.dispose();
      if (await root.exists()) await root.delete(recursive: true);
    }
  });

  test('a dead TTS worker immediately replaces Ready with an error', () async {
    final engine = _ControllableSherpaEngine();
    final service = TtsService(engine: engine);
    try {
      engine.fail(StateError('worker exited'));
      await Future<void>.delayed(Duration.zero);

      expect(service.currentLoadState.phase, TtsLoadPhase.error);
      expect(service.currentLoadState.error, contains('worker exited'));
      expect(service.isBusy, isFalse);
    } finally {
      await service.dispose();
    }
  });
}

class _CountingDownloader implements ArtifactDownloader {
  _CountingDownloader(this.onDownload);

  final void Function() onDownload;

  @override
  Future<void> download(
    ArtifactDownloadRequest request, {
    ArtifactDownloadCancellation? cancellation,
    void Function(ArtifactDownloadProgress progress)? onProgress,
  }) async {
    onDownload();
    throw StateError('Unexpected download of ${request.id}.');
  }
}

class _ControllableSherpaEngine extends SherpaTtsEngine {
  final _failures = StreamController<Object>.broadcast();

  @override
  Stream<Object> get workerFailures => _failures.stream;

  void fail(Object error) => _failures.add(error);

  @override
  Future<void> dispose() async {
    await _failures.close();
    await super.dispose();
  }
}
