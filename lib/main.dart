import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app/godsense_app.dart';
import 'infrastructure/diagnostics/app_error_boundary.dart';
import 'infrastructure/diagnostics/app_logger.dart';

export 'app/godsense_app.dart';

void main() {
  AppErrorBoundary.run(() {
    WidgetsFlutterBinding.ensureInitialized();
    AppErrorBoundary.install();
    unawaited(AppLogger.initialize());
    runGodSense();
  });
}
