enum FactSource { lcu, liveClient, vision, riotData, user, derived }

class TacticalSighting {
  const TacticalSighting({
    required this.champion,
    required this.location,
    required this.observedAt,
    required this.confidence,
    this.role,
  });

  final String champion;
  final String location;
  final DateTime observedAt;
  final double confidence;
  final String? role;
}

class TacticalEvidence {
  const TacticalEvidence({
    required this.factType,
    required this.source,
    required this.observedAt,
    required this.confidence,
    this.gameTimeSeconds,
  });

  final String factType;
  final FactSource source;
  final DateTime observedAt;
  final double confidence;
  final double? gameTimeSeconds;
}

class TacticalAdvice {
  const TacticalAdvice({
    required this.id,
    required this.title,
    required this.hints,
    required this.rationale,
    required this.ttsText,
    required this.priority,
    required this.evidence,
  });

  final String id;
  final String title;
  final List<String> hints;
  final String rationale;
  final String ttsText;
  final int priority;
  final List<TacticalEvidence> evidence;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'hints': hints,
    'rationale': rationale,
    'tts_text': ttsText,
    'priority': priority,
    'evidence': evidence
        .map(
          (item) => {
            'fact_type': item.factType,
            'source': item.source.name,
            'observed_at': item.observedAt.toUtc().toIso8601String(),
            'confidence': item.confidence,
            'game_time_seconds': item.gameTimeSeconds,
          },
        )
        .toList(growable: false),
  };
}

class TacticalQualityMetrics {
  const TacticalQualityMetrics({
    required this.evidenceCoverage,
    required this.actionability,
    required this.temporalRelevance,
    required this.contradictionCount,
  });

  final double evidenceCoverage;
  final double actionability;
  final double temporalRelevance;
  final int contradictionCount;

  double get score =>
      ((evidenceCoverage + actionability + temporalRelevance) / 3) *
      (contradictionCount == 0 ? 1 : 0.5);
}
