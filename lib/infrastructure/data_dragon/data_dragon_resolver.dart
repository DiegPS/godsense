import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/data_dragon/data_dragon_models.dart';
import '../../domain/identity/league_identity.dart';
import 'data_dragon_artifact_store.dart';
import 'data_dragon_transport.dart';

class DataDragonResolver {
  DataDragonResolver({
    required this.transport,
    required this.store,
    DateTime Function()? now,
    Uri? baseUri,
  }) : _now = now ?? DateTime.now,
       baseUri = baseUri ?? Uri.parse('https://ddragon.leagueoflegends.com');

  static const validatorVersion = 1;

  final DataDragonTransport transport;
  final DataDragonArtifactStore store;
  final DateTime Function() _now;
  final Uri baseUri;

  Future<DataDragonArtifact> resolve(
    DataDragonResolutionRequest request, {
    bool revalidate = false,
  }) async {
    final cached = await store.readResolution(request.cacheIdentity);
    if (cached != null && !revalidate) return cached;

    try {
      final candidates = await _candidateVersions(request);
      final locales = <LeagueLocale>[
        request.requestedLocale,
        if (request.requestedLocale.value != 'en_US') LeagueLocale('en_US'),
      ];
      for (final version in candidates) {
        for (final locale in locales) {
          try {
            final bytes = await transport.get(
              baseUri.replace(
                path:
                    '/cdn/${version.value}/data/${locale.value}/'
                    '${_fileName(request.resource)}',
              ),
            );
            _validate(bytes, request.resource);
            final artifact = DataDragonArtifact(
              clientVersion: request.clientVersion,
              requestedPatch: request.patch,
              resolvedVersion: version,
              requestedLocale: request.requestedLocale,
              resolvedLocale: locale,
              resource: request.resource,
              contentHash: sha256.convert(bytes).toString(),
              bytes: bytes,
              resolvedAt: _now().toUtc(),
              validatorVersion: validatorVersion,
              fromCache: false,
            );
            return await store.writeResolution(request.cacheIdentity, artifact);
          } catch (_) {
            continue;
          }
        }
      }
    } catch (_) {
      if (cached != null) return cached;
      rethrow;
    }
    if (cached != null) return cached;
    throw DataDragonResolutionException(
      'No validated ${request.resource.name} artifact exists for '
      '${request.patch.value}.',
    );
  }

  Future<List<DataDragonVersion>> _candidateVersions(
    DataDragonResolutionRequest request,
  ) async {
    final values = <DataDragonVersion>[];
    if (request.intent == DataDragonResolutionIntent.currentRegional &&
        request.platformId != null) {
      try {
        final realmBytes = await transport.get(
          baseUri.replace(
            path: '/realms/${request.platformId!.value.toLowerCase()}.json',
          ),
        );
        final realm = _jsonMap(realmBytes);
        final resourceVersions = realm['n'];
        final rawVersion = resourceVersions is Map
            ? resourceVersions[_realmKey(request.resource)]
            : null;
        final candidate = _tryVersion(rawVersion);
        if (candidate != null && candidate.patchKey == request.patch) {
          values.add(candidate);
        }
      } catch (_) {
        // versions.json remains the authoritative fallback candidate list.
      }
    }

    final versionsBytes = await transport.get(
      baseUri.replace(path: '/api/versions.json'),
    );
    final decoded = jsonDecode(utf8.decode(versionsBytes));
    if (decoded is! List) {
      throw const DataDragonResolutionException('Invalid versions manifest.');
    }
    for (final raw in decoded) {
      final candidate = _tryVersion(raw);
      if (candidate != null &&
          candidate.patchKey == request.patch &&
          !values.contains(candidate)) {
        values.add(candidate);
      }
    }
    if (values.isEmpty) {
      throw DataDragonResolutionException(
        'No Data Dragon build matches patch ${request.patch.value}.',
      );
    }
    return values;
  }

  void _validate(List<int> bytes, DataDragonResource resource) {
    final decoded = jsonDecode(utf8.decode(bytes));
    final valid = switch (resource) {
      DataDragonResource.runes =>
        decoded is List &&
            decoded.isNotEmpty &&
            decoded.every(
              (style) =>
                  style is Map && style['id'] is num && style['slots'] is List,
            ),
      _ =>
        decoded is Map && decoded['data'] is Map && decoded['data'].isNotEmpty,
    };
    if (!valid) {
      throw DataDragonResolutionException(
        'Validator $validatorVersion rejected ${resource.name}.',
      );
    }
  }
}

DataDragonVersion? _tryVersion(Object? value) {
  try {
    return DataDragonVersion(value?.toString() ?? '');
  } on FormatException {
    return null;
  }
}

Map<String, Object?> _jsonMap(List<int> bytes) {
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map) {
    throw const DataDragonResolutionException('Expected a JSON object.');
  }
  return decoded.map((key, value) => MapEntry(key.toString(), value));
}

String _fileName(DataDragonResource resource) => switch (resource) {
  DataDragonResource.items => 'item.json',
  DataDragonResource.champions => 'champion.json',
  DataDragonResource.runes => 'runesReforged.json',
  DataDragonResource.summonerSpells => 'summoner.json',
};

String _realmKey(DataDragonResource resource) => switch (resource) {
  DataDragonResource.items => 'item',
  DataDragonResource.champions => 'champion',
  DataDragonResource.runes => 'rune',
  DataDragonResource.summonerSpells => 'summoner',
};
