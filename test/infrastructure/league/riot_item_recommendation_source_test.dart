import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/item_recommendation.dart';
import 'package:godsense/domain/league/rune_recommendation.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_artifact_store.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_catalog_service.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_resolver.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_transport.dart';
import 'package:godsense/infrastructure/league/item_recommendation_cache.dart';
import 'package:godsense/infrastructure/league/riot_item_recommendation_source.dart';
import 'package:godsense/infrastructure/league/riot_item_recommendation_transport.dart';

void main() {
  const catalog = {
    1056: {'name': "Doran's Ring"},
    2003: {'name': 'Health Potion'},
    3850: {'name': "Spellthief's Edge"},
    6655: {'name': "Luden's Companion"},
    3020: {'name': "Sorcerer's Shoes"},
  };

  test(
    'decodes and validates the current Riot champion artifact end to end',
    () async {
      final transport = CommunityDragonItemRecommendationTransport();
      addTearDown(transport.dispose);
      final cache = await Directory.systemTemp.createTemp('godsense-items-');
      addTearDown(() => cache.delete(recursive: true));
      final dataDragon = DataDragonCatalogService(
        DataDragonResolver(
          transport: HttpDataDragonTransport(),
          store: FileDataDragonArtifactStore(cache),
        ),
      );
      final patch = PatchKey('16.17');
      final items = await dataDragon.loadItems(
        patch: patch,
        platformId: PlatformId('LA1'),
      );
      final result = await RiotItemRecommendationSource(transport: transport)
          .load(
            championId: 103,
            championAlias: 'Ahri',
            position: LeaguePosition.middle,
            patch: patch,
            itemCatalog: items,
          );

      expect(result.startingBundles, isNotEmpty);
      expect(result.purchaseRanges.length, greaterThanOrEqualTo(5));
      expect(
        result.purchaseRanges
            .expand((range) => range.items)
            .every((item) => item.name.isNotEmpty),
        isTrue,
      );
    },
    skip: Platform.environment['GODSENSE_CDRAGON_SMOKE'] == '1'
        ? false
        : 'Set GODSENSE_CDRAGON_SMOKE=1 for the network smoke test.',
  );

  test('uses a position override before the generic Riot build', () async {
    final source = RiotItemRecommendationSource(
      transport: _FakeTransport(_document),
    );

    final result = await source.load(
      championId: 103,
      championAlias: 'Ahri',
      position: LeaguePosition.utility,
      patch: PatchKey('16.17'),
      itemCatalog: catalog,
    );

    expect(result.positionSpecific, isTrue);
    expect(result.startingBundles.single.items.first.id, 3850);
    expect(result.purchaseRanges.single.items.first.name, "Luden's Companion");
    expect(result.toImportGroups().first['category'], 'Inicio 1');
  });

  test('falls back to the map and mode build for other positions', () async {
    final source = RiotItemRecommendationSource(
      transport: _FakeTransport(_document),
    );

    final result = await source.load(
      championId: 103,
      championAlias: 'Ahri',
      position: LeaguePosition.middle,
      patch: PatchKey('16.17'),
      itemCatalog: catalog,
    );

    expect(result.positionSpecific, isFalse);
    expect(result.startingBundles.single.items.map((item) => item.id), [
      1056,
      2003,
      2003,
    ]);
    expect(result.toImportGroups().first['items'], [
      {'item_id': 1056, 'count': 1},
      {'item_id': 2003, 'count': 2},
    ]);
    final json = result.toBuildJson();
    expect(json['patch'], '16.17');
    expect(((json['items'] as List).first as Map)['items'], [
      {'item_id': 1056, 'count': 1, 'name': "Doran's Ring"},
      {'item_id': 2003, 'count': 2, 'name': 'Health Potion'},
    ]);
  });

  test('rejects an item absent from the patch catalog', () async {
    final source = RiotItemRecommendationSource(
      transport: _FakeTransport(_document),
    );

    await expectLater(
      source.load(
        championId: 103,
        championAlias: 'Ahri',
        position: LeaguePosition.middle,
        patch: PatchKey('16.17'),
        itemCatalog: const {
          1056: {'name': "Doran's Ring"},
          2003: {'name': 'Health Potion'},
        },
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('uses the same-patch cached build while offline', () async {
    final cached = ItemRecommendationBundle(
      championId: 103,
      championAlias: 'Ahri',
      position: LeaguePosition.middle,
      patch: PatchKey('16.17'),
      mapId: 11,
      mode: 'CLASSIC',
      startingBundles: const [
        RecommendedItemBundle(
          items: [RecommendedItem(id: 1056, name: "Doran's Ring")],
        ),
      ],
      purchaseRanges: const [
        RecommendedItemRange(
          items: [RecommendedItem(id: 6655, name: "Luden's Companion")],
        ),
      ],
      positionSpecific: false,
      fetchedAt: DateTime.utc(2026, 9, 1),
      sourceUri: Uri.parse('https://example.invalid/ahri.bin.json'),
    );
    final source = RiotItemRecommendationSource(
      transport: const _ThrowingTransport(),
      cache: _MemoryCache(cached),
    );

    final result = await source.load(
      championId: 103,
      championAlias: 'Ahri',
      position: LeaguePosition.middle,
      patch: PatchKey('16.17'),
      itemCatalog: const {},
    );

    expect(result, same(cached));
  });
}

class _FakeTransport implements RiotItemRecommendationTransport {
  const _FakeTransport(this.document);

  final Map<String, dynamic> document;

  @override
  Future<({Map<String, dynamic> document, Uri sourceUri})> fetch({
    required PatchKey patch,
    required String championAlias,
  }) async => (
    document: document,
    sourceUri: Uri.parse('https://example.invalid/$championAlias.bin.json'),
  );
}

class _ThrowingTransport implements RiotItemRecommendationTransport {
  const _ThrowingTransport();

  @override
  Future<({Map<String, dynamic> document, Uri sourceUri})> fetch({
    required PatchKey patch,
    required String championAlias,
  }) => throw const SocketException('offline');
}

class _MemoryCache implements ItemRecommendationCache {
  _MemoryCache(this.value);

  final ItemRecommendationBundle value;

  @override
  Future<ItemRecommendationBundle?> read({
    required int championId,
    required LeaguePosition position,
    required PatchKey patch,
    required int mapId,
    required String mode,
  }) async => value;

  @override
  Future<void> write(ItemRecommendationBundle bundle) async {}
}

final _document = <String, dynamic>{
  '{set}': {
    '__type': 'ItemRecommendationOverrideSet',
    'mOverrides': [
      {
        '__type': 'ItemRecommendationOverride',
        'mOverrideContexts': [
          {
            '__type': 'ItemRecommendationOverrideContext',
            'mMapID': 11,
            'mModeNameStringId': 'CLASSIC',
          },
        ],
        'StartingItemBundles': [
          {
            'items': ['Items/1056', 'Items/2003', 'Items/2003'],
          },
        ],
        'mRecItemRanges': [
          {
            'items': ['Items/6655', 'Items/3020'],
          },
        ],
      },
      {
        '__type': 'ItemRecommendationOverride',
        'mOverrideContexts': [
          {
            '__type': 'ItemRecommendationOverrideContext',
            'mMapID': 11,
            'mModeNameStringId': 'CLASSIC',
            'mPosition': 'utility',
          },
        ],
        'StartingItemBundles': [
          {
            'items': ['Items/3850'],
          },
        ],
        'mRecItemRanges': [
          {
            'items': ['Items/6655'],
          },
        ],
      },
    ],
  },
};
