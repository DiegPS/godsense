import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/native_speech_settings.dart';

class SharedPreferencesSpeechSettingsRepository
    implements NativeSpeechSettingsRepository {
  static const _storageKey = 'native_speech_settings_v1';

  @override
  Future<NativeSpeechSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return const NativeSpeechSettings();
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return const NativeSpeechSettings();
      return NativeSpeechSettings.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on FormatException {
      return const NativeSpeechSettings();
    }
  }

  @override
  Future<void> save(NativeSpeechSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(settings.toJson()));
  }
}
