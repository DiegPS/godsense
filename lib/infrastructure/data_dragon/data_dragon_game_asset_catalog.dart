import 'dart:convert';

import '../../domain/assets/game_asset_catalog.dart';
import '../../domain/data_dragon/data_dragon_models.dart';
import '../../domain/identity/league_identity.dart';
import 'data_dragon_resolver.dart';

class DataDragonGameAssetCatalog implements GameAssetCatalog {
  DataDragonGameAssetCatalog(this.resolver);

  final DataDragonResolver resolver;

  @override
  Future<GameAssetCatalogSnapshot> load({
    required PatchKey patch,
    required PlatformId platformId,
    ClientVersion? clientVersion,
    LeagueLocale? locale,
  }) async {
    final requestedLocale = locale ?? LeagueLocale('es_MX');
    final artifacts = await Future.wait([
      _resolve(
        patch,
        platformId,
        clientVersion,
        requestedLocale,
        DataDragonResource.runes,
      ),
      _resolve(
        patch,
        platformId,
        clientVersion,
        requestedLocale,
        DataDragonResource.summonerSpells,
      ),
      _resolve(
        patch,
        platformId,
        clientVersion,
        requestedLocale,
        DataDragonResource.items,
      ),
    ]);
    final runesArtifact = artifacts[0];
    final spellsArtifact = artifacts[1];
    final itemsArtifact = artifacts[2];
    return GameAssetCatalogSnapshot(
      resolvedVersion: itemsArtifact.resolvedVersion,
      runes: _runes(runesArtifact),
      summonerSpells: _spells(spellsArtifact),
      items: _items(itemsArtifact),
    );
  }

  Future<DataDragonArtifact> _resolve(
    PatchKey patch,
    PlatformId platformId,
    ClientVersion? clientVersion,
    LeagueLocale locale,
    DataDragonResource resource,
  ) => resolver.resolve(
    DataDragonResolutionRequest(
      clientVersion: clientVersion,
      patch: patch,
      platformId: platformId,
      requestedLocale: locale,
      resource: resource,
      intent: DataDragonResolutionIntent.currentRegional,
    ),
  );
}

Map<int, RuneMetadata> _runes(DataDragonArtifact artifact) {
  final decoded = jsonDecode(utf8.decode(artifact.bytes));
  if (decoded is! List) return const {};
  final result = <int, RuneMetadata>{};
  for (final rawStyle in decoded.whereType<Map>()) {
    final styleId = (rawStyle['id'] as num?)?.toInt();
    if (styleId == null) continue;
    final slots = rawStyle['slots'];
    if (slots is! List) continue;
    for (var slotIndex = 0; slotIndex < slots.length; slotIndex++) {
      final slot = slots[slotIndex];
      if (slot is! Map || slot['runes'] is! List) continue;
      for (final raw in (slot['runes'] as List).whereType<Map>()) {
        final id = (raw['id'] as num?)?.toInt();
        if (id == null) continue;
        result[id] = RuneMetadata(
          id: id,
          name: raw['name']?.toString() ?? '$id',
          styleId: styleId,
          slot: slotIndex,
          isKeystone: slotIndex == 0,
          iconPath: raw['icon']?.toString() ?? '',
          description: _plainText(raw['longDesc']?.toString() ?? ''),
          provenance: _provenance(artifact),
        );
      }
    }
  }
  return Map.unmodifiable(result);
}

Map<int, SummonerSpellMetadata> _spells(DataDragonArtifact artifact) {
  final data = _dataMap(artifact);
  final result = <int, SummonerSpellMetadata>{};
  for (final raw in data.values.whereType<Map>()) {
    final id = int.tryParse(raw['key']?.toString() ?? '');
    if (id == null) continue;
    result[id] = SummonerSpellMetadata(
      id: id,
      name: raw['name']?.toString() ?? '$id',
      description: _plainText(raw['description']?.toString() ?? ''),
      iconPath: _imagePath(raw),
      provenance: _provenance(artifact),
    );
  }
  return Map.unmodifiable(result);
}

Map<int, ItemMetadata> _items(DataDragonArtifact artifact) {
  final data = _dataMap(artifact);
  final result = <int, ItemMetadata>{};
  for (final entry in data.entries) {
    final id = int.tryParse(entry.key.toString());
    final raw = entry.value;
    if (id == null || raw is! Map) continue;
    final gold = raw['gold'] is Map ? raw['gold'] as Map : const {};
    result[id] = ItemMetadata(
      id: id,
      name: raw['name']?.toString() ?? '$id',
      description: _plainText(raw['description']?.toString() ?? ''),
      totalPrice: (gold['total'] as num?)?.toInt() ?? 0,
      basePrice: (gold['base'] as num?)?.toInt() ?? 0,
      iconPath: _imagePath(raw),
      provenance: _provenance(artifact),
    );
  }
  return Map.unmodifiable(result);
}

Map _dataMap(DataDragonArtifact artifact) {
  final decoded = jsonDecode(utf8.decode(artifact.bytes));
  return decoded is Map && decoded['data'] is Map
      ? decoded['data'] as Map
      : const {};
}

String _imagePath(Map raw) {
  final image = raw['image'];
  return image is Map ? image['full']?.toString() ?? '' : '';
}

AssetProvenance _provenance(DataDragonArtifact artifact) => AssetProvenance(
  source: GameAssetSource.dataDragon,
  sourceVersion: artifact.resolvedVersion.value,
  locale: artifact.resolvedLocale,
  contentHash: artifact.contentHash,
);

String _plainText(String value) => value
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .trim();
