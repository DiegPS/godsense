import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/identity/league_identity.dart';
import '../../domain/league/item_recommendation.dart';
import '../../domain/league/rune_recommendation.dart';

abstract interface class ItemRecommendationCache {
  Future<ItemRecommendationBundle?> read({
    required int championId,
    required LeaguePosition position,
    required PatchKey patch,
    required int mapId,
    required String mode,
  });

  Future<void> write(ItemRecommendationBundle bundle);
}

class FileItemRecommendationCache implements ItemRecommendationCache {
  FileItemRecommendationCache({required this.rootDirectory});

  factory FileItemRecommendationCache.defaultCache() =>
      FileItemRecommendationCache(
        rootDirectory: () async => Directory(
          p.join(
            (await getApplicationSupportDirectory()).path,
            'item_recommendations',
          ),
        ),
      );

  final Future<Directory> Function() rootDirectory;

  @override
  Future<ItemRecommendationBundle?> read({
    required int championId,
    required LeaguePosition position,
    required PatchKey patch,
    required int mapId,
    required String mode,
  }) async {
    try {
      final file = await _file(championId, position, patch, mapId, mode);
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return null;
      final data = raw.map((key, value) => MapEntry(key.toString(), value));
      final starting = _lists(data['starting'])
          .map((items) => RecommendedItemBundle(items: _items(items)))
          .toList(growable: false);
      final ranges = _maps(data['ranges'])
          .map(
            (range) => RecommendedItemRange(
              items: _items(range['items']),
              maxCompletedItems: (range['max_completed'] as num?)?.toInt(),
            ),
          )
          .toList(growable: false);
      if (starting.isEmpty || ranges.isEmpty) return null;
      return ItemRecommendationBundle(
        championId: championId,
        championAlias: data['champion_alias']?.toString() ?? '',
        position: position,
        patch: patch,
        mapId: mapId,
        mode: mode,
        startingBundles: starting,
        purchaseRanges: ranges,
        positionSpecific: data['position_specific'] == true,
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
  Future<void> write(ItemRecommendationBundle bundle) async {
    final file = await _file(
      bundle.championId,
      bundle.position,
      bundle.patch,
      bundle.mapId,
      bundle.mode,
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'champion_alias': bundle.championAlias,
        'position_specific': bundle.positionSpecific,
        'fetched_at': bundle.fetchedAt.toIso8601String(),
        'source_uri': bundle.sourceUri.toString(),
        'starting': [
          for (final group in bundle.startingBundles)
            [for (final item in group.items) _itemJson(item)],
        ],
        'ranges': [
          for (final range in bundle.purchaseRanges)
            {
              'items': [for (final item in range.items) _itemJson(item)],
              'max_completed': range.maxCompletedItems,
            },
        ],
      }),
      flush: true,
    );
  }

  Future<File> _file(
    int championId,
    LeaguePosition position,
    PatchKey patch,
    int mapId,
    String mode,
  ) async => File(
    p.join(
      (await rootDirectory()).path,
      '${patch.value}-$championId-${position.name}-$mapId-${mode.toLowerCase()}.json',
    ),
  );
}

Map<String, dynamic> _itemJson(RecommendedItem item) => {
  'id': item.id,
  'name': item.name,
};

List<RecommendedItem> _items(Object? value) => _maps(value)
    .map(
      (item) => RecommendedItem(
        id: (item['id'] as num).toInt(),
        name: item['name'].toString(),
      ),
    )
    .toList(growable: false);

List<List<dynamic>> _lists(Object? value) =>
    value is List ? value.whereType<List>().toList(growable: false) : const [];

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false)
    : const [];
