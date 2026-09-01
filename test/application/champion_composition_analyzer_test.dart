import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/champion_composition_analyzer.dart';

void main() {
  const analyzer = ChampionCompositionAnalyzer();
  test('uses champion attributes instead of assuming power from lane role', () {
    final profile = analyzer.profile([
      _champion('TOP', durability: 3, control: 3),
      _champion('TOP', durability: 1, control: 1),
    ])!;
    expect((profile['axes'] as Map)['durability'], 2.0);
    expect((profile['axes'] as Map)['crowdControl'], 2.0);
    expect(profile['archetype'], 'Control y resistencia');
    expect(profile['axis_max'], 3);
    expect(profile['source'], 'lcu_champion_playstyle');
  });
  test('does not fabricate a champion profile from role alone', () {
    expect(
      analyzer.profile([
        {'champion_name': 'Leona', 'position': 'UTILITY'},
      ]),
      isNull,
    );
  });
  test('adapts advice when the actual team lacks durability and control', () {
    final result = analyzer.analyze([
      _champion('TOP', durability: 1, control: 1),
    ], const []);
    expect(
      (result['guidelines'] as List).join(' '),
      contains('Resistencia limitada'),
    );
    expect(
      (result['guidelines'] as List).join(' '),
      contains('Control limitado'),
    );
  });
}

Map<String, dynamic> _champion(
  String role, {
  required int durability,
  required int control,
}) => {
  'position': role,
  'champion_profile': {
    'classes': ['tank'],
    'tactical': {'damageType': 'kMagic'},
    'playstyle': {
      'damage': 2,
      'durability': durability,
      'crowdControl': control,
      'mobility': 1,
      'utility': 1,
    },
  },
};
