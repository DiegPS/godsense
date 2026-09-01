import 'dart:ffi' as ffi;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart' as memory;
import 'package:opencv_dart/opencv.dart' as cv;

import '../../domain/summoners_rift_map.dart';
import 'win32_screen_capture.dart';

class NativeDetection {
  const NativeDetection({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.area,
    this.championName,
    this.confidence = 0,
    this.templateScore = 0,
    this.histogramScore = 0,
    this.pixelMae = -1,
  });

  final int x;
  final int y;
  final int width;
  final int height;
  final double area;
  final String? championName;
  final double confidence;
  final double templateScore;
  final double histogramScore;
  final double pixelMae;

  double get centerX => x + width / 2;
  double get centerY => y + height / 2;

  String regionFor(int frameWidth, int frameHeight) {
    return resolveMapLocation(
      centerX,
      centerY,
      frameWidth.toDouble(),
      frameHeight.toDouble(),
    ).name;
  }
}

class NativeChampionTarget {
  NativeChampionTarget({required this.name, required this.variants});

  final String name;
  final List<NativeChampionVariant> variants;

  void dispose() {
    for (final variant in variants) {
      variant.faceTemplate.dispose();
    }
  }
}

class NativeChampionVariant {
  NativeChampionVariant({required this.faceTemplate, required this.histogram});

  final cv.Mat faceTemplate;
  final List<double> histogram;
}

class NativeVisionFrame {
  const NativeVisionFrame({
    required this.capturedAt,
    required this.processedAt,
    required this.capturePng,
    required this.maskPng,
    required this.annotatedPng,
    required this.detections,
    required this.stageMicroseconds,
    required this.previewMicroseconds,
  });

  final DateTime capturedAt;
  final DateTime processedAt;
  final Uint8List capturePng;
  final Uint8List maskPng;
  final Uint8List annotatedPng;
  final List<NativeDetection> detections;
  final Map<String, int> stageMicroseconds;
  final int previewMicroseconds;

  int get cvMicroseconds => stageMicroseconds.values.fold(0, (a, b) => a + b);
  Duration get processingTime => Duration(microseconds: cvMicroseconds);
}

class DartCvMinimapTracker {
  final List<NativeChampionTarget> _targets = [];
  final Float32List _float32Scratch = Float32List(1);
  cv.Mat? _kernel;

  void setTargets(Map<String, List<Uint8List>> icons, {required int iconSize}) {
    for (final target in _targets) {
      target.dispose();
    }
    _targets.clear();
    for (final entry in icons.entries) {
      final variants = <NativeChampionVariant>[];
      for (final bytes in entry.value) {
        final decoded = cv.imdecode(bytes, cv.IMREAD_COLOR);
        if (decoded.isEmpty) {
          decoded.dispose();
          continue;
        }
        final resized = cv.resize(decoded, (iconSize, iconSize));
        final face = _innerFace(resized, iconSize);
        decoded.dispose();
        resized.dispose();
        if (face == null) continue;
        variants.add(
          NativeChampionVariant(
            faceTemplate: face,
            histogram: _faceHistogram(face),
          ),
        );
      }
      if (variants.isNotEmpty) {
        _targets.add(NativeChampionTarget(name: entry.key, variants: variants));
      }
    }
  }

  void setRawTargets(
    Map<String, List<Uint8List>> icons, {
    required int iconSize,
  }) {
    for (final target in _targets) {
      target.dispose();
    }
    _targets.clear();
    for (final entry in icons.entries) {
      final variants = <NativeChampionVariant>[];
      for (final bytes in entry.value) {
        if (bytes.length != iconSize * iconSize * 3) continue;
        final image = cv.Mat.fromList(
          iconSize,
          iconSize,
          cv.MatType.CV_8UC3,
          bytes,
        );
        final face = _innerFace(image, iconSize);
        image.dispose();
        if (face == null) continue;
        variants.add(
          NativeChampionVariant(
            faceTemplate: face,
            histogram: _faceHistogram(face),
          ),
        );
      }
      if (variants.isNotEmpty) {
        _targets.add(NativeChampionTarget(name: entry.key, variants: variants));
      }
    }
  }

