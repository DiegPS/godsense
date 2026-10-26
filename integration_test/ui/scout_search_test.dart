import 'package:integration_test/integration_test.dart';

import '../../test/presentation/scout_search_test.dart' as journey;
import '../../test/presentation/scout_profile_regression_test.dart' as profile;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  journey.main();
  profile.main();
}
