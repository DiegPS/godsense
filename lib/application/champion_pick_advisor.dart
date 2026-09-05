import 'dart:math' as math;

import '../domain/tactical/composition_models.dart';
import 'champion_composition_analyzer.dart';

class ChampionPickAdvisor {
  const ChampionPickAdvisor();

  List<Map<String, dynamic>> suggest({
    required List<Map<String, dynamic>> mastery,
    required Set<int> pickableIds,
    required Set<int> excludedIds,
    required Map<int, String> championNames,
    List<Map<String, dynamic>> allies = const [],
    List<Map<String, dynamic>> enemies = const [],
    String? assignedPosition,
    Map<int, Set<String>> championPositions = const {},
    Map<int, Map<String, dynamic>> championProfiles = const {},
    int limit = 3,
  }) {
    final available = mastery.where((entry) {
      final id = (entry['championId'] as num?)?.toInt();
      final points = (entry['championPoints'] as num?)?.toInt() ?? 0;
      return id != null &&
          entry['championPoints'] is num &&
          points >= 0 &&
          (assignedPosition == null ||
              assignedPosition.isEmpty ||
              (championPositions[id]?.contains(
                    assignedPosition.toUpperCase(),
                  ) ??
                  false)) &&
          pickableIds.contains(id) &&
          !excludedIds.contains(id) &&
          championNames.containsKey(id);
    }).toList();
    if (available.isEmpty) return const [];
    final maxPoints = available
        .map((entry) => (entry['championPoints'] as num).toDouble())
        .reduce(math.max);
    const composition = ChampionCompositionAnalyzer();
    final teamProfile = composition.typedProfile(
      allies.where((p) => p['is_local'] != true).toList(),
    );
    final enemyProfile = composition.typedProfile(enemies);
    final scored =
        available.map((entry) {
          final id = (entry['championId'] as num).toInt();
          final points = (entry['championPoints'] as num).toInt();
          final fit = _compositionFit(
            teamProfile: teamProfile,
            enemyProfile: enemyProfile,
            candidate: championProfiles[id],
          );
          final familiarity = maxPoints <= 0
              ? 0
              : math.log(points + 1) / math.log(maxPoints + 1) * 100;
          final score = fit.available
              ? familiarity * 0.4 + fit.score * 0.6
              : familiarity;
          return (entry: entry, score: score, fit: fit);
        }).toList()..sort((left, right) {
          final scoreOrder = right.score.compareTo(left.score);
          if (scoreOrder != 0) return scoreOrder;
          final pointOrder = (right.entry['championPoints'] as num).compareTo(
            left.entry['championPoints'] as num,
          );
          return pointOrder != 0
              ? pointOrder
              : (left.entry['championId'] as num).compareTo(
                  right.entry['championId'] as num,
                );
        });
    return scored
        .take(limit)
        .map((candidate) {
          final entry = candidate.entry;
          final id = (entry['championId'] as num).toInt();
          return <String, dynamic>{
            'champion_id': id,
            'champion': championNames[id],
            'score': candidate.fit.available
                ? '${entry['championPoints']} pts · encaje ${candidate.fit.score.round()}'
                : '${entry['championPoints']} pts',
            'source': 'lcu_champion_mastery',
            'policy': candidate.fit.available
                ? 'personal_familiarity_and_composition_v2'
                : 'personal_familiarity_v1',
            'reasons': [
              if (assignedPosition != null && assignedPosition.isNotEmpty)
                {
                  'kind': 'Posición',
                  'play': assignedPosition,
                  'trait': 'Posición observada en tu historial local.',
                },
              {
                'kind': 'Dominio personal',
                'play': 'Maestría ${entry['championLevel'] ?? 0}',
                'trait':
                    'Disponible para elegir; no es una predicción de counter.',
              },
              for (final reason in candidate.fit.reasons)
                {
                  'kind': 'Necesidad de composición',
                  'play': reason,
                  'trait': 'Basado en atributos oficiales del equipo visible.',
                },
            ],
          };
        })
        .toList(growable: false);
  }
}

({bool available, double score, List<String> reasons}) _compositionFit({
  required DeterministicCompositionProfile? teamProfile,
  required DeterministicCompositionProfile? enemyProfile,
  required Map<String, dynamic>? candidate,
}) {
  if ((teamProfile == null && enemyProfile == null) ||
      candidate == null ||
      candidate.isEmpty) {
    return (available: false, score: 0, reasons: const []);
  }
  final playstyle = _map(candidate['playstyle']);
  final tactical = _map(candidate['tactical']);
  if (playstyle.isEmpty && tactical.isEmpty) {
    return (available: false, score: 0, reasons: const []);
  }
  var score = 40.0;
  final reasons = <String>[];
  final damageTypes = teamProfile?.damageTypes ?? const <String, int>{};
  final knownDamage = damageTypes.values.fold<int>(
    0,
    (sum, value) => sum + value,
  );
  final dominantDamage = damageTypes.length == 1 && knownDamage >= 2
      ? damageTypes.keys.single
      : null;
  final candidateDamage = tactical['damageType']?.toString();
  if (dominantDamage != null &&
      candidateDamage != null &&
      candidateDamage != dominantDamage) {
    score += 25;
    reasons.add('Aporta un tipo de daño distinto al predominante.');
  }
  final durability = teamProfile?.axes.durability ?? 3;
  if (durability < 1.5 && _axis(playstyle, 'durability') >= 2) {
    score += 20;
    reasons.add('Añade resistencia a una composición con poca primera línea.');
  }
  final control = teamProfile?.axes.crowdControl ?? 3;
  if (control < 1.5 && _axis(playstyle, 'crowdControl') >= 2) {
    score += 15;
    reasons.add('Añade control a una composición con CC limitado.');
  }
  if ((enemyProfile?.axes.mobility ?? 0) >= 2 &&
      (_axis(playstyle, 'crowdControl') >= 2 ||
          _axis(playstyle, 'mobility') >= 2)) {
    score += 20;
    reasons.add(
      'Aporta control o movilidad ante un rival con alta movilidad; no garantiza el enfrentamiento.',
    );
  }
  return (available: true, score: score.clamp(0, 100), reasons: reasons);
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : const {};

double _axis(Map<String, dynamic> values, String key) =>
    (values[key] as num?)?.toDouble() ?? 0;
