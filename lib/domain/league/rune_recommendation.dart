import '../identity/league_identity.dart';

enum LeaguePosition {
  top('TOP'),
  jungle('JUNGLE'),
  middle('MIDDLE'),
  bottom('BOTTOM'),
  utility('UTILITY');

  const LeaguePosition(this.lcuValue);

  final String lcuValue;

  static LeaguePosition? tryParse(Object? value) {
    final normalized = value?.toString().trim().toUpperCase();
    return switch (normalized) {
      'TOP' => top,
      'JUNGLE' => jungle,
      'MIDDLE' || 'MID' => middle,
      'BOTTOM' || 'BOT' || 'ADC' => bottom,
      'UTILITY' || 'SUPPORT' => utility,
      _ => null,
    };
  }
}

class RuneRecommendationVariant {
  const RuneRecommendationVariant({
    required this.recommendationId,
    required this.championId,
    required this.position,
    required this.perkIds,
    required this.primaryStyleId,
    required this.secondaryStyleId,
    required this.summonerSpellIds,
    required this.keystoneId,
    required this.primaryAttribute,
    required this.secondaryAttribute,
    required this.isDefaultPosition,
    required this.isOverride,
  });

  final String recommendationId;
  final int championId;
  final LeaguePosition position;
  final List<int> perkIds;
  final int primaryStyleId;
  final int secondaryStyleId;
  final List<int> summonerSpellIds;
  final int keystoneId;
  final String primaryAttribute;
  final String secondaryAttribute;
  final bool isDefaultPosition;
  final bool isOverride;

  Map<String, dynamic> toImportJson() => {
    'perk_ids': perkIds,
    'primary_tree_id': primaryStyleId,
    'secondary_tree_id': secondaryStyleId,
    'summoner_spell_ids': summonerSpellIds,
    'recommendation_id': recommendationId,
  };
}

class RuneRecommendationBundle {
  const RuneRecommendationBundle({
    required this.championId,
    required this.position,
    required this.mapId,
    required this.variants,
    required this.fetchedAt,
    this.clientVersion,
    this.patch,
  });

  final int championId;
  final LeaguePosition position;
  final int mapId;
  final List<RuneRecommendationVariant> variants;
  final DateTime fetchedAt;
  final ClientVersion? clientVersion;
  final PatchKey? patch;
}

class RuneRecommendationException implements Exception {
  const RuneRecommendationException(this.message);

  final String message;

  @override
  String toString() => 'RuneRecommendationException: $message';
}
