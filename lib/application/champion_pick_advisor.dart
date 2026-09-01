class ChampionPickAdvisor {
  const ChampionPickAdvisor();

  List<Map<String, dynamic>> suggest({
    required List<Map<String, dynamic>> mastery,
    required Set<int> pickableIds,
    required Set<int> excludedIds,
    required Map<int, String> championNames,
    int limit = 3,
  }) {
    final candidates =
        mastery.where((entry) {
          final id = (entry['championId'] as num?)?.toInt();
          final points = (entry['championPoints'] as num?)?.toInt() ?? 0;
          return id != null &&
              points > 0 &&
              pickableIds.contains(id) &&
              !excludedIds.contains(id) &&
              championNames.containsKey(id);
        }).toList()..sort((left, right) {
          final pointsOrder = (right['championPoints'] as num).compareTo(
            left['championPoints'] as num,
          );
          return pointsOrder != 0
              ? pointsOrder
              : (left['championId'] as num).compareTo(
                  right['championId'] as num,
                );
        });
    return candidates
        .take(limit)
        .map((entry) {
          final id = (entry['championId'] as num).toInt();
          return <String, dynamic>{
            'champion_id': id,
            'champion': championNames[id],
            'score': '${entry['championPoints']} pts',
            'source': 'lcu_champion_mastery',
            'policy': 'personal_familiarity_v1',
            'reasons': [
              {
                'kind': 'Dominio personal',
                'play': 'Maestría ${entry['championLevel'] ?? 0}',
                'trait':
                    'Disponible para elegir; no es una predicción de counter.',
              },
            ],
          };
        })
        .toList(growable: false);
  }
}
