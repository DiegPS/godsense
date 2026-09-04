import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../application/coach_controller.dart';

class SharedPreferencesPostGameReportStore implements PostGameReportStore {
  const SharedPreferencesPostGameReportStore();

  String _key(String account) =>
      'coach.postgame.v1.${Uri.encodeComponent(account)}';

  @override
  Future<Map<String, dynamic>?> load(String accountKey) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _key(accountKey),
    );
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['account'] != accountKey ||
        decoded['snapshot'] is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(decoded['snapshot'] as Map);
  }

  @override
  Future<void> save(String accountKey, Map<String, dynamic> snapshot) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _key(accountKey),
      jsonEncode({'account': accountKey, 'snapshot': snapshot}),
    );
    if (!saved) throw StateError('No se pudo guardar el resumen de partida.');
  }
}
