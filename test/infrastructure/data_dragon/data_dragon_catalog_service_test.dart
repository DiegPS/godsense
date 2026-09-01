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
    return utf8.encode(
      jsonEncode({
        'data': {
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
