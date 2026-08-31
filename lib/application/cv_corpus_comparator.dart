import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/native_vision/dartcv_minimap_tracker.dart';

class CvCorpusComparisonState {
  const CvCorpusComparisonState({
    this.running = false,
    this.frames = 0,
    this.pythonDetections = 0,
    this.dartDetections = 0,
    this.matchedBoxes = 0,
    this.matchedIdentities = 0,
    this.exactBoxes = 0,
    this.averageIou = 0,
    this.averageConfidenceDelta = 0,
    this.averageTemplateDelta = 0,
    this.averageHistogramDelta = 0,
    this.averageDartMilliseconds = 0,
    this.scoreSamples = 0,
    this.sampleComparisons = const [],
    this.error,
  });

  final bool running;
  final int frames;
  final int pythonDetections;
  final int dartDetections;
  final int matchedBoxes;
  final int matchedIdentities;
  final int exactBoxes;
  final double averageIou;
  final double averageConfidenceDelta;
  final double averageTemplateDelta;
  final double averageHistogramDelta;
  final double averageDartMilliseconds;
  final int scoreSamples;
  final List<String> sampleComparisons;
  final String? error;

  double get precision =>
      dartDetections == 0 ? 0 : matchedBoxes / dartDetections;
  double get recall =>
      pythonDetections == 0 ? 0 : matchedBoxes / pythonDetections;
  double get identityAgreement =>
      matchedBoxes == 0 ? 0 : matchedIdentities / matchedBoxes;
}

final cvCorpusComparatorProvider =
    StateNotifierProvider<CvCorpusComparator, CvCorpusComparisonState>(
      (_) => CvCorpusComparator(),
    );

class CvCorpusComparator extends StateNotifier<CvCorpusComparisonState> {
  CvCorpusComparator() : super(const CvCorpusComparisonState());

