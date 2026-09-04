import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/native_vision/desktop_screen_capture.dart';
import 'package:godsense/infrastructure/native_vision/native_minimap_calibrator.dart';

void main() {
  final appData = Platform.environment['APPDATA'];
  final directory = appData == null
      ? null
      : Directory('$appData\\GodSense\\calibration-corpus');

  test(
    'native Canny calibration matches Python exactly',
    () async {
      final metadata = jsonDecode(
        await File('${directory!.path}\\corpus.json').readAsString(),
      ) as List;
      final capture = DesktopScreenCapture();
      final calibrator = NativeMinimapCalibrator(capture);
      addTearDown(capture.dispose);
      for (final rawCase in metadata) {
        final testCase = Map<String, dynamic>.from(rawCase as Map);
        final expected = Map<String, dynamic>.from(testCase['expected'] as Map);
        final result = calibrator.detectBgr(
          await File('${directory.path}\\${testCase['file']}').readAsBytes(),
          width: (testCase['width'] as num).toInt(),
          height: (testCase['height'] as num).toInt(),
          priorSize: (testCase['prior_size'] as num).toInt(),
        );
        expect(
          result.bounds,
          expected,
          reason: 'Bounds mismatch for ${testCase['file']}',
        );
        expect(
          result.confidence,
          closeTo((testCase['confidence'] as num).toDouble(), 1e-6),
          reason: 'Confidence mismatch for ${testCase['file']}',
        );
        final expectedIcon = ((expected['width'] as num).toDouble() * 0.088)
            .round()
            .clamp(16, 64);
        expect(result.iconSize, expectedIcon);
      }
    },
    skip: directory?.existsSync() == true
        ? false
        : 'Calibration corpus unavailable.',
  );
}
