import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/identity/league_identity.dart';
import '../../domain/jungle/jungle_recommendation.dart';

abstract interface class JungleRecommendationCache {
  Future<JungleRecommendationBundle?> read(PatchKey patch);

  Future<void> write(JungleRecommendationBundle bundle);
}

class FileJungleRecommendationCache implements JungleRecommendationCache {
  FileJungleRecommendationCache({required this.rootDirectory});

  factory FileJungleRecommendationCache.defaultCache() =>
      FileJungleRecommendationCache(
        rootDirectory: () async => Directory(
          p.join(
            (await getApplicationSupportDirectory()).path,
            'jungle_recommendations',
          ),
        ),
      );

  final Future<Directory> Function() rootDirectory;

  @override
  Future<JungleRecommendationBundle?> read(PatchKey patch) async {
    try {
      final file = await _file(patch);
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return null;
      final data = raw.map((key, value) => MapEntry(key.toString(), value));
      final order = _routeFromJson(JungleSide.order, data['order']);
      final chaos = _routeFromJson(JungleSide.chaos, data['chaos']);
      if (order == null || chaos == null) return null;
      return JungleRecommendationBundle(
        patch: patch,
        mapId: (data['map_id'] as num?)?.toInt() ?? 11,
        order: order,
        chaos: chaos,
        fetchedAt:
            DateTime.tryParse(data['fetched_at']?.toString() ?? '')?.toUtc() ??
            (await file.lastModified()).toUtc(),
        sourceUri: Uri.parse(data['source_uri']?.toString() ?? 'about:blank'),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(JungleRecommendationBundle bundle) async {
    final file = await _file(bundle.patch);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'patch': bundle.patch.value,
        'map_id': bundle.mapId,
        'fetched_at': bundle.fetchedAt.toUtc().toIso8601String(),
        'source_uri': bundle.sourceUri.toString(),
        'order': _routeToJson(bundle.order),
        'chaos': _routeToJson(bundle.chaos),
      }),
      flush: true,
    );
  }

  Future<File> _file(PatchKey patch) async =>
      File(p.join((await rootDirectory()).path, '${patch.value}.map11.json'));
}

List<Map<String, Object>> _routeToJson(JungleRoute route) => route.camps
    .map(
      (camp) => <String, Object>{
        'location_id': camp.locationId,
        'name': camp.name,
        'x': camp.x,
        'z': camp.z,
      },
    )
    .toList(growable: false);

JungleRoute? _routeFromJson(JungleSide side, Object? raw) {
  if (raw is! List) return null;
  final camps = raw
      .whereType<Map>()
      .map((value) {
        final camp = value.map((key, item) => MapEntry(key.toString(), item));
        return JungleCamp(
          locationId: (camp['location_id'] as num?)?.toInt() ?? -1,
          name: camp['name']?.toString() ?? '',
          x: (camp['x'] as num?)?.toDouble() ?? double.nan,
          z: (camp['z'] as num?)?.toDouble() ?? double.nan,
        );
      })
      .where(
        (camp) =>
            camp.locationId >= 0 &&
            camp.name.isNotEmpty &&
            camp.x.isFinite &&
            camp.z.isFinite,
      );
  final values = camps.toList(growable: false);
  if (values.length < 5) return null;
  return JungleRoute(side: side, camps: List.unmodifiable(values));
}