  NativeVisionFrame process(
    CapturedRegion capture, {
    required int iconSize,
    required bool generatePreview,
    Uint8List? previousCapturePng,
    Uint8List? previousMaskPng,
    Uint8List? previousAnnotatedPng,
  }) {
    final stopwatch = Stopwatch()..start();
    final stages = <String, int>{};
    var checkpoint = 0;
    void mark(String name) {
      final elapsed = stopwatch.elapsedMicroseconds;
      stages[name] = elapsed - checkpoint;
      checkpoint = elapsed;
    }

    final inputBuffer = memory.calloc<ffi.Uint8>(capture.bgra.length);
    inputBuffer.asTypedList(capture.bgra.length).setAll(0, capture.bgra);
    final bgra = cv.Mat.fromBuffer(
      capture.height,
      capture.width,
      cv.MatType.CV_8UC4,
      inputBuffer.cast(),
    );
    final bgr = cv.cvtColor(bgra, cv.COLOR_BGRA2BGR);
    mark('input');
    final hsv = cv.cvtColor(bgr, cv.COLOR_BGR2HSV);
    final lower1 = cv.Scalar(2, 120, 120);
    final upper1 = cv.Scalar(5, 255, 255);
    final lower2 = cv.Scalar(170, 120, 120);
    final upper2 = cv.Scalar(179, 255, 255);
    final lowRed = cv.inRangebyScalar(hsv, lower1, upper1);
    final highRed = cv.inRangebyScalar(hsv, lower2, upper2);
    final redMask = cv.bitwiseOR(lowRed, highRed);
    _kernel ??= cv.Mat.ones(3, 3, cv.MatType.CV_8UC1);
    // DartCV substitutes Scalar(0) when borderValue is omitted, whereas
    // Python OpenCV uses morphologyDefaultBorderValue(). The distinction is
    // observable for closing operations that touch an image boundary.
    final morphologyBorder = cv.morphologyDefaultBorderValue();
    final dilated = cv.dilate(
      redMask,
      _kernel!,
      iterations: 1,
      borderValue: morphologyBorder,
    );
    final closed = cv.morphologyEx(
      dilated,
      cv.MORPH_CLOSE,
      _kernel!,
      borderValue: morphologyBorder,
    );
    mark('mask');
    final cleanMask = cv.Mat.zeros(
      capture.height,
      capture.width,
      cv.MatType.CV_8UC1,
    );
    final testMask = cv.Mat.zeros(
      capture.height,
      capture.width,
      cv.MatType.CV_8UC1,
    );
    final (contours, hierarchy) = cv.findContours(
      closed,
      cv.RETR_EXTERNAL,
      cv.CHAIN_APPROX_SIMPLE,
    );
    final zero = cv.Scalar(0);
    final white = cv.Scalar(255);
    for (var index = 0; index < contours.length; index++) {
      final contour = contours[index];
      if (cv.contourArea(contour) <= 15) continue;
      final (center, radius) = cv.minEnclosingCircle(contour);
      testMask.setTo(zero);
      // Python/OpenCV uses int(cx), which truncates positive contour centers.
      // Rounding here changes the artifact mask by one pixel on half-pixel
      // centers and can add or remove ring-template hits.
      final centerPoint = cv.Point(center.x.toInt(), center.y.toInt());
      cv.circle(
        testMask,
        centerPoint,
        (radius * 0.4).toInt(),
        white,
        thickness: cv.FILLED,
      );
      final intersection = cv.bitwiseAND(closed, testMask);
      final mean = cv.mean(intersection, mask: testMask);
      if (mean.val1 < 80) {
        // Python calls drawContours(cleanMask, [contour], -1, ...). Passing
        // the complete contour vector with an index is normally equivalent,
        // but differs by boundary pixels for contours clipped at the image
        // edge in the DartCV wrapper.
        final singleContour = cv.VecVecPoint.fromVecPoint(contour);
        try {
          cv.drawContours(
            cleanMask,
            singleContour,
            -1,
            white,
            thickness: cv.FILLED,
          );
        } finally {
          singleContour.dispose();
        }
      }
      mean.dispose();
      intersection.dispose();
      centerPoint.dispose();
      center.dispose();
    }
    final filtered = cv.bitwiseAND(closed, cleanMask);
    mark('artifact_filter');

    if (filtered.rows < iconSize || filtered.cols < iconSize) {
      throw StateError(
        'Capture ${filtered.cols}x${filtered.rows} is smaller than ring template ${iconSize}x$iconSize.',
      );
    }
    final ringTemplate = cv.Mat.zeros(iconSize, iconSize, cv.MatType.CV_8UC1);
    final ringCenter = cv.Point(iconSize ~/ 2, iconSize ~/ 2);
    cv.circle(ringTemplate, ringCenter, iconSize ~/ 2 - 1, white, thickness: 2);
    final match = cv.matchTemplate(filtered, ringTemplate, cv.TM_CCOEFF_NORMED);
    final matchValues = match.dataPtr.cast<ffi.Float>().asTypedList(
      match.rows * match.cols,
    );
    final hits = <({int x, int y})>[];
    for (var y = 0; y < match.rows; y++) {
      for (var x = 0; x < match.cols; x++) {
        if (matchValues[y * match.cols + x] >= 0.4) {
          hits.add((x: x, y: y));
        }
      }
    }
    final grouped = _groupRectangles(
      hits,
      size: iconSize,
      groupThreshold: 1,
      eps: 0.5,
      frameWidth: capture.width,
      frameHeight: capture.height,
    );
    mark('ring_sweep');
    final annotated = bgr.clone();
    final detections = <NativeDetection>[];
    final scored =
        <
          ({
            int rectIndex,
            int targetIndex,
            double combined,
            double tm,
            double hist,
            double mae,
          })
        >[];

    for (var rectIndex = 0; rectIndex < grouped.length; rectIndex++) {
      final rect = grouped[rectIndex];
      final crop = _integerCrop(bgr, rect.x, rect.y, rect.width, rect.height);
      final face = _innerFace(crop, iconSize);
      crop.dispose();
      if (face == null) continue;
      final liveHistogram = _faceHistogram(face);
      for (var targetIndex = 0; targetIndex < _targets.length; targetIndex++) {
        final target = _targets[targetIndex];
        ({double combined, double tm, double hist, double mae})? best;
        for (final variant in target.variants) {
          if (face.rows != variant.faceTemplate.rows ||
              face.cols != variant.faceTemplate.cols) {
            continue;
          }
          final result = cv.matchTemplate(
            face,
            variant.faceTemplate,
            cv.TM_CCOEFF_NORMED,
          );
          final (_, tm, minLoc, maxLoc) = cv.minMaxLoc(result);
          minLoc.dispose();
          maxLoc.dispose();
          result.dispose();
          final hist = _histogramCorrelation(liveHistogram, variant.histogram);
          final combined = 0.7 * tm + 0.3 * hist;
          final mae = _pixelMae(face, variant.faceTemplate);
          if (best == null || combined > best.combined) {
            best = (combined: combined, tm: tm, hist: hist, mae: mae);
          }
        }
        if (best != null) {
          scored.add((
            rectIndex: rectIndex,
            targetIndex: targetIndex,
            combined: best.combined,
            tm: best.tm,
            hist: best.hist,
            mae: best.mae,
          ));
        }
      }
      face.dispose();
    }
    scored.sort((a, b) => b.combined.compareTo(a.combined));
    final assignedRects = <int>{};
    final assignedTargets = <int>{};
    final assignments =
        <
          int,
          ({
            int targetIndex,
            double combined,
            double tm,
            double hist,
            double mae,
          })
        >{};
    for (final score in scored) {
      if (score.combined < 0.35) break;
      if (assignedRects.contains(score.rectIndex) ||
          assignedTargets.contains(score.targetIndex)) {
        continue;
      }
      assignedRects.add(score.rectIndex);
      assignedTargets.add(score.targetIndex);
      assignments[score.rectIndex] = (
        targetIndex: score.targetIndex,
        combined: score.combined,
        tm: score.tm,
        hist: score.hist,
        mae: score.mae,
      );
    }
    mark('classification');

    try {
      for (var index = 0; index < grouped.length; index++) {
        final rect = grouped[index];
        final assignment = assignments[index];
        detections.add(
          NativeDetection(
            x: rect.x,
            y: rect.y,
            width: rect.width,
            height: rect.height,
            area: 0.4,
            championName: assignment == null
                ? null
                : _targets[assignment.targetIndex].name,
            confidence: assignment?.combined ?? 0,
            templateScore: assignment?.tm ?? 0,
            histogramScore: assignment?.hist ?? 0,
            pixelMae: assignment?.mae ?? -1,
          ),
        );
        final color = assignment == null
            ? cv.Scalar(0, 165, 255)
            : cv.Scalar(0, 255, 0);
        cv.rectangle(annotated, rect, color, thickness: 2);
        color.dispose();
      }

      final processedAt = DateTime.now();
      final previewStopwatch = Stopwatch()..start();
      final capturePng = generatePreview || previousCapturePng == null
          ? cv.imencode('.png', bgr).$2
          : previousCapturePng;
      final maskPng = generatePreview || previousMaskPng == null
          ? cv.imencode('.png', filtered).$2
          : previousMaskPng;
      final annotatedPng = generatePreview || previousAnnotatedPng == null
          ? cv.imencode('.png', annotated).$2
          : previousAnnotatedPng;
      return NativeVisionFrame(
        capturedAt: capture.capturedAt,
        processedAt: processedAt,
        capturePng: capturePng,
        maskPng: maskPng,
        annotatedPng: annotatedPng,
        detections: detections,
        stageMicroseconds: stages,
        previewMicroseconds: previewStopwatch.elapsedMicroseconds,
      );
    } finally {
      hierarchy.dispose();
      contours.dispose();
      for (final rect in grouped) {
        rect.dispose();
      }
      match.dispose();
      ringCenter.dispose();
      ringTemplate.dispose();
      annotated.dispose();
      filtered.dispose();
      testMask.dispose();
      cleanMask.dispose();
      closed.dispose();
      dilated.dispose();
      morphologyBorder.dispose();
      redMask.dispose();
      highRed.dispose();
      lowRed.dispose();
      upper2.dispose();
      lower2.dispose();
      upper1.dispose();
      lower1.dispose();
      white.dispose();
      zero.dispose();
      hsv.dispose();
      bgr.dispose();
      bgra.dispose();
      memory.calloc.free(inputBuffer);
    }
  }

