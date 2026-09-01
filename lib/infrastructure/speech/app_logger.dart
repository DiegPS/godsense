import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

abstract final class AppLogger {
  static final Logger _logger = Logger(
    level: kDebugMode ? Level.debug : Level.warning,
    printer: SimplePrinter(colors: false, printTime: true),
  );

  static void debug(String message) => _logger.d(message);

  static void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => _logger.w(message, error: error, stackTrace: stackTrace);

  static void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
