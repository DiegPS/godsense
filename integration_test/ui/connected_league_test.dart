import 'package:integration_test/integration_test.dart';

import '../../test/application/coach_import_lifecycle_test.dart' as imports;
import '../../test/application/league_draft_pool_lifecycle_test.dart' as draft;

import '../../test/presentation/connected_league_ui_journey_test.dart'
    as connected;
import '../../test/presentation/coach/setup_recommendations_interaction_test.dart'
    as setup;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  connected.main();
  setup.main();
  imports.main();
  draft.main();
}
