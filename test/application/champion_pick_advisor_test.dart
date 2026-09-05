import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/champion_pick_advisor.dart';

void main() {
  const advisor = ChampionPickAdvisor();
  test('enemy attributes inform composition fit without claiming counters', () {
    final result = advisor.suggest(
      mastery: const [
        {'championId': 1, 'championPoints': 100},
        {'championId': 2, 'championPoints': 100},
      ],
      pickableIds: {1, 2},
      excludedIds: {},
      championNames: {1: 'Low control', 2: 'High control'},
      enemies: const [
        {
          'champion_profile': {
            'playstyle': {'mobility': 3},
          },
        },
      ],
      championProfiles: const {
        1: {
          'playstyle': {'crowdControl': 1},
        },
        2: {
          'playstyle': {'crowdControl': 3},
        },
      },
    );
    expect(result.first['champion'], 'High control');
    expect(result.first['reasons'].toString(), contains('no garantiza'));
  });
  test('assigned role excludes unrelated mastery and unknown positions', () {
    final result = advisor.suggest(
      mastery: const [
        {'championId': 1, 'championPoints': 1000000},
        {'championId': 2, 'championPoints': 100},
        {'championId': 3, 'championPoints': 2000},
      ],
      pickableIds: {1, 2, 3},
      excludedIds: {},
      championNames: {1: 'ADC', 2: 'Support', 3: 'Unknown'},
      assignedPosition: 'utility',
      championPositions: {
        1: {'BOTTOM'},
        2: {'UTILITY'},
      },
    );
    expect(result.map((e) => e['champion']), ['Support']);
  });
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

  test('balances familiarity with observable composition needs', () {
    final result = advisor.suggest(
      mastery: const [
        {'championId': 1, 'championPoints': 10000, 'championLevel': 7},
        {'championId': 2, 'championPoints': 8500, 'championLevel': 6},
      ],
      pickableIds: {1, 2},
      excludedIds: {},
      championNames: {1: 'AD Familiar', 2: 'AP Frontline'},
      allies: const [
        {
          'champion_profile': {
            'playstyle': {'damage': 2, 'durability': 1, 'crowdControl': 1},
            'tactical': {'damageType': 'PHYSICAL_DAMAGE'},
          },
        },
        {
          'champion_profile': {
            'playstyle': {'damage': 2, 'durability': 1, 'crowdControl': 1},
            'tactical': {'damageType': 'PHYSICAL_DAMAGE'},
          },
        },
      ],
      championProfiles: const {
        1: {
          'playstyle': {'durability': 1, 'crowdControl': 1},
          'tactical': {'damageType': 'PHYSICAL_DAMAGE'},
        },
        2: {
          'playstyle': {'durability': 3, 'crowdControl': 3},
          'tactical': {'damageType': 'MAGIC_DAMAGE'},
        },
      },
    );

    expect(result.first['champion'], 'AP Frontline');
    expect(result.first['policy'], 'personal_familiarity_and_composition_v2');
    expect(result.first['score'], contains('encaje'));
    expect(
      (result.first['reasons'] as List).whereType<Map>().map(
        (reason) => reason['play'],
      ),
      contains('Aporta un tipo de daño distinto al predominante.'),
    );
  });
}