  NativeVisionFrame processPng(
    Uint8List png, {
    required int iconSize,
    bool generatePreview = false,
  }) {
    final bgr = cv.imdecode(png, cv.IMREAD_COLOR);
    if (bgr.isEmpty) {
      bgr.dispose();
      throw const FormatException('Could not decode corpus PNG.');
    }
    final bgra = cv.cvtColor(bgr, cv.COLOR_BGR2BGRA);
    try {
      return process(
        CapturedRegion(
          width: bgra.cols,
          height: bgra.rows,
          bgra: Uint8List.fromList(bgra.data),
          capturedAt: DateTime.now(),
          captureMicroseconds: 0,
        ),
        iconSize: iconSize,
        generatePreview: generatePreview,
      );
    } finally {
      bgra.dispose();
      bgr.dispose();
    }
  }

  NativeVisionFrame processBgr(
    Uint8List bgrBytes, {
    required int width,
    required int height,
    required int iconSize,
    bool generatePreview = false,
  }) {
    if (bgrBytes.length != width * height * 3) {
      throw ArgumentError('Expected ${width * height * 3} BGR bytes.');
    }
    final bgr = cv.Mat.fromList(height, width, cv.MatType.CV_8UC3, bgrBytes);
    final bgra = cv.cvtColor(bgr, cv.COLOR_BGR2BGRA);
    try {
      return process(
        CapturedRegion(
          width: width,
          height: height,
          bgra: Uint8List.fromList(bgra.data),
          capturedAt: DateTime.now(),
          captureMicroseconds: 0,
        ),
        iconSize: iconSize,
        generatePreview: generatePreview,
      );
    } finally {
      bgra.dispose();
      bgr.dispose();
    }
  }

