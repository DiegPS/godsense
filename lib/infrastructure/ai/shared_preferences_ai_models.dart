import 'package:shared_preferences/shared_preferences.dart';

import '../../application/ai/ai_model_selection_controller.dart';

class SharedPreferencesAiModels implements AiModelPreferences {
  @override
  Future<String?> read(String runtimeId) async =>
      (await SharedPreferences.getInstance()).getString(
        'coach.model.$runtimeId',
      );

  @override
  Future<void> write(String runtimeId, String modelKey) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      'coach.model.$runtimeId',
      modelKey,
    );
    if (!saved) throw StateError('Could not save coach model selection.');
  }
}
