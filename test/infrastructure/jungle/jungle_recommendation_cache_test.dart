import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/jungle/jungle_recommendation.dart';
import 'package:godsense/infrastructure/jungle/jungle_recommendation_cache.dart';

void main() {
  test('persists and restores compact patch-specific jungle routes', () async {
    final root = await Directory.systemTemp.createTemp('godsense-jungle-');
    addTearDown(() => root.delete(recursive: true));
    final cache = FileJungleRecommendationCache(
      rootDirectory: () async => root,
    );
    final patch = PatchKey('16.17');
    final bundle = JungleRecommendationBundle(
      patch: patch,
      mapId: 11,
      order: _route(JungleSide.order, 'Order'),
      chaos: _route(JungleSide.chaos, 'Chaos'),
      fetchedAt: DateTime.utc(2026, 9, 1),
      sourceUri: Uri.parse('https://example.invalid/map11.bin.json'),
    );

    await cache.write(bundle);
    final restored = await cache.read(patch);

    expect(restored, isNotNull);
    expect(restored!.order.camps.map((camp) => camp.name), [
      for (var index = 0; index < 6; index++) 'Order $index',
    ]);
    expect(restored.chaos.camps, hasLength(6));
    expect(restored.sourceUri, bundle.sourceUri);
  });
}

JungleRoute _route(JungleSide side, String prefix) => JungleRoute(
  side: side,
  camps: [
    for (var index = 0; index < 6; index++)
      JungleCamp(
        locationId: index,
        name: '$prefix $index',
        x: index * 10,
        z: index * 20,
      ),
  ],
);
