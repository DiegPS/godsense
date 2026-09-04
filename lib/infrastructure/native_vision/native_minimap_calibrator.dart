import 'dart:math' as math;
import 'dart:typed_data';

import 'package:opencv_dart/opencv.dart' as cv;

import '../league/league_installation.dart';
import 'desktop_screen_capture.dart';

class NativeCalibrationResult {
  const NativeCalibrationResult({
    required this.bounds,
    required this.iconSize,
    required this.confidence,
    required this.edgesPng,
    required this.detectedAt,
  });

  final Map<String, dynamic> bounds;
  final int iconSize;
  final double confidence;
  final Uint8List edgesPng;
  final DateTime detectedAt;
}

class NativeMinimapCalibrator {
  NativeMinimapCalibrator(
    this.capture, {
    Map<String, num> Function()? configReader,
  }) : _configReader = configReader ?? LeagueConfigSource().read;

  final ScreenCaptureSource capture;
  final Map<String, num> Function() _configReader;

  Future<NativeCalibrationResult> detect() async {
    final config = _configReader();
    final displays = await capture.getDisplays();
    NativeCalibrationResult? best;
    Object? lastError;
    for (final display in displays) {
      final configuredHeight = config['height']?.toInt();
      final referenceHeight = configuredHeight != null && configuredHeight > 0
          ? configuredHeight
          : display.height;
      final scale = config['minimapscale']?.toDouble() ?? 1.3;
      final priorSize = (referenceHeight * scale * 0.119)
          .round()
          .clamp(120, math.min(900, math.min(display.width, display.height)))
          .toInt();
      final roiSide = math
          .min(
            math.min(display.width, display.height),
            math.max(
              (2.2 * priorSize).round(),
              (0.5 * math.min(display.width, display.height)).round(),
            ),
          )
          .toInt();
      final positions = <(int, int)>{
        (display.left, display.top),
        (display.left + display.width - roiSide, display.top),
        (display.left, display.top + display.height - roiSide),
        (
          display.left + display.width - roiSide,
          display.top + display.height - roiSide,
        ),
      };
      for (final (roiLeft, roiTop) in positions) {
        try {
          final captured = await capture.capture(
            left: roiLeft,
            top: roiTop,
            width: roiSide,
            height: roiSide,
            displayId: display.id,
            localLeft: roiLeft - display.left,
            localTop: roiTop - display.top,
          );
          final detected = _detectCaptured(
            captured,
            roiLeft,
            roiTop,
            priorSize,
            display: display,
          );
          if (best == null || detected.confidence > best.confidence) {
            best = detected;
          }
        } catch (error) {
          lastError = error;
        }
      }
    }
    if (best == null) {
      throw StateError('No se pudo leer ninguna pantalla: $lastError');
    }
    return best;
  }

  NativeCalibrationResult detectBgr(
    Uint8List bgr, {
    required int width,
    required int height,
    required int priorSize,
    int absoluteLeft = 0,
    int absoluteTop = 0,
  }) {
    if (bgr.length != width * height * 3) {
      throw ArgumentError('Expected ${width * height * 3} BGR bytes.');
    }
    final bgrMat = cv.Mat.fromList(height, width, cv.MatType.CV_8UC3, bgr);
    final bgraMat = cv.cvtColor(bgrMat, cv.COLOR_BGR2BGRA);
    try {
      return _detectCaptured(
        CapturedRegion(
          width: width,
          height: height,
          bgra: Uint8List.fromList(bgraMat.data),
          capturedAt: DateTime.now(),
          captureMicroseconds: 0,
        ),
        absoluteLeft,
        absoluteTop,
        priorSize,
      );
    } finally {
      bgraMat.dispose();
      bgrMat.dispose();
    }
  }

