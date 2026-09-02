import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_vision_controller.dart';
import 'package:godsense/infrastructure/native_vision/dartcv_minimap_tracker.dart';
import 'package:godsense/infrastructure/native_vision/native_minimap_calibrator.dart';
import 'package:godsense/infrastructure/native_vision/vision_runtime.dart';

void main() {
  const bounds = {'left': 0, 'top': 0, 'width': 300, 'height': 300};
  test('late calibration proposal is discarded after stopping', () async {
    final runtime = _DelayedRuntime();
    final controller = NativeVisionController(runtime: runtime);
    addTearDown(controller.dispose);
    final detecting = controller.detectCalibration();
    controller.stop();
    runtime.calibration.complete(
      NativeCalibrationResult(
        bounds: bounds,
        iconSize: 26,
        confidence: 0.9,
        edgesPng: Uint8List(0),
        detectedAt: DateTime.now(),
      ),
    );
    await detecting;
    expect(controller.state.calibrationProposal, isNull);
    expect(controller.state.processing, isFalse);
  });
  test('late worker frame cannot restore tracking after stop', () async {
    final runtime = _DelayedRuntime();
    final controller = NativeVisionController(runtime: runtime);
    addTearDown(controller.dispose);
    controller.configure(enabled: true, bounds: bounds);
    controller.stop();
    runtime.next.complete(_result());
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.frame, isNull);
    expect(controller.state.identified, isEmpty);
    expect(controller.state.processing, isFalse);
  });
  test('stale calibration stops recognition with actionable feedback', () {
    final controller = NativeVisionController(runtime: _DelayedRuntime());
    addTearDown(controller.dispose);
    controller.configure(enabled: true, bounds: bounds, calibrationStale: true);
    expect(controller.state.running, isFalse);
    expect(controller.state.error, contains('Vuelve a calibrar'));
  });
  test(
    'capture timestamp is preserved and recalibration clears old locations',
    () async {
      final runtime = _DelayedRuntime();
      final controller = NativeVisionController(runtime: runtime);
      addTearDown(controller.dispose);
      final result = _result();
      final capturing = controller.captureOnce(bounds);
      runtime.next.complete(result);
      await capturing;
      expect(
        controller.state.lastKnown['Vex']?.lastSeen,
        result.frame.capturedAt,
      );
      expect(controller.state.lastKnown['Vex']?.x, 23);
      runtime.next = Completer<VisionCaptureResult>();
      controller.configure(
        enabled: true,
        bounds: {...bounds, 'width': 310},
        iconSize: 29,
      );
      expect(controller.state.lastKnown, isEmpty);
      expect(controller.state.events, isEmpty);
      controller.stop();
      runtime.next.complete(_result());
      await Future<void>.delayed(Duration.zero);
    },
  );
}

VisionCaptureResult _result() => VisionCaptureResult(
  NativeVisionFrame(
    capturedAt: DateTime.utc(2026),
    processedAt: DateTime.utc(2026).add(const Duration(milliseconds: 90)),
    capturePng: Uint8List(0),
    maskPng: Uint8List(0),
    annotatedPng: Uint8List(0),
    detections: const [
      NativeDetection(
        x: 0,
        y: 0,
        width: 47,
        height: 47,
        area: 1,
        championName: 'Vex',
        confidence: 0.9,
      ),
    ],
    stageMicroseconds: const {},
    previewMicroseconds: 0,
  ),
  300,
  300,
  0,
);

class _DelayedRuntime extends LocalVisionRuntime {
  final calibration = Completer<NativeCalibrationResult>();
  @override
  Future<NativeCalibrationResult> detectCalibration() => calibration.future;
  Completer<VisionCaptureResult> next = Completer();
  @override
  Future<VisionCaptureResult> capture(
    Map<String, dynamic> bounds,
    int size,
    bool preview,
  ) => next.future;
}
