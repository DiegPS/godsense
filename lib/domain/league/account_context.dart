import '../identity/league_identity.dart';

class RiotId {
  const RiotId({required this.gameName, required this.tagLine});

  final String gameName;
  final String tagLine;

  String get displayName => '$gameName#$tagLine';
}

class LeagueAccountProfile {
  const LeagueAccountProfile({
    required this.puuid,
    required this.platformId,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.riotId,
    this.summonerId,
    this.summonerLevel,
    this.profileIconId,
    this.clientVersion,
    this.patchKey,
  });

  final Puuid puuid;
  final PlatformId platformId;
  final RiotId? riotId;
  final int? summonerId;
  final int? summonerLevel;
  final int? profileIconId;
  final String? clientVersion;
  final PatchKey? patchKey;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;

  LeagueAccountProfile copyWith({
    PlatformId? platformId,
    RiotId? riotId,
    int? summonerId,
    int? summonerLevel,
    int? profileIconId,
    String? clientVersion,
    PatchKey? patchKey,
    DateTime? lastSeenAt,
  }) {
    return LeagueAccountProfile(
      puuid: puuid,
      platformId: platformId ?? this.platformId,
      riotId: riotId ?? this.riotId,
      summonerId: summonerId ?? this.summonerId,
      summonerLevel: summonerLevel ?? this.summonerLevel,
      profileIconId: profileIconId ?? this.profileIconId,
      clientVersion: clientVersion ?? this.clientVersion,
      patchKey: patchKey ?? this.patchKey,
      firstSeenAt: firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

class AccountContext {
  const AccountContext({
    required this.account,
    required this.accountGeneration,
    required this.syncRevision,
    required this.activatedAt,
  });

  final LeagueAccountProfile account;
  final int accountGeneration;
  final int syncRevision;
  final DateTime activatedAt;
}

enum AccountSourceConnection { connected, disconnected }

class CurrentAccountResult {
  const CurrentAccountResult.connected(this.account)
    : connection = AccountSourceConnection.connected,
      error = null;

  const CurrentAccountResult.noAccount([this.error])
    : connection = AccountSourceConnection.connected,
      account = null;

  const CurrentAccountResult.disconnected([this.error])
    : connection = AccountSourceConnection.disconnected,
      account = null;

  final AccountSourceConnection connection;
  final LeagueAccountProfile? account;
  final String? error;
}

abstract interface class CurrentAccountSource {
  Future<CurrentAccountResult> loadCurrentAccount();
}

abstract interface class AccountContextRepository {
  Future<AccountContext?> loadActive();

  Future<bool> activate(AccountContext context);

  Future<List<LeagueAccountProfile>> loadAllAccounts();
}
