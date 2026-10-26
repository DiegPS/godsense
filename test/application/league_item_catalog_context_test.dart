import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/account_context_coordinator.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/application/native_league_foundation.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/account_context.dart';
import 'package:godsense/domain/league/item_recommendation.dart';
import 'package:godsense/domain/league/rune_recommendation.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_catalog_service.dart';
import 'package:godsense/infrastructure/league/riot_item_recommendation_source.dart';

void main() {
  late _Foundation foundation;
  late _Catalog catalog;
  late _Recommendations recommendations;
  late NativeLeagueController controller;
  Future<void> recommend() => controller.loadItemRecommendations(
    championId: 103,
    championAlias: 'Ahri',
    position: LeaguePosition.middle,
  );
  setUp(() {
    foundation = _Foundation();
    catalog = _Catalog();
    recommendations = _Recommendations();
    controller = NativeLeagueController(
      foundation: foundation,
      dataDragonCatalog: catalog,
      itemRecommendationSource: recommendations,
    );
  });
  tearDown(() => controller.dispose());

  test(
    'a failed catalog fetch can be retried without retaining a failed future',
    () async {
      catalog.pending['16.17'] = Future.error(
        StateError('synthetic catalog outage'),
      );
      await recommend();
      expect(controller.state.itemRecommendations, isNull);
      expect(controller.state.itemRecommendationsError, isNotNull);
      catalog.pending.clear();
      await recommend();
      expect(controller.state.itemRecommendations?.patch.value, '16.17');
      expect(controller.state.itemRecommendationsError, isNull);
      expect(catalog.requested, ['16.17', '16.17']);
    },
  );

  test(
    'a stale catalog failure cannot clear a newer successful cache',
    () async {
      final oldCatalog = Completer<Map<int, Map<String, dynamic>>>();
      catalog.pending['16.17'] = oldCatalog.future;
      final older = recommend();
      await Future<void>.delayed(Duration.zero);
      foundation.patch = '16.18';
      await recommend();
      oldCatalog.completeError(StateError('synthetic obsolete response'));
      await older;
      await recommend();
      expect(catalog.requested, ['16.17', '16.18']);
      expect(recommendations.catalogVersions, ['16.18', '16.18']);
    },
  );

  test('repeated recommendations reuse the same patch catalog', () async {
    await recommend();
    await recommend();
    expect(catalog.requested, ['16.17']);
    expect(recommendations.catalogVersions, ['16.17', '16.17']);
  });

  test(
    'client patch change cannot reuse prices from the previous patch',
    () async {
      await recommend();
      foundation.patch = '16.18';
      await recommend();
      expect(catalog.requested, ['16.17', '16.18']);
      expect(recommendations.catalogVersions, ['16.17', '16.18']);
      expect(controller.state.itemRecommendations?.patch.value, '16.18');
    },
  );

  test('late previous patch catalog cannot poison the current cache', () async {
    final oldCatalog = Completer<Map<int, Map<String, dynamic>>>();
    catalog.pending['16.17'] = oldCatalog.future;
    final older = recommend();
    await Future<void>.delayed(Duration.zero);
    expect(catalog.requested, ['16.17']);
    foundation.patch = '16.18';
    await recommend();
    oldCatalog.complete(_items('16.17'));
    await older;
    await recommend();
    expect(recommendations.catalogVersions, ['16.18', '16.18']);
    expect(controller.state.itemRecommendations?.patch.value, '16.18');
  });
}

Map<int, Map<String, dynamic>> _items(String patch) => {
  1001: {
    'name': 'Synthetic boots',
    '_version': patch,
    'gold': {'total': patch == '16.17' ? 300 : 400},
  },
};

class _Foundation implements NativeLeagueFoundation {
  String patch = '16.17';
  @override
  NativeLeagueFoundationState get state {
    final now = DateTime.utc(2026);
    final initial = NativeLeagueFoundationState.initial(now);
    return NativeLeagueFoundationState(
      account: AccountContextState(
        status: AccountContextStatus.ready,
        syncRevision: 1,
        context: AccountContext(
          account: LeagueAccountProfile(
            puuid: Puuid('synthetic-catalog-player'),
            platformId: PlatformId('LA1'),
            patchKey: PatchKey(patch),
            clientVersion: '$patch.123.1',
            firstSeenAt: now,
            lastSeenAt: now,
          ),
          accountGeneration: 1,
          syncRevision: 1,
          activatedAt: now,
        ),
      ),
      capabilities: initial.capabilities,
      gameSession: initial.gameSession,
    );
  }

  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Catalog implements DataDragonCatalogService {
  final requested = <String>[];
  final pending = <String, Future<Map<int, Map<String, dynamic>>>>{};
  @override
  Future<Map<int, Map<String, dynamic>>> loadItems({
    required PatchKey patch,
    required PlatformId platformId,
    ClientVersion? clientVersion,
    LeagueLocale? locale,
  }) async {
    requested.add(patch.value);
    return await (pending[patch.value] ?? Future.value(_items(patch.value)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recommendations implements RiotItemRecommendationSource {
  final catalogVersions = <String>[];
  @override
  Future<ItemRecommendationBundle> load({
    required int championId,
    required String championAlias,
    required LeaguePosition position,
    required PatchKey patch,
    required Map<int, Map<String, dynamic>> itemCatalog,
    int mapId = 11,
    String mode = 'CLASSIC',
  }) async {
    catalogVersions.add(itemCatalog[1001]?['_version'] as String);
    return ItemRecommendationBundle(
      championId: championId,
      championAlias: championAlias,
      position: position,
      patch: patch,
      mapId: mapId,
      mode: mode,
      startingBundles: const [],
      purchaseRanges: const [],
      positionSpecific: true,
      fetchedAt: DateTime.utc(2026),
      sourceUri: Uri.parse('https://example.invalid/fixture'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
