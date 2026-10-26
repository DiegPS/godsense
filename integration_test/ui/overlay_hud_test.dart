import 'package:integration_test/integration_test.dart';

import '../../test/presentation/overlay/overlay_status_regression_test.dart'
    as status;
import '../../test/presentation/overlay/overlay_visibility_journey_test.dart'
    as visibility;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  status.main();
  visibility.main();
}
