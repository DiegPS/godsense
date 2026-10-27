import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'connected_league_test.dart' as connected;
import 'desktop_app_test.dart' as desktop;
import 'native_window_test.dart' as window;
import 'overlay_hud_test.dart' as overlay;
import 'scout_search_test.dart' as scout;
import 'settings_controls_test.dart' as settings;
import 'windows_artifact_download_test.dart' as downloads;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Each suite owns its setup and teardown; groups prevent hooks from leaking
  // into other suites while exercising the same Windows process.
  group('Connected League and Coach', connected.main);
  group('Desktop navigation', desktop.main);
  group('Native windows', window.main);
  group('Overlay', overlay.main);
  group('Scout', scout.main);
  group('Settings and speech', settings.main);
  group('Artifact transport', downloads.main);
}
