/// Enum representing standard League of Legends positions.
enum ScoutRole {
  top('TOP', 'Superior'),
  jungle('JUNGLE', 'Jungla'),
  mid('MIDDLE', 'Central'),
  bottom('BOTTOM', 'Tirador'),
  support('UTILITY', 'Soporte'),
  unknown('UNKNOWN', 'Desconocido');

  const ScoutRole(this.rawLane, this.label);

  final String rawLane;
  final String label;

  static ScoutRole parse(String? lane, [String? role]) {
    final raw = '${lane ?? ''}_${role ?? ''}'.toUpperCase();
    final laneUpper = (lane ?? '').toUpperCase();
    final roleUpper = (role ?? '').toUpperCase();

    if (raw.contains('TOP') || laneUpper == 'TOP') {
      return ScoutRole.top;
    }
    if (raw.contains('JUNGLE') || laneUpper == 'JUNGLE') {
      return ScoutRole.jungle;
    }
    if (raw.contains('MID') || laneUpper == 'MIDDLE') {
      return ScoutRole.mid;
    }
    if (roleUpper.contains('SUPPORT') ||
        roleUpper.contains('UTILITY') ||
        laneUpper.contains('UTILITY')) {
      return ScoutRole.support;
    }
    if (raw.contains('BOT') ||
        raw.contains('DUO_CARRY') ||
        laneUpper == 'BOTTOM') {
      return ScoutRole.bottom;
    }
    return ScoutRole.unknown;
  }
}

/// Aggregate performance indicators with mathematically defined statistics.
class ScoutKpis {
  const ScoutKpis({
    required this.sampleSize,
    required this.wins,
    required this.losses,
    required this.recentWinRate,
    this.avgKda,
    this.avgDamage,
    this.killParticipation,
    this.avgObjectiveDamage,
    this.avgGoldPerMin,
    this.avgCsPerMin,
    this.avgVisionPerMin,
  });

  final int sampleSize;
  final int wins;
  final int losses;
  final double recentWinRate;
  final double? avgKda;
  final double? avgDamage;
  final double? killParticipation;
  final double? avgObjectiveDamage;
  final double? avgGoldPerMin;
  final double? avgCsPerMin;
  final double? avgVisionPerMin;
}

/// Statistics for a specific champion played by the scouted summoner.
class ScoutChampionStats {
  const ScoutChampionStats({
    required this.championId,
    required this.name,
    this.iconUrl,
    required this.games,
    required this.wins,
    required this.losses,
    required this.winrate,
    required this.kda,
    this.csPerMin,
    this.avgDamage,
  });

  final int championId;
  final String name;
  final String? iconUrl;
  final int games;
  final int wins;
  final int losses;
  final double winrate;
  final double kda;
  final double? csPerMin;
  final double? avgDamage;
}

/// Statistics per role/lane.
class ScoutRoleStats {
  const ScoutRoleStats({
    required this.role,
    required this.games,
    required this.percentage,
    required this.winrate,
    required this.wins,
    required this.losses,
  });

  final ScoutRole role;
  final int games;
  final double percentage;
  final double winrate;
  final int wins;
  final int losses;
}

/// Frequently encountered teammate or opponent.
class ScoutRelationshipStats {
  const ScoutRelationshipStats({
    required this.summonerName,
    required this.tagLine,
    required this.puuid,
    required this.games,
    required this.wins,
    required this.losses,
    required this.winrate,
    this.iconUrl,
  });

  final String summonerName;
  final String tagLine;
  final String puuid;
  final int games;
  final int wins;
  final int losses;
  final double winrate;
  final String? iconUrl;
}

/// Deterministic, versioned heuristic rating calculated by GodSense.
class ScoutPerformanceScore {
  const ScoutPerformanceScore({
    required this.value,
    required this.version,
    required this.breakdown,
  });

  static const currentVersion = 2;

  final int value; // 0 - 100
  final int version;
  final Map<String, double> breakdown;

  String get heuristicLabel => 'GodSense Rating (Heurístico v$version)';
}

/// A meaningful event recovered from the persisted LCU match timeline.
class ScoutTimelineEvent {
  const ScoutTimelineEvent({
    required this.timestampMilliseconds,
    required this.type,
    required this.label,
    this.isAlly,
  });

  final int timestampMilliseconds;
  final String type;
  final String label;
  final bool? isAlly;
}

/// Team gold difference at one point of the persisted match timeline.
class ScoutGoldTimelinePoint {
  const ScoutGoldTimelinePoint({
    required this.timestampMilliseconds,
    required this.difference,
  });

