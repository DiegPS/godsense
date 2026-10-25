import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/speech/microphone_test_service.dart';
import 'package:godsense/infrastructure/speech/native_audio_playback_service.dart';
import 'package:godsense/infrastructure/speech/speech/live_captions_service.dart';

void main() {
  test(
    'cleanup failures are visible and never delete unrelated files',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'godsense-mic-cleanup-',
      );
      final sentinel = File.fromUri(directory.uri.resolve('keep.txt'));
      await sentinel.writeAsString('Keep this file.');
      final capture = _Capture();
      final service = MicrophoneTestService(
        capture: capture,
        playback: _Playback(),
        recordDuration: const Duration(milliseconds: 20),
        temporaryDirectory: () async => directory,
      );
      try {
        final running = service.run();
        await capture.started.future;
        capture.stream.add(Uint8List(640));
        await running;
        expect(service.state.cleanupFailed, isTrue);
        expect(service.state.phase, MicrophoneTestPhase.error);
        expect(await sentinel.readAsString(), 'Keep this file.');
        expect(
          await File.fromUri(directory.uri.resolve('sample.wav')).exists(),
          isFalse,
        );
      } finally {
        await service.dispose();
        await sentinel.delete();
        await directory.delete();
      }
    },
  );
  test(
    'bounded PCM is played as WAV and the temporary recording is removed',
    () async {
      final capture = _Capture();
      final playback = _Playback();
      Directory? directory;
      final service = MicrophoneTestService(
        capture: capture,
        playback: playback,
        recordDuration: const Duration(milliseconds: 20),
        temporaryDirectory: () async => directory = await Directory.systemTemp
            .createTemp('godsense-mic-check-'),
      );
      addTearDown(service.dispose);
      final phases = <MicrophoneTestPhase>[];
      final subscription = service.states.listen((s) => phases.add(s.phase));
      addTearDown(subscription.cancel);
      final running = service.run();
      await capture.started.future;
      capture.stream.add(Uint8List(120000)..fillRange(0, 120000, 32));
      await running;
      expect(service.state.phase, MicrophoneTestPhase.completed);
      expect(service.state.silent, isFalse);
      expect(
        phases,
        containsAllInOrder([
          MicrophoneTestPhase.preparing,
          MicrophoneTestPhase.recording,
          MicrophoneTestPhase.playing,
          MicrophoneTestPhase.completed,
        ]),
      );
      expect(playback.bytes!.length, 44 + 640);
      final header = ByteData.sublistView(playback.bytes!);
      expect(String.fromCharCodes(playback.bytes!.take(4)), 'RIFF');
      expect(header.getUint32(24, Endian.little), 16000);
      expect(header.getUint32(40, Endian.little), 640);
      expect(await File(playback.path!).exists(), isFalse);
      expect(await directory!.exists(), isFalse);
    },
  );

  test(
    'cancelling during playback stops sound and deletes the recording',
    () async {
      final capture = _Capture();
      final playback = _Playback(blocked: true);
      final service = MicrophoneTestService(
        capture: capture,
        playback: playback,
        recordDuration: const Duration(milliseconds: 20),
      );
      addTearDown(service.dispose);
      final running = service.run();
      await capture.started.future;
      capture.stream.add(Uint8List(640));
      await playback.started.future;
      expect(await File(playback.path!).exists(), isTrue);
      await service.cancel();
      await running;
      expect(service.state.phase, MicrophoneTestPhase.idle);
      expect(await File(playback.path!).exists(), isFalse);
      expect(playback.stops, greaterThan(0));
    },
  );

  test(
    'cancelling a pending microphone start never plays or leaves it open',
    () async {
      final capture = _Capture()..startGate = Completer<void>();
      final playback = _Playback();
      final service = MicrophoneTestService(
        capture: capture,
        playback: playback,
      );
      addTearDown(service.dispose);
      final running = service.run();
      expect(identical(service.run(), running), isTrue);
      await capture.started.future;
      final cancelling = service.cancel();
      capture.startGate!.complete();
      await Future.wait([running, cancelling]);
      expect(service.state.phase, MicrophoneTestPhase.idle);
      expect(capture.stream.isClosed, isTrue);
      expect(playback.path, isNull);
    },
  );

  test(
    'permission failure is actionable and a later test can succeed',
    () async {
      final capture = _Capture()..failure = const MicrophonePermissionDenied();
      final playback = _Playback();
      final service = MicrophoneTestService(
        capture: capture,
        playback: playback,
        recordDuration: const Duration(milliseconds: 20),
      );
      addTearDown(service.dispose);
      await service.run();
      expect(service.state.phase, MicrophoneTestPhase.error);
      expect(service.state.permissionDenied, isTrue);
      expect(playback.path, isNull);
      capture.failure = null;
      capture.started = Completer<void>();
      final retry = service.run();
      await capture.started.future;
      capture.stream.add(Uint8List(640));
      await retry;
      expect(service.state.phase, MicrophoneTestPhase.completed);
      expect(service.state.silent, isTrue);
    },
  );

  test(
    'a disconnected microphone reports failure instead of playing partial data',
    () async {
      final capture = _Capture();
      final playback = _Playback();
      final service = MicrophoneTestService(
        capture: capture,
        playback: playback,
      );
      addTearDown(service.dispose);
      final running = service.run();
      await capture.started.future;
      capture.stream.addError(StateError('device disconnected'));
      await running;
      expect(service.state.phase, MicrophoneTestPhase.error);
      expect(playback.path, isNull);
    },
  );
}

class _Capture implements SpeechAudioCapture {
  StreamController<Uint8List> stream = StreamController();
  Completer<void> started = Completer();
  Completer<void>? startGate;
  Object? failure;
  @override
  Future<Stream<Uint8List>> start() async {
    if (failure != null) throw failure!;
    if (stream.isClosed) stream = StreamController();
    started.complete();
    await startGate?.future;
    return stream.stream;
  }

  @override
  Future<void> stop() async {
    if (!stream.isClosed) unawaited(stream.close());
  }

  @override
  Future<void> dispose() => stop();
}

class _Playback extends NativeAudioPlaybackService {
  _Playback({this.blocked = false});
  final bool blocked;
  final started = Completer<void>();
  final release = Completer<void>();
  Uint8List? bytes;
  String? path;
  int stops = 0;
  @override
  Future<void> playFile(
    File file, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    path = file.path;
    bytes = await file.readAsBytes();
    started.complete();
    if (blocked) await release.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (!release.isCompleted) release.complete();
  }
}
