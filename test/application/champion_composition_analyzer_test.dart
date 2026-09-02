import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/champion_composition_analyzer.dart';

void main() {
  test('returns a versioned deterministic composition profile', () {
    final profile = const ChampionCompositionAnalyzer().typedProfile([
      {
        'champion_profile': {
          'playstyle': {
            'damage': 3,
            'durability': 2,
            'crowdControl': 2,
            'mobility': 1,
            'utility': 1,
          },
          'classes': ['Mage'],
          'tactical': {'damageType': 'MAGIC'},
        },
      },
    ]);

    expect(profile, isNotNull);
    expect(profile?.axes.damage, 3);
    expect(profile?.evaluatorVersion, 1);
    expect(profile?.archetype, 'Control y resistencia');
    expect(profile?.toJson()['source'], 'lcu_champion_playstyle');
  });

  test('does not invent a profile without champion attributes', () {
    expect(
      const ChampionCompositionAnalyzer().typedProfile(const [{}]),
      isNull,
    );
  });
}