  final int timestampMilliseconds;
  final int difference;
}

/// A participant within a 5v5 match.
class ScoutMatchParticipant {
  const ScoutMatchParticipant({
    required this.participantId,
    required this.puuid,
    required this.name,
    required this.tag,
    required this.championId,
    required this.championName,
    this.championIconUrl,
    required this.role,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.cs,
    required this.damage,
    required this.gold,
    required this.visionScore,
    required this.items,
    this.spell1IconUrl,
    this.spell2IconUrl,
    this.primaryRuneIconUrl,
    this.secondaryRuneIconUrl,
    required this.isSubject,
    required this.isAlly,
    this.performanceScore,
  });

  final int participantId;
  final String puuid;
  final String name;
  final String tag;
  final int championId;
  final String championName;
  final String? championIconUrl;
  final ScoutRole role;
  final int kills;
  final int deaths;
  final int assists;
  final int cs;
  final int damage;
  final int gold;
  final int visionScore;
  final List<int> items;
  final String? spell1IconUrl;
  final String? spell2IconUrl;
  final String? primaryRuneIconUrl;
  final String? secondaryRuneIconUrl;
  final bool isSubject;
  final bool isAlly;
  final int? performanceScore;
}

/// Summary and optional expanded details for a single match.
class ScoutMatchSummary {
  const ScoutMatchSummary({
    required this.matchId,
    required this.queueId,
    required this.queueLabel,
    this.startedAt,
    required this.durationMinutes,
    required this.isWin,
    this.patch,
    required this.championId,
    required this.championName,
    this.championIconUrl,
    this.championLevel,
    required this.role,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.kdaRatio,
    required this.cs,
    required this.csm,
    this.damage,
    this.gold,
    this.visionScore,
    this.killParticipation,
    required this.items,
    this.spell1IconUrl,
    this.spell2IconUrl,
    this.primaryRuneIconUrl,
    this.secondaryRuneIconUrl,
    this.performanceScore,
    required this.hasFullDetails,
    this.teams = const [],
    this.participants = const [],
    this.timelineEvents = const [],
    this.goldTimeline = const [],
  });

  final int matchId;
  final int? queueId;
  final String queueLabel;
  final DateTime? startedAt;
  final double durationMinutes;
  final bool isWin;
  final String? patch;
  final int championId;
  final String championName;
  final String? championIconUrl;
  final int? championLevel;
  final ScoutRole role;
  final int kills;
  final int deaths;
  final int assists;
  final double kdaRatio;
  final int cs;
  final double csm;
  final int? damage;
  final int? gold;
  final int? visionScore;
  final double? killParticipation;
  final List<int> items;
  final String? spell1IconUrl;
  final String? spell2IconUrl;
  final String? primaryRuneIconUrl;
  final String? secondaryRuneIconUrl;
  final ScoutPerformanceScore? performanceScore;
  final bool hasFullDetails;
  final List<Map<String, dynamic>> teams;
  final List<ScoutMatchParticipant> participants;
  final List<ScoutTimelineEvent> timelineEvents;
  final List<ScoutGoldTimelinePoint> goldTimeline;
}

/// The complete analytics payload computed for a scouted summoner.
class ScoutProfileAnalytics {
  const ScoutProfileAnalytics({
    required this.gamesCount,
    required this.winsCount,
    required this.lossesCount,
    required this.recentForm,
    required this.kpis,
    required this.topChampions,
    required this.roleDistribution,
    required this.recentTeammates,
    required this.recentOpponents,
    required this.badges,
    required this.gpi,
  });

  final int gamesCount;
  final int winsCount;
  final int lossesCount;
  final List<bool> recentForm;
  final ScoutKpis kpis;
  final List<ScoutChampionStats> topChampions;
  final List<ScoutRoleStats> roleDistribution;
  final List<ScoutRelationshipStats> recentTeammates;
  final List<ScoutRelationshipStats> recentOpponents;
  final List<Map<String, dynamic>> badges;
  final List<Map<String, dynamic>> gpi;

  // Compatibility projections for map-based consumers during typed migration.
  int get games => gamesCount;
  int get wins => winsCount;
  List<Map<String, dynamic>> get signatureChampions => topChampions
      .map(
        (champ) => {
          'champion_id': champ.championId,
          'name': champ.name,
          'icon_url': champ.iconUrl,
          'games': champ.games,
          'wins': champ.wins,
          'winrate': champ.winrate,
          'kda': champ.kda,
        },
      )
      .toList();
}
