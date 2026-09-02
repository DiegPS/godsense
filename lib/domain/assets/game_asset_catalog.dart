import '../identity/league_identity.dart';

enum GameAssetSource { dataDragon, installedClient, communityDragon }

class AssetProvenance {
  const AssetProvenance({
    required this.source,
    required this.sourceVersion,
    required this.locale,
    required this.contentHash,
  });

  final GameAssetSource source;
  final String sourceVersion;
  final LeagueLocale locale;
  final String contentHash;
}

class RuneMetadata {
  const RuneMetadata({
    required this.id,
    required this.name,
    required this.styleId,
    required this.slot,
    required this.isKeystone,
    required this.iconPath,
    required this.description,
    required this.provenance,
  });

  final int id;
  final String name;
  final int styleId;
  final int slot;
  final bool isKeystone;
  final String iconPath;
  final String description;
  final AssetProvenance provenance;
}

class SummonerSpellMetadata {
  const SummonerSpellMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.iconPath,
    required this.provenance,
  });

  final int id;
  final String name;
  final String description;
  final String iconPath;
  final AssetProvenance provenance;
}

class ItemMetadata {
  const ItemMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.totalPrice,
    required this.basePrice,
    required this.iconPath,
    required this.provenance,
  });

  final int id;
  final String name;
  final String description;
  final int totalPrice;
  final int basePrice;
  final String iconPath;
  final AssetProvenance provenance;
}

class GameAssetCatalogSnapshot {
  const GameAssetCatalogSnapshot({
    required this.resolvedVersion,
    required this.runes,
    required this.summonerSpells,
    required this.items,
  });

  final DataDragonVersion resolvedVersion;
  final Map<int, RuneMetadata> runes;
  final Map<int, SummonerSpellMetadata> summonerSpells;
  final Map<int, ItemMetadata> items;
}

abstract interface class GameAssetCatalog {
  Future<GameAssetCatalogSnapshot> load({
    required PatchKey patch,
    required PlatformId platformId,
    ClientVersion? clientVersion,
    LeagueLocale? locale,
  });
}
