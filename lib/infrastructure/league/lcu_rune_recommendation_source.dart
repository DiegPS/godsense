import '../../domain/identity/league_identity.dart';
import '../../domain/league/rune_recommendation.dart';
import 'lcu_probe_transport.dart';

class LcuRuneRecommendationSource {
  LcuRuneRecommendationSource({required this.client, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final LcuReadTransport client;
  final DateTime Function() _now;

  Future<RuneRecommendationBundle> load({
    required int championId,
    required LeaguePosition position,
    int mapId = 11,
    ClientVersion? clientVersion,
    PatchKey? patch,
  }) async {
    if (championId <= 0) {
      throw const RuneRecommendationException(
        'A positive champion ID is required.',
      );
    }
    if (mapId <= 0) {
      throw const RuneRecommendationException('A positive map ID is required.');
    }
    final raw = await client.get(
      '/lol-perks/v1/recommended-pages/champion/$championId/'
      'position/${position.lcuValue}/map/$mapId',
    );
    if (raw is! List || raw.isEmpty) {
      throw RuneRecommendationException(
        'The League Client returned no rune recommendations for champion '
        '$championId, ${position.lcuValue}, map $mapId.',
      );
    }

    final variants = <RuneRecommendationVariant>[];
    for (final value in raw.whereType<Map>()) {
      final item = value.map((key, entry) => MapEntry(key.toString(), entry));
      final returnedChampion = (item['recommendationChampionId'] as num?)
          ?.toInt();
      final returnedPosition = LeaguePosition.tryParse(item['position']);
      if (returnedChampion != championId || returnedPosition != position) {
        continue;
      }
      final perkIds = _ids(item['perks']);
      final spellIds = _integerList(item['summonerSpellIds']);
      final primary = (item['primaryPerkStyleId'] as num?)?.toInt() ?? 0;
      final secondary = (item['secondaryPerkStyleId'] as num?)?.toInt() ?? 0;
      final keystone = item['keystone'] is Map
          ? ((item['keystone'] as Map)['id'] as num?)?.toInt() ?? 0
          : 0;
      final id = item['recommendationId']?.toString().trim() ?? '';
      if (id.isEmpty ||
          perkIds.length != 9 ||
          perkIds.toSet().length != 9 ||
          spellIds.length != 2 ||
          primary <= 0 ||
          secondary <= 0 ||
          keystone <= 0 ||
          perkIds.first != keystone) {
        continue;
      }
      variants.add(
        RuneRecommendationVariant(
          recommendationId: id,
          championId: championId,
          position: position,
          perkIds: List.unmodifiable(perkIds),
          primaryStyleId: primary,
          secondaryStyleId: secondary,
          summonerSpellIds: List.unmodifiable(spellIds),
          keystoneId: keystone,
          primaryAttribute:
              item['primaryRecommendationAttribute']?.toString() ?? '',
          secondaryAttribute:
              item['secondaryRecommendationAttribute']?.toString() ?? '',
          isDefaultPosition: item['isDefaultPosition'] == true,
          isOverride: item['isRecommendationOverride'] == true,
        ),
      );
    }
    if (variants.isEmpty) {
      throw const RuneRecommendationException(
        'The League Client response did not contain a valid recommendation '
        'for the requested champion and position.',
      );
    }
    return RuneRecommendationBundle(
      championId: championId,
      position: position,
      mapId: mapId,
      variants: List.unmodifiable(variants),
      fetchedAt: _now().toUtc(),
      clientVersion: clientVersion,
      patch: patch,
    );
  }
}

List<int> _ids(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item is Map ? item['id'] : item)
      .whereType<num>()
      .map((item) => item.toInt())
      .toList(growable: false);
}

List<int> _integerList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<num>()
      .map((item) => item.toInt())
      .toList(growable: false);
}
