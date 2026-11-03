import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/local_scout_controller.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/account_context.dart';
import 'package:godsense/domain/league/local_scout.dart';
import 'package:godsense/domain/league/scout_selection_store.dart';
import 'package:godsense/infrastructure/persistence/shared_preferences_scout_selection.dart';
import 'package:shared_preferences/shared_preferences.dart';

LeagueAccountProfile account(String id, String platform) =>
    LeagueAccountProfile(
      puuid: Puuid(id),
      platformId: PlatformId(platform),
      riotId: const RiotId(gameName: 'Same name', tagLine: 'TAG'),
      firstSeenAt: DateTime.utc(2026),
      lastSeenAt: DateTime.utc(2026),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final lan = account('lan-player', 'LA1');
  final na = account('na-player', 'NA1');
  LocalScoutController create({ScoutSelectionStore? store}) =>
      LocalScoutController(
        loadMatches: (_, {limit = 20}) async => [],
        loadRanked: (_) async => null,
        loadKnownAccounts: () async => [lan, na],
        selectionStore: store,
      );

  test(
    'selection survives restart and does not follow another League account',
    () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesScoutSelection();
      final first = create(store: store);
      await first.loadAccount(lan);
      await first.selectSavedAccount(na);
      first.dispose();
      final second = create(store: store);
      addTearDown(second.dispose);
      await second.loadAccount(lan);
      expect(second.state.subjectAccount?.puuid, na.puuid);
      expect(second.followsConnectedAccount, false);
      await second.loadAccount(null);
      expect(second.state.subjectAccount?.puuid, na.puuid);
      await second.useConnectedAccount();
      expect(second.state.subjectAccount, isNull);
      expect(second.state.lastError, isNull);
      expect(await store.load(), isNull);
      await second.loadAccount(lan);
      expect(second.state.subjectAccount?.puuid, lan.puuid);
    },
  );

  test(
    'browsing saved profiles never synchronizes or changes the active session',
    () async {
      var syncs = 0;
      final scout = LocalScoutController(
        loadMatches: (_, {limit = 20}) async => [],
        loadRanked: (_) async => null,
        synchronizeAccount: (_, {onProgress}) async {
          syncs++;
          throw StateError('offline');
        },
      );
      addTearDown(scout.dispose);
      await scout.loadAccount(lan);
      expect(syncs, 1);
      await scout.selectSavedAccount(na);
      expect(syncs, 1);
      expect(scout.state.lastError, isNull);
      await scout.loadAccount(lan);
      expect(scout.state.subjectAccount?.puuid, na.puuid);
      await scout.useConnectedAccount();
      expect(scout.state.subjectAccount?.puuid, lan.puuid);
    },
  );

  test('last selection wins when an older local read finishes later', () async {
    final delayed = Completer<LocalRankedSnapshot?>();
    final scout = LocalScoutController(
      loadMatches: (_, {limit = 20}) async => [],
      loadRanked: (id) => id == lan.puuid ? delayed.future : Future.value(null),
    );
    addTearDown(scout.dispose);
    final old = scout.selectSavedAccount(lan);
    await Future<void>.delayed(Duration.zero);
    await scout.selectSavedAccount(na);
    delayed.complete(null);
    await old;
    expect(scout.state.subjectAccount?.puuid, na.puuid);
    expect(scout.state.loading, false);
  });

  test('deleted profile selection returns to follow mode without resurrecting data', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesScoutSelection.storageKey: ['deleted-player', 'LA1'],
    });
    const store = SharedPreferencesScoutSelection();
    final scout = create(store: store);
    addTearDown(scout.dispose);
    await scout.loadAccount(lan);
    expect(scout.followsConnectedAccount, true);
    expect(scout.state.subjectAccount?.puuid, lan.puuid);
    expect(await store.load(), isNull);
  });

  test('region is part of the persisted selection identity', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesScoutSelection.storageKey: ['lan-player', 'NA1'],
    });
    final scout = create(store: const SharedPreferencesScoutSelection());
    addTearDown(scout.dispose);
    await scout.restoreSelection();
    expect(scout.followsConnectedAccount, true);
    expect(scout.state.subjectAccount, isNull);
  });

  test(
    'preference failure keeps the selected profile usable and reports failure',
    () async {
      final scout = create(store: _FailingStore());
      addTearDown(scout.dispose);
      await scout.selectSavedAccount(na);
      expect(scout.state.subjectAccount?.puuid, na.puuid);
      expect(scout.state.selectionError, contains('no se pudo recordar'));
    },
  );

  test('malformed stored choice is safe', () async {
    for (final values in [
      <String>[],
      ['only-id'],
      ['', 'LA1'],
    ]) {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesScoutSelection.storageKey: values,
      });
      expect(await const SharedPreferencesScoutSelection().load(), isNull);
    }
  });

  test(
    'a preference failure during search remains visible after hydration',
    () async {
      final scout = LocalScoutController(
        loadMatches: (_, {limit = 20}) async => [],
        loadRanked: (_) async => null,
        resolveAccount: ({required gameName, required tagLine}) async => na,
        selectionStore: _FailingStore(),
        loadKnownAccounts: () async => [lan, na],
      );
      addTearDown(scout.dispose);
      await scout.searchRiotId(gameName: 'Same name', tagLine: 'TAG');
      expect(scout.state.subjectAccount?.puuid, na.puuid);
      expect(scout.state.selectionError, contains('no se pudo recordar'));
    },
  );

  test('disposing while selection restores does not publish state', () async {
    final store = _DelayedStore();
    final scout = create(store: store);
    final restoring = scout.restoreSelection();
    scout.dispose();
    store.result.complete((puuid: na.puuid.value, platform: 'NA1'));
    await restoring;
  });

  test(
    'a delayed search cannot replace the subsequently selected saved profile',
    () async {
      final response = Completer<LeagueAccountProfile>();
      final scout = LocalScoutController(
        loadMatches: (_, {limit = 20}) async => [],
        loadRanked: (_) async => null,
        resolveAccount: ({required gameName, required tagLine}) =>
            response.future,
      );
      addTearDown(scout.dispose);
      final searching = scout.searchRiotId(
        gameName: 'Same name',
        tagLine: 'TAG',
      );
      await Future<void>.delayed(Duration.zero);
      await scout.selectSavedAccount(na);
      response.complete(lan);
      await searching;
      expect(scout.state.subjectAccount?.puuid, na.puuid);
      expect(scout.followsConnectedAccount, false);
    },
  );
}

class _FailingStore implements ScoutSelectionStore {
  @override
  Future<ScoutProfileKey?> load() async => null;
  @override
  Future<void> save(ScoutProfileKey? key) async =>
      throw StateError('disk full');
}

class _DelayedStore implements ScoutSelectionStore {
  final result = Completer<ScoutProfileKey?>();
  @override
  Future<ScoutProfileKey?> load() => result.future;
  @override
  Future<void> save(ScoutProfileKey? key) async {}
}
