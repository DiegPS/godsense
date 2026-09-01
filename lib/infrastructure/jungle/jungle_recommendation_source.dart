import '../../domain/identity/league_identity.dart';
import '../../domain/jungle/jungle_recommendation.dart';
import 'jungle_map_transport.dart';
import 'jungle_recommendation_cache.dart';

class JungleRecommendationSource {
  JungleRecommendationSource({
    required this.transport,
    this.cache,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final JungleMapTransport transport;
  final JungleRecommendationCache? cache;
  final DateTime Function() _now;

  Future<JungleRecommendationBundle> load(PatchKey patch) async {
    try {
      final bundle = await _loadOnline(patch);
      await cache?.write(bundle);
      return bundle;
    } catch (_) {
      final cached = await cache?.read(patch);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<JungleRecommendationBundle> _loadOnline(PatchKey patch) async {
    final root = await transport.loadMap11(patch);
    final mapInfo = _typedObject(
      root.values,
      'JungleRecommendationMapInformation',
    );
    final pathInfo = _typedObject(root.values, 'JunglePathRecommendation');
    if (mapInfo == null || pathInfo == null) {
      throw const JungleRecommendationException(
        'Map11 does not contain Riot jungle recommendation contracts.',
      );
    }

    final camps = <int, JungleCamp>{};
    final rawLocations = mapInfo['JungleLocationInformation'];
    if (rawLocations is List) {
      for (final value in rawLocations.whereType<Map>()) {
        final location = _stringMap(value);
        final position = location['Position'];
        if (position is! List || position.length < 3) continue;
        final id = (location['Location'] as num?)?.toInt() ?? 0;
        final x = (position[0] as num?)?.toDouble();
        final z = (position[2] as num?)?.toDouble();
        if (x == null || z == null || camps.containsKey(id)) continue;
        camps[id] = JungleCamp(
          locationId: id,
          name: _modernCampName(location['name']?.toString() ?? 'Camp $id'),
          x: x,
          z: z,
        );
      }
    }

    final order = _route(JungleSide.order, pathInfo['OrderJunglePath'], camps);
    final chaos = _route(JungleSide.chaos, pathInfo['ChaosJunglePath'], camps);
    return JungleRecommendationBundle(
      patch: patch,
      mapId: 11,
      order: order,
      chaos: chaos,
      fetchedAt: _now().toUtc(),
      sourceUri: transport.sourceUri(patch),
    );
  }
}

Map<String, dynamic>? _typedObject(Iterable<Object?> values, String type) {
  for (final value in values.whereType<Map>()) {
    final item = _stringMap(value);
    if (item['__type'] == type) return item;
  }
  return null;
}

JungleRoute _route(JungleSide side, Object? raw, Map<int, JungleCamp> camps) {
  if (raw is! List) {
    throw JungleRecommendationException('${side.name} route is missing.');
  }
  final result = <JungleCamp>[];
  for (final value in raw.whereType<Map>()) {
    final step = _stringMap(value);
    if (step['__type'] != 'TakeCamp') continue;
    final locationId = (step['Camp'] as num?)?.toInt() ?? 0;
    final camp = camps[locationId];
    if (camp == null) {
      throw JungleRecommendationException(
        '${side.name} route references unknown camp $locationId.',
      );
    }
    result.add(camp);
  }
  if (result.length < 5) {
    throw JungleRecommendationException(
      '${side.name} route has only ${result.length} resolved camps.',
    );
  }
  return JungleRoute(side: side, camps: List.unmodifiable(result));
}

String _modernCampName(String value) => value
    .replaceAll(RegExp('OwlBear', caseSensitive: false), 'Gromp')
    .replaceAll(RegExp('Wraiths', caseSensitive: false), 'Raptors')
    .replaceAll(RegExp('Small Golems', caseSensitive: false), 'Krugs');

Map<String, dynamic> _stringMap(Map value) =>
    value.map((key, item) => MapEntry(key.toString(), item));
