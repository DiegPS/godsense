import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/data_dragon/data_dragon_models.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_artifact_store.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_catalog_service.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_resolver.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_transport.dart';

void main() {
  test(
    'portraits resolve independently of champion ability requests',
    () async {
      final service = DataDragonCatalogService(
        DataDragonResolver(
          transport: _SingleBuildTransport(),
          store: _MemoryStore(),
        ),
      );
      final portraits = await service.loadChampionPortraits(
        patch: PatchKey('16.17'),
        platformId: PlatformId('LA1'),
      );
      expect(
        portraits['vex'],
        'https://ddragon.leagueoflegends.com/cdn/16.17.2/img/champion/Vex.png',
      );
    },
  );
  test(
    'item catalog exposes the resolved metadata used by projections',
    () async {
      final service = DataDragonCatalogService(
        DataDragonResolver(
          transport: _SingleBuildTransport(),
          store: _MemoryStore(),
        ),
      );

      final items = await service.loadItems(
        patch: PatchKey('16.17'),
        platformId: PlatformId('LA1'),
        clientVersion: ClientVersion('16.17.999.1'),
      );

      expect(items[1001]?['name'], 'Boots');
      expect(items[1001]?['_version'], '16.17.2');
      expect(items[1001]?['_requested_patch'], '16.17');
      expect(items[1001]?['_content_hash'], hasLength(64));
    },
  );

  test('champion catalog exposes normalized passive and four spells', () async {
    final service = DataDragonCatalogService(
      DataDragonResolver(
        transport: _SingleBuildTransport(),
        store: _MemoryStore(),
      ),
    );

    final abilities = await service.loadChampionAbilities(
      championNames: const ['Vex'],
      patch: PatchKey('16.17'),
      platformId: PlatformId('LA1'),
    );

    expect(abilities['vex'], hasLength(5));
    expect(abilities['vex']?.first['slot'], 'P');
    expect(abilities['vex']?[1]['slot'], 'Q');
    expect(abilities['vex']?[1]['cooldown'], '8');
    expect(abilities['vex']?[1]['description'], 'Deals magic damage.');
    expect(abilities['vex']?[1]['source_version'], '16.17.2');
  });
}

class _SingleBuildTransport implements DataDragonTransport {
  @override
  Future<List<int>> get(Uri uri) async {
    if (uri.path == '/realms/la1.json') {
      return utf8.encode(
        jsonEncode({
          'n': {'item': '16.17.2'},
        }),
      );
    }
    if (uri.path == '/api/versions.json') {
      return utf8.encode(jsonEncode(['16.17.2']));
    }
    if (uri.path.endsWith('/champion/Vex.json')) {
      return utf8.encode(
        jsonEncode({
          'data': {
            'Vex': {
              'passive': {
                'name': 'Doom n Gloom',
                'description': 'Passive.',
                'image': {'full': 'Vex_Passive.png'},
              },
              'spells': [
                for (final entry in const [
                  ('Q', 'Mistral Bolt'),
                  ('W', 'Personal Space'),
                  ('E', 'Looming Darkness'),
                  ('R', 'Shadow Surge'),
                ])
                  {
                    'name': entry.$2,
                    'description': '<b>Deals</b> magic damage.',
                    'cooldownBurn': '8',
                    'costBurn': '45',
                    'rangeBurn': '1200',
                    'image': {'full': 'Vex${entry.$1}.png'},
                  },
              ],
            },
          },
        }),
      );
    }
    return utf8.encode(
      jsonEncode({
        'data': {
          'Vex': {
            'id': 'Vex',
            'name': 'Vex',
            'image': {'full': 'Vex.png'},
          },
          '1001': {
            'name': 'Boots',
            'gold': {'total': 300},
          },
        },
      }),
    );
  }
}

class _MemoryStore implements DataDragonArtifactStore {
  DataDragonArtifact? value;

  @override
  Future<DataDragonArtifact?> readResolution(String resolutionKey) async =>
      value?.copyWith(fromCache: true);

  @override
  Future<DataDragonArtifact> writeResolution(
    String resolutionKey,
    DataDragonArtifact artifact,
  ) async => value = artifact;
}
