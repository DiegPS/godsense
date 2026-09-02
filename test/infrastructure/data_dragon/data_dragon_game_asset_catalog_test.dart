import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/assets/game_asset_catalog.dart';
import 'package:godsense/domain/data_dragon/data_dragon_models.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_artifact_store.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_game_asset_catalog.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_resolver.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_transport.dart';

void main() {
  test(
    'resolves typed rune, spell, and item metadata from one build',
    () async {
      final catalog = DataDragonGameAssetCatalog(
        DataDragonResolver(transport: _Transport(), store: _Store()),
      );

      final result = await catalog.load(
        patch: PatchKey('16.17'),
        platformId: PlatformId('LA1'),
        locale: LeagueLocale('es_MX'),
      );

      expect(result.resolvedVersion.value, '16.17.2');
      expect(result.runes[8112]?.name, 'Electrocutar');
      expect(result.runes[8112]?.isKeystone, isTrue);
      expect(result.summonerSpells[4]?.name, 'Destello');
      expect(result.items[1001]?.totalPrice, 300);
      expect(result.items[1001]?.provenance.source, GameAssetSource.dataDragon);
      expect(result.items[1001]?.provenance.sourceVersion, '16.17.2');
    },
  );

  test('rejects a malformed rune list', () async {
    final resolver = DataDragonResolver(
      transport: _Transport(malformedRunes: true),
      store: _Store(),
    );

    expect(
      () => resolver.resolve(
        DataDragonResolutionRequest(
          patch: PatchKey('16.17'),
          platformId: PlatformId('LA1'),
          requestedLocale: LeagueLocale('es_MX'),
          resource: DataDragonResource.runes,
          intent: DataDragonResolutionIntent.currentRegional,
        ),
      ),
      throwsA(isA<DataDragonResolutionException>()),
    );
  });
}

class _Transport implements DataDragonTransport {
  _Transport({this.malformedRunes = false});

  final bool malformedRunes;

  @override
  Future<List<int>> get(Uri uri) async {
    if (uri.path == '/realms/la1.json') {
      return _json({
        'n': {'item': '16.17.2', 'rune': '16.17.2', 'summoner': '16.17.2'},
      });
    }
    if (uri.path == '/api/versions.json') return _json(['16.17.2']);
    if (uri.path.endsWith('/runesReforged.json')) {
      if (malformedRunes) return _json({'data': {}});
      return _json([
        {
          'id': 8100,
          'name': 'Dominación',
          'slots': [
            {
              'runes': [
                {
                  'id': 8112,
                  'name': 'Electrocutar',
                  'icon': 'perk-images/Styles/Domination/Electrocute/Electrocute.png',
                  'longDesc': '<b>Golpea</b> tres veces.',
                },
              ],
            },
          ],
        },
      ]);
    }
    if (uri.path.endsWith('/summoner.json')) {
      return _json({
        'data': {
          'SummonerFlash': {
            'key': '4',
            'name': 'Destello',
            'description': 'Teletransporta una distancia corta.',
            'image': {'full': 'SummonerFlash.png'},
          },
        },
      });
    }
    if (uri.path.endsWith('/item.json')) {
      return _json({
        'data': {
          '1001': {
            'name': 'Botas',
            'description': '<mainText>Movimiento</mainText>',
            'gold': {'base': 300, 'total': 300},
            'image': {'full': '1001.png'},
          },
        },
      });
    }
    throw HttpException('not found', uri: uri);
  }
}

List<int> _json(Object value) => utf8.encode(jsonEncode(value));

class _Store implements DataDragonArtifactStore {
  final values = <String, DataDragonArtifact>{};

  @override
  Future<DataDragonArtifact?> readResolution(String resolutionKey) async =>
      values[resolutionKey]?.copyWith(fromCache: true);

  @override
  Future<DataDragonArtifact> writeResolution(
    String resolutionKey,
    DataDragonArtifact artifact,
  ) async => values[resolutionKey] = artifact;
}
