import 'package:integration_test/integration_test.dart';

import '../../test/application/scout_async_boundaries_test.dart' as boundaries;

import '../../test/presentation/scout_search_test.dart' as journey;
import '../../test/presentation/scout_profile_regression_test.dart' as profile;
import '../../test/presentation/scout_match_history_journey_test.dart'
    as history;
import '../../test/presentation/scout_details_retry_journey_test.dart'
    as details;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  journey.main();
  profile.main();
  history.main();
  details.main();
  boundaries.main();
}
