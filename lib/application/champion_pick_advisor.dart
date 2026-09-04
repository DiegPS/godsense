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
    Map<int, Map<String, dynamic>> championProfiles = const {},
    int limit = 3,
  }) {
    final available = mastery.where((entry) {
      final id = (entry['championId'] as num?)?.toInt();
      final points = (entry['championPoints'] as num?)?.toInt() ?? 0;
      return id != null &&
          points > 0 &&
          pickableIds.contains(id) &&
          !excludedIds.contains(id) &&
          championNames.containsKey(id);
    }).toList();
    if (available.isEmpty) return const [];
    final maxPoints = available
        .map((entry) => (entry['championPoints'] as num).toDouble())
        .reduce(math.max);
    const composition = ChampionCompositionAnalyzer();
    final teamProfile = composition.typedProfile(allies);
    final scored =
        available.map((entry) {
          final id = (entry['championId'] as num).toInt();
          final points = (entry['championPoints'] as num).toInt();
          final fit = _compositionFit(
            teamProfile: teamProfile,
            candidate: championProfiles[id],
          );
          final familiarity = maxPoints <= 0 ? 0 : points / maxPoints * 100;
          final score = fit.available
              ? familiarity * 0.7 + fit.score * 0.3
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
                ? 'personal_familiarity_and_composition_v1'
                : 'personal_familiarity_v1',
            'reasons': [
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
  required Map<String, dynamic>? candidate,
}) {
  if (teamProfile == null || candidate == null || candidate.isEmpty) {
    return (available: false, score: 0, reasons: const []);
  }
  final playstyle = _map(candidate['playstyle']);
  final tactical = _map(candidate['tactical']);
  if (playstyle.isEmpty && tactical.isEmpty) {
    return (available: false, score: 0, reasons: const []);
  }
  var score = 40.0;
  final reasons = <String>[];
  final damageTypes = teamProfile.damageTypes;
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
  final durability = teamProfile.axes.durability ?? 0;
  if (durability < 1.5 && _axis(playstyle, 'durability') >= 2) {
    score += 20;
    reasons.add('Añade resistencia a una composición con poca primera línea.');
  }
  final control = teamProfile.axes.crowdControl ?? 0;
  if (control < 1.5 && _axis(playstyle, 'crowdControl') >= 2) {
    score += 15;
    reasons.add('Añade control a una composición con CC limitado.');
  }
  return (available: true, score: score.clamp(0, 100), reasons: reasons);
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : const {};

double _axis(Map<String, dynamic> values, String key) =>
    (values[key] as num?)?.toDouble() ?? 0;
