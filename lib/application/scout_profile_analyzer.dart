import 'dart:convert';

import '../domain/identity/league_identity.dart';
import '../domain/league/local_scout.dart';
import '../domain/league/scout_models.dart';

export '../domain/league/scout_models.dart';

class ScoutProfileAnalyzer {
  const ScoutProfileAnalyzer();

  ScoutProfileAnalytics analyze(
    List<LocalMatchRecord> records, {
    required Puuid puuid,
    required Map<int, String> championNames,
  }) {
    final samples = records
        .map((record) => _sample(record, puuid, championNames))
        .whereType<_ScoutSample>()
        .toList(growable: false);

    if (samples.isEmpty) {
      return const ScoutProfileAnalytics(
        gamesCount: 0,
        winsCount: 0,
        lossesCount: 0,
        recentForm: [],
        kpis: ScoutKpis(sampleSize: 0, wins: 0, losses: 0, recentWinRate: 0.0),
        topChampions: [],
        roleDistribution: [],
        recentTeammates: [],
        recentOpponents: [],
        badges: [],
        gpi: [],
      );
    }

    final games = samples.length;
    final wins = samples.where((sample) => sample.won).length;
    final losses = games - wins;
    final winrate = _ratio(wins * 100, games);

    // Durations and aggregate sums
    final validDurationSamples = samples.where((s) => s.minutes > 0).toList();
    final totalMinutes = validDurationSamples.fold<double>(
      0.0,
      (sum, s) => sum + s.minutes,
    );

    final totalKills = _sum(samples, (s) => s.kills);
    final totalDeaths = _sum(samples, (s) => s.deaths);
    final totalAssists = _sum(samples, (s) => s.assists);
    final totalCs = _sum(samples, (s) => s.cs);
    final totalVision = _sum(samples, (s) => s.visionScore);
    final totalObjectiveDmg = _sum(samples, (s) => s.objectiveDamage);
    final totalChampionDmg = _sum(
      samples,
      (s) => s.totalDamageDealtToChampions,
    );
    final totalGold = _sum(samples, (s) => s.goldEarned);

    // 1. Mathematically Defined KPIs
    final avgKda = totalDeaths == 0
        ? (totalKills + totalAssists).toDouble()
        : _ratio(totalKills + totalAssists, totalDeaths).toDouble();
    final avgDamage = samples.isEmpty
        ? null
        : _oneDecimal(totalChampionDmg / games);
    final avgObjectiveDamage = samples.isEmpty
        ? null
        : _oneDecimal(totalObjectiveDmg / games);
    final avgGoldPerMin = totalMinutes <= 0
        ? null
        : _oneDecimal(totalGold / totalMinutes);
    final avgCsPerMin = totalMinutes <= 0
        ? null
        : _oneDecimal(totalCs / totalMinutes);
    final avgVisionPerMin = totalMinutes <= 0
        ? null
        : _oneDecimal(totalVision / totalMinutes);

    // Kill Participation Average across matches where team kills > 0
    final kpSamples = samples.where((s) => s.teamKills > 0).toList();
    final killParticipation = kpSamples.isEmpty
        ? null
        : _oneDecimal(
            kpSamples.fold<double>(
                  0.0,
                  (acc, s) => acc + ((s.kills + s.assists) / s.teamKills * 100),
                ) /
                kpSamples.length,
          );

    final kpis = ScoutKpis(
      sampleSize: games,
      wins: wins,
      losses: losses,
      recentWinRate: winrate.toDouble(),
      avgKda: avgKda,
      avgDamage: avgDamage?.toDouble(),
      killParticipation: killParticipation?.toDouble(),
      avgObjectiveDamage: avgObjectiveDamage?.toDouble(),
      avgGoldPerMin: avgGoldPerMin?.toDouble(),
      avgCsPerMin: avgCsPerMin?.toDouble(),
      avgVisionPerMin: avgVisionPerMin?.toDouble(),
    );

    // 2. Recent Form (up to 10 most recent)
    final recentForm = samples.take(10).map((s) => s.won).toList();

    // 3. Champion Statistics & Signatures
    final championGroups = <int, List<_ScoutSample>>{};
    for (final sample in samples) {
      championGroups.putIfAbsent(sample.championId, () => []).add(sample);
    }

    final championStatsList =
        championGroups.entries.map((entry) {
          final cSamples = entry.value;
          final cWins = cSamples.where((s) => s.won).length;
          final cLosses = cSamples.length - cWins;
          final cKills = _sum(cSamples, (s) => s.kills);
          final cDeaths = _sum(cSamples, (s) => s.deaths);
          final cAssists = _sum(cSamples, (s) => s.assists);
          final cCs = _sum(cSamples, (s) => s.cs);
          final cMinutes = cSamples
              .where((s) => s.minutes > 0)
              .fold<double>(0.0, (acc, s) => acc + s.minutes);
          final cDmg = _sum(cSamples, (s) => s.totalDamageDealtToChampions);
          final cKda = cDeaths == 0
              ? (cKills + cAssists).toDouble()
              : _ratio(cKills + cAssists, cDeaths).toDouble();

          return ScoutChampionStats(
            championId: entry.key,
            name: championNames[entry.key] ?? '${entry.key}',
            iconUrl: _championIcon(entry.key),
            games: cSamples.length,
            wins: cWins,
            losses: cLosses,
            winrate: _ratio(cWins * 100, cSamples.length).toDouble(),
            kda: cKda,
            csPerMin: cMinutes > 0
                ? _oneDecimal(cCs / cMinutes).toDouble()
                : null,
            avgDamage: _oneDecimal(cDmg / cSamples.length).toDouble(),
          );
        }).toList()..sort((a, b) {
          final cmp = b.games.compareTo(a.games);
          return cmp != 0 ? cmp : b.wins.compareTo(a.wins);
        });

    // 4. Role / Lane Distribution
    final roleGroups = <ScoutRole, List<_ScoutSample>>{};
    for (final sample in samples) {
      if (sample.role != ScoutRole.unknown) {
        roleGroups.putIfAbsent(sample.role, () => []).add(sample);
      }
    }

    final roleDistribution = roleGroups.entries.map((entry) {
      final rSamples = entry.value;
      final rWins = rSamples.where((s) => s.won).length;
      return ScoutRoleStats(
        role: entry.key,
        games: rSamples.length,
        percentage: _ratio(rSamples.length * 100, games).toDouble(),
        winrate: _ratio(rWins * 100, rSamples.length).toDouble(),
        wins: rWins,
        losses: rSamples.length - rWins,
      );
    }).toList()..sort((a, b) => b.games.compareTo(a.games));

    // 5. Frequently Encountered Teammates and Opponents from Match Details
    final teammatesMap = <String, _RelationshipAccumulator>{};
    final opponentsMap = <String, _RelationshipAccumulator>{};

    for (final record in records) {
      final detailsJson = record.detailsJson ?? record.summaryJson;
      final details = _map(_decode(detailsJson));
      if (details.isEmpty) continue;

      final participants = _mapList(details['participants']);
      final identities = _mapList(details['participantIdentities']);

      // Find subject's team and identity
      int? subjectParticipantId;
      int? subjectTeamId;
      bool? subjectWin;

      for (final idObj in identities) {
        final player = _map(idObj['player']);
        if (player['puuid']?.toString() == puuid.value) {
          subjectParticipantId = (idObj['participantId'] as num?)?.toInt();
          break;
        }
      }

      if (subjectParticipantId != null) {
        for (final p in participants) {
          if ((p['participantId'] as num?)?.toInt() == subjectParticipantId) {
            subjectTeamId = (p['teamId'] as num?)?.toInt();
            final stats = _map(p['stats']);
            subjectWin = stats['win'] == true || p['win'] == true;
            break;
          }
        }
      }

      if (subjectTeamId == null) continue;

      for (final p in participants) {
        final pId = (p['participantId'] as num?)?.toInt();
        if (pId == subjectParticipantId) continue;

        final idObj = identities
            .where((item) => (item['participantId'] as num?)?.toInt() == pId)
            .firstOrNull;
        if (idObj == null) continue;

        final player = _map(idObj['player']);
        final pPuuid = player['puuid']?.toString() ?? '';
        final pName =
            player['gameName']?.toString() ??
            player['summonerName']?.toString() ??
            '';
        final pTag = player['tagLine']?.toString() ?? '';
        final pIconId = (player['profileIcon'] as num?)?.toInt();

        if (pName.isEmpty) continue;

        final pTeamId = (p['teamId'] as num?)?.toInt();
        final isAlly = pTeamId == subjectTeamId;
        final targetMap = isAlly ? teammatesMap : opponentsMap;

        final acc = targetMap.putIfAbsent(
          pPuuid.isNotEmpty ? pPuuid : pName,
          () => _RelationshipAccumulator(
            puuid: pPuuid,
            summonerName: pName,
            tagLine: pTag,
            iconUrl: pIconId != null ? _profileIcon(pIconId) : null,
          ),
        );

        acc.games++;
        if (subjectWin == true) {
          acc.wins++;
        } else if (subjectWin == false) {
          acc.losses++;
        }
      }
    }

    final recentTeammates =
        teammatesMap.values
            .where((acc) => acc.games >= 1)
            .map((acc) => acc.toStats())
            .toList()
          ..sort(
            (a, b) => b.games != a.games
                ? b.games.compareTo(a.games)
                : b.winrate.compareTo(a.winrate),
          );

    final recentOpponents =
        opponentsMap.values
            .where((acc) => acc.games >= 1)
            .map((acc) => acc.toStats())
            .toList()
          ..sort(
            (a, b) => b.games != a.games
                ? b.games.compareTo(a.games)
                : b.winrate.compareTo(a.winrate),
          );

    // 6. Badges
    final badges = <Map<String, dynamic>>[];
    if (championStatsList.isNotEmpty) {
      final main = championStatsList.first;
      if (main.games >= 3 && main.games / games >= 0.4) {
        badges.add({
          'name': 'Especialista en ${main.name}',
          'description':
              '${main.games} de $games partidas recientes con el mismo campeón.',
        });
      }
    }
    if (games >= 5 && winrate >= 60) {
      badges.add({
        'name': 'Racha positiva',
        'description': '$winrate% de victorias en $games partidas.',
      });
    }
    if (avgCsPerMin != null && avgCsPerMin >= 7) {
      badges.add({
        'name': 'Farmeador constante',
        'description': '$avgCsPerMin CS por minuto.',
      });
    }
    if (games >= 5 && championGroups.length >= 4) {
      badges.add({
        'name': 'Versátil',
        'description': '${championGroups.length} campeones en $games partidas.',
      });
    }

    // 7. General Performance Index (GPI)
    final gpi = [
      _metric('KDA', avgKda, 'ratio'),
      _metric('CS/min', avgCsPerMin ?? 0.0, 'por minuto'),
      _metric('Visión', avgVisionPerMin ?? 0.0, 'por minuto'),
      _metric('Participación', killParticipation ?? 0.0, '%'),
      _metric('Victorias', winrate, '%'),
      _metric('Versatilidad', championGroups.length, 'campeones'),
      _metric('Daño medio', avgDamage ?? 0.0, 'por partida'),
      _metric('Objetivos', avgObjectiveDamage ?? 0.0, 'daño'),
    ];

    return ScoutProfileAnalytics(
      gamesCount: games,
      winsCount: wins,
      lossesCount: losses,
      recentForm: recentForm,
      kpis: kpis,
      topChampions: championStatsList.take(5).toList(growable: false),
      roleDistribution: roleDistribution,
      recentTeammates: recentTeammates.take(5).toList(growable: false),
      recentOpponents: recentOpponents.take(5).toList(growable: false),
      badges: badges,
      gpi: gpi,
    );
  }

