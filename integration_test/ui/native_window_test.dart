import 'package:integration_test/integration_test.dart';

import '../../test/support/desktop_journeys.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  desktopJourneys(nativeWindow: true);
}
