import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:godsense/infrastructure/speech/speech/live_captions_service.dart';
import 'package:godsense/infrastructure/speech/speech/speech_model_catalog.dart';
import 'package:godsense/infrastructure/speech/tts/sherpa_tts_engine.dart';
import 'package:godsense/infrastructure/speech/tts/tts_model_catalog.dart';
import 'package:godsense/infrastructure/speech/tts_model_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'caption shutdown waits for worker resource cleanup acknowledgement',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'captions-cleanup-test-',
      );
      final cleaned = ReceivePort();
      final capture = _FakeSpeechAudioCapture();
      final cache = _InstalledModelCache(directory);
      final service = LiveCaptionsService(
        modelCache: cache,
        audioCapture: capture,
        workerEntrypoint: _cleanupWorker(cleaned.sendPort),
      );
      try {
        await service.updateConfig(
          enabled: true,
          sourceLanguage: 'es',
          targetLanguage: 'es',
          denoise: true,
        );
        final observedCleanup = cleaned.first.timeout(
          const Duration(seconds: 2),
        );
        await Future.wait([service.stop(), service.stop(), service.stop()]);
        expect(await observedCleanup, true);
        expect(service.currentState.phase, LiveCaptionsPhase.idle);
      } finally {
        cleaned.close();
        await service.dispose();
        cache.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'disabling captions while its worker loads completes the pending start',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'captions-start-cancel-',
      );
      final started = ReceivePort();
      final capture = _FakeSpeechAudioCapture();
      final cache = _InstalledModelCache(directory);
      final service = LiveCaptionsService(
        modelCache: cache,
        audioCapture: capture,
        workerEntrypoint: _loadingWorker(started.sendPort),
      );
      try {
        final starting = service.updateConfig(
          enabled: true,
          sourceLanguage: 'es',
          targetLanguage: 'es',
          denoise: true,
        );
        await started.first.timeout(const Duration(seconds: 2));
        await service.updateConfig(
          enabled: false,
          sourceLanguage: 'es',
          targetLanguage: 'es',
          denoise: true,
        );
        await expectLater(
          starting.timeout(const Duration(seconds: 2)),
          completes,
        );
        expect(service.currentState.phase, LiveCaptionsPhase.idle);
        expect(capture.startCalls, 0);
      } finally {
        started.close();
        await service.dispose();
        cache.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test('unloading TTS while its worker loads rejects the pending initialization promptly', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tts-start-cancel-',
    );
    final started = ReceivePort();
    final engine = SherpaTtsEngine(
      workerEntrypoint: _loadingWorker(started.sendPort),
    );
    try {
      final initializing = engine.initialize(
        TtsModelInstallation(TtsModelCatalog.supertonic, directory),
      );
      final outcome = expectLater(
        initializing.timeout(const Duration(seconds: 2)),
        throwsStateError,
      );
      await started.first.timeout(const Duration(seconds: 2));
      await engine.unload();
      await outcome;
      expect(engine.isReady, false);
    } finally {
      started.close();
      await engine.dispose();
      await directory.delete(recursive: true);
    }
  });

  test('TTS synthesis fails immediately when a ready worker exits', () async {
    final directory = await Directory.systemTemp.createTemp('tts-worker-test-');
    final engine = SherpaTtsEngine(workerEntrypoint: _exitingTtsWorker);
    try {
      await engine.initialize(
        TtsModelInstallation(TtsModelCatalog.supertonic, directory),
      );
      final stopwatch = Stopwatch()..start();

      await expectLater(
        engine.synthesize(
          text: 'hola',
          speakerId: 0,
          language: 'es',
          speed: 1,
          steps: 2,
        ),
        throwsA(isA<StateError>()),
      );

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(engine.isReady, isFalse);
    } finally {
      await engine.dispose();
      await directory.delete(recursive: true);
    }
  });

  test(
    'TTS timeout keeps native cancellation memory alive until worker reply',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tts-timeout-test-',
      );
      final engine = SherpaTtsEngine(
        workerEntrypoint: _delayedTtsWorker,
        synthesisTimeout: const Duration(milliseconds: 20),
      );
      try {
        await engine.initialize(
          TtsModelInstallation(TtsModelCatalog.supertonic, directory),
        );
        await expectLater(
          engine.synthesize(
            text: 'hola',
            speakerId: 0,
            language: 'es',
            speed: 1,
            steps: 2,
          ),
          throwsA(isA<TimeoutException>()),
        );

        expect(engine.isReady, isFalse);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(engine.isReady, isTrue);
      } finally {
        await engine.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'captions show an error and stop audio when a ready worker exits',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'captions-worker-test-',
      );
      final capture = _FakeSpeechAudioCapture();
      final cache = _InstalledModelCache(directory);
      final service = LiveCaptionsService(
        modelCache: cache,
        audioCapture: capture,
        workerEntrypoint: _exitingCaptionsWorker,
      );
      try {
        await service.updateConfig(
          enabled: true,
          sourceLanguage: 'es',
          targetLanguage: 'es',
          denoise: true,
        );
        expect(service.currentState.phase, LiveCaptionsPhase.listening);

        capture.add(Uint8List(320));
        final failed = await service.states
            .firstWhere((state) => state.phase == LiveCaptionsPhase.error)
            .timeout(const Duration(seconds: 2));

        expect(failed.error, contains('exited unexpectedly'));
        await Future<void>.delayed(Duration.zero);
        expect(capture.stopCalls, greaterThan(0));
      } finally {
        await service.dispose();
        cache.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test('Push-to-Talk flush returns the final pending transcript', () async {
    final directory = await Directory.systemTemp.createTemp('ptt-flush-test-');
    final capture = _FakeSpeechAudioCapture();
    final cache = _InstalledModelCache(directory);
    final service = LiveCaptionsService(
      modelCache: cache,
      audioCapture: capture,
      workerEntrypoint: _flushingCaptionsWorker,
    );
    try {
      await service.updateConfig(
        enabled: true,
        sourceLanguage: 'es',
        targetLanguage: 'es',
        denoise: true,
      );
      capture.add(Uint8List(320));

      final transcript = await service.finishUtterance();

      expect(transcript, '¿Dónde está el jungla enemigo?');
      expect(capture.stopCalls, greaterThan(0));
    } finally {
      await service.dispose();
      cache.dispose();
      await directory.delete(recursive: true);
    }
  });
}