  /// Calculates a deterministic, explainable performance rating between 0 and 100.
  static ScoutPerformanceScore calculatePerformanceScore({
    required ScoutRole role,
    required int kills,
    required int deaths,
    required int assists,
    required int cs,
    required double durationMinutes,
    required int damage,
    required int teamKills,
    required int visionScore,
    required int objectiveDamage,
  }) {
    final kda = (kills + assists) / (deaths <= 0 ? 1 : deaths);
    final csm = durationMinutes <= 0 ? 0.0 : cs / durationMinutes;
    final dpm = durationMinutes <= 0 ? 0.0 : damage / durationMinutes;
    final vpm = durationMinutes <= 0 ? 0.0 : visionScore / durationMinutes;
    final kp = teamKills <= 0 ? 50.0 : ((kills + assists) / teamKills * 100);

    // Component ratings normalized to 0-100 based on role benchmarks
    final kdaScore = (kda / 4.0 * 100).clamp(0.0, 100.0);
    final csmScore = (csm / 9.0 * 100).clamp(0.0, 100.0);
    final dpmScore = (dpm / 800.0 * 100).clamp(0.0, 100.0);
    final kpScore = (kp / 65.0 * 100).clamp(0.0, 100.0);
    final visScore = (vpm / 1.5 * 100).clamp(0.0, 100.0);

    double totalScore;
    Map<String, double> breakdown;

    switch (role) {
      case ScoutRole.top:
      case ScoutRole.mid:
        totalScore =
            dpmScore * 0.30 +
            csmScore * 0.25 +
            kdaScore * 0.20 +
            kpScore * 0.15 +
            visScore * 0.10;
        breakdown = {
          'Daño': 30.0,
          'Farm': 25.0,
          'KDA': 20.0,
          'KP': 15.0,
          'Visión': 10.0,
        };
        break;
      case ScoutRole.jungle:
        final objScore =
            (durationMinutes <= 0
                    ? 0.0
                    : (objectiveDamage / durationMinutes) / 500.0 * 100)
                .clamp(0.0, 100.0);
        totalScore =
            kpScore * 0.25 +
            objScore * 0.25 +
            kdaScore * 0.20 +
            visScore * 0.15 +
            csmScore * 0.15;
        breakdown = {
          'KP': 25.0,
          'Objetivos': 25.0,
          'KDA': 20.0,
          'Visión': 15.0,
          'Farm': 15.0,
        };
        break;
      case ScoutRole.bottom:
        totalScore =
            dpmScore * 0.35 +
            csmScore * 0.30 +
            kdaScore * 0.20 +
            kpScore * 0.15;
        breakdown = {'Daño': 35.0, 'Farm': 30.0, 'KDA': 20.0, 'KP': 15.0};
        break;
      case ScoutRole.support:
        totalScore =
            kpScore * 0.30 +
            visScore * 0.30 +
            kdaScore * 0.25 +
            dpmScore * 0.15;
        breakdown = {'KP': 30.0, 'Visión': 30.0, 'KDA': 25.0, 'Daño': 15.0};
        break;
      case ScoutRole.unknown:
        totalScore =
            dpmScore * 0.25 +
            csmScore * 0.25 +
            kdaScore * 0.25 +
            kpScore * 0.25;
        breakdown = {'Daño': 25.0, 'Farm': 25.0, 'KDA': 25.0, 'KP': 25.0};
        break;
    }

    return ScoutPerformanceScore(
      value: totalScore.round().clamp(10, 100),
      version: ScoutPerformanceScore.currentVersion,
      breakdown: breakdown,
    );
  }
}

