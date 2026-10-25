import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:record/record.dart';

import '../diagnostics/app_logger.dart';
import 'native_audio_playback_service.dart';
import 'speech/live_captions_service.dart';

enum MicrophoneTestPhase {
  idle,
  preparing,
  recording,
  playing,
  cancelling,
  completed,
  error,
}

class MicrophoneTestState {
  const MicrophoneTestState({
    this.phase = MicrophoneTestPhase.idle,
    this.level = 0,
    this.silent = false,
    this.permissionDenied = false,
    this.cleanupFailed = false,
  });
  final MicrophoneTestPhase phase;
  final double level;
  final bool silent;
  final bool permissionDenied;
  final bool cleanupFailed;
  bool get active => switch (phase) {
    MicrophoneTestPhase.preparing ||
    MicrophoneTestPhase.recording ||
    MicrophoneTestPhase.playing ||
    MicrophoneTestPhase.cancelling => true,
    _ => false,
  };
}

class MicrophonePermissionDenied implements Exception {
  const MicrophonePermissionDenied();
}

class MicrophoneTestService {
  MicrophoneTestService({
    SpeechAudioCapture? capture,
    NativeAudioPlaybackService? playback,
    this.recordDuration = const Duration(seconds: 3),
    Future<Directory> Function()? temporaryDirectory,
  }) : _capture = capture ?? _TestCapture(),
       _playback = playback ?? NativeAudioPlaybackService(),
       _temporaryDirectory =
           temporaryDirectory ??
           (() => Directory.systemTemp.createTemp('godsense-mic-test-')) {
    if (recordDuration <= Duration.zero ||
        recordDuration > const Duration(seconds: 3)) {
      throw ArgumentError.value(recordDuration, 'recordDuration');
    }
  }
  final SpeechAudioCapture _capture;
  final NativeAudioPlaybackService _playback;
  final Duration recordDuration;
  final Future<Directory> Function() _temporaryDirectory;
  final _states = StreamController<MicrophoneTestState>.broadcast(sync: true);
  MicrophoneTestState _state = const MicrophoneTestState();
  Future<void>? _running;
  Completer<void>? _cancel;
  bool _disposed = false;
  Stream<MicrophoneTestState> get states => _states.stream;
  MicrophoneTestState get state => _state;
  bool get _cancelled => _disposed || _cancel?.isCompleted == true;

  Future<void> run({Future<void> Function()? prepare}) {
    if (_disposed) return Future.value();
    return _running ??= _run(prepare).whenComplete(() => _running = null);
  }