  NativeCalibrationResult _detectCaptured(
    CapturedRegion captured,
    int roiLeft,
    int roiTop,
    int priorSize, {
    CaptureDisplay? display,
  }) {
    final bgra = cv.Mat.fromList(
      captured.height,
      captured.width,
      cv.MatType.CV_8UC4,
      captured.bgra,
    );
    final gray = cv.cvtColor(bgra, cv.COLOR_BGRA2GRAY);
    final edges = cv.canny(gray, 40, 120, apertureSize: 3);
    try {
      final data = edges.data;
      final rowMass = List<double>.filled(edges.rows, 0);
      final colMass = List<double>.filled(edges.cols, 0);
      for (var y = 0; y < edges.rows; y++) {
        final offset = y * edges.cols;
        for (var x = 0; x < edges.cols; x++) {
          if (data[offset + x] != 0) {
            rowMass[y]++;
            colMass[x]++;
          }
        }
      }
      final rowPeak = rowMass.reduce(math.max);
      final colPeak = colMass.reduce(math.max);
      final subMin = math.min(edges.cols, edges.rows).toDouble();
      final sizeRef = math.max(
        0.12 * subMin,
        math.min(priorSize.toDouble(), subMin),
      );
      if (rowPeak <= 0 || colPeak <= 0) {
        final size = sizeRef
            .round()
            .clamp(1, math.min(captured.width, captured.height))
            .toInt();
        return NativeCalibrationResult(
          bounds: _bounds(
            display,
            left: roiLeft + captured.width - size,
            top: roiTop + captured.height - size,
            width: size,
            height: size,
          ),
          iconSize: _deriveIconSize(size),
          confidence: 0,
          edgesPng: cv.imencode('.png', edges).$2,
          detectedAt: DateTime.now(),
        );
      }
      final strongRows = <int>[
        for (var index = 0; index < rowMass.length; index++)
          if (rowMass[index] >= 0.55 * rowPeak) index,
      ];
      final strongCols = <int>[
        for (var index = 0; index < colMass.length; index++)
          if (colMass[index] >= 0.55 * colPeak) index,
      ];
      final right = strongCols.reduce(math.max);
      final bottom = strongRows.reduce(math.max);
      final left = _nearestStrongBelow(strongCols, right, right - sizeRef);
      final top = _nearestStrongBelow(strongRows, bottom, bottom - sizeRef);
      final width = math.max(1, right - left);
      final height = math.max(1, bottom - top);
      final lineRef = math.max(1.0, 0.9 * sizeRef);
      final lineConfidence = math.min(
        1.0,
        (rowMass[top] + colMass[left]) / (2 * lineRef),
      );
      final squareness =
          1 - math.min(1.0, (width - height).abs() / math.max(width, height));
      final averageSize = (width + height) / 2;
      final sizeMatch =
          1 - math.min(1.0, (averageSize - sizeRef).abs() / sizeRef);
      final confidence =
          0.5 * lineConfidence + 0.25 * squareness + 0.25 * sizeMatch;
      return NativeCalibrationResult(
        bounds: _bounds(
          display,
          left: roiLeft + left,
          top: roiTop + top,
          width: width,
          height: height,
        ),
        iconSize: _deriveIconSize(width),
        confidence: confidence,
        edgesPng: cv.imencode('.png', edges).$2,
        detectedAt: DateTime.now(),
      );
    } finally {
      edges.dispose();
      gray.dispose();
      bgra.dispose();
    }
  }

  Map<String, dynamic> _bounds(
    CaptureDisplay? display, {
    required int left,
    required int top,
    required int width,
    required int height,
  }) =>
      display?.enrichBounds(
        regionLeft: left,
        regionTop: top,
        regionWidth: width,
        regionHeight: height,
      ) ??
      {'left': left, 'top': top, 'width': width, 'height': height};

  int _nearestStrongBelow(List<int> strong, int limit, double target) {
    final candidates = strong.where((value) => value < limit);
    if (candidates.isEmpty) return 0;
    return candidates.reduce(
      (best, value) =>
          (value - target).abs() < (best - target).abs() ? value : best,
    );
  }

  int _deriveIconSize(int width) => (width * 0.088).round().clamp(16, 64);
}