class _RelationshipAccumulator {
  _RelationshipAccumulator({
    required this.puuid,
    required this.summonerName,
    required this.tagLine,
    this.iconUrl,
  });

  final String puuid;
  final String summonerName;
  final String tagLine;
  final String? iconUrl;
  int games = 0;
  int wins = 0;
  int losses = 0;

  ScoutRelationshipStats toStats() => ScoutRelationshipStats(
    summonerName: summonerName,
    tagLine: tagLine,
    puuid: puuid,
    games: games,
    wins: wins,
    losses: losses,
    winrate: games == 0 ? 0.0 : ((wins * 100 / games) * 10).round() / 10,
    iconUrl: iconUrl,
  );
}

class _ScoutSample {
  const _ScoutSample({
    required this.championId,
    required this.championName,
    required this.role,
    required this.won,
    required this.minutes,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.cs,
    required this.goldEarned,
    required this.totalDamageDealtToChampions,
    required this.visionScore,
    required this.objectiveDamage,
    required this.teamKills,
  });

  final int championId;
  final String championName;
  final ScoutRole role;
  final bool won;
  final double minutes;
  final int kills;
  final int deaths;
  final int assists;
  final int cs;
  final int goldEarned;
  final int totalDamageDealtToChampions;
  final int visionScore;
  final int objectiveDamage;
  final int teamKills;
}

