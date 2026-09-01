import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/item_recommendation.dart';
import 'package:godsense/domain/league/rune_recommendation.dart';
import 'package:godsense/infrastructure/league/item_recommendation_cache.dart';

void main() {
  test(
    'persists and restores a patch and position specific Riot build',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'godsense-item-cache-',
      );
      addTearDown(() => root.delete(recursive: true));
      final cache = FileItemRecommendationCache(
        rootDirectory: () async => root,
      );
      final bundle = ItemRecommendationBundle(
        championId: 103,
        championAlias: 'Ahri',
        position: LeaguePosition.middle,
        patch: PatchKey('16.17'),
        mapId: 11,
        mode: 'CLASSIC',
        startingBundles: const [
          RecommendedItemBundle(
            items: [
              RecommendedItem(id: 1056, name: "Doran's Ring"),
              RecommendedItem(id: 2003, name: 'Health Potion'),
            ],
          ),
        ],
        purchaseRanges: const [
          RecommendedItemRange(
            items: [RecommendedItem(id: 6655, name: "Luden's Companion")],
            maxCompletedItems: 2,
          ),
        ],
        positionSpecific: false,
        fetchedAt: DateTime.utc(2026, 9, 1),
        sourceUri: Uri.parse('https://example.invalid/ahri.bin.json'),
      );

      await cache.write(bundle);
      final restored = await cache.read(
        championId: 103,
        position: LeaguePosition.middle,
        patch: PatchKey('16.17'),
        mapId: 11,
        mode: 'CLASSIC',
      );

      expect(restored, isNotNull);
      expect(restored!.championAlias, 'Ahri');
      expect(restored.startingBundles.single.items.last.id, 2003);
      expect(restored.purchaseRanges.single.maxCompletedItems, 2);
    },
  );
}
