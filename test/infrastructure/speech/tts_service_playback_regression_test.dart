import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/speech/native_audio_playback_service.dart';
import 'package:godsense/infrastructure/speech/tts/sherpa_tts_engine.dart';
import 'package:godsense/infrastructure/speech/tts/tts_model_catalog.dart';
import 'package:godsense/infrastructure/speech/tts_model_cache.dart';
import 'package:godsense/infrastructure/speech/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late _Engine engine;
  late _Playback playback;
  late TtsService service;
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  setUp(() async {
    root = await Directory.systemTemp.createTemp('godsense-tts-playback-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
    engine = _Engine();
    playback = _Playback();
    service = TtsService(
      modelCache: _Cache(root),
      engine: engine,
      audioPlayback: playback,
    );
  });
  tearDown(() async {
    await service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  test(
    'speech produces valid PCM WAV, plays it and removes the temporary file',
    () async {
      final busy = <bool>[];
      final subscription = service.busyStream.listen(busy.add);
      service.speak('  Mira https://example.com el río.  ');
      await _until(() => playback.files.length == 1 && !service.isBusy);
      expect(engine.texts, ['Mira el río.']);
      expect(busy, [true, false]);
      final bytes = playback.bytes.single;
      final header = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(header.getUint32(24, Endian.little), 16000);
      expect(header.getUint16(34, Endian.little), 16);
      expect(header.getUint32(40, Endian.little), 10);
      expect(
        [
          for (var i = 0; i < 5; i++)
            header.getInt16(44 + i * 2, Endian.little),
        ],
        [-32767, -32767, 0, 32767, 32767],
      );
      expect(playback.timeouts.single, const Duration(seconds: 8));
      expect(await playback.files.single.exists(), isFalse);
      await subscription.cancel();
    },
  );

  test(
    'playback failure is reported and subsequent queued advice still plays',
    () async {
      final errors = <Object>[];
      final subscription = service.playbackErrors.listen(errors.add);
      playback.failFirst = true;
      service.speak('Primero');
      service.speak('Segundo');
      await _until(() => playback.files.length == 2 && !service.isBusy);
      expect(engine.texts, ['Primero', 'Segundo']);
      expect(errors, hasLength(1));
      expect(errors.single.toString(), contains('synthetic playback failure'));
      for (final file in playback.files) {
        expect(await file.exists(), isFalse);
      }
      await subscription.cancel();
    },
  );

  test(
    'stop during synthesis discards late audio and clears pending advice',
    () async {
      engine.gate = Completer<void>();
      service.speak('En proceso');
      await _until(() => engine.texts.length == 1);
      service.speak('Pendiente');
      await service.stop();
      engine.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(playback.files, isEmpty);
      expect(service.isBusy, isFalse);
      expect(engine.texts, ['En proceso']);
      expect(engine.cancelCount, greaterThan(0));
      engine.gate = null;
      service.speak('Nueva generación');
      await _until(() => playback.files.length == 1 && !service.isBusy);
      expect(engine.texts, ['En proceso', 'Nueva generación']);
    },
  );

  test(
    'burst of advice retains only the eight newest pending utterances',
    () async {
      engine.gate = Completer<void>();
      service.speak('actual');
      await _until(() => engine.texts.length == 1);
      for (var i = 0; i < 12; i++) {
        service.speak('consejo $i');
      }
      engine.gate!.complete();
      await _until(() => playback.files.length == 9 && !service.isBusy);
      expect(engine.texts, [
        'actual',
        for (var i = 4; i < 12; i++) 'consejo $i',
      ]);
    },
  );
}

Future<void> _until(bool Function() done) async {
  final timer = Stopwatch()..start();
  while (!done()) {
    if (timer.elapsed > const Duration(seconds: 3)) {
      fail('Speech operation did not settle within three seconds.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _Cache extends TtsModelCache {
  _Cache(this.directory) : super(rootDirectory: directory);
  final Directory directory;
  @override
  Future<TtsModelInstallation?> installed(TtsModelDefinition model) async =>
      TtsModelInstallation(model, directory);
}

class _Engine extends SherpaTtsEngine {
  final texts = <String>[];
  Completer<void>? gate;
  bool ready = false;
  int cancelCount = 0;
  @override
  bool get isReady => ready;
  @override
  Future<void> initialize(TtsModelInstallation installation) async {
    ready = true;
  }

  @override
  Future<TtsAudio> synthesize({
    required String text,
    required int speakerId,
    required String language,
    required double speed,
    required int steps,
    String? referenceAudio,
    String referenceText = '',
  }) async {
    texts.add(text);
    await gate?.future;
    return TtsAudio(Float32List.fromList([-2, -1, 0, 1, 2]), 16000);
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    ready = false;
  }
}

class _Playback extends NativeAudioPlaybackService {
  final files = <File>[];
  final bytes = <Uint8List>[];
  final timeouts = <Duration>[];
  bool failFirst = false;
  @override
  Future<void> playFile(
    File file, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    files.add(file);
    bytes.add(await file.readAsBytes());
    timeouts.add(timeout);
    if (failFirst && files.length == 1) {
      throw StateError('synthetic playback failure');
    }
  }
}