_ScoutSample? _sample(
  LocalMatchRecord record,
  Puuid puuid,
  Map<int, String> championNames,
) {
  final summary = _map(_decode(record.summaryJson));
  final participant = _subjectParticipant(summary, puuid);
  if (participant.isEmpty) return null;

  final stats = _map(participant['stats']);
  final timeline = _map(participant['timeline']);
  final championId = (participant['championId'] as num?)?.toInt();
  if (championId == null || championId <= 0) return null;

  final seconds = (summary['gameDuration'] as num?)?.toDouble() ?? 0;

  // Compute team kills from participants if available
  final teamId = (participant['teamId'] as num?)?.toInt();
  final allParticipants = _mapList(summary['participants']);
  int teamKills = 0;
  if (teamId != null) {
    for (final p in allParticipants) {
      if ((p['teamId'] as num?)?.toInt() == teamId) {
        final pStats = _map(p['stats']);
        teamKills += (pStats['kills'] as num?)?.toInt() ?? 0;
      }
    }
  }

  return _ScoutSample(
    championId: championId,
    championName: championNames[championId] ?? '$championId',
    role: ScoutRole.parse(
      timeline['lane']?.toString(),
      timeline['role']?.toString() ?? participant['role']?.toString(),
    ),
    won: stats['win'] == true || participant['win'] == true,
    minutes: seconds <= 0 ? 0 : seconds / 60,
    kills: (stats['kills'] as num?)?.toInt() ?? 0,
    deaths: (stats['deaths'] as num?)?.toInt() ?? 0,
    assists: (stats['assists'] as num?)?.toInt() ?? 0,
    cs:
        ((stats['totalMinionsKilled'] as num?)?.toInt() ?? 0) +
        ((stats['neutralMinionsKilled'] as num?)?.toInt() ?? 0),
    goldEarned: (stats['goldEarned'] as num?)?.toInt() ?? 0,
    totalDamageDealtToChampions:
        (stats['totalDamageDealtToChampions'] as num?)?.toInt() ?? 0,
    visionScore: (stats['visionScore'] as num?)?.toInt() ?? 0,
    objectiveDamage: (stats['damageDealtToObjectives'] as num?)?.toInt() ?? 0,
    teamKills: teamKills,
  );
}