  Future<void> run({int? limit, bool rawTargets = true}) async {
    if (state.running) return;
    state = const CvCorpusComparisonState(running: true);
    final appData = Platform.environment['APPDATA'];
    if (appData == null) {
      state = const CvCorpusComparisonState(error: 'APPDATA unavailable.');
      return;
    }
    final directory = Directory('$appData\\GodSense\\cv-corpus');
    if (!directory.existsSync()) {
      state = const CvCorpusComparisonState(
        error: 'No corpus. Run start-local-coach.ps1 -CvApi in a game.',
      );
      return;
    }
    final metadata =
        directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final files = limit == null ? metadata : metadata.take(limit).toList();
    final tracker = DartCvMinimapTracker();
    String targetSignature = '';
    var pythonCount = 0;
    var dartCount = 0;
    var boxMatches = 0;
    var identityMatches = 0;
    var exactBoxMatches = 0;
    var iouSum = 0.0;
    var confidenceDelta = 0.0;
    var confidenceSamples = 0;
    var templateDelta = 0.0;
    var histogramDelta = 0.0;
    var scoreSamples = 0;
    var dartMicroseconds = 0;
    var processedFrames = 0;
    final sampleComparisons = <String>[];

    try {
      for (final metadataFile in files) {
        final expected = jsonDecode(await metadataFile.readAsString());
        if (expected is! Map) continue;
        final iconSize = (expected['icon_size'] as num?)?.round() ?? 28;
        final targetIcons =
            expected[rawTargets ? 'target_raw' : 'target_original'];
        if (targetIcons is Map) {
          final signature = '$iconSize:${jsonEncode(targetIcons)}';
          if (signature != targetSignature) {
            final icons = <String, List<Uint8List>>{};
            for (final entry in targetIcons.entries) {
              final file = File('${directory.path}\\${entry.value}');
              if (file.existsSync()) {
                icons[entry.key.toString()] = [await file.readAsBytes()];
              }
            }
            if (rawTargets) {
              tracker.setRawTargets(icons, iconSize: iconSize);
            } else {
              tracker.setTargets(icons, iconSize: iconSize);
            }
            targetSignature = signature;
          }
        }
        final raw = File(metadataFile.path.replaceAll('.json', '.bgr'));
        final shape = expected['shape'];
        if (!raw.existsSync() || shape is! List || shape.length != 2) continue;
        final frame = tracker.processBgr(
          await raw.readAsBytes(),
          width: (shape[1] as num).toInt(),
          height: (shape[0] as num).toInt(),
          iconSize: iconSize,
        );
        final expectedDetections = _mapList(expected['detections']);
        pythonCount += expectedDetections.length;
        dartCount += frame.detections.length;
        dartMicroseconds += frame.cvMicroseconds;
        processedFrames++;
        final usedDart = <int>{};
        for (final python in expectedDetections) {
          final box = python['box'];
          if (box is! List || box.length != 4) continue;
          var bestIndex = -1;
          var bestIou = 0.0;
          for (var index = 0; index < frame.detections.length; index++) {
            if (usedDart.contains(index)) continue;
            final iou = _iou(box, frame.detections[index]);
            if (iou > bestIou) {
              bestIou = iou;
              bestIndex = index;
            }
          }
          if (bestIndex < 0 || bestIou < 0.5) continue;
          usedDart.add(bestIndex);
          boxMatches++;
          iouSum += bestIou;
          final dart = frame.detections[bestIndex];
          if ((box[0] as num).toInt() == dart.x &&
              (box[1] as num).toInt() == dart.y &&
              (box[2] as num).toInt() == dart.x + dart.width &&
              (box[3] as num).toInt() == dart.y + dart.height) {
            exactBoxMatches++;
          }
          if (python['name'] == dart.championName) identityMatches++;
          final expectedConfidence = (python['confidence'] as num?)?.toDouble();
          final expectedName = python['name']?.toString();
          if (expectedName != null &&
              expectedConfidence != null &&
              dart.championName != null) {
            confidenceDelta += (expectedConfidence - dart.confidence).abs();
            confidenceSamples++;
          }
          final expectedTemplate = (python['template_score'] as num?)
              ?.toDouble();
          final expectedHistogram = (python['histogram_score'] as num?)
              ?.toDouble();
          if (expectedName != null &&
              dart.championName != null &&
              expectedTemplate != null &&
              expectedHistogram != null) {
            templateDelta += (expectedTemplate - dart.templateScore).abs();
            histogramDelta += (expectedHistogram - dart.histogramScore).abs();
            scoreSamples++;
            if (sampleComparisons.length < 8) {
              sampleComparisons.add(
                '${metadataFile.uri.pathSegments.last}: $expectedName '
                'py=(${expectedConfidence!.toStringAsFixed(4)}, '
                '${expectedTemplate.toStringAsFixed(4)}, '
                '${expectedHistogram.toStringAsFixed(4)}) '
                'dart=(${dart.confidence.toStringAsFixed(4)}, '
                '${dart.templateScore.toStringAsFixed(4)}, '
                '${dart.histogramScore.toStringAsFixed(4)}) '
                'mae=${dart.pixelMae.toStringAsFixed(3)}',
              );
            }
          }
        }
      }
      state = CvCorpusComparisonState(
        frames: processedFrames,
        pythonDetections: pythonCount,
        dartDetections: dartCount,
        matchedBoxes: boxMatches,
        matchedIdentities: identityMatches,
        exactBoxes: exactBoxMatches,
        averageIou: boxMatches == 0 ? 0 : iouSum / boxMatches,
        averageConfidenceDelta: confidenceSamples == 0
            ? 0
            : confidenceDelta / confidenceSamples,
        averageTemplateDelta: scoreSamples == 0
            ? 0
            : templateDelta / scoreSamples,
        averageHistogramDelta: scoreSamples == 0
            ? 0
            : histogramDelta / scoreSamples,
        averageDartMilliseconds: processedFrames == 0
            ? 0
            : dartMicroseconds / processedFrames / 1000,
        scoreSamples: scoreSamples,
        sampleComparisons: sampleComparisons,
      );
    } catch (error) {
      state = CvCorpusComparisonState(error: error.toString());
    } finally {
      tracker.dispose();
    }
  }

  List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  double _iou(List<dynamic> expected, NativeDetection actual) {
    final ax1 = (expected[0] as num).toDouble();
    final ay1 = (expected[1] as num).toDouble();
    final ax2 = (expected[2] as num).toDouble();
    final ay2 = (expected[3] as num).toDouble();
    final bx1 = actual.x.toDouble();
    final by1 = actual.y.toDouble();
    final bx2 = (actual.x + actual.width).toDouble();
    final by2 = (actual.y + actual.height).toDouble();
    final intersection =
        math.max(0, math.min(ax2, bx2) - math.max(ax1, bx1)) *
        math.max(0, math.min(ay2, by2) - math.max(ay1, by1));
    final union =
        (ax2 - ax1) * (ay2 - ay1) + (bx2 - bx1) * (by2 - by1) - intersection;
    return union <= 0 ? 0 : intersection / union;
  }
}