  Future<void> _run(Future<void> Function()? prepare) async {
    _cancel = Completer<void>();
    _emit(const MicrophoneTestState(phase: MicrophoneTestPhase.preparing));
    StreamSubscription<Uint8List>? subscription;
    Timer? deadline;
    Directory? temporary;
    File? recording;
    var result = const MicrophoneTestState();
    try {
      await prepare?.call();
      if (_cancelled) return;
      final stream = await _capture.start();
      if (_cancelled) return;
      final pcm = BytesBuilder(copy: true);
      final maxBytes =
          32000 *
          recordDuration.inMicroseconds ~/
          Duration.microsecondsPerSecond;
      final finished = Completer<void>();
      Object? captureError;
      var peak = 0.0;
      _emit(const MicrophoneTestState(phase: MicrophoneTestPhase.recording));
      subscription = stream.listen(
        (bytes) {
          if (_cancelled || pcm.length >= maxBytes) return;
          final remaining = maxBytes - pcm.length;
          final chunk = bytes.length <= remaining
              ? bytes
              : Uint8List.sublistView(bytes, 0, remaining);
          pcm.add(chunk);
          var level = 0.0;
          final data = ByteData.sublistView(chunk);
          for (var i = 0; i + 1 < chunk.length; i += 2) {
            final value = data.getInt16(i, Endian.little).abs() / 32768;
            if (value > level) level = value;
          }
          if (level > peak) peak = level;
          _emit(
            MicrophoneTestState(
              phase: MicrophoneTestPhase.recording,
              level: level,
            ),
          );
          if (pcm.length >= maxBytes && !finished.isCompleted) {
            finished.complete();
          }
        },
        onError: (Object error) {
          captureError = error;
          if (!finished.isCompleted) finished.complete();
        },
        onDone: () {
          if (!finished.isCompleted) {
            captureError = StateError(
              'Microphone stream ended before capture completed.',
            );
            finished.complete();
          }
        },
      );
      deadline = Timer(recordDuration, () {
        if (!finished.isCompleted) finished.complete();
      });
      await Future.any([finished.future, _cancel!.future]);
      await _capture.stop();
      await subscription.cancel();
      subscription = null;
      if (_cancelled) return;
      if (captureError != null) throw captureError!;
      final bytes = pcm.takeBytes();
      if (bytes.length < 2) throw StateError('No microphone samples received.');
      temporary = await _temporaryDirectory();
      recording = File(p.join(temporary.path, 'sample.wav'));
      await recording.writeAsBytes(_wave(bytes), flush: true);
      if (_cancelled) return;
      _emit(const MicrophoneTestState(phase: MicrophoneTestPhase.playing));
      await _playback.playFile(recording, timeout: const Duration(seconds: 8));
      result = MicrophoneTestState(
        phase: MicrophoneTestPhase.completed,
        silent: peak < 0.001,
      );
    } catch (error, stack) {
      if (!_cancelled) {
        AppLogger.warning(
          'Microphone test failed.',
          category: 'speech',
          error: error,
          stackTrace: stack,
        );
        result = MicrophoneTestState(
          phase: MicrophoneTestPhase.error,
          permissionDenied: error is MicrophonePermissionDenied,
        );
      }
    } finally {
      deadline?.cancel();
      try {
        await subscription?.cancel();
      } catch (_) {}
      try {
        await _capture.stop();
      } catch (_) {}
      try {
        await _playback.stop();
      } catch (_) {}
      try {
        if (recording != null && await recording.exists()) {
          await recording.delete();
        }
        if (temporary != null && await temporary.exists()) {
          await temporary.delete();
        }
      } catch (error, stack) {
        AppLogger.warning(
          'Microphone test cleanup failed.',
          category: 'speech',
          error: error,
          stackTrace: stack,
        );
        result = const MicrophoneTestState(
          phase: MicrophoneTestPhase.error,
          cleanupFailed: true,
        );
      }
      _emit(
        _cancelled && !result.cleanupFailed
            ? const MicrophoneTestState()
            : result,
      );
    }
  }

  Future<void> cancel() async {
    final running = _running;
    if (running == null) return;
    _emit(const MicrophoneTestState(phase: MicrophoneTestPhase.cancelling));
    if (_cancel?.isCompleted == false) _cancel!.complete();
    await _playback.stop();
    await running;
  }

  void _emit(MicrophoneTestState next) {
    if (_disposed) return;
    _state = next;
    _states.add(next);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await cancel();
    await _capture.dispose();
    await _playback.dispose();
    await _states.close();
  }
}

class _TestCapture implements SpeechAudioCapture {
  AudioRecorder? _recorder;
  @override
  Future<Stream<Uint8List>> start() async {
    final recorder = _recorder ??= AudioRecorder();
    if (!await recorder.hasPermission()) {
      throw const MicrophonePermissionDenied();
    }
    return recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
    );
  }

  @override
  Future<void> stop() async {
    await _recorder?.stop();
  }

  @override
  Future<void> dispose() async {
    await _recorder?.dispose();
    _recorder = null;
  }
}

Uint8List _wave(Uint8List pcm) {
  final length = pcm.length - pcm.length % 2;
  final bytes = Uint8List(44 + length);
  final header = ByteData.sublistView(bytes);
  void text(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  text(0, 'RIFF');
  text(8, 'WAVE');
  text(12, 'fmt ');
  text(36, 'data');
  header.setUint32(4, 36 + length, Endian.little);
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, 16000, Endian.little);
  header.setUint32(28, 32000, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  header.setUint32(40, length, Endian.little);
  bytes.setRange(44, bytes.length, pcm);
  return bytes;
}