Map<String, dynamic> _metric(String category, num value, String unit) => {
  'category': category,
  'value': value,
  'unit': unit,
};

num _sum(List<_ScoutSample> values, int Function(_ScoutSample) select) =>
    values.fold<int>(0, (total, value) => total + select(value));

num _ratio(num numerator, num denominator) =>
    denominator == 0 ? 0 : _oneDecimal(numerator / denominator);

num _oneDecimal(num value) => (value * 10).round() / 10;

String _championIcon(int championId) =>
    'https://raw.communitydragon.org/latest/plugins/'
    'rcp-be-lol-game-data/global/default/v1/champion-icons/$championId.png';

String _profileIcon(int iconId) =>
    'https://raw.communitydragon.org/latest/plugins/'
    'rcp-be-lol-game-data/global/default/v1/profile-icons/$iconId.jpg';

Object? _decode(String value) {
  try {
    return jsonDecode(value);
  } on FormatException {
    return null;
  }
}

Map<String, dynamic> _subjectParticipant(
  Map<String, dynamic> payload,
  Puuid puuid,
) {
  final participants = _mapList(payload['participants']);
  final identity = _mapList(payload['participantIdentities'])
      .where((item) => _map(item['player'])['puuid']?.toString() == puuid.value)
      .firstOrNull;
  if (identity == null) {
    return participants
            .where((item) => item['puuid']?.toString() == puuid.value)
            .firstOrNull ??
        const {};
  }
  final participantId = (identity['participantId'] as num?)?.toInt();
  final participant = participants
      .where(
        (item) => (item['participantId'] as num?)?.toInt() == participantId,
      )
      .firstOrNull;
  return {...?participant, ..._map(identity['player'])};
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : const {};

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false)
    : const [];
