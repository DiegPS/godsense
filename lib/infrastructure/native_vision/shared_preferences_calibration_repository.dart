import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/calibration_repository.dart';
import '../../domain/companion_models.dart';
import '../league/league_installation.dart';

class SharedPreferencesCalibrationRepository implements CalibrationRepository {
  SharedPreferencesCalibrationRepository({
    Future<Map<String, num>> Function()? contextReader,
  }) : _contextReader = contextReader ?? readLeagueCalibrationContext;
  final Future<Map<String, num>> Function() _contextReader;
  static const _storageKey = 'native_minimap_calibration_v1';

  @override
  Future<CalibrationState?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      final value = decoded.map((key, item) => MapEntry(key.toString(), item));
      final bounds = value['bounds'];
      if (bounds is! Map) return null;
      final normalizedBounds = bounds.map(
        (key, item) => MapEntry(key.toString(), item),
      );
      final calibration = CalibrationState(
        calibrated: true,
        recalibrationSuggested: calibrationContextChanged(
          value['provenance'] is Map
              ? Map<String, dynamic>.from(value['provenance'] as Map)
              : null,
          await _contextReader(),
        ),
        provenance: value['provenance'] is Map
            ? Map<String, dynamic>.from(value['provenance'] as Map)
            : null,
        bounds: normalizedBounds,
        iconSize: (value['icon_size'] as num?)?.toDouble(),
        confidence: (value['confidence'] as num?)?.toDouble(),
        defaultBounds: null,
        defaultIconSize: null,
        defaultTrustworthy: false,
      );
      return calibration.boundsAreUsable(calibration.bounds)
          ? calibration
          : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(CalibrationState calibration) async {
    final bounds = calibration.bounds;
    if (!calibration.boundsAreUsable(bounds)) {
      throw ArgumentError.value(bounds, 'bounds', 'Invalid minimap bounds.');
    }
    final preferences = await SharedPreferences.getInstance();
    final context = await _contextReader();
    await preferences.setString(
      _storageKey,
      jsonEncode({
        'bounds': bounds,
        'icon_size': calibration.trackingIconSize,
        'confidence': calibration.confidence ?? 0,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'provenance': context,
      }),
    );
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }
}
