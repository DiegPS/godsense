import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'dartcv_minimap_tracker.dart';
import 'native_minimap_calibrator.dart';
import 'win32_screen_capture.dart';

class VisionCaptureResult {
  const VisionCaptureResult(
    this.frame,
    this.width,
    this.height,
    this.captureMicroseconds,
  );
  final NativeVisionFrame frame;
  final int width;
  final int height;
  final int captureMicroseconds;
}

abstract class VisionRuntime {
  Future<List<String>> setTargets(Map<String, List<Uint8List>> icons, int size);
  Future<VisionCaptureResult> capture(
    Map<String, dynamic> bounds,
    int size,
    bool preview,
  );
  Future<NativeVisionFrame> process(CapturedRegion image, int size);
  Future<NativeCalibrationResult> detectCalibration();
  void dispose();
}

// Used inside the worker, or with explicitly injected test doubles.
class LocalVisionRuntime implements VisionRuntime {
  LocalVisionRuntime({
    Win32ScreenCapture? capture,
    DartCvMinimapTracker? tracker,
  }) : screen = capture ?? Win32ScreenCapture(),
       tracker = tracker ?? DartCvMinimapTracker();
  final Win32ScreenCapture screen;
  final DartCvMinimapTracker tracker;
  NativeVisionFrame? _previous;
  @override
  Future<List<String>> setTargets(
    Map<String, List<Uint8List>> icons,
    int size,
  ) async {
    tracker.setTargets(icons, iconSize: size);
    _previous = null;
    return tracker.targetNames;
  }

  @override
  Future<VisionCaptureResult> capture(
    Map<String, dynamic> bounds,
    int size,
    bool preview,
  ) async {
    final image = screen.capture(
      left: (bounds['left'] as num).round(),
      top: (bounds['top'] as num).round(),
      width: (bounds['width'] as num).round(),
      height: (bounds['height'] as num).round(),
    );
    final frame = tracker.process(
      image,
      iconSize: size,
      generatePreview: preview,
      previousCapturePng: _previous?.capturePng,
      previousMaskPng: _previous?.maskPng,
      previousAnnotatedPng: _previous?.annotatedPng,
    );
    _previous = frame;
    return VisionCaptureResult(
      frame,
      image.width,
      image.height,
      image.captureMicroseconds,
    );
  }

  @override
  Future<NativeVisionFrame> process(CapturedRegion image, int size) async =>
      tracker.process(image, iconSize: size, generatePreview: false);
  @override
  Future<NativeCalibrationResult> detectCalibration() async =>
      NativeMinimapCalibrator(screen).detect();
  @override
  void dispose() {
    tracker.dispose();
    screen.dispose();
  }
}

class IsolateVisionRuntime implements VisionRuntime {
  final _responses = ReceivePort();
  final _exits = ReceivePort();
  final _errors = ReceivePort();
  final _pending = <int, Completer<Object?>>{};
  final _ready = Completer<SendPort>();
  final _closed = Completer<void>();
  Future<void> get closed => _closed.future;
  bool get failed => _disposed && !_closing;
  Isolate? _isolate;
  bool _started = false;
  bool _disposed = false;
  bool _closing = false;
  int _sequence = 0;

  void _start() {
    if (_started) return;
    _started = true;
    _responses.listen((message) {
      if (message is SendPort) {
        if (!_ready.isCompleted) _ready.complete(message);
      } else if (message is List) {
        final completer = _pending.remove(message[0]);
        if (message[1] == true) {
          completer?.complete(message[2]);
        } else {
          completer?.completeError(StateError(message[2].toString()));
        }
      }
    });
    _exits.listen((_) => _fail(StateError('El proceso de visión se detuvo.')));
    _errors.listen((error) => _fail(StateError('Error de visión: $error')));
    unawaited(
      Isolate.spawn(
        _visionWorker,
        _responses.sendPort,
        onExit: _exits.sendPort,
        onError: _errors.sendPort,
        debugName: 'GodSense vision',
      ).then(
        (isolate) {
          _isolate = isolate;
          if (_disposed) isolate.kill(priority: Isolate.immediate);
        },
        onError: (Object error, StackTrace stack) {
          _fail(error);
        },
      ),
    );
  }

  void _fail(Object error) {
    if (_disposed) return;
    if (!_ready.isCompleted) _ready.completeError(error);
    for (final pending in _pending.values) {
      pending.completeError(error);
    }
    _pending.clear();
    _disposed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _responses.close();
    _exits.close();
    _errors.close();
    if (!_closed.isCompleted) _closed.complete();
  }

  Future<Object?> _request(String method, Object? value) async {
    if (_disposed || (_closing && method != 'close')) {
      throw StateError('Visión cerrada');
    }
    _start();
    final port = await _ready.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        final error = TimeoutException('No se pudo iniciar la visión.');
        _fail(error);
        throw error;
      },
    );
    if (_disposed) throw StateError('Visión cerrada');
    final id = _sequence++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    port.send([id, method, value]);
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        // A hung native call must not leave an unbounded command queue.
        _pending.remove(id);
        _fail(TimeoutException('La visión no respondió.'));
        throw TimeoutException('La visión no respondió.');
      },
    );
  }

  @override
  Future<List<String>> setTargets(
    Map<String, List<Uint8List>> icons,
    int size,
  ) async => (await _request('targets', (icons, size))) as List<String>;
  @override
  Future<VisionCaptureResult> capture(
    Map<String, dynamic> bounds,
    int size,
    bool preview,
  ) async =>
      (await _request('capture', (bounds, size, preview)))
          as VisionCaptureResult;
  @override
  Future<NativeVisionFrame> process(CapturedRegion image, int size) async =>
      (await _request('process', (image, size))) as NativeVisionFrame;
  @override
  Future<NativeCalibrationResult> detectCalibration() async =>
      (await _request('calibrate', null)) as NativeCalibrationResult;
  @override
  void dispose() {
    if (_disposed || _closing) return;
    if (!_started) {
      _disposed = true;
      _responses.close();
      _exits.close();
      _errors.close();
      _closed.complete();
      return;
    }
    // Let in-flight GDI/OpenCV finish and release their resources before exit.
    _closing = true;
    unawaited(
      _request('close', null).then(
        (_) {
          _fail(StateError('Visión cerrada'));
        },
        onError: (Object _) {
          _fail(StateError('Visión cerrada'));
        },
      ),
    );
  }
}

Future<void> _visionWorker(SendPort responses) async {
  final commands = ReceivePort();
  final runtime = LocalVisionRuntime();
  var released = false;
  responses.send(commands.sendPort);
  try {
    await for (final message in commands) {
      final request = message as List;
      final id = request[0] as int;
      final method = request[1] as String;
      final value = request[2];
      try {
        final Object? result;
        switch (method) {
          case 'targets':
            final (icons, size) = value as (Map<String, List<Uint8List>>, int);
            result = await runtime.setTargets(icons, size);
          case 'capture':
            final (bounds, size, preview) =
                value as (Map<String, dynamic>, int, bool);
            result = await runtime.capture(bounds, size, preview);
          case 'process':
            final (image, size) = value as (CapturedRegion, int);
            result = await runtime.process(image, size);
          case 'calibrate':
            result = await runtime.detectCalibration();
          case 'close':
            runtime.dispose();
            released = true;
            responses.send([id, true, null]);
            return;
          default:
            throw StateError('Unknown vision command');
        }
        responses.send([id, true, result]);
      } catch (error) {
        responses.send([id, false, error.toString()]);
      }
    }
  } finally {
    if (!released) runtime.dispose();
    commands.close();
  }
}
