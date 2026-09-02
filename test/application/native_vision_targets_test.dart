import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_vision_controller.dart';
import 'package:godsense/infrastructure/native_vision/dartcv_minimap_tracker.dart';
import 'package:godsense/infrastructure/native_vision/vision_icon_cache.dart';
import 'package:godsense/infrastructure/native_vision/win32_screen_capture.dart';
import 'package:godsense/infrastructure/native_vision/vision_runtime.dart';
import 'package:opencv_dart/opencv.dart' as cv;

void main() {
  test('worker captures GDI and shuts down cleanly', () async {
    final worker = IsolateVisionRuntime();
    try {
      final capture = await worker.capture(
        {'left': 0, 'top': 0, 'width': 64, 'height': 64},
        28,
        true,
      );
      expect(capture.width, 64);
      expect(capture.frame.capturePng, isNotEmpty);
    } finally {
      worker.dispose();
      await worker.closed;
    }
    await expectLater(worker.setTargets({}, 28), throwsStateError);
  }, skip: !Platform.isWindows);
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
      final worker = IsolateVisionRuntime();
      addTearDown(() async {
        worker.dispose();
        await worker.closed;
      });
      expect(
        await worker.setTargets({
          'Vex': [png],
        }, size),
        ['Vex'],
      );
      final isolated = await worker.process(
        CapturedRegion(
          width: dimension,
          height: dimension,
          bgra: bgra,
          capturedAt: frame.capturedAt,
          captureMicroseconds: 0,
        ),
        size,
      );
      expect(
        isolated.detections.map((d) => d.championName),
        frame.detections.map((d) => d.championName),
      );
      expect(
        isolated.detections.map((d) => d.confidence),
        frame.detections.map((d) => d.confidence),
      );
      expect(isolated.capturedAt, frame.capturedAt);
      expect(
        isolated.detections.every(
          (d) => d.centerX == d.centerX.floorToDouble(),
        ),
        isTrue,
      );
    },
  );

  test(
    'missing Kayn transformations retry even when base portrait loaded',
    () async {
      final tracker = _RecordingTracker();
      final cache = _KaynCache();
      var now = DateTime.utc(2026);
      final controller = NativeVisionController(
        tracker: tracker,
        iconCache: cache,
        clock: () => now,
      );
      addTearDown(controller.dispose);
      await controller.configureTargets([_enemy('Kayn')], iconSize: 47);
      expect(controller.state.loadedTargets, 1);
      expect(controller.state.pendingVariants, isTrue);
      expect(controller.state.recognitionReady, isFalse);
      cache.variantsAvailable = true;
      now = now.add(const Duration(seconds: 11));
      await controller.configureTargets([_enemy('Kayn')], iconSize: 47);
      expect(controller.state.pendingVariants, isFalse);
      expect(
        cache.requests.where((url) => url.contains('/rhaast/')),
        hasLength(2),
      );
    },
  );

  test('running capture with no targets is not reported as ready', () {
    const state = NativeVisionState(running: true, fps: 6, expectedTargets: 5);
    expect(state.recognitionReady, isFalse);
    expect(state.recognitionStatus, contains('Esperando retratos'));
  });

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

class _KaynCache extends VisionIconCache {
  bool variantsAvailable = false;
  final requests = <String>[];
  @override
  Future<Uint8List?> load(String url) async {
    requests.add(url);
    if (url.contains('communitydragon') && !variantsAvailable) return null;
    return Uint8List.fromList([1]);
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
