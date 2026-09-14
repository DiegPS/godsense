import 'package:flutter/widgets.dart';

import 'app/godsense_app.dart';
import 'infrastructure/diagnostics/app_error_boundary.dart';
import 'infrastructure/diagnostics/app_logger.dart';

export 'app/godsense_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.initialize();
  AppErrorBoundary.install();
  AppErrorBoundary.run(runGodSense);
}
