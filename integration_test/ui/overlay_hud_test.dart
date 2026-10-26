import 'package:integration_test/integration_test.dart';

import '../../test/presentation/overlay/overlay_status_regression_test.dart'
    as status;
import '../../test/presentation/overlay/overlay_visibility_journey_test.dart'
    as visibility;
import '../../test/presentation/overlay/native_gank_ring_test.dart' as danger;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  status.main();
  visibility.main();
  danger.main();
}
