import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_vision_controller.dart';
import 'package:godsense/infrastructure/native_vision/dartcv_minimap_tracker.dart';
import 'package:godsense/infrastructure/native_vision/vision_icon_cache.dart';
import 'package:godsense/infrastructure/native_vision/win32_screen_capture.dart';
import 'package:opencv_dart/opencv.dart' as cv;

void main() {
  test(
    '47px templates identify a champion through the real CV pipeline',
    () async {
      const size = 47;
      const dimension = 120;
      final bgra = Uint8List(dimension * dimension * 4);
      final portrait = Uint8List(size * size * 3);
      for (var y = 0; y < dimension; y++) {
        for (var x = 0; x < dimension; x++) {
          final dx = x - 60;
          final dy = y - 60;
          final distance2 = dx * dx + dy * dy;
          final ring = distance2 >= 21 * 21 && distance2 <= 23 * 23;
          final b = ring ? 0 : 100 + (x * 7 + y * 3) % 140;
          final g = ring ? 25 : 70 + (x * 3 + y * 7) % 140;
          final r = ring ? 255 : 20;
          final index = (y * dimension + x) * 4;
          bgra.setRange(index, index + 4, [b, g, r, 255]);
          if (x >= 37 && x < 84 && y >= 37 && y < 84) {
            final target = ((y - 37) * size + x - 37) * 3;
            portrait.setRange(target, target + 3, [b, g, r]);
          }
        }
      }
      final mat = cv.Mat.fromList(size, size, cv.MatType.CV_8UC3, portrait);
      final (_, png) = cv.imencode('.png', mat);
      mat.dispose();
      final tracker = DartCvMinimapTracker();
      final controller = NativeVisionController(
        tracker: tracker,
        iconCache: _Cache(pending: Future.value(png)),
      );
      addTearDown(controller.dispose);
      await controller.configureTargets([_enemy('Vex')], iconSize: size);
      final frame = tracker.process(
        CapturedRegion(
          width: dimension,
          height: dimension,
          bgra: bgra,
          capturedAt: DateTime.now(),
          captureMicroseconds: 0,
        ),
        iconSize: size,
        generatePreview: false,
      );
      expect(frame.detections, isNotEmpty);
      expect(frame.detections.any((d) => d.championName == 'Vex'), isTrue);
    },
  );

  test('templates retain the exact odd calibration size', () async {
    final tracker = _RecordingTracker();
    final cache = _Cache();
    final controller = NativeVisionController(
      tracker: tracker,
      iconCache: cache,
    );
    addTearDown(controller.dispose);
    await controller.configureTargets([_enemy('Vex')], iconSize: 47);
    expect(tracker.size, 47);
    expect(tracker.targetNames, ['Vex']);
    await controller.configureTargets([_enemy('Vex')], iconSize: 47);
    expect(cache.requests, hasLength(1));
    await controller.configureTargets([_enemy('Vex')], iconSize: 49);
    expect(tracker.size, 49);
  });

  test('late downloads cannot restore targets after a game ends', () async {
    final tracker = _RecordingTracker();
    final pending = Completer<Uint8List?>();
    final controller = NativeVisionController(
      tracker: tracker,
      iconCache: _Cache(pending: pending.future),
    );
    addTearDown(controller.dispose);
    final loading = controller.configureTargets([_enemy('Vex')], iconSize: 47);
    await controller.configureTargets([], iconSize: 47);
    pending.complete(Uint8List.fromList([1]));
    await loading;
    expect(tracker.targetNames, isEmpty);
  });

  test('late downloads do not access a disposed tracker', () async {
    final tracker = _RecordingTracker();
    final pending = Completer<Uint8List?>();
    final controller = NativeVisionController(
      tracker: tracker,
      iconCache: _Cache(pending: pending.future),
    );
    final loading = controller.configureTargets([_enemy('Vex')], iconSize: 47);
    controller.dispose();
    pending.complete(Uint8List.fromList([1]));
    await loading;
    expect(tracker.targetNames, isEmpty);
  });

  test('UI portraits are not silently used as CV templates', () async {
    final tracker = _RecordingTracker();
    final cache = _Cache();
    final controller = NativeVisionController(
      tracker: tracker,
      iconCache: cache,
    );
    addTearDown(controller.dispose);
    await controller.configureTargets([
      {
        'champion_name': 'Vex',
        'icon_url': 'https://raw.communitydragon.org/latest/profile.png',
      },
    ], iconSize: 47);
    expect(cache.requests, isEmpty);
    expect(tracker.targetNames, isEmpty);
    // Canonical metadata arriving later must trigger loading immediately.
    await controller.configureTargets([_enemy('Vex')], iconSize: 47);
    expect(tracker.targetNames, ['Vex']);
  });
}

Map<String, dynamic> _enemy(String name) => {
  'champion_name': name,
  'vision_icon_url':
      'https://ddragon.leagueoflegends.com/cdn/16.17.1/img/champion/$name.png',
};

class _Cache extends VisionIconCache {
  _Cache({this.pending});
  final Future<Uint8List?>? pending;
  final requests = <String>[];
  @override
  Future<Uint8List?> load(String url) {
    requests.add(url);
    return pending ?? Future.value(Uint8List.fromList([1]));
  }
}

class _RecordingTracker extends DartCvMinimapTracker {
  int? size;
  List<String> names = [];
  bool disposed = false;
  @override
  List<String> get targetNames => names;
  @override
  void setTargets(Map<String, List<Uint8List>> icons, {required int iconSize}) {
    if (disposed) throw StateError('Tracker disposed');
    size = iconSize;
    names = icons.keys.toList();
  }

  @override
  void dispose() {
    disposed = true;
  }
}
