import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _PlaySoundWNative = Int32 Function(
  Pointer<Utf16> sound,
  IntPtr module,
  Uint32 flags,
);
typedef _PlaySoundW = int Function(Pointer<Utf16> sound, int module, int flags);

/// Plays generated WAV files without a persistent native callback into Dart.
///
/// Flutter deletes Dart callbacks during Hot Restart, so the Windows path uses
/// the operating system's multimedia API without retaining a Dart callback.
class NativeAudioPlaybackService {
  static const _sndAsync = 0x0001;
  static const _sndNoDefault = 0x0002;
  static const _sndFileName = 0x00020000;

  _PlaySoundW? _playSound;
  Completer<void>? _activePlayback;
  Timer? _completionTimer;
  Process? _process;
  bool _disposed = false;

  Future<void> startKeepAlive() async {}

  Future<void> playFile(
    File file, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (_disposed) return;
    await stop();

    if (Platform.isWindows) {
      await _playWindows(file, timeout: timeout);
      return;
    }
    await _playProcess(file, timeout: timeout);
  }

  Future<void> _playWindows(File file, {required Duration timeout}) async {
    final playback = Completer<void>();
    Timer? completionTimer;
    _activePlayback = playback;
    final sound = file.absolute.path.toNativeUtf16();
    try {
      final started = _windowsPlaySound(
        sound,
        0,
        _sndAsync | _sndNoDefault | _sndFileName,
      );
      if (started == 0) {
        throw StateError('Windows could not play ${file.path}.');
      }
      final duration = await _wavDuration(file);
      if (!identical(_activePlayback, playback)) return;
      completionTimer = Timer(duration, () {
        if (!playback.isCompleted) playback.complete();
      });
      _completionTimer = completionTimer;
      try {
        await playback.future.timeout(timeout);
      } on TimeoutException {
        _windowsPlaySound(nullptr.cast<Utf16>(), 0, 0);
        rethrow;
      }
    } finally {
      calloc.free(sound);
      completionTimer?.cancel();
      if (identical(_completionTimer, completionTimer)) _completionTimer = null;
      if (identical(_activePlayback, playback)) _activePlayback = null;
    }
  }

  Future<void> _playProcess(File file, {required Duration timeout}) async {
    final command = Platform.isMacOS ? 'afplay' : 'aplay';
    final process = await Process.start(command, [file.absolute.path]);
    _process = process;
    try {
      final exitCode = await process.exitCode.timeout(timeout);
      if (exitCode != 0) {
        throw StateError('$command exited with code $exitCode.');
      }
    } finally {
      if (identical(_process, process)) _process = null;
    }
  }

  Future<void> stop() async {
    _completionTimer?.cancel();
    _completionTimer = null;
    if (Platform.isWindows && _playSound != null) {
      _windowsPlaySound(nullptr.cast<Utf16>(), 0, 0);
    }
    _process?.kill();
    _process = null;
    final playback = _activePlayback;
    _activePlayback = null;
    if (playback != null && !playback.isCompleted) playback.complete();
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
  }

  _PlaySoundW get _windowsPlaySound =>
      _playSound ??= DynamicLibrary.open('winmm.dll')
          .lookupFunction<_PlaySoundWNative, _PlaySoundW>('PlaySoundW');

  static Future<Duration> _wavDuration(File file) async {
    final builder = await file
        .openRead(0, 44)
        .fold<BytesBuilder>(
          BytesBuilder(copy: false),
          (builder, bytes) => builder..add(bytes),
        );
    final bytes = builder.takeBytes();
    if (bytes.length < 44) return const Duration(milliseconds: 100);
    final data = ByteData.sublistView(bytes);
    final byteRate = data.getUint32(28, Endian.little);
    final dataSize = data.getUint32(40, Endian.little);
    if (byteRate == 0) return const Duration(milliseconds: 100);
    return Duration(
      microseconds: dataSize * Duration.microsecondsPerSecond ~/ byteRate,
    );
  }
}
