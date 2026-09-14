import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_logger.dart';

abstract final class AppErrorBoundary {
  static bool _installed = false;

  static void install() {
    if (_installed) return;
    _installed = true;
    FlutterError.onError = (details) {
      AppLogger.error(
        details.context?.toDescription() ??
            'Unhandled Flutter framework error.',
        category: 'flutter',
        error: details.exception,
        stackTrace: details.stack,
      );
      if (kDebugMode) FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      AppLogger.error(
        'Unhandled asynchronous platform error.',
        category: 'platform',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    };
  }

  static void run(void Function() body) {
    runZonedGuarded(body, (error, stackTrace) {
      AppLogger.error(
        'Unhandled application-zone error.',
        category: 'zone',
        error: error,
        stackTrace: stackTrace,
      );
    });
  }
}
