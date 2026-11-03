import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:godsense/main.dart' as app;
import 'package:multiview_desktop/multiview_desktop.dart';

// Native resize stress after every page has been visited. Restore window size
// and position afterwards; no preferences or calibration are changed.
void main() {
  app.main();
  unawaited(_run());
}

Future<void> _run() async {
  try {
    await _measure().timeout(const Duration(seconds: 90));
    exit(0);
  } catch (error) {
    stderr.writeln('GODSENSE_RESIZE_FAILED ${error.runtimeType}');
    exit(1);
  }
}

Future<void> _measure() async {
  await Future<void>.delayed(const Duration(seconds: 5));
  for (var page = 0; page < 6; page++) {
    app.appProviderContainer.read(app.selectedPageProvider.notifier).state =
        page;
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 5),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  final window = MultiViewDesktop.fromId(MultiViewDesktop.getAnchorId()!);
  final bounds = await window.getBounds();
  final frames = <int>[];
  final gaps = <int>[];
  final clock = Stopwatch()..start();
  var previous = 0;
  final heartbeat = Timer.periodic(const Duration(milliseconds: 16), (_) {
    final now = clock.elapsedMicroseconds;
    gaps.add(now - previous);
    previous = now;
  });
  try {
    for (var round = 0; round < 2; round++) {
      for (final page in [5, 4, 3, 2, 1, 0]) {
        app.appProviderContainer.read(app.selectedPageProvider.notifier).state =
            page;
        await WidgetsBinding.instance.endOfFrame.timeout(
          const Duration(seconds: 5),
        );
        for (final size in [const Size(1000, 700), const Size(1300, 850)]) {
          final start = clock.elapsedMicroseconds;
          await window.setSize(size);
          await WidgetsBinding.instance.endOfFrame.timeout(
            const Duration(seconds: 5),
          );
          frames.add(clock.elapsedMicroseconds - start);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
  } finally {
    heartbeat.cancel();
    await window.setSize(bounds.size);
    await window.setPosition(bounds.topLeft);
    app.appProviderContainer.read(app.selectedPageProvider.notifier).state = 0;
  }
  frames.sort();
  gaps.sort();
  final result = {
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'samples': frames.length,
    'resize_p95_ms': frames[(frames.length * .95).floor()] / 1000,
    'resize_max_ms': frames.last / 1000,
    'event_loop_max_ms': gaps.last / 1000,
  };
  final report = File(
    'build/performance/page-resize-${DateTime.now().microsecondsSinceEpoch}.json',
  );
  await report.parent.create(recursive: true);
  await report.writeAsString(jsonEncode(result));
  stdout.writeln('GODSENSE_RESIZE ${jsonEncode(result)}');
  if (frames.last > 250000 || gaps.last > 250000) {
    throw StateError('Native page resizing exceeded 250 ms.');
  }
}
