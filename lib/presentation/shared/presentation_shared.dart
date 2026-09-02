part of '../../app/godsense_app.dart';

String _sessionLabel(CompanionState state, NativeLeagueState native) {
  if (native.inGame) return 'League game active · native';
  if (native.lcuConnected) return '${native.gameflowPhase} · native';
  if (state.connection != CompanionConnection.online) return 'League offline';
  if (state.lobby?.lcuConnected == true) {
    return '${state.lobby!.phase} · fallback';
  }
  return 'Waiting for League';
}

String _formatGameTime(double seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds.floor() % 60;
  return '$minutes:${remaining.toString().padLeft(2, '0')}';
}

String _formatDuration(num seconds) => _formatGameTime(seconds.toDouble());

String _buildDescription(Map<String, dynamic> builds) {
  final names = <String>[];

  void collect(Object? value) {
    if (value is Map) {
      final name = value['name'];
      if (name is String && name.isNotEmpty) names.add(name);
      for (final child in value.values) {
        collect(child);
      }
    } else if (value is List) {
      for (final child in value) {
        collect(child);
      }
    }
  }

  collect(builds);
  if (names.isNotEmpty) return names.toSet().take(12).join(' · ');
  return builds.keys.join(' · ');
}

String _formatTimestamp(DateTime timestamp) {
  final local = timestamp.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  String three(int value) => value.toString().padLeft(3, '0');
  return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}.${three(local.millisecond)}';
}

String _calibrationDescription(CalibrationState? calibration) {
  if (calibration == null) return 'Sin calibración nativa guardada.';
  if (!calibration.calibrated && calibration.defaultBounds == null) {
    return 'Detecta el minimapa o introduce sus límites manualmente.';
  }
  if (calibration.calibrated &&
      !calibration.boundsAreUsable(calibration.bounds)) {
    final bad = calibration.bounds!;
    return 'Calibración inválida ${bad['width']}x${bad['height']}. '
        'Vuelve a calibrar manualmente.';
  }
  final bounds = calibration.effectiveBounds;
  if (bounds == null) return 'Calibración nativa activa.';
  final source = calibration.calibrated
      ? 'calibración guardada'
      : calibration.defaultTrustworthy
      ? 'estimación confiable'
      : 'estimación provisional';
  return '$source · ${bounds['width']}x${bounds['height']} at '
      '${bounds['left']}, ${bounds['top']} · icon ${calibration.iconSize?.round() ?? '-'} px';
}

String _signedNumber(int value) => value > 0 ? '+$value' : '$value';

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

int _teamKills(List<Map<String, dynamic>> players) {
  return players.fold(0, (total, player) {
    final kda = player['kda'];
    return total +
        (kda is List && kda.isNotEmpty ? (kda.first as num?)?.toInt() ?? 0 : 0);
  });
}

int _teamGold(List<Map<String, dynamic>> players) {
  return players.fold(
    0,
    (total, player) => total + ((player['gold_total'] as num?)?.toInt() ?? 0),
  );
}

NativeIdentifiedChampion? _nativeForEnemy(
  Map<String, NativeIdentifiedChampion> lastKnown,
  Map<String, dynamic> enemy,
) {
  String normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final name = enemy['champion_name']?.toString();
  if (name == null || name.isEmpty) return null;
  final direct = lastKnown[name];
  if (direct != null) return direct;
  final normalized = normalize(name);
  for (final entry in lastKnown.entries) {
    if (normalize(entry.key) == normalized) return entry.value;
  }
  return null;
}

List<String> _stringValues(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}

String _mapDescription(Map<dynamic, dynamic> map) {
  if (map.isEmpty) return 'Sin datos';
  return map.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n');
}

class _NetworkPortrait extends StatelessWidget {
  const _NetworkPortrait({
    required this.url,
    required this.size,
    this.fallback = Icons.person,
  });

  final String? url;
  final double size;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return SizedBox.square(dimension: size, child: Icon(fallback));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            SizedBox.square(dimension: size, child: Icon(fallback)),
      ),
    );
  }
}
