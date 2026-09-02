import '../identity/league_identity.dart';

enum DataDragonResolutionIntent { currentRegional, historicalPatch }

enum DataDragonResource { items, champions, runes, summonerSpells }

class DataDragonResolutionRequest {
  const DataDragonResolutionRequest({
    required this.patch,
    required this.requestedLocale,
    required this.resource,
    required this.intent,
    this.clientVersion,
    this.platformId,
  });

  final ClientVersion? clientVersion;
  final PatchKey patch;
  final PlatformId? platformId;
  final LeagueLocale requestedLocale;
  final DataDragonResource resource;
  final DataDragonResolutionIntent intent;

  String get cacheIdentity => [
    intent.name,
    patch.value,
    platformId?.value ?? '-',
    requestedLocale.value,
    resource.name,
  ].join('|');
}

class DataDragonArtifact {
  const DataDragonArtifact({
    required this.clientVersion,
    required this.requestedPatch,
    required this.resolvedVersion,
    required this.requestedLocale,
    required this.resolvedLocale,
    required this.resource,
    required this.contentHash,
    required this.bytes,
    required this.resolvedAt,
    required this.validatorVersion,
    required this.fromCache,
  });

  final ClientVersion? clientVersion;
  final PatchKey requestedPatch;
  final DataDragonVersion resolvedVersion;
  final LeagueLocale requestedLocale;
  final LeagueLocale resolvedLocale;
  final DataDragonResource resource;
  final String contentHash;
  final List<int> bytes;
  final DateTime resolvedAt;
  final int validatorVersion;
  final bool fromCache;

  DataDragonArtifact copyWith({bool? fromCache, List<int>? bytes}) {
    return DataDragonArtifact(
      clientVersion: clientVersion,
      requestedPatch: requestedPatch,
      resolvedVersion: resolvedVersion,
      requestedLocale: requestedLocale,
      resolvedLocale: resolvedLocale,
      resource: resource,
      contentHash: contentHash,
      bytes: bytes ?? this.bytes,
      resolvedAt: resolvedAt,
      validatorVersion: validatorVersion,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

class DataDragonResolutionException implements Exception {
  const DataDragonResolutionException(this.message);

  final String message;

  @override
  String toString() => 'DataDragonResolutionException: $message';
}
