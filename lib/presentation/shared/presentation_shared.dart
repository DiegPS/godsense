part of '../../app/godsense_app.dart';

String _sessionLabel(CompanionState state, NativeLeagueState native) {
  if (native.inGame) return 'Partida en curso';
  if (native.lcuConnected) return 'League conectado';
  if (state.connection != CompanionConnection.online) {
    return 'Abre League para comenzar';
  }
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
  if (calibration == null) return 'El minimapa todavía no está configurado.';
  if (calibration.recalibrationSuggested) {
    return 'Cambió la resolución o la escala del minimapa. Vuelve a calibrar para recuperar las alertas.';
  }
  if (!calibration.calibrated && calibration.defaultBounds == null) {
    return 'Detecta el minimapa o introduce sus límites manualmente.';
  }
  if (calibration.calibrated &&
      !calibration.boundsAreUsable(calibration.bounds)) {
    return 'El área guardada ya no es válida. Vuelve a calibrar el minimapa.';
  }
  final bounds = calibration.effectiveBounds;
  if (bounds == null) return 'El área del minimapa está configurada.';
  return calibration.calibrated
      ? 'Área del minimapa guardada y lista para detectar alertas.'
      : 'Área estimada automáticamente; puedes ajustarla si no coincide.';
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

class _NetworkPortrait extends StatelessWidget {
  const _NetworkPortrait({
    required this.url,
    required this.size,
    this.fallback = Icons.person,
    this.fallbackUrls = const [],
  });

  final String? url;
  final double size;
  final IconData fallback;
  final List<String> fallbackUrls;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ResilientNetworkImage(
        urls: [url, ...fallbackUrls],
        width: size,
        height: size,
        fit: BoxFit.cover,
        fallback: SizedBox.square(dimension: size, child: Icon(fallback)),
      ),
    );
  }
}
