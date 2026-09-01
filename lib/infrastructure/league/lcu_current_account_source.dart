import '../../domain/identity/league_identity.dart';
import '../../domain/league/account_context.dart';
import 'lcu_probe_transport.dart';

class LcuCurrentAccountSource implements CurrentAccountSource {
  LcuCurrentAccountSource({required this.client, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final LcuReadTransport client;
  final DateTime Function() _now;

  @override
  Future<CurrentAccountResult> loadCurrentAccount() async {
    final response = await client.getDetailed(
      '/lol-summoner/v1/current-summoner',
    );
    if (!response.isSuccess) {
      if (response.failureKind == LcuProbeFailureKind.disconnected ||
          response.failureKind == LcuProbeFailureKind.timeout) {
        return CurrentAccountResult.disconnected(response.error);
      }
      return CurrentAccountResult.noAccount(
        'Current summoner is unavailable (${response.statusCode ?? 'unknown'}).',
      );
    }
    final summoner = _stringMap(response.body);
    final puuid = summoner['puuid']?.toString().trim();
    if (puuid == null || puuid.isEmpty) {
      return const CurrentAccountResult.noAccount(
        'LCU current summoner response did not contain a PUUID.',
      );
    }

    Map<String, Object?> region = const {};
    String? clientVersion;
    try {
      region = _stringMap(await client.get('/riotclient/region-locale'));
      final version = await client.get('/lol-patch/v1/game-version');
      clientVersion = version?.toString().replaceAll('"', '').trim();
    } catch (_) {
      // Account identity remains usable when optional enrichment endpoints
      // are temporarily unavailable.
    }
    final platform =
        region['region']?.toString() ??
        region['webRegion']?.toString() ??
        summoner['region']?.toString();
    if (platform == null || platform.trim().isEmpty) {
      return const CurrentAccountResult.noAccount(
        'LCU did not expose the current platform.',
      );
    }

    final gameName = summoner['gameName']?.toString().trim();
    final tagLine = summoner['tagLine']?.toString().trim();
    final observedAt = _now().toUtc();
    return CurrentAccountResult.connected(
      LeagueAccountProfile(
        puuid: Puuid(puuid),
        platformId: PlatformId(platform),
        riotId:
            gameName != null &&
                gameName.isNotEmpty &&
                tagLine != null &&
                tagLine.isNotEmpty
            ? RiotId(gameName: gameName, tagLine: tagLine)
            : null,
        summonerId: (summoner['summonerId'] as num?)?.toInt(),
        summonerLevel: (summoner['summonerLevel'] as num?)?.toInt(),
        profileIconId: (summoner['profileIconId'] as num?)?.toInt(),
        clientVersion: clientVersion,
        patchKey: _patchKey(clientVersion),
        firstSeenAt: observedAt,
        lastSeenAt: observedAt,
      ),
    );
  }
}

PatchKey? _patchKey(String? clientVersion) {
  if (clientVersion == null) return null;
  final match = RegExp(r'^(\d+)\.(\d+)').firstMatch(clientVersion);
  if (match == null) return null;
  return PatchKey('${match.group(1)}.${match.group(2)}');
}

Map<String, Object?> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}