void Function(Map<String, Object>) _loadingWorker(
  SendPort started,
) => (startup) {
  // Simulate a native model initialization that has not produced its command
  // port yet. No microphone, model files or native callback is involved.
  final keepAlive = ReceivePort();
  keepAlive.listen((_) {});
  started.send(true);
};

void Function(Map<String, Object>) _cleanupWorker(SendPort cleaned) =>
    (startup) {
      final commands = ReceivePort();
      (startup['reply'] as SendPort).send(commands.sendPort);
      commands.listen((dynamic message) async {
        if (message is Map && message['type'] == 'dispose') {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          cleaned.send(true);
          (message['reply'] as SendPort).send(true);
          commands.close();
        }
      });
    };

void _exitingTtsWorker(Map<String, Object> startup) {
  final owner = startup['reply']! as SendPort;
  final commands = ReceivePort();
  owner.send(commands.sendPort);
  commands.listen((dynamic message) {
    if (message is Map && message['type'] == 'synthesize') {
      Isolate.exit();
    }
  });
}

void _delayedTtsWorker(Map<String, Object> startup) {
  final owner = startup['reply']! as SendPort;
  final commands = ReceivePort();
  owner.send(commands.sendPort);
  commands.listen((dynamic message) async {
    if (message is! Map) return;
    if (message['type'] == 'dispose') {
      (message['reply'] as SendPort?)?.send(true);
      commands.close();
      return;
    }
    if (message['type'] != 'synthesize') return;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final cancelled =
        Pointer<Uint8>.fromAddress(message['cancelAddress'] as int).value == 1;
    (message['reply'] as SendPort).send({if (cancelled) 'error': 'cancelled'});
  });
}

void _exitingCaptionsWorker(Map<String, Object> startup) {
  final owner = startup['reply']! as SendPort;
  final commands = ReceivePort();
  owner.send(commands.sendPort);
  commands.listen((dynamic message) {
    if (message is Map && message['type'] == 'audio') {
      Isolate.exit();
    }
  });
}

void _flushingCaptionsWorker(Map<String, Object> startup) {
  final owner = startup['reply']! as SendPort;
  final commands = ReceivePort();
  SendPort? events;
  owner.send(commands.sendPort);
  commands.listen((dynamic message) {
    if (message is! Map) return;
    if (message['type'] == 'listen') {
      events = message['reply'] as SendPort;
    } else if (message['type'] == 'flush') {
      events?.send({
        'caption': '¿Dónde está el jungla enemigo?',
        'speechDetected': false,
      });
      events?.send({'flushDone': true, 'speechDetected': false});
    } else if (message['type'] == 'dispose') {
      (message['reply'] as SendPort?)?.send(true);
      commands.close();
    }
  });
}

class _FakeSpeechAudioCapture implements SpeechAudioCapture {
  final _audio = StreamController<Uint8List>.broadcast();
  int stopCalls = 0;
  int startCalls = 0;

  void add(Uint8List bytes) => _audio.add(bytes);

  @override
  Future<Stream<Uint8List>> start() async {
    startCalls++;
    return _audio.stream;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() => _audio.close();
}

class _InstalledModelCache extends TtsModelCache {
  _InstalledModelCache(this.directory) : super(rootDirectory: directory);

  final Directory directory;

  @override
  Future<TtsModelInstallation?> installed(TtsModelDefinition model) async {
    return TtsModelInstallation(SpeechModelCatalog.canary.package, directory);
  }
}
