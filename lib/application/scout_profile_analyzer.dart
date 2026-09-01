import 'dart:convert';

import '../domain/identity/league_identity.dart';
import '../domain/league/local_scout.dart';

class ScoutProfileAnalytics {
  const ScoutProfileAnalytics({
    required this.games,
    required this.wins,
    required this.gpi,
    required this.badges,
    required this.signatureChampions,
  });

  final int games;
  final int wins;
  final List<Map<String, dynamic>> gpi;
  final List<Map<String, dynamic>> badges;
  final List<Map<String, dynamic>> signatureChampions;
}

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
        games: 0,
        wins: 0,
        gpi: [],
        badges: [],
        signatureChampions: [],
      );
    }

    final games = samples.length;
    final wins = samples.where((sample) => sample.won).length;
    final totalMinutes = samples.fold<double>(
      0,
      (total, sample) => total + sample.minutes,
    );
    final kills = _sum(samples, (sample) => sample.kills);
    final deaths = _sum(samples, (sample) => sample.deaths);
    final assists = _sum(samples, (sample) => sample.assists);
    final cs = _sum(samples, (sample) => sample.cs);
    final vision = _sum(samples, (sample) => sample.visionScore);
    final objectiveDamage = _sum(samples, (sample) => sample.objectiveDamage);
    final championGroups = <int, List<_ScoutSample>>{};
    for (final sample in samples) {
      championGroups.putIfAbsent(sample.championId, () => []).add(sample);
    }
    final signatures =
        championGroups.entries.map((entry) {
          final championSamples = entry.value;
          final championWins = championSamples
              .where((sample) => sample.won)
              .length;
          final championKills = _sum(championSamples, (sample) => sample.kills);
          final championDeaths = _sum(
            championSamples,
            (sample) => sample.deaths,
          );
          final championAssists = _sum(
            championSamples,
            (sample) => sample.assists,
          );
          return {
            'champion_id': entry.key,
            'name': championNames[entry.key] ?? '${entry.key}',
            'icon_url': _championIcon(entry.key),
            'games': championSamples.length,
            'wins': championWins,
            'winrate': _ratio(championWins * 100, championSamples.length),
            'kda': _ratio(championKills + championAssists, championDeaths),
          };
        }).toList()..sort((left, right) {
          final gamesOrder = (right['games'] as int).compareTo(
            left['games'] as int,
          );
          return gamesOrder != 0
              ? gamesOrder
              : (right['wins'] as int).compareTo(left['wins'] as int);
        });

    final csm = totalMinutes <= 0 ? 0.0 : cs / totalMinutes;
    final kda = _ratio(kills + assists, deaths);
    final winrate = _ratio(wins * 100, games);
    final badges = <Map<String, dynamic>>[];
    final main = signatures.first;
    if ((main['games'] as int) >= 3 && (main['games'] as int) / games >= 0.4) {
      badges.add({
        'name': 'Especialista en ${main['name']}',
        'description':
            '${main['games']} de $games partidas recientes con el mismo campeón.',
      });
    }
    if (games >= 5 && winrate >= 60) {
      badges.add({
        'name': 'Racha positiva',
        'description': '$winrate% de victorias en $games partidas.',
      });
    }
    if (games >= 3 && csm >= 7) {
      badges.add({
        'name': 'Farmeador constante',
        'description': '${_oneDecimal(csm)} CS por minuto.',
      });
    }
    if (games >= 5 && championGroups.length >= 4) {
      badges.add({
        'name': 'Versátil',
        'description': '${championGroups.length} campeones en $games partidas.',
      });
    }

    return ScoutProfileAnalytics(
      games: games,
      wins: wins,
      gpi: [
        _metric('KDA', _oneDecimal(kda), 'ratio'),
        _metric('CS/min', _oneDecimal(csm), 'por minuto'),
        _metric('Visión', _oneDecimal(vision / games), 'por partida'),
        _metric(
          'Participación',
          _oneDecimal((kills + assists) / games),
          'K+A por partida',
        ),
        _metric(
          'Supervivencia',
          _oneDecimal(deaths / games),
          'muertes por partida',
        ),
        _metric(
          'Objetivos',
          _oneDecimal(objectiveDamage / games),
          'daño por partida',
        ),
        _metric('Victorias', winrate, 'porcentaje'),
        _metric('Versatilidad', championGroups.length, 'campeones'),
      ],
      badges: badges,
      signatureChampions: signatures.take(3).toList(growable: false),
    );
  }
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
  final championId = (participant['championId'] as num?)?.toInt();
  if (championId == null || championId <= 0) return null;
  final seconds = (summary['gameDuration'] as num?)?.toDouble() ?? 0;
  return _ScoutSample(
    championId: championId,
    championName: championNames[championId] ?? '$championId',
    won: stats['win'] == true || participant['win'] == true,
    minutes: seconds <= 0 ? 0 : seconds / 60,
    kills: (stats['kills'] as num?)?.toInt() ?? 0,
    deaths: (stats['deaths'] as num?)?.toInt() ?? 0,
    assists: (stats['assists'] as num?)?.toInt() ?? 0,
    cs:
        ((stats['totalMinionsKilled'] as num?)?.toInt() ?? 0) +
        ((stats['neutralMinionsKilled'] as num?)?.toInt() ?? 0),
    visionScore: (stats['visionScore'] as num?)?.toInt() ?? 0,
    objectiveDamage: (stats['damageDealtToObjectives'] as num?)?.toInt() ?? 0,
  );
}

class _ScoutSample {
  const _ScoutSample({
    required this.championId,
    required this.championName,
    required this.won,
    required this.minutes,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.cs,
    required this.visionScore,
    required this.objectiveDamage,
  });

  final int championId;
  final String championName;
  final bool won;
  final double minutes;
  final int kills;
  final int deaths;
  final int assists;
  final int cs;
  final int visionScore;
  final int objectiveDamage;
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
