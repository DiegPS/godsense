import 'package:flutter/widgets.dart';

import 'app/godsense_app.dart';
import 'infrastructure/diagnostics/app_error_boundary.dart';
import 'infrastructure/diagnostics/app_logger.dart';

export 'app/godsense_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppErrorBoundary.install();
  AppErrorBoundary.run(() async {
    await AppLogger.initialize();
    runGodSense();
  });
}
