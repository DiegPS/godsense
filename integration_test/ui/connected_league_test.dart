import 'package:integration_test/integration_test.dart';

import '../../test/presentation/connected_league_ui_journey_test.dart'
    as connected;
import '../../test/presentation/coach/setup_recommendations_interaction_test.dart'
    as setup;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  connected.main();
  setup.main();
}
