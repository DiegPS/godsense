import 'package:drift/drift.dart';

import '../../domain/identity/league_identity.dart';
import '../../domain/league/account_context.dart';
import 'godsense_database.dart';

class DriftAccountContextRepository implements AccountContextRepository {
  DriftAccountContextRepository(this._database);

  final GodSenseDatabase _database;

  @override
  Future<bool> activate(AccountContext context) {
    return _database.transaction(() async {
      final currentState = await (_database.select(
        _database.accountContextStates,
      )..where((table) => table.singletonId.equals(1))).getSingleOrNull();
      if (currentState != null &&
          currentState.syncRevision > context.syncRevision) {
        return false;
      }

      final account = context.account;
      await saveKnownAccount(account);
      await _database
          .into(_database.accountContextStates)
          .insertOnConflictUpdate(
            AccountContextStatesCompanion.insert(
              singletonId: const Value(1),
              currentPuuid: Value(account.puuid.value),
              accountGeneration: context.accountGeneration,
              syncRevision: context.syncRevision,
              updatedAtUs: _micros(context.activatedAt),
            ),
          );
      return true;
    });
  }

  Future<void> saveKnownAccount(LeagueAccountProfile account) async {
    final existing =
        await (_database.select(_database.accounts)
              ..where((table) => table.puuid.equals(account.puuid.value)))
            .getSingleOrNull();
    await _database
        .into(_database.accounts)
        .insertOnConflictUpdate(
          AccountsCompanion.insert(
            puuid: account.puuid.value,
            platformId: account.platformId.value,
            gameName: Value(account.riotId?.gameName),
            tagLine: Value(account.riotId?.tagLine),
            summonerId: Value(account.summonerId),
            summonerLevel: Value(account.summonerLevel),
            profileIconId: Value(account.profileIconId),
            lastClientVersion: Value(account.clientVersion),
            lastPatchKey: Value(account.patchKey?.value),
            firstSeenAtUs:
                existing?.firstSeenAtUs ?? _micros(account.firstSeenAt),
            lastSeenAtUs: _micros(account.lastSeenAt),
          ),
        );
  }

  @override
  Future<AccountContext?> loadActive() async {
    final state = await (_database.select(
      _database.accountContextStates,
    )..where((table) => table.singletonId.equals(1))).getSingleOrNull();
    final puuid = state?.currentPuuid;
    if (state == null || puuid == null) return null;
    final account = await (_database.select(
      _database.accounts,
    )..where((table) => table.puuid.equals(puuid))).getSingleOrNull();
    if (account == null) return null;
    return AccountContext(
      account: _mapAccount(account),
      accountGeneration: state.accountGeneration,
      syncRevision: state.syncRevision,
      activatedAt: _dateTime(state.updatedAtUs),
    );
  }

  @override
  Future<List<LeagueAccountProfile>> loadAllAccounts() async {
    final query = _database.select(_database.accounts)
      ..orderBy([(table) => OrderingTerm.desc(table.lastSeenAtUs)]);
    return (await query.get()).map(_mapAccount).toList(growable: false);
  }

  LeagueAccountProfile _mapAccount(Account row) {
    final gameName = row.gameName;
    final tagLine = row.tagLine;
    return LeagueAccountProfile(
      puuid: Puuid(row.puuid),
      platformId: PlatformId(row.platformId),
      riotId: gameName != null && tagLine != null
          ? RiotId(gameName: gameName, tagLine: tagLine)
          : null,
      summonerId: row.summonerId,
      summonerLevel: row.summonerLevel,
      profileIconId: row.profileIconId,
      clientVersion: row.lastClientVersion,
      patchKey: row.lastPatchKey == null ? null : PatchKey(row.lastPatchKey!),
      firstSeenAt: _dateTime(row.firstSeenAtUs),
      lastSeenAt: _dateTime(row.lastSeenAtUs),
    );
  }
}

int _micros(DateTime value) => value.toUtc().microsecondsSinceEpoch;

DateTime _dateTime(int microseconds) =>
    DateTime.fromMicrosecondsSinceEpoch(microseconds, isUtc: true);
