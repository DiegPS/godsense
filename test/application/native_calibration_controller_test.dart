import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_calibration_controller.dart';
import 'package:godsense/domain/calibration_repository.dart';
import 'package:godsense/domain/companion_models.dart';
import 'package:godsense/infrastructure/native_vision/desktop_screen_capture.dart';
import 'package:godsense/infrastructure/native_vision/native_minimap_calibrator.dart';

void main() {
  group('NativeCalibrationController', () {
    late _MemoryCalibrationRepository repository;
    late NativeCalibrationController controller;

    setUp(() {
      repository = _MemoryCalibrationRepository();
      controller = NativeCalibrationController(
        repository,
        screenCapture: _MetadataCapture(),
      );
    });

    tearDown(() => controller.dispose());

    test('loads and exposes persisted calibration', () async {
      repository.value = _calibration;
      await controller.load();

      expect(controller.state.loading, isFalse);
      expect(controller.state.calibration?.bounds, containsPair('left', 1600));
      expect(
        controller.state.calibration?.bounds,
        containsPair('display_id', 'secondary'),
      );
      expect(controller.state.error, isNull);
    });

    test('persists the complete native detection result', () async {
      await controller.saveDetected(
        NativeCalibrationResult(
          bounds: const {'left': 1600, 'top': 700, 'width': 300, 'height': 300},
          iconSize: 26,
          confidence: 0.91,
          edgesPng: Uint8List(0),
          detectedAt: DateTime.utc(2026),
        ),
      );

      expect(repository.value?.trackingIconSize, 26);
      expect(repository.value?.confidence, 0.91);
      expect(controller.state.calibration, same(repository.value));
    });

    test('rejects invalid manual bounds before persistence', () async {
      expect(
        () => controller.save(const {
          'left': 0,
          'top': 0,
          'width': 400,
          'height': 100,
        }),
        throwsArgumentError,
      );
      expect(repository.value, isNull);
    });

    test('accepts negative coordinates and binds them to a display', () async {
      await controller.save(const {
        'left': -420,
        'top': 700,
        'width': 300,
        'height': 300,
      });

      expect(repository.value?.bounds?['left'], -420);
      expect(repository.value?.bounds?['display_id'], 'secondary');
      expect(repository.value?.bounds?['local_left'], 1500);
    });

    test('clears persisted calibration', () async {
      repository.value = _calibration;
      await controller.load();
      await controller.clear();

      expect(repository.value, isNull);
      expect(controller.state.calibration, isNull);
    });
  });
}

const _calibration = CalibrationState(
  calibrated: true,
  recalibrationSuggested: false,
  bounds: {'left': 1600, 'top': 700, 'width': 300, 'height': 300},
  iconSize: 26,
  confidence: 0.9,
  defaultBounds: null,
  defaultIconSize: null,
);

class _MemoryCalibrationRepository implements CalibrationRepository {
  CalibrationState? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<CalibrationState?> load() async => value;

  @override
  Future<void> save(CalibrationState calibration) async => value = calibration;
}

class _MetadataCapture implements ScreenCaptureSource {
  @override
  Future<Map<String, dynamic>> describeBounds(
    Map<String, dynamic> bounds,
  ) async => {...bounds, 'display_id': 'secondary', 'local_left': 1500};

  @override
  Future<List<CaptureDisplay>> getDisplays() async => const [];

  @override
  Future<CapturedRegion> capture({
    required int left,
    required int top,
    required int width,
    required int height,
    String? displayId,
    int? localLeft,
    int? localTop,
  }) => throw UnimplementedError();

  @override
  void dispose() {}
}