  cv.Mat? _innerFace(cv.Mat image, int size) {
    if (image.rows != size || image.cols != size) return null;
    final padding = (size * 0.25).floor();
    final edge = size - padding * 2;
    if (edge <= 0) return null;
    return _integerCrop(image, padding, padding, edge, edge);
  }

  cv.Mat _integerCrop(cv.Mat image, int left, int top, int width, int height) {
    final channels = image.channels;
    final source = image.data;
    final output = Uint8List(width * height * channels);
    final sourceStride = image.cols * channels;
    final rowBytes = width * channels;
    for (var row = 0; row < height; row++) {
      final sourceStart = (top + row) * sourceStride + left * channels;
      output.setRange(
        row * rowBytes,
        (row + 1) * rowBytes,
        source,
        sourceStart,
      );
    }
    return cv.Mat.fromList(height, width, cv.MatType.CV_8UC(channels), output);
  }

  List<double> _faceHistogram(cv.Mat face) {
    final hsv = cv.cvtColor(face, cv.COLOR_BGR2HSV);
    final histogram = List<double>.filled(30 * 32, 0);
    final data = hsv.data;
    for (var index = 0; index < hsv.rows * hsv.cols; index++) {
      final h = data[index * 3];
      final s = data[index * 3 + 1];
      final hBin = (h * 30 ~/ 180).clamp(0, 29);
      final sBin = (s * 32 ~/ 256).clamp(0, 31);
      histogram[hBin * 32 + sBin]++;
    }
    hsv.dispose();
    final norm = histogram.fold<double>(0, (sum, value) => sum + value * value);
    final scale = norm == 0 ? 1 : 1 / _sqrt(norm);
    return histogram.map((value) => value * scale).toList(growable: false);
  }

