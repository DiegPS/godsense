import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/data_dragon/data_dragon_models.dart';
import '../../domain/identity/league_identity.dart';
import 'data_dragon_artifact_store.dart';
import 'data_dragon_resolver.dart';
import 'data_dragon_transport.dart';

class DataDragonCatalogService {
  DataDragonCatalogService(this.resolver);

  final DataDragonResolver resolver;

  static Future<DataDragonCatalogService> createDefault() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'data_dragon'));
    return DataDragonCatalogService(
      DataDragonResolver(
        transport: HttpDataDragonTransport(),
        store: FileDataDragonArtifactStore(root),
      ),
    );
  }

  Future<Map<int, Map<String, dynamic>>> loadItems({
    required PatchKey patch,
    required PlatformId platformId,
    ClientVersion? clientVersion,
    LeagueLocale? locale,
  }) async {
    final artifact = await resolver.resolve(
      DataDragonResolutionRequest(
        clientVersion: clientVersion,
        patch: patch,
        platformId: platformId,
        requestedLocale: locale ?? LeagueLocale('en_US'),
        resource: DataDragonResource.items,
        intent: DataDragonResolutionIntent.currentRegional,
      ),
    );
    final decoded = jsonDecode(utf8.decode(artifact.bytes));
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! Map) return const {};
    return {
      for (final entry in data.entries)
        if (int.tryParse(entry.key.toString()) != null && entry.value is Map)
          int.parse(entry.key.toString()): {
            ...Map<String, dynamic>.from(entry.value as Map),
            '_version': artifact.resolvedVersion.value,
            '_requested_patch': artifact.requestedPatch.value,
            '_locale': artifact.resolvedLocale.value,
            '_content_hash': artifact.contentHash,
          },
    };
  }

  Future<Map<String, String>> loadChampionPortraits({
    required PatchKey patch,
    required PlatformId platformId,
    ClientVersion? clientVersion,
  }) async {
    final artifact = await resolver.resolve(
      DataDragonResolutionRequest(
        clientVersion: clientVersion,
        patch: patch,
        platformId: platformId,
        requestedLocale: LeagueLocale('en_US'),
        resource: DataDragonResource.champions,
        intent: DataDragonResolutionIntent.currentRegional,
      ),
    );
    final decoded = jsonDecode(utf8.decode(artifact.bytes));
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! Map) return const {};
    final result = <String, String>{};
    for (final champion in data.values.whereType<Map>()) {
      final image = champion['image'];
      final filename = image is Map ? image['full']?.toString() : null;
      if (filename == null || filename.isEmpty) continue;
      final url =
          'https://ddragon.leagueoflegends.com/cdn/'
          '${artifact.resolvedVersion.value}/img/champion/$filename';
      for (final key in [champion['name'], champion['id']]) {
        if (key != null) result[_championKey(key.toString())] = url;
      }
    }
    return result;
  }

  Future<Map<String, List<Map<String, dynamic>>>> loadChampionAbilities({
    required Iterable<String> championNames,
    required PatchKey patch,
    required PlatformId platformId,
    ClientVersion? clientVersion,
    LeagueLocale? locale,
  }) async {
    final artifact = await resolver.resolve(
      DataDragonResolutionRequest(
        clientVersion: clientVersion,
        patch: patch,
        platformId: platformId,
        requestedLocale: locale ?? LeagueLocale('en_US'),
        resource: DataDragonResource.champions,
        intent: DataDragonResolutionIntent.currentRegional,
      ),
    );
    final decoded = jsonDecode(utf8.decode(artifact.bytes));
    final summaries = decoded is Map ? decoded['data'] : null;
    if (summaries is! Map) return const {};

    final requested = championNames.map(_championKey).toSet();
    final result = <String, List<Map<String, dynamic>>>{};
    for (final raw in summaries.values.whereType<Map>()) {
      final name = raw['name']?.toString() ?? '';
      final alias = raw['id']?.toString() ?? '';
      final image = raw['image'] is Map
          ? (raw['image'] as Map)['full']?.toString() ?? ''
          : '';
      final key = _championKey(name);
      if (alias.isEmpty || !requested.contains(key)) continue;
      try {
        final bytes = await resolver.transport.get(
          resolver.baseUri.replace(
            path:
                '/cdn/${artifact.resolvedVersion.value}/data/'
                '${artifact.resolvedLocale.value}/champion/$alias.json',
          ),
        );
        final detailJson = jsonDecode(utf8.decode(bytes));
        final detailData = detailJson is Map ? detailJson['data'] : null;
        final detail = detailData is Map ? detailData[alias] : null;
        if (detail is! Map) continue;
        final iconUrl = image.isEmpty
            ? ''
            : 'https://ddragon.leagueoflegends.com/cdn/'
                  '${artifact.resolvedVersion.value}/img/champion/$image';
        result[key] =
            _abilities(detail, version: artifact.resolvedVersion.value)
                .map(
                  (ability) => {
                    ...ability,
                    'champion_alias': alias,
                    'champion_icon_url': iconUrl,
                  },
                )
                .toList(growable: false);
      } catch (_) {
        // One unavailable champion must not suppress the other nine players.
      }
    }
    return result;
  }
}

List<Map<String, dynamic>> _abilities(Map detail, {required String version}) {
  final result = <Map<String, dynamic>>[];
  final passive = detail['passive'];
  if (passive is Map) {
    result.add(
      _ability(
        passive,
        slot: 'P',
        version: version,
        cooldown: '—',
        cost: '—',
        range: '—',
      ),
    );
  }
  final spells = detail['spells'];
  if (spells is List) {
    const slots = ['Q', 'W', 'E', 'R'];
    for (
      var index = 0;
      index < spells.length && index < slots.length;
      index++
    ) {
      final spell = spells[index];
      if (spell is! Map) continue;
      result.add(
        _ability(
          spell,
          slot: slots[index],
          version: version,
          cooldown: spell['cooldownBurn']?.toString() ?? '—',
          cost: spell['costBurn']?.toString() ?? '—',
          range: spell['rangeBurn']?.toString() ?? '—',
        ),
      );
    }
  }
  return List.unmodifiable(result);
}

Map<String, dynamic> _ability(
  Map raw, {
  required String slot,
  required String version,
  required String cooldown,
  required String cost,
  required String range,
}) {
  final image = raw['image'];
  final imageName = image is Map ? image['full']?.toString() ?? '' : '';
  return {
    'slot': slot,
    'name': raw['name']?.toString() ?? '',
    'description': _plainText(raw['description']?.toString() ?? ''),
    'cooldown': cooldown,
    'cost': cost,
    'range': range,
    'icon_url': imageName.isEmpty
        ? ''
        : 'https://ddragon.leagueoflegends.com/cdn/$version/img/'
              '${slot == 'P' ? 'passive' : 'spell'}/'
              '$imageName',
    'source': 'data_dragon',
    'source_version': version,
  };
}

String _plainText(String value) => value
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .trim();

String _championKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]"), '');
