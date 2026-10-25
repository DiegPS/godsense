import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:godsense/main.dart' as app;
import 'package:godsense/infrastructure/diagnostics/app_logger.dart';
import 'package:godsense/infrastructure/native_vision/desktop_screen_capture.dart';

void main() {
  app.main();
  unawaited(_profile());
}

Future<void> _profile() async {
  // Let startup finish before the cold-navigation pass. Use the real providers,
  // saved configuration, Windows plugin and rendering engine.
  await Future<void>.delayed(const Duration(seconds: 5));
  final report = <String, Object?>{
    'mode': const bool.fromEnvironment('dart.vm.product')
        ? 'release'
        : const bool.fromEnvironment('dart.vm.profile')
        ? 'profile'
        : 'debug',
    'timestamp': DateTime.now().toUtc().toIso8601String(),
  };
  report['cold_navigation'] = await _navigate(rounds: 1);
  report['warm_navigation'] = await _navigate(rounds: 3);

  final screen = DesktopScreenCapture();
  var capturing = true;
  var captures = 0;
  var captureErrors = 0;
  try {
    final displays = await screen.getDisplays();
    final display = displays.firstWhere(
      (display) => display.primary,
      orElse: () => displays.first,
    );
    final captureLoop = () async {
      while (capturing) {
        try {
          await screen.capture(
            left: display.left,
            top: display.top,
            width: display.width.clamp(1, 300),
            height: display.height.clamp(1, 300),
            displayId: display.id,
            localLeft: 0,
            localTop: 0,
          );
          captures++;
        } catch (_) {
          captureErrors++;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }();
    try {
      report['navigation_with_capture'] = await _navigate(rounds: 3);
    } finally {
      capturing = false;
      await captureLoop;
    }
  } catch (error) {
    report['capture_setup_error'] = AppLogger.redact(error);
  } finally {
    screen.dispose();
  }
  report['captures'] = captures;
  report['capture_errors'] = captureErrors;
  final file = File(
    const String.fromEnvironment(
      'GODSENSE_PERF_REPORT',
      defaultValue: 'build/performance/windows-navigation.json',
    ),
  );
  await file.parent.create(recursive: true);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  // A stable marker for the local PowerShell runner; contains no user data.
  debugPrint('GODSENSE_PERFORMANCE ${jsonEncode(report)}');
  app.appProviderContainer.read(app.selectedPageProvider.notifier).state = 0;
  if (const bool.fromEnvironment('GODSENSE_PERF_AUTOCLOSE')) {
    await AppLogger.flush();
    exit(captures == 0 ? 1 : 0);
  }
}

Future<Map<String, Object?>> _navigate({required int rounds}) async {
  final timings = <FrameTiming>[];
  final timerGaps = <int>[];
  final navigation = <int>[];
  final clock = Stopwatch()..start();
  var previous = 0;
  final heartbeat = Timer.periodic(const Duration(milliseconds: 16), (_) {
    final now = clock.elapsedMicroseconds;
    timerGaps.add(now - previous);
    previous = now;
  });
  void onTimings(List<FrameTiming> frames) => timings.addAll(frames);
  WidgetsBinding.instance.addTimingsCallback(onTimings);
  try {
    for (var round = 0; round < rounds; round++) {
      for (var page = 0; page < 6; page++) {
        final started = clock.elapsedMicroseconds;
        app.appProviderContainer.read(app.selectedPageProvider.notifier).state =
            page;
        await WidgetsBinding.instance.endOfFrame;
        navigation.add(clock.elapsedMicroseconds - started);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    // The engine batches FrameTiming delivery; allow the final batch to arrive.
    await Future<void>.delayed(const Duration(seconds: 1));
  } finally {
    heartbeat.cancel();
    WidgetsBinding.instance.removeTimingsCallback(onTimings);
  }
  Map<String, num> distribution(Iterable<int> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return {'samples': 0};
    return {
      'samples': sorted.length,
      'p50_ms': sorted[(sorted.length * .50).floor()] / 1000,
      'p95_ms': sorted[(sorted.length * .95).floor()] / 1000,
      'max_ms': sorted.last / 1000,
    };
  }

  return {
    'navigation': distribution(navigation),
    'event_loop': distribution(timerGaps),
    'build': distribution(
      timings.map((frame) => frame.buildDuration.inMicroseconds),
    ),
    'raster': distribution(
      timings.map((frame) => frame.rasterDuration.inMicroseconds),
    ),
  };
}
