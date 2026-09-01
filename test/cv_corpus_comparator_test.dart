import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/cv_corpus_comparator.dart';
import 'package:opencv_dart/opencv.dart' as cv;

void main() {
  final appData = Platform.environment['APPDATA'];
  final corpusExists =
      appData != null &&
      Directory('$appData\\GodSense\\cv-corpus').existsSync();

  test('compares DartCV against the exact Python corpus', () async {
    final comparator = CvCorpusComparator();
    addTearDown(comparator.dispose);

    await comparator.run();
    final result = comparator.state;
    debugPrint(
      'CV corpus: frames=${result.frames}, '
      'precision=${(result.precision * 100).toStringAsFixed(2)}%, '
      'recall=${(result.recall * 100).toStringAsFixed(2)}%, '
      'identity=${(result.identityAgreement * 100).toStringAsFixed(2)}%, '
      'exactBoxes=${result.exactBoxes}/${result.matchedBoxes}, '
      'avgIoU=${result.averageIou.toStringAsFixed(4)}, '
      'confidenceDelta=${result.averageConfidenceDelta.toStringAsFixed(4)}, '
      'tmDelta=${result.averageTemplateDelta.toStringAsFixed(4)}, '
      'histDelta=${result.averageHistogramDelta.toStringAsFixed(4)}, '
      'dartMs=${result.averageDartMilliseconds.toStringAsFixed(2)}',
    );
    for (final sample in result.sampleComparisons) {
      debugPrint(sample);
    }
    expect(result.error, isNull);
    expect(result.frames, 120);
    expect(result.precision, 1);
    expect(result.recall, 1);
    expect(result.identityAgreement, 1);
    expect(result.exactBoxes, result.matchedBoxes);
    expect(result.averageIou, 1);
    expect(result.averageConfidenceDelta, lessThan(1e-6));
    expect(result.averageTemplateDelta, lessThan(1e-6));
    expect(result.averageHistogramDelta, lessThan(1e-6));
  }, skip: corpusExists ? false : 'Local CV corpus is not available.');

  test('production target decode matches the exact Python corpus', () async {
    final comparator = CvCorpusComparator();
    addTearDown(comparator.dispose);
    await comparator.run(rawTargets: false);
    final result = comparator.state;
    debugPrint(
      'Production target path: precision=${result.precision}, '
      'recall=${result.recall}, identity=${result.identityAgreement}, '
      'confidenceDelta=${result.averageConfidenceDelta}',
    );
    expect(result.error, isNull);
    expect(result.precision, 1);
    expect(result.recall, 1);
    expect(result.identityAgreement, 1);
    expect(result.averageConfidenceDelta, lessThan(1e-5));
  }, skip: corpusExists ? false : 'Local CV corpus is not available.');

  final realCorpusExists =
      appData != null &&
      Directory('$appData\\GodSense\\cv-real-corpus').existsSync();
  test('compares current real-game Python corpus', () async {
    final comparator = CvCorpusComparator();
    addTearDown(comparator.dispose);
    await comparator.run(rawTargets: false, corpusDirectory: 'cv-real-corpus');
    final result = comparator.state;
    debugPrint(
      'REAL CV: frames=${result.frames}, precision=${result.precision}, '
      'recall=${result.recall}, identity=${result.identityAgreement}, '
      'IoU=${result.averageIou}, confidenceDelta=${result.averageConfidenceDelta}, '
      'dartMs=${result.averageDartMilliseconds}',
    );
    for (final sample in result.sampleComparisons) {
      debugPrint('REAL $sample');
    }
    for (final mismatch in result.identityMismatches) {
      debugPrint('MISMATCH $mismatch');
    }
    expect(result.error, isNull);
    expect(result.frames, equals(866));
    expect(result.precision, greaterThan(0.99));
    expect(result.recall, greaterThan(0.99));
    expect(result.averageIou, greaterThan(0.99));
    expect(result.identityAgreement, greaterThan(0.99));
  }, timeout: const Timeout(Duration(minutes: 2)), skip: realCorpusExists ? false : 'Real-game corpus unavailable.');

  test('checks direct Dart pixel parity for a saved frame', () async {
    final root = Directory('$appData\\GodSense\\cv-corpus');
    final frame = cv.imdecode(
      await File('${root.path}\\frame-000001.png').readAsBytes(),
      cv.IMREAD_COLOR,
    );
    final target = cv.imdecode(
      await File('${root.path}\\targets_resized\\Sion.bmp').readAsBytes(),
      cv.IMREAD_COLOR,
    );
    final box = cv.Rect(41, 47, 28, 28);
    final live = cv.Mat.fromMat(frame, roi: box, copy: true);
    final inner = cv.Rect(7, 7, 14, 14);
    final liveFace = cv.Mat.fromMat(live, roi: inner, copy: true);
    final targetFace = cv.Mat.fromMat(target, roi: inner, copy: true);
    var delta = 0;
    for (var index = 0; index < liveFace.data.length; index++) {
      delta += (liveFace.data[index] - targetFace.data[index]).abs();
    }
    final mae = delta / liveFace.data.length;
    final liveRange = cv.Mat.fromRange(frame, 47, 75, colStart: 41, colEnd: 69);
    final liveFaceRange = cv.Mat.fromRange(
      liveRange,
      7,
      21,
      colStart: 7,
      colEnd: 21,
    );
    final targetFaceRange = cv.Mat.fromRange(
      target,
      7,
      21,
      colStart: 7,
      colEnd: 21,
    );
    var rangeDelta = 0;
    for (var index = 0; index < liveFaceRange.data.length; index++) {
      rangeDelta += (liveFaceRange.data[index] - targetFaceRange.data[index])
          .abs();
    }
    final rangeMae = rangeDelta / liveFaceRange.data.length;
    var manualDelta = 0;
    var manualCount = 0;
    for (var y = 7; y < 21; y++) {
      for (var x = 7; x < 21; x++) {
        for (var channel = 0; channel < 3; channel++) {
          final frameIndex = ((47 + y) * frame.cols + (41 + x)) * 3 + channel;
          final targetIndex = (y * target.cols + x) * 3 + channel;
          manualDelta += (frame.data[frameIndex] - target.data[targetIndex])
              .abs();
          manualCount++;
        }
      }
    }
    final manualMae = manualDelta / manualCount;
    debugPrint(
      'Dart crop MAE: roi=${mae.toStringAsFixed(4)}, '
      'range=${rangeMae.toStringAsFixed(4)}, '
      'manual=${manualMae.toStringAsFixed(4)}',
    );
    expect(manualMae, 0);
    targetFaceRange.dispose();
    liveFaceRange.dispose();
    liveRange.dispose();
    targetFace.dispose();
    liveFace.dispose();
    inner.dispose();
    live.dispose();
    box.dispose();
    target.dispose();
    frame.dispose();
  }, skip: corpusExists ? false : 'Local CV corpus is not available.');

  test('checks raw BGR and BGRA roundtrip parity', () async {
    final root = Directory('$appData\\GodSense\\cv-corpus');
    final raw = await File('${root.path}\\frame-000001.bgr').readAsBytes();
    final target = cv.imdecode(
      await File('${root.path}\\targets_resized\\Sion.bmp').readAsBytes(),
      cv.IMREAD_COLOR,
    );
    var rawDelta = 0;
    var count = 0;
    for (var y = 7; y < 21; y++) {
      for (var x = 7; x < 21; x++) {
        for (var channel = 0; channel < 3; channel++) {
          rawDelta +=
              (raw[((47 + y) * 300 + (41 + x)) * 3 + channel] -
                      target.data[(y * 28 + x) * 3 + channel])
                  .abs();
          count++;
        }
      }
    }
    final bgr = cv.Mat.fromList(300, 300, cv.MatType.CV_8UC3, raw);
    final bgra = cv.cvtColor(bgr, cv.COLOR_BGR2BGRA);
    final restored = cv.cvtColor(bgra, cv.COLOR_BGRA2BGR);
    var roundtripDelta = 0;
    for (var index = 0; index < raw.length; index++) {
      roundtripDelta += (raw[index] - restored.data[index]).abs();
    }
    debugPrint(
      'Raw MAE=${(rawDelta / count).toStringAsFixed(4)}, '
      'roundtrip MAE=${(roundtripDelta / raw.length).toStringAsFixed(4)}',
    );
    expect(rawDelta, 0);
    expect(roundtripDelta, 0);
    restored.dispose();
    bgra.dispose();
    bgr.dispose();
    target.dispose();
  }, skip: corpusExists ? false : 'Local CV corpus is not available.');

  test('checks raw frame bytes against raw target bytes', () async {
    final root = Directory('$appData\\GodSense\\cv-corpus');
    final frame = await File('${root.path}\\frame-000001.bgr').readAsBytes();
    final target = await File('${root.path}\\targets_resized\\Sion.bgr')
        .readAsBytes();
    var delta = 0;
    var count = 0;
    final mismatches = <String>[];
    for (var y = 7; y < 21; y++) {
      for (var x = 7; x < 21; x++) {
        for (var channel = 0; channel < 3; channel++) {
          final frameValue = frame[((47 + y) * 300 + (41 + x)) * 3 + channel];
          final targetValue = target[(y * 28 + x) * 3 + channel];
          delta += (frameValue - targetValue).abs();
          if (frameValue != targetValue && mismatches.length < 12) {
            mismatches.add(
              '($x,$y,$channel) frame=$frameValue target=$targetValue',
            );
          }
          count++;
        }
      }
    }
    final mae = delta / count;
    debugPrint(
      'Raw file-to-file MAE: ${mae.toStringAsFixed(4)}; '
      'frameBytes=${frame.length}; targetBytes=${target.length}; '
      'mismatches=$mismatches',
    );
    expect(mae, 0);
  }, skip: corpusExists ? false : 'Local CV corpus is not available.');
}
