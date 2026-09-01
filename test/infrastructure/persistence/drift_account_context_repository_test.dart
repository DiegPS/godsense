import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/account_context.dart';
import 'package:godsense/infrastructure/persistence/drift_account_context_repository.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';

void main() {
  late GodSenseDatabase database;
  late DriftAccountContextRepository repository;

  setUp(() {
    database = GodSenseDatabase.inMemory();
    repository = DriftAccountContextRepository(database);
  });

  tearDown(() => database.close());

  test(
    'persists and restores the active account independently of LCU',
    () async {
      final context = _context(puuid: 'account-a', revision: 1, generation: 1);

      expect(await repository.activate(context), isTrue);
      final restored = await repository.loadActive();

      expect(restored?.account.puuid.value, 'account-a');
      expect(restored?.account.riotId?.displayName, 'Diego#LAN');
      expect(restored?.account.platformId.value, 'LA1');
      expect(restored?.account.patchKey?.value, '16.17');
      expect(restored?.accountGeneration, 1);
      expect(restored?.syncRevision, 1);
    },
  );

  test('preserves firstSeen while refreshing mutable account fields', () async {
    await repository.activate(
      _context(
        puuid: 'account-a',
        revision: 1,
        generation: 1,
        observedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await repository.activate(
      _context(
        puuid: 'account-a',
        revision: 2,
        generation: 1,
        observedAt: DateTime.utc(2026, 2, 1),
        summonerLevel: 200,
      ),
    );

    final restored = await repository.loadActive();
    expect(restored?.account.firstSeenAt, DateTime.utc(2026, 1, 1));
    expect(restored?.account.lastSeenAt, DateTime.utc(2026, 2, 1));
    expect(restored?.account.summonerLevel, 200);
  });

  test('rejects stale synchronization revisions', () async {
    await repository.activate(
      _context(puuid: 'account-b', revision: 10, generation: 2),
    );

    expect(
      await repository.activate(
        _context(puuid: 'account-a', revision: 9, generation: 1),
      ),
      isFalse,
    );
    expect((await repository.loadActive())?.account.puuid.value, 'account-b');
  });
}

AccountContext _context({
  required String puuid,
  required int revision,
  required int generation,
  DateTime? observedAt,
  int summonerLevel = 100,
}) {
  final timestamp = observedAt ?? DateTime.utc(2026, 9, 1);
  return AccountContext(
    account: LeagueAccountProfile(
      puuid: Puuid(puuid),
      platformId: PlatformId('LA1'),
      riotId: const RiotId(gameName: 'Diego', tagLine: 'LAN'),
      summonerId: 42,
      summonerLevel: summonerLevel,
      profileIconId: 7,
      clientVersion: '16.17.123.1',
      patchKey: PatchKey('16.17'),
      firstSeenAt: timestamp,
      lastSeenAt: timestamp,
    ),
    accountGeneration: generation,
    syncRevision: revision,
    activatedAt: timestamp,
  );
}
