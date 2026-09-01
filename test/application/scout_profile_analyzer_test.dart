import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/scout_profile_analyzer.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/local_scout.dart';

void main() {
  const analyzer = ScoutProfileAnalyzer();
  final puuid = Puuid('player');

  test('computes factual playstyle metrics and signature champions', () {
    final result = analyzer.analyze(
      [
        _match(1, championId: 22, won: true, kills: 8, deaths: 2),
        _match(2, championId: 22, won: true, kills: 6, deaths: 3),
        _match(3, championId: 22, won: false, kills: 4, deaths: 4),
        _match(4, championId: 103, won: true, kills: 7, deaths: 2),
        _match(5, championId: 103, won: true, kills: 5, deaths: 1),
      ],
      puuid: puuid,
      championNames: const {22: 'Ashe', 103: 'Ahri'},
    );

    expect(result.games, 5);
    expect(result.wins, 4);
    expect(result.gpi, hasLength(8));
    expect(
      result.gpi.firstWhere((item) => item['category'] == 'Victorias'),
      containsPair('value', 80.0),
    );
    expect(result.signatureChampions.first['name'], 'Ashe');
    expect(result.signatureChampions.first['games'], 3);
    expect(
      result.badges.map((badge) => badge['name']),
      containsAll(['Especialista en Ashe', 'Racha positiva']),
    );
  });

  test('returns no invented analytics without match evidence', () {
    final result = analyzer.analyze(
      const [],
      puuid: puuid,
      championNames: const {},
    );

    expect(result.games, 0);
    expect(result.gpi, isEmpty);
    expect(result.badges, isEmpty);
    expect(result.signatureChampions, isEmpty);
  });
}

LocalMatchRecord _match(
  int id, {
  required int championId,
  required bool won,
  required int kills,
  required int deaths,
}) => LocalMatchRecord(
  match: MatchKey(platformId: PlatformId('LA1'), gameId: id),
  puuid: Puuid('player'),
  summaryJson:
      '''{"gameDuration":1800,"participantIdentities":[{"participantId":1,"player":{"puuid":"player"}}],"participants":[{"participantId":1,"championId":$championId,"stats":{"win":$won,"kills":$kills,"deaths":$deaths,"assists":6,"totalMinionsKilled":210,"neutralMinionsKilled":0,"visionScore":24,"damageDealtToObjectives":5000}}]}''',
  syncedAt: DateTime.utc(2026),
);
