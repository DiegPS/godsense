@Tags(['native-cv'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/native_vision/desktop_screen_capture.dart';
import 'package:godsense/infrastructure/native_vision/native_minimap_calibrator.dart';

void main() {
  test(
    'automatic calibration inspects every corner of every display',
    () async {
      final capture = _RecordingCapture();
      final result = await NativeMinimapCalibrator(
        capture,
        configReader: () => const {'height': 1080, 'minimapscale': 1.3},
      ).detect();

      expect(capture.requests, hasLength(8));
      expect(
        capture.requests,
        contains(
          const _CaptureRequest(
            displayId: 'left',
            left: -1920,
            top: 0,
            localLeft: 0,
            localTop: 0,
          ),
        ),
      );
      expect(capture.requests.map((request) => request.displayId).toSet(), {
        'left',
        'primary',
      });
      expect(result.bounds['display_id'], isNotNull);
    },
  );
}

class _RecordingCapture implements ScreenCaptureSource {
  final requests = <_CaptureRequest>[];

  @override
  Future<List<CaptureDisplay>> getDisplays() async => const [
    CaptureDisplay(
      id: 'left',
      name: r'\\.\DISPLAY2',
      left: -1920,
      top: 0,
      width: 1920,
      height: 1080,
      dpiScale: 1,
      primary: false,
      rotation: 1,
    ),
    CaptureDisplay(
      id: 'primary',
      name: r'\\.\DISPLAY1',
      left: 0,
      top: 0,
      width: 1920,
      height: 1080,
      dpiScale: 1,
      primary: true,
      rotation: 1,
    ),
  ];

  @override
  Future<CapturedRegion> capture({
    required int left,
    required int top,
    required int width,
    required int height,
    String? displayId,
    int? localLeft,
    int? localTop,
  }) async {
    requests.add(
      _CaptureRequest(
        displayId: displayId!,
        left: left,
        top: top,
        localLeft: localLeft!,
        localTop: localTop!,
      ),
    );
    final display = (await getDisplays()).firstWhere(
      (value) => value.id == displayId,
    );
    return CapturedRegion(
      width: width,
      height: height,
      bgra: Uint8List(width * height * 4),
      capturedAt: DateTime.utc(2026),
      captureMicroseconds: 1,
      display: display,
    );
  }

  @override
  Future<Map<String, dynamic>> describeBounds(
    Map<String, dynamic> bounds,
  ) async => bounds;

  @override
  void dispose() {}
}

class _CaptureRequest {
  const _CaptureRequest({
    required this.displayId,
    required this.left,
    required this.top,
    required this.localLeft,
    required this.localTop,
  });

  final String displayId;
  final int left;
  final int top;
  final int localLeft;
  final int localTop;

  @override
  bool operator ==(Object other) =>
      other is _CaptureRequest &&
      other.displayId == displayId &&
      other.left == left &&
      other.top == top &&
      other.localLeft == localLeft &&
      other.localTop == localTop;

  @override
  int get hashCode => Object.hash(displayId, left, top, localLeft, localTop);
}
