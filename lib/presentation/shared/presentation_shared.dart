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

String _highlightLabel(String? eventType) {
  return switch (eventType) {
    'penta' => 'Pentakill',
    'quadra' => 'Quadrakill',
    'triple' => 'Triple kill',
    'double' => 'Double kill',
    'steal' => 'Robo de objetivo',
    'solo' => 'Eliminación en solitario',
    _ => eventType ?? 'Highlight',
  };
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

String _championLabel(String? champion) {
  return champion == null || champion.isEmpty ? '—' : champion;
}

List<String> _stringValues(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}

String _mapDescription(Map<dynamic, dynamic> map) {
  if (map.isEmpty) return 'Sin datos';
  return map.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n');
}

String _operationResultDescription(Map<String, dynamic> result) {
  final parts = <String>[];
  final runes = result['runes'];
  if (runes is Map && runes['page_name'] != null) {
    parts.add('Runas importadas: ${runes['page_name']}');
  }
  if (result['runes_error'] != null) {
    parts.add('Error de runas: ${result['runes_error']}');
  }
  final build = result['build'];
  if (build is Map && build['set_title'] != null) {
    parts.add('Build importada: ${build['set_title']}');
  }
  if (result['build_error'] != null) {
    parts.add('Error de build: ${result['build_error']}');
  }
  final failed = result['failed'];
  if (failed is Map && failed.isNotEmpty) {
    parts.add('No aplicado: ${_mapDescription(failed)}');
  }
  if (parts.isEmpty && result['ok'] == true) return 'Operación completada.';
  return parts.isEmpty ? _mapDescription(result) : parts.join('\n');
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
