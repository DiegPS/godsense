import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/ai/ai_runtime_models.dart';

class AiRuntimeUserSettings {
  const AiRuntimeUserSettings({this.preferredKind, this.autoStart = false});

  final AiRuntimeKind? preferredKind;
  final bool autoStart;
}

class SharedPreferencesAiRuntimeSettings {
  const SharedPreferencesAiRuntimeSettings();

  static const _kindKey = 'coach.runtime.preferred';
  static const _autoStartKey = 'coach.runtime.auto_start';

  Future<AiRuntimeUserSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final kindId = preferences.getString(_kindKey);
    return AiRuntimeUserSettings(
      preferredKind: AiRuntimeKind.values
          .where((kind) => kind.id == kindId)
          .firstOrNull,
      autoStart: preferences.getBool(_autoStartKey) ?? false,
    );
  }

  Future<void> rememberStarted(AiRuntimeKind kind) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_kindKey, kind.id),
      preferences.setBool(_autoStartKey, true),
    ]);
  }

  Future<void> setAutoStart(bool enabled) async {
    await (await SharedPreferences.getInstance()).setBool(
      _autoStartKey,
      enabled,
    );
  }
}
