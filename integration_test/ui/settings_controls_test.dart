import 'package:integration_test/integration_test.dart';

import '../../test/presentation/coach/ai_provider_connections_test.dart'
    as auth;
import '../../test/presentation/native_speech_settings_card_test.dart' as voice;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Exercise real Flutter dialogs, dropdown routes and text input on Windows.
  // Account/model transports are synthetic; this never changes real accounts.
  auth.main();
  voice.main();
}
