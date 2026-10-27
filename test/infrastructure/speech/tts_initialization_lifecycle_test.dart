import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/speech/native_audio_playback_service.dart';
import 'package:godsense/infrastructure/speech/tts/sherpa_tts_engine.dart';
import 'package:godsense/infrastructure/speech/tts/tts_model_catalog.dart';
import 'package:godsense/infrastructure/speech/tts_model_cache.dart';
import 'package:godsense/infrastructure/speech/tts_service.dart';

void main() {
  late _Cache cache;
  late _Engine engine;
  late _Playback playback;
  late TtsService service;
  setUp(() {
    cache = _Cache();
    engine = _Engine();
    playback = _Playback();
    service = TtsService(
      modelCache: cache,
      engine: engine,
      audioPlayback: playback,
    );
  });
  tearDown(() => service.dispose());

  Future<void> config({
    required bool enabled,
    String model = 'supertonic-3-hybrid',
  }) => service.updateConfig(
    enabled: enabled,
    modelId: model,
    voice: 'M1',
    language: 'es',
    speed: 1,
    steps: 8,
    referenceAudioPath: '',
    referenceText: '',
  );

  test(
    'stopping during a missing-model check cannot restore an obsolete notice',
    () async {
      final gate = Completer<TtsModelInstallation?>();
      cache.lookup = gate.future;
      final initializing = service.ensureReady(allowDownload: false);
      await cache.checked.future;
      await config(enabled: false);
      final stopped = service.currentLoadState;
      gate.complete(null);
      await initializing;
      expect(service.currentLoadState, same(stopped));
      expect(cache.downloads, 0);
    },
  );

  test(
    'stopping during cache lookup cannot initiate a cancelled download',
    () async {
      final gate = Completer<TtsModelInstallation?>();
      cache.lookup = gate.future;
      final initializing = service.prepareModel();
      await cache.checked.future;
      await service.stop(unload: true);
      gate.complete(null);
      await initializing;
      expect(cache.downloads, 0);
      expect(engine.initializations, 0);
    },
  );

  test('an explicit preparation waiting for old startup cannot redownload after stop', () async {
    final gate = Completer<TtsModelInstallation?>();
    cache.lookup = gate.future;
    final automatic = service.ensureReady(allowDownload: false);
    await cache.checked.future;
    final requested = service.prepareModel();
    await service.stop(unload: true);
    gate.complete(null);
    await Future.wait([automatic, requested]);
    expect(cache.downloads, 0);
    expect(engine.initializations, 0);
  });

  test(
    'stopping during playback keepalive cannot publish Ready afterwards',
    () async {
      final gate = Completer<void>();
      playback.gate = gate.future;
      final initializing = service.prepareModel();
      await playback.started.future;
      await config(enabled: false);
      final stopped = service.currentLoadState;
      gate.complete();
      await initializing;
      expect(service.currentLoadState, same(stopped));
      expect(service.currentLoadState.isReady, isFalse);
    },
  );

  test('automatic preparation cannot retry after an explicit stop', () async {
    final gate = Completer<TtsModelInstallation?>();
    cache.lookup = gate.future;
    await config(enabled: true);
    await cache.checked.future;
    await service.stop(unload: true);
    gate.complete(null);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(cache.checks, 1);
    expect(engine.initializations, 0);
    expect(cache.downloads, 0);
  });

  test('new preparation requested after stop can wait for the old check and succeed', () async {
    final gate = Completer<TtsModelInstallation?>();
    cache.lookup = gate.future;
    final previous = service.ensureReady(allowDownload: false);
    await cache.checked.future;
    await service.stop(unload: true);
    final requested = service.prepareModel();
    gate.complete(null);
    await Future.wait([previous, requested]);
    expect(cache.downloads, 1);
    expect(engine.initializations, 1);
    expect(service.currentLoadState.isReady, isTrue);
  });

  test(
    'current initialization still reports a missing model without downloading',
    () async {
      cache.missing = true;
      await service.ensureReady(allowDownload: false);
      expect(service.currentLoadState.message, contains('not downloaded'));
      expect(cache.downloads, 0);
    },
  );
}

class _Cache extends TtsModelCache {
  Future<TtsModelInstallation?>? lookup;
  bool missing = false;
  int downloads = 0;
  int checks = 0;
  final checked = Completer<void>();
  @override
  Future<TtsModelInstallation?> installed(TtsModelDefinition model) async {
    checks++;
    if (!checked.isCompleted) checked.complete();
    if (lookup != null) return await lookup;
    return missing ? null : TtsModelInstallation(model, Directory.systemTemp);
  }

  @override
  Future<TtsModelInstallation> ensureAvailable(
    TtsModelDefinition model, {
    void Function(TtsInstallProgress)? onProgress,
    TtsDownloadCancellation? cancellation,
  }) async {
    downloads++;
    cancellation?.throwIfCancelled();
    return TtsModelInstallation(model, Directory.systemTemp);
  }
}

class _Engine extends SherpaTtsEngine {
  bool ready = false;
  int initializations = 0;
  @override
  bool get isReady => ready;
  @override
  Future<void> initialize(TtsModelInstallation installation) async {
    initializations++;
    ready = true;
  }

  @override
  Future<void> cancel() async => ready = false;
}

class _Playback extends NativeAudioPlaybackService {
  Future<void>? gate;
  final started = Completer<void>();
  @override
  Future<void> startKeepAlive() async {
    if (!started.isCompleted) started.complete();
    await gate;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}
