import 'package:integration_test/integration_test.dart';

import '../../test/application/native_speech_async_safety_test.dart' as speech;

import '../../test/presentation/coach/ai_provider_connections_test.dart'
    as auth;
import '../../test/presentation/native_speech_settings_card_test.dart' as voice;
import '../../test/presentation/runtime_settings_lifecycle_test.dart'
    as runtimes;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Exercise real Flutter dialogs, dropdown routes and text input on Windows.
  // Account/model transports are synthetic; this never changes real accounts.
  auth.main();
  voice.main();
  runtimes.main();
  speech.main();
}
