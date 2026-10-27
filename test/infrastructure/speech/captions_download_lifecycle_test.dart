import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/speech/speech/live_captions_service.dart';
import 'package:godsense/infrastructure/speech/tts/tts_model_catalog.dart';
import 'package:godsense/infrastructure/speech/tts_model_cache.dart';

void main() {
  late _Cache cache;
  late _Audio audio;
  late LiveCaptionsService service;
  setUp(() {
    cache = _Cache();
    audio = _Audio();
    service = LiveCaptionsService(
      modelCache: cache,
      audioCapture: audio,
      workerEntrypoint: _worker,
    );
  });
  tearDown(() async {
    await service.dispose();
    for (final request in cache.requests) {
      if (!request.result.isCompleted) {
        request.result.complete(request.installation);
      }
    }
    await Future<void>.delayed(Duration.zero);
  });

  test('old cancellation cannot clear a replacement download', () async {
    final old = service.prepareModel();
    final first = cache.requests.single;
    final current = service.prepareModel();
    final second = cache.requests.last;
    expect(first.cancellation!.isCancelled, isTrue);
    second.progress('current download');
    first.result.completeError(const TtsDownloadCancelledException());
    await old;
    expect(service.currentState.message, 'current download');
    second.result.complete(second.installation);
    await current;
  });

  test('old progress cannot replace the current download progress', () async {
    final old = service.prepareModel();
    final first = cache.requests.single;
    final current = service.prepareModel();
    final second = cache.requests.last;
    second.progress('new progress');
    first.progress('obsolete progress');
    expect(service.currentState.message, 'new progress');
    first.result.complete(first.installation);
    second.result.complete(second.installation);
    await Future.wait([old, current]);
  });

  test(
    'old failure reaches its caller without replacing current status',
    () async {
      final old = service.prepareModel();
      final first = cache.requests.single;
      final expectation = expectLater(old, throwsStateError);
      final current = service.prepareModel();
      final second = cache.requests.last;
      second.progress('new progress');
      first.result.completeError(StateError('old download failed'));
      await expectation;
      expect(service.currentState.message, 'new progress');
      expect(service.currentState.error, isNull);
      second.result.complete(second.installation);
      await current;
    },
  );

  test('stop suppresses progress from a cancelled download', () async {
    final pending = service.prepareModel();
    final request = cache.requests.single;
    await service.stop();
    expect(request.cancellation!.isCancelled, isTrue);
    request.progress('late progress');
    expect(service.currentState.phase, LiveCaptionsPhase.idle);
    request.result.complete(request.installation);
    await pending;
  });

  test('late download success cannot restart capture after stop', () async {
    await service.updateConfig(
      enabled: true,
      sourceLanguage: 'es',
      targetLanguage: 'es',
      denoise: true,
    );
    final pending = service.prepareModel();
    final request = cache.requests.single;
    await service.stop();
    request.result.complete(request.installation);
    await pending;
    expect(audio.starts, 0);
    expect(service.currentState.phase, LiveCaptionsPhase.idle);
  });

  test(
    'download without enabling capture finishes in idle instead of loading',
    () async {
      final pending = service.prepareModel();
      final request = cache.requests.single;
      request.progress('installing', phase: TtsInstallPhase.extracting);
      request.result.complete(request.installation);
      await pending;
      expect(service.currentState.phase, LiveCaptionsPhase.idle);
      expect(audio.starts, 0);
    },
  );

  test(
    'active cancellation returns to idle and permits another download',
    () async {
      final pending = service.prepareModel();
      cache.requests.single.progress('downloading');
      cache.requests.single.result.completeError(
        const TtsDownloadCancelledException(),
      );
      await pending;
      expect(service.currentState.phase, LiveCaptionsPhase.idle);
      final retry = service.prepareModel();
      cache.requests.last.result.complete(cache.requests.last.installation);
      await retry;
      expect(service.currentState.error, isNull);
    },
  );

  test('active success starts capture when captions remain enabled', () async {
    await service.updateConfig(
      enabled: true,
      sourceLanguage: 'es',
      targetLanguage: 'es',
      denoise: true,
    );
    final pending = service.prepareModel();
    cache.requests.single.result.complete(cache.requests.single.installation);
    await pending;
    expect(audio.starts, 1);
    expect(service.currentState.phase, LiveCaptionsPhase.listening);
  });

  test(
    'dispose rejects late progress and success without activating capture',
    () async {
      await service.updateConfig(
        enabled: true,
        sourceLanguage: 'es',
        targetLanguage: 'es',
        denoise: true,
      );
      final pending = service.prepareModel();
      final request = cache.requests.single;
      final before = service.currentState;
      await service.dispose();
      request.progress('obsolete progress');
      request.result.complete(request.installation);
      await pending;
      expect(audio.starts, 0);
      expect(service.currentState, same(before));
    },
  );

  test(
    'active download failure remains visible and a retry can succeed',
    () async {
      final pending = service.prepareModel();
      final expectation = expectLater(pending, throwsStateError);
      cache.requests.single.result.completeError(
        StateError('synthetic failure'),
      );
      await expectation;
      expect(service.currentState.phase, LiveCaptionsPhase.error);
      expect(service.currentState.error, contains('synthetic failure'));
      final retry = service.prepareModel();
      final request = cache.requests.last;
      request.result.complete(request.installation);
      await retry;
      expect(service.currentState.error, isNull);
      expect(service.currentState.phase, LiveCaptionsPhase.idle);
    },
  );
}

class _Request {
  _Request(this.model, this.cancellation, this.onProgress);
  final TtsModelDefinition model;
  final TtsDownloadCancellation? cancellation;
  final void Function(TtsInstallProgress)? onProgress;
  final result = Completer<TtsModelInstallation>();
  TtsModelInstallation get installation =>
      TtsModelInstallation(model, Directory.systemTemp);
  void progress(
    String message, {
    TtsInstallPhase phase = TtsInstallPhase.downloading,
  }) => onProgress?.call(TtsInstallProgress(phase: phase, message: message));
}

class _Cache extends TtsModelCache {
  final requests = <_Request>[];
  @override
  Future<TtsModelInstallation?> installed(TtsModelDefinition model) async =>
      null;
  @override
  Future<TtsModelInstallation> ensureAvailable(
    TtsModelDefinition model, {
    void Function(TtsInstallProgress)? onProgress,
    TtsDownloadCancellation? cancellation,
  }) {
    final request = _Request(model, cancellation, onProgress);
    requests.add(request);
    return request.result.future;
  }
}

class _Audio implements SpeechAudioCapture {
  int starts = 0;
  @override
  Future<Stream<Uint8List>> start() async {
    starts++;
    return const Stream.empty();
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void _worker(Map<String, Object> startup) {
  final commands = ReceivePort();
  (startup['reply']! as SendPort).send(commands.sendPort);
  commands.listen((dynamic message) {
    if (message is Map && message['type'] == 'dispose') {
      (message['reply'] as SendPort?)?.send(true);
      commands.close();
    }
  });
}
