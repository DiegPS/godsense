import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_calibration_controller.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/application/native_vision_controller.dart';
import 'package:godsense/application/vision_session_coordinator.dart';
import 'package:godsense/domain/calibration_repository.dart';
import 'package:godsense/domain/companion_models.dart';
import 'package:godsense/infrastructure/native_vision/dartcv_minimap_tracker.dart';
import 'package:godsense/infrastructure/native_vision/desktop_screen_capture.dart';
import 'package:godsense/infrastructure/native_vision/native_minimap_calibrator.dart';
import 'package:godsense/infrastructure/native_vision/vision_runtime.dart';

void main() {
  test(
    'saved calibration starts vision without an active League game',
    () async {
      final calibration = NativeCalibrationController(
        _CalibrationRepository(),
        screenCapture: _MetadataCapture(),
      );
      await calibration.load();
      final league = NativeLeagueController();
      final vision = NativeVisionController(runtime: _IdleRuntime());
      final container = ProviderContainer(
        overrides: [
          nativeCalibrationProvider.overrideWith((_) => calibration),
          nativeLeagueProvider.overrideWith((_) => league),
          nativeVisionProvider.overrideWith((_) => vision),
        ],
      );
      addTearDown(container.dispose);

      container.read(visionSessionCoordinatorProvider);
      await Future<void>.delayed(Duration.zero);

      expect(league.state.liveGame, isNull);
      expect(vision.state.running, isTrue);
      expect(vision.state.bounds?['display_id'], 'secondary');
    },
  );
}

class _CalibrationRepository implements CalibrationRepository {
  CalibrationState value = const CalibrationState(
    calibrated: true,
    recalibrationSuggested: false,
    bounds: {
      'left': -420,
      'top': 700,
      'width': 300,
      'height': 300,
      'display_id': 'secondary',
      'local_left': 1500,
      'local_top': 700,
    },
    iconSize: 26,
  );

  @override
  Future<void> clear() async {}

  @override
  Future<CalibrationState?> load() async => value;

  @override
  Future<void> save(CalibrationState calibration) async => value = calibration;
}

class _MetadataCapture implements ScreenCaptureSource {
  @override
  Future<Map<String, dynamic>> describeBounds(
    Map<String, dynamic> bounds,
  ) async => bounds;

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

class _IdleRuntime implements VisionRuntime {
  @override
  Future<VisionCaptureResult> capture(
    Map<String, dynamic> bounds,
    int size,
    bool preview,
  ) async => VisionCaptureResult(
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
    (bounds['width'] as num).round(),
    (bounds['height'] as num).round(),
    1,
  );

  @override
  Future<NativeCalibrationResult> detectCalibration() =>
      throw UnimplementedError();

  @override
  Future<NativeVisionFrame> process(CapturedRegion image, int size) =>
      throw UnimplementedError();

  @override
  Future<List<String>> setTargets(
    Map<String, List<Uint8List>> icons,
    int size,
  ) async => icons.keys.toList();

  @override
  void dispose() {}
}