  double _histogramCorrelation(List<double> a, List<double> b) {
    final meanA = a.reduce((x, y) => x + y) / a.length;
    final meanB = b.reduce((x, y) => x + y) / b.length;
    var numerator = 0.0;
    var denominatorA = 0.0;
    var denominatorB = 0.0;
    for (var index = 0; index < a.length; index++) {
      final da = a[index] - meanA;
      final db = b[index] - meanB;
      numerator += da * db;
      denominatorA += da * da;
      denominatorB += db * db;
    }
    final denominator = _sqrt(denominatorA * denominatorB);
    return denominator == 0 ? -1 : numerator / denominator;
  }

  double _pixelMae(cv.Mat a, cv.Mat b) {
    if (a.rows != b.rows ||
        a.cols != b.cols ||
        a.data.length != b.data.length) {
      return double.infinity;
    }
    final aData = a.data;
    final bData = b.data;
    var total = 0;
    for (var index = 0; index < aData.length; index++) {
      total += (aData[index] - bData[index]).abs();
    }
    return total / aData.length;
  }

  double _sqrt(double value) {
    if (value <= 0) return 0;
    var result = value;
    for (var i = 0; i < 12; i++) {
      result = (result + value / result) / 2;
    }
    return result;
  }

  List<cv.Rect> _groupRectangles(
    List<({int x, int y})> hits, {
    required int size,
    required int groupThreshold,
    required double eps,
    required int frameWidth,
    required int frameHeight,
  }) {
    if (hits.isEmpty) return [];
    final parent = List<int>.generate(hits.length, (index) => index);
    int find(int value) {
      var root = value;
      while (parent[root] != root) {
        root = parent[root];
      }
      while (parent[value] != value) {
        final next = parent[value];
        parent[value] = root;
        value = next;
      }
      return root;
    }

    void union(int a, int b) {
      final rootA = find(a);
      final rootB = find(b);
      if (rootA != rootB) parent[rootB] = rootA;
    }

    // cv::SimilarRects compares integer coordinates against eps * size. With
    // equal-sized rectangles, a 22.5 delta therefore accepts at most 22 px.
    // cv::groupRectangles also uses cvRound (ties-to-even) for suppression.
    final delta = _cvRoundNonNegative(eps * size);
    final cellSize = delta.clamp(1, size);
    final cells = <(int, int), List<int>>{};
    for (var index = 0; index < hits.length; index++) {
      final hit = hits[index];
      final cx = hit.x ~/ cellSize;
      final cy = hit.y ~/ cellSize;
      for (var oy = -1; oy <= 1; oy++) {
        for (var ox = -1; ox <= 1; ox++) {
          for (final otherIndex in cells[(cx + ox, cy + oy)] ?? const []) {
            final other = hits[otherIndex];
            if ((hit.x - other.x).abs() <= delta &&
                (hit.y - other.y).abs() <= delta) {
              union(index, otherIndex);
            }
          }
        }
      }
      cells.putIfAbsent((cx, cy), () => []).add(index);
    }

    final sums = <int, ({int x, int y, int count})>{};
    for (var index = 0; index < hits.length; index++) {
      final root = find(index);
      final current = sums[root] ?? (x: 0, y: 0, count: 0);
      sums[root] = (
        x: current.x + hits[index].x,
        y: current.y + hits[index].y,
        count: current.count + 1,
      );
    }
    final clusters = sums.values
        .where((cluster) => cluster.count > groupThreshold)
        .map((cluster) {
          return (
            x: _opencvAverage(cluster.x, cluster.count),
            y: _opencvAverage(cluster.y, cluster.count),
            count: cluster.count,
          );
        })
        .toList();

    final output = <cv.Rect>[];
    for (var i = 0; i < clusters.length; i++) {
      final first = clusters[i];
      var suppressed = false;
      for (var j = 0; j < clusters.length; j++) {
        if (i == j) continue;
        final second = clusters[j];
        if (first.x >= second.x - delta &&
            first.y >= second.y - delta &&
            first.x + size <= second.x + size + delta &&
            first.y + size <= second.y + size + delta &&
            (second.count > (first.count > 3 ? first.count : 3) ||
                first.count < 3)) {
          suppressed = true;
          break;
        }
      }
      if (!suppressed) {
        output.add(
          cv.Rect(
            first.x.clamp(0, math.max(0, frameWidth - size)),
            first.y.clamp(0, math.max(0, frameHeight - size)),
            size,
            size,
          ),
        );
      }
    }
    return output;
  }

  int _cvRoundNonNegative(double value) {
    final lower = value.floor();
    final fraction = value - lower;
    if (fraction < 0.5) return lower;
    if (fraction > 0.5) return lower + 1;
    return lower.isEven ? lower : lower + 1;
  }

  int _opencvAverage(int sum, int count) {
    // groupRectangles averages through a float (`1.f / count`) before
    // saturate_cast<int>. Preserving those float32 rounding steps matters at
    // half-pixel boundaries and avoids systematic one-pixel box drift.
    final scale = _asFloat32(1 / count);
    final product = _asFloat32(_asFloat32(sum.toDouble()) * scale);
    return _cvRoundNonNegative(product);
  }

  double _asFloat32(double value) {
    _float32Scratch[0] = value;
    return _float32Scratch[0];
  }

  void dispose() {
    for (final target in _targets) {
      target.dispose();
    }
    _targets.clear();
    _kernel?.dispose();
    _kernel = null;
  }
}
