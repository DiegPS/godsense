import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_vision_controller.dart';
import 'package:godsense/infrastructure/native_vision/dartcv_minimap_tracker.dart';
import 'package:godsense/infrastructure/native_vision/desktop_screen_capture.dart';
import 'package:godsense/infrastructure/native_vision/native_minimap_calibrator.dart';
import 'package:godsense/infrastructure/native_vision/vision_runtime.dart';

void main() {
  for (final bounds in [
    {'left': 0, 'top': 0, 'width': 10, 'height': 10},
    {'left': 0, 'top': 0, 'width': 400, 'height': 100},
    {'left': 0, 'top': 0, 'width': 300, 'height': 0},
  ]) {
    test('invalid calibration never starts capture: $bounds', () {
      final runtime = _Runtime();
      final controller = NativeVisionController(runtime: runtime);
      addTearDown(controller.dispose);
      controller.configure(enabled: true, bounds: bounds);
      expect(controller.state.running, isFalse);
      expect(controller.state.error, contains('Bounds inválidos'));
      expect(runtime.calls, 0);
    });
  }

  testWidgets(
    'failed captures back off and a successful capture restores healthy state',
    (tester) async {
      var now = DateTime.utc(2026);
      final runtime = _Runtime()..failing = true;
      final controller = NativeVisionController(
        runtime: runtime,
        clock: () => now,
      );
      addTearDown(controller.dispose);
      Future<void> advance(int milliseconds) async {
        now = now.add(Duration(milliseconds: milliseconds));
        await tester.pump(Duration(milliseconds: milliseconds));
      }

      controller.configure(enabled: true, bounds: _bounds);
      await tester.pump();
      expect(runtime.calls, 1);
      expect(controller.state.error, contains('reintentando'));
      await advance(500);
      expect(runtime.calls, 1);
      await advance(500);
      expect(runtime.calls, 2);
      await advance(1000);
      expect(runtime.calls, 2);
      await advance(1000);
      expect(runtime.calls, 3);
      await advance(3000);
      expect(runtime.calls, 3);
      await advance(1000);
      expect(runtime.calls, 4);
      await advance(7000);
      expect(runtime.calls, 4);
      runtime.failing = false;
      await advance(1000);
      expect(runtime.calls, greaterThanOrEqualTo(5));
      expect(controller.state.error, isNull);
      expect(controller.state.frame, isNotNull);
      controller.stop();
      final callsAtStop = runtime.calls;
      await advance(10000);
      expect(runtime.calls, callsAtStop);
    },
  );

  testWidgets(
    'pending captures never overlap and dispose ignores the last frame',
    (tester) async {
      final runtime = _Runtime()..pending = Completer<VisionCaptureResult>();
      final controller = NativeVisionController(runtime: runtime);
      controller.configure(enabled: true, bounds: _bounds);
      await tester.pump(const Duration(seconds: 3));
      expect(runtime.calls, 1);
      controller.dispose();
      runtime.pending!.complete(_frame());
      await tester.pump();
      expect(runtime.calls, 1);
      expect(runtime.disposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'invalid or low-confidence automatic proposals do not become calibration',
    () async {
      for (final (width, height, confidence) in [
        (600, 100, .9),
        (300, 300, .24),
      ]) {
        final runtime = _Runtime()
          ..proposal = NativeCalibrationResult(
            bounds: {'left': 0, 'top': 0, 'width': width, 'height': height},
            iconSize: 26,
            confidence: confidence,
            edgesPng: Uint8List(0),
            detectedAt: DateTime.utc(2026),
          );
        final controller = NativeVisionController(runtime: runtime);
        try {
          await controller.detectCalibration();
          expect(controller.state.calibrationProposal, isNull);
          expect(controller.state.processing, isFalse);
          expect(controller.state.error, contains('bounds inválidos'));
        } finally {
          controller.dispose();
        }
      }
    },
  );
}

const _bounds = {'left': 0, 'top': 0, 'width': 300, 'height': 300};
VisionCaptureResult _frame() => VisionCaptureResult(
  NativeVisionFrame(
    capturedAt: DateTime.utc(2026),
    processedAt: DateTime.utc(2026),
    capturePng: Uint8List(0),
    maskPng: Uint8List(0),
    annotatedPng: Uint8List(0),
    detections: const [],
    stageMicroseconds: const {},
    previewMicroseconds: 0,
  ),
  300,
  300,
  100,
);

class _Runtime implements VisionRuntime {
  int calls = 0;
  bool failing = false;
  bool disposed = false;
  Completer<VisionCaptureResult>? pending;
  NativeCalibrationResult? proposal;
  @override
  Future<VisionCaptureResult> capture(
    Map<String, dynamic> bounds,
    int size,
    bool preview,
  ) async {
    calls++;
    if (pending != null) return pending!.future;
    if (failing) throw StateError('synthetic temporarily unavailable capture');
    return _frame();
  }

  @override
  Future<NativeCalibrationResult> detectCalibration() async => proposal!;
  @override
  Future<List<String>> setTargets(
    Map<String, List<Uint8List>> icons,
    int size,
  ) async => icons.keys.toList();
  @override
  Future<NativeVisionFrame> process(CapturedRegion image, int size) async =>
      _frame().frame;
  @override
  void dispose() => disposed = true;
}
