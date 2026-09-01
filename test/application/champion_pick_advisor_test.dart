import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/champion_pick_advisor.dart';

void main() {
  const advisor = ChampionPickAdvisor();
  test('ranks available familiar champions and excludes picks and bans', () {
    final result = advisor.suggest(
      mastery: const [
        {'championId': 1, 'championPoints': 1000, 'championLevel': 3},
        {'championId': 2, 'championPoints': 5000, 'championLevel': 6},
        {'championId': 3, 'championPoints': 9000, 'championLevel': 7},
        {'championId': 4, 'championPoints': 300, 'championLevel': 2},
      ],
      pickableIds: {1, 2, 3},
      excludedIds: {3},
      championNames: {1: 'Annie', 2: 'Olaf', 3: 'Galio', 4: 'Twisted Fate'},
    );
    expect(result.map((entry) => entry['champion']), ['Olaf', 'Annie']);
    expect(result.first['policy'], 'personal_familiarity_v1');
    expect(result.first['score'], '5000 pts');
  });
  test('does not invent a recommendation without a known playable pool', () {
    expect(
      advisor.suggest(
        mastery: const [
          {'championId': 1, 'championPoints': 1000},
        ],
        pickableIds: {},
        excludedIds: {},
        championNames: {1: 'Annie'},
      ),
      isEmpty,
    );
  });
}
