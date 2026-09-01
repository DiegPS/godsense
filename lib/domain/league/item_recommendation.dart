import '../identity/league_identity.dart';
import 'rune_recommendation.dart';

class RecommendedItem {
  const RecommendedItem({required this.id, required this.name});

  final int id;
  final String name;
}

class RecommendedItemBundle {
  const RecommendedItemBundle({required this.items});

  final List<RecommendedItem> items;
}

class RecommendedItemRange {
  const RecommendedItemRange({required this.items, this.maxCompletedItems});

  final List<RecommendedItem> items;
  final int? maxCompletedItems;
}

class ItemRecommendationBundle {
  const ItemRecommendationBundle({
    required this.championId,
    required this.championAlias,
    required this.position,
    required this.patch,
    required this.mapId,
    required this.mode,
    required this.startingBundles,
    required this.purchaseRanges,
    required this.positionSpecific,
    required this.fetchedAt,
    required this.sourceUri,
  });

  final int championId;
  final String championAlias;
  final LeaguePosition position;
  final PatchKey patch;
  final int mapId;
  final String mode;
  final List<RecommendedItemBundle> startingBundles;
  final List<RecommendedItemRange> purchaseRanges;
  final bool positionSpecific;
  final DateTime fetchedAt;
  final Uri sourceUri;

  List<Map<String, dynamic>> toImportGroups() {
    final groups = <Map<String, dynamic>>[];
    for (var index = 0; index < startingBundles.length; index++) {
      groups.add({
        'category': 'Inicio ${index + 1}',
        'items': _countItems(startingBundles[index].items),
      });
    }
    for (var index = 0; index < purchaseRanges.length; index++) {
      final range = purchaseRanges[index];
      final suffix = range.maxCompletedItems == null
          ? ''
          : ' · hasta ${range.maxCompletedItems} objetos completos';
      groups.add({
        'category': 'Compra ${index + 1}$suffix',
        'items': _countItems(range.items),
      });
    }
    return groups;
  }
}

List<Map<String, dynamic>> _countItems(List<RecommendedItem> items) {
  final counts = <int, int>{};
  for (final item in items) {
    counts.update(item.id, (value) => value + 1, ifAbsent: () => 1);
  }
  return [
    for (final entry in counts.entries)
      {'item_id': entry.key, 'count': entry.value},
  ];
}

class ItemRecommendationException implements Exception {
  const ItemRecommendationException(this.message);

  final String message;

  @override
  String toString() => 'ItemRecommendationException: $message';
}
