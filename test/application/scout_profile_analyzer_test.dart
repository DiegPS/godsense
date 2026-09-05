import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/scout_profile_analyzer.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/local_scout.dart';

void main() {
  const analyzer = ScoutProfileAnalyzer();
  final puuid = Puuid('player');

  test('team ratios require all teammates and DPM uses match duration', () {
    final record = _match(100, championId: 22, won: true, kills: 5, deaths: 2);
    final incomplete = analyzer.analyze(
      [record],
      puuid: puuid,
      championNames: {},
    );
    expect(incomplete.kpis.damageShare, isNull);
    expect(incomplete.kpis.goldShare, isNull);
    expect(incomplete.kpis.damageEfficiency, isNull);
    expect(incomplete.kpis.damagePerMinute, closeTo(22000 / 30, .01));
    final summary = jsonDecode(record.summaryJson) as Map<String, dynamic>;
    (summary['participants'] as List).addAll(
      List.generate(
        4,
        (i) => {
          'participantId': i + 2,
          'teamId': 100,
          'championId': i + 1,
          'stats': {'totalDamageDealtToChampions': 5500, 'goldEarned': 12500},
        },
      ),
    );
    final complete = analyzer.analyze(
      [
        LocalMatchRecord(
          match: record.match,
          puuid: puuid,
          summaryJson: jsonEncode(summary),
          syncedAt: record.syncedAt,
        ),
      ],
      puuid: puuid,
      championNames: {},
    );
    expect(complete.kpis.damageShare, closeTo(50, .001));
    expect(complete.kpis.goldShare, closeTo(20, .001));
    expect(complete.kpis.damageEfficiency, closeTo(2.5, .001));
  });

  test('computes factual playstyle metrics and signature champions', () {
    final result = analyzer.analyze(
      [
        _match(1, championId: 22, won: true, kills: 8, deaths: 2, role: 'TOP'),
        _match(2, championId: 22, won: true, kills: 6, deaths: 3, role: 'TOP'),
        _match(3, championId: 22, won: false, kills: 4, deaths: 4, role: 'TOP'),
        _match(
          4,
          championId: 103,
          won: true,
          kills: 7,
          deaths: 2,
          role: 'MIDDLE',
        ),
        _match(
          5,
          championId: 103,
          won: true,
          kills: 5,
          deaths: 1,
          role: 'MIDDLE',
        ),
      ],
      puuid: puuid,
      championNames: const {22: 'Ashe', 103: 'Ahri'},
    );

    expect(result.gamesCount, 5);
    expect(result.winsCount, 4);
    expect(result.recentForm, [true, true, false, true, true]);
    expect(result.kpis.recentWinRate, 80.0);
    expect(result.topChampions.first.name, 'Ashe');
    expect(result.topChampions.first.games, 3);
    expect(
      result.badges.map((badge) => badge['name']),
      containsAll(['Especialista en Ashe', 'Racha positiva']),
    );
  });

  test('calculates exact aggregated KDA and handles zero deaths without division error', () {
    final result = analyzer.analyze(
      [
        _match(1, championId: 22, won: true, kills: 5, deaths: 0),
        _match(2, championId: 22, won: true, kills: 5, deaths: 0),
      ],
      puuid: puuid,
      championNames: const {22: 'Ashe'},
    );

    // 10 kills + 12 assists / max(1, 0 deaths) = 22.0
    expect(result.kpis.avgKda, 22.0);
  });

  test('calculates deterministic performance score for roles', () {
    final topScore = ScoutProfileAnalyzer.calculatePerformanceScore(
      role: ScoutRole.top,
      kills: 8,
      deaths: 2,
      assists: 6,
      cs: 240,
      durationMinutes: 30.0,
      damage: 28000,
      teamKills: 25,
      visionScore: 30,
      objectiveDamage: 12000,
    );

    expect(topScore.version, 2);
    expect(topScore.value, greaterThanOrEqualTo(50));
    expect(topScore.value, lessThanOrEqualTo(100));
    expect(topScore.breakdown, containsPair('Objetivos', 20.0));
  });

  test(
    'normalizes the same performance according to role responsibilities',
    () {
      final topScore = ScoutProfileAnalyzer.calculatePerformanceScore(
        role: ScoutRole.top,
        kills: 2,
        deaths: 5,
        assists: 15,
        cs: 45,
        durationMinutes: 30,
        damage: 10000,
        teamKills: 25,
        visionScore: 45,
        objectiveDamage: 2500,
      );
      final supportScore = ScoutProfileAnalyzer.calculatePerformanceScore(
        role: ScoutRole.support,
        kills: 2,
        deaths: 5,
        assists: 15,
        cs: 45,
        durationMinutes: 30,
        damage: 10000,
        teamKills: 25,
        visionScore: 45,
        objectiveDamage: 2500,
      );

      expect(supportScore.value, greaterThan(topScore.value));
      expect(supportScore.breakdown, isNot(contains('Farm')));
      expect(supportScore.breakdown, containsPair('Visión', 30.0));
    },
  );

  test('does not award farming badge to a support from global CS', () {
    final result = analyzer.analyze(
      [
        _match(
          1,
          championId: 40,
          won: true,
          kills: 1,
          deaths: 2,
          role: 'UTILITY',
          cs: 240,
        ),
      ],
      puuid: puuid,
      championNames: const {40: 'Janna'},
    );

    expect(
      result.badges.map((badge) => badge['name']),
      isNot(contains('Farmeador constante')),
    );
  });

  test('returns no invented analytics without match evidence', () {
    final result = analyzer.analyze(
      const [],
      puuid: puuid,
      championNames: const {},
    );

    expect(result.gamesCount, 0);
    expect(result.recentForm, isEmpty);
    expect(result.topChampions, isEmpty);
    expect(result.roleDistribution, isEmpty);
    expect(result.recentTeammates, isEmpty);
    expect(result.recentOpponents, isEmpty);
    expect(result.gpi, isEmpty);
    expect(result.badges, isEmpty);
  });
}

LocalMatchRecord _match(
  int id, {
  required int championId,
  required bool won,
  required int kills,
  required int deaths,
  String role = 'BOTTOM',
  int cs = 210,
}) => LocalMatchRecord(
  match: MatchKey(platformId: PlatformId('LA1'), gameId: id),
  puuid: Puuid('player'),
  summaryJson:
      '''{"gameDuration":1800,"participants":[{"participantId":1,"championId":$championId,"teamId":100,"timeline":{"lane":"$role"},"stats":{"win":$won,"kills":$kills,"deaths":$deaths,"assists":6,"totalMinionsKilled":$cs,"neutralMinionsKilled":0,"visionScore":24,"damageDealtToObjectives":5000,"totalDamageDealtToChampions":22000,"goldEarned":12500}}],"participantIdentities":[{"participantId":1,"player":{"puuid":"player","gameName":"Player","tagLine":"LAN"}}]}''',
  syncedAt: DateTime.utc(2026),
);
