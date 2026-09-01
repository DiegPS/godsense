import '../../domain/identity/league_identity.dart';
import '../../domain/league/item_recommendation.dart';
import '../../domain/league/rune_recommendation.dart';
import 'item_recommendation_cache.dart';
import 'riot_item_recommendation_transport.dart';

class RiotItemRecommendationSource {
  const RiotItemRecommendationSource({required this.transport, this.cache});

  final RiotItemRecommendationTransport transport;
  final ItemRecommendationCache? cache;

  Future<ItemRecommendationBundle> load({
    required int championId,
    required String championAlias,
    required LeaguePosition position,
    required PatchKey patch,
    required Map<int, Map<String, dynamic>> itemCatalog,
    int mapId = 11,
    String mode = 'CLASSIC',
  }) async {
    if (championId <= 0) {
      throw const ItemRecommendationException('A valid champion is required.');
    }
    try {
      return await _loadOnline(
        championId: championId,
        championAlias: championAlias,
        position: position,
        patch: patch,
        itemCatalog: itemCatalog,
        mapId: mapId,
        mode: mode,
      );
    } catch (_) {
      final cached = await cache?.read(
        championId: championId,
        position: position,
        patch: patch,
        mapId: mapId,
        mode: mode,
      );
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<ItemRecommendationBundle> _loadOnline({
    required int championId,
    required String championAlias,
    required LeaguePosition position,
    required PatchKey patch,
    required Map<int, Map<String, dynamic>> itemCatalog,
    required int mapId,
    required String mode,
  }) async {
    if (itemCatalog.isEmpty) {
      throw const ItemRecommendationException(
        'Patch-exact item catalog is not available.',
      );
    }
    final fetched = await transport.fetch(
      patch: patch,
      championAlias: championAlias,
    );
    final sets = <Map<String, dynamic>>[];
    _collectTyped(fetched.document, 'ItemRecommendationOverrideSet', sets);
    if (sets.length != 1) {
      throw ItemRecommendationException(
        'Expected one Riot item recommendation set, found ${sets.length}.',
      );
    }
    final overrides = _maps(sets.single['mOverrides']);
    final generic = <Map<String, dynamic>>[];
    final exact = <Map<String, dynamic>>[];
    for (final override in overrides) {
      for (final context in _maps(override['mOverrideContexts'])) {
        final contextMap = (context['mMapID'] as num?)?.toInt();
        final contextMode = context['mModeNameStringId']?.toString();
        if (contextMap != mapId || contextMode != mode) continue;
        final contextPosition = LeaguePosition.tryParse(context['mPosition']);
        if (contextPosition == position) {
          exact.add(override);
        } else if (context['mPosition'] == null) {
          generic.add(override);
        }
      }
    }
    final selected = exact.isNotEmpty ? exact : generic;
    if (selected.length != 1) {
      throw ItemRecommendationException(
        'Expected one matching Riot override, found ${selected.length}.',
      );
    }
    final value = selected.single;
    final starting = _maps(value['StartingItemBundles'])
        .map(
          (bundle) => RecommendedItemBundle(
            items: _items(bundle['items'], itemCatalog),
          ),
        )
        .where((bundle) => bundle.items.isNotEmpty)
        .toList(growable: false);
    final ranges = _maps(value['mRecItemRanges'])
        .map(
          (range) => RecommendedItemRange(
            items: _items(range['items'], itemCatalog),
            maxCompletedItems: (range['MaxCompletedItems'] as num?)?.toInt(),
          ),
        )
        .where((range) => range.items.isNotEmpty)
        .toList(growable: false);
    if (starting.isEmpty || ranges.isEmpty) {
      throw const ItemRecommendationException(
        'Riot recommendation is missing starting or purchase groups.',
      );
    }
    final bundle = ItemRecommendationBundle(
      championId: championId,
      championAlias: championAlias,
      position: position,
      patch: patch,
      mapId: mapId,
      mode: mode,
      startingBundles: starting,
      purchaseRanges: ranges,
      positionSpecific: exact.isNotEmpty,
      fetchedAt: DateTime.now().toUtc(),
      sourceUri: fetched.sourceUri,
    );
    try {
      await cache?.write(bundle);
    } catch (_) {
      // A valid online response remains usable when local persistence fails.
    }
    return bundle;
  }
}

List<RecommendedItem> _items(
  Object? raw,
  Map<int, Map<String, dynamic>> catalog,
) {
  if (raw is! List) return const [];
  return raw
      .map((value) {
        final match = RegExp(r'(\d+)$').firstMatch(value.toString());
        final id = int.tryParse(match?.group(1) ?? '');
        final item = id == null ? null : catalog[id];
        final name = item?['name']?.toString().trim() ?? '';
        if (id == null || name.isEmpty) {
          throw ItemRecommendationException(
            'Riot recommended unknown item ${value.toString()}.',
          );
        }
        return RecommendedItem(id: id, name: name);
      })
      .toList(growable: false);
}

void _collectTyped(
  Object? value,
  String type,
  List<Map<String, dynamic>> output,
) {
  if (value is Map) {
    final mapped = value.map((key, item) => MapEntry(key.toString(), item));
    if (mapped['__type'] == type) output.add(mapped);
    for (final item in mapped.values) {
      _collectTyped(item, type, output);
    }
  } else if (value is List) {
    for (final item in value) {
      _collectTyped(item, type, output);
    }
  }
}

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false)
    : const [];
