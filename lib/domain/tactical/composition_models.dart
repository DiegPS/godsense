class CompositionAxes {
  const CompositionAxes({
    this.damage,
    this.durability,
    this.crowdControl,
    this.mobility,
    this.utility,
  });

  final double? damage;
  final double? durability;
  final double? crowdControl;
  final double? mobility;
  final double? utility;

  Map<String, double> toMap() => {
    'damage': ?damage,
    'durability': ?durability,
    'crowdControl': ?crowdControl,
    'mobility': ?mobility,
    'utility': ?utility,
  };
}

class DeterministicCompositionProfile {
  const DeterministicCompositionProfile({
    required this.axes,
    required this.archetype,
    required this.knownChampions,
    required this.totalChampions,
    required this.damageTypes,
    required this.confidence,
    this.evaluatorVersion = 1,
  });

  final CompositionAxes axes;
  final String archetype;
  final int knownChampions;
  final int totalChampions;
  final Map<String, int> damageTypes;
  final double confidence;
  final int evaluatorVersion;

  Map<String, dynamic> toJson() => {
    'axes': axes.toMap(),
    'axis_max': 3,
    'known': knownChampions,
    'total': totalChampions,
    'damage_types': damageTypes,
    'archetype': archetype,
    'source': 'lcu_champion_playstyle',
    'confidence': confidence,
    'evaluator_version': evaluatorVersion,
    'inference': 'Arquetipo derivado de atributos estáticos, no de win rates.',
  };
}
