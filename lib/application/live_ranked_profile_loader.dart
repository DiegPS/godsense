import 'dart:convert';

import '../domain/identity/league_identity.dart';
import '../domain/league/account_context.dart';
import '../domain/league/local_scout.dart';

class LiveRankedProfileLoader {
  const LiveRankedProfileLoader({
    required this.resolve,
    required this.loadRanked,
  });

  final Future<LeagueAccountProfile> Function({
    required String gameName,
    required String tagLine,
  })
  resolve;
  final Future<LocalRankedSnapshot?> Function(Puuid puuid) loadRanked;

  Future<Map<String, Map<String, dynamic>>> load(
    Iterable<Map<String, dynamic>> players,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    for (final player in players) {
      final identity = livePlayerRiotId(player);
      if (identity == null) continue;
      final key = identity.displayName.toLowerCase();
      if (result.containsKey(key)) continue;
      try {
        final account = await resolve(
          gameName: identity.gameName,
          tagLine: identity.tagLine,
        );
        final ranked = await loadRanked(account.puuid);
        result[key] = _rankedProfile(ranked);
      } catch (_) {
        result[key] = const {'status': 'unavailable'};
      }
    }
    return result;
  }
}

RiotId? livePlayerRiotId(Map<String, dynamic> player) {
  var name = player['riotIdGameName']?.toString().trim() ?? '';
  var tag = player['riotIdTagLine']?.toString().trim() ?? '';
  final full =
      player['riotId']?.toString() ?? player['summonerName']?.toString() ?? '';
  final separator = full.lastIndexOf('#');
  if (separator > 0) {
    if (name.isEmpty) name = full.substring(0, separator).trim();
    if (tag.isEmpty) tag = full.substring(separator + 1).trim();
  }
  if (name.isEmpty || tag.isEmpty) return null;
  return RiotId(gameName: name, tagLine: tag);
}

Map<String, dynamic> _rankedProfile(LocalRankedSnapshot? snapshot) {
  if (snapshot == null) return const {'status': 'unavailable'};
  final decoded = jsonDecode(snapshot.payloadJson);
  if (decoded is! Map) return const {'status': 'unavailable'};
  final queues = decoded['queueMap'];
  final solo = queues is Map
      ? queues['RANKED_SOLO_5x5'] ?? queues['RANKED_SOLO_5X5']
      : decoded['tier'] == null
      ? null
      : decoded;
  if (queues is! Map && solo == null) {
    return const {'status': 'unavailable'};
  }
  final values = solo is Map ? solo : const {};
  return {
    'status': 'available',
    'tier': values['tier'] ?? 'UNRANKED',
    'division': values['division'] ?? values['rank'] ?? '',
    'lp': values['leaguePoints'] ?? 0,
    'wins': values['wins'] ?? 0,
    'losses': values['losses'] ?? 0,
    'source': 'lcu',
    'observed_at': snapshot.observedAt.toUtc().toIso8601String(),
  };
}
