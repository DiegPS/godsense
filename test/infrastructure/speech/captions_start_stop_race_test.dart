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
  late _Capture capture;
  late LiveCaptionsService service;
  setUp(() {
    cache = _Cache();
    capture = _Capture();
    service = LiveCaptionsService(
      modelCache: cache,
      audioCapture: capture,
      workerEntrypoint: _worker,
    );
  });
  tearDown(() => service.dispose());

  Future<void> enable() => service.updateConfig(
    enabled: true,
    sourceLanguage: 'es',
    targetLanguage: 'es',
    denoise: true,
  );

  test(
    'stop invalidates a pending installed-model check before it starts capture',
    () async {
      final pending = Completer<TtsModelInstallation?>();
      cache.lookup = pending.future;
      final enabling = enable();
      await cache.started.future;
      await service.stop();
      pending.complete(cache.installation);
      await enabling;
      expect(capture.starts, 0);
      expect(service.currentState.phase, LiveCaptionsPhase.idle);
    },
  );

  test('microphone opened after stop is immediately released and cannot restore listening', () async {
    final pending = Completer<void>();
    capture.gate = pending.future;
    final enabling = enable();
    await capture.started.future.timeout(const Duration(seconds: 3));
    await service.stop();
    pending.complete();
    await enabling;
    expect(capture.open, isFalse);
    expect(service.currentState.phase, LiveCaptionsPhase.idle);
  });

  test('an explicit enable after stop can start capture again', () async {
    await enable();
    expect(capture.open, isTrue);
    await service.stop();
    expect(capture.open, isFalse);
    await enable();
    expect(capture.starts, 2);
    expect(capture.open, isTrue);
    expect(service.currentState.phase, LiveCaptionsPhase.listening);
  });

  test(
    'changing language and denoising restarts capture with the new config',
    () async {
      await enable();
      await service.updateConfig(
        enabled: true,
        sourceLanguage: 'en',
        targetLanguage: 'en',
        denoise: false,
      );
      expect(capture.starts, 2);
      expect(capture.open, isTrue);
      expect(service.currentState.phase, LiveCaptionsPhase.listening);
    },
  );
}

class _Cache extends TtsModelCache {
  Future<TtsModelInstallation?>? lookup;
  final started = Completer<void>();
  TtsModelInstallation? installation;
  @override
  Future<TtsModelInstallation?> installed(TtsModelDefinition model) async {
    installation = TtsModelInstallation(model, Directory.systemTemp);
    if (!started.isCompleted) started.complete();
    return await (lookup ?? Future.value(installation));
  }
}

class _Capture implements SpeechAudioCapture {
  final started = Completer<void>();
  Future<void>? gate;
  int starts = 0;
  bool open = false;
  @override
  Future<Stream<Uint8List>> start() async {
    starts++;
    if (!started.isCompleted) started.complete();
    await gate;
    open = true;
    return const Stream.empty();
  }

  @override
  Future<void> stop() async => open = false;
  @override
  Future<void> dispose() => stop();
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
