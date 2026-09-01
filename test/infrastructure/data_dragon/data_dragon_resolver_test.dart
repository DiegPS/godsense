import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/data_dragon/data_dragon_models.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_artifact_store.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_resolver.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_transport.dart';

void main() {
  group('DataDragonResolver', () {
    test(
      'records client, requested patch, resolved build, and locale',
      () async {
        final transport = _FakeTransport({
          '/realms/la1.json': _json({
            'n': {'item': '16.17.2'},
          }),
          '/api/versions.json': _json(['16.18.1', '16.17.1']),
          '/cdn/16.17.2/data/es_MX/item.json': _catalog('Espada'),
        });
        final resolver = DataDragonResolver(
          transport: transport,
          store: _MemoryStore(),
          now: () => DateTime.utc(2026, 9, 1),
        );

        final artifact = await resolver.resolve(
          _request(
            clientVersion: ClientVersion('16.17.555.1'),
            locale: LeagueLocale('es_MX'),
          ),
        );

        expect(artifact.clientVersion?.value, '16.17.555.1');
        expect(artifact.requestedPatch.value, '16.17');
        expect(artifact.resolvedVersion.value, '16.17.2');
        expect(artifact.resolvedLocale.value, 'es_MX');
        expect(artifact.fromCache, isFalse);
      },
    );

    test('falls back in locale without changing gameplay patch', () async {
      final transport = _FakeTransport({
        '/realms/la1.json': _json({
          'n': {'item': '16.17.2'},
        }),
        '/api/versions.json': _json(['16.18.1', '16.17.1']),
        '/cdn/16.17.2/data/en_US/item.json': _catalog('Sword'),
      });

      final artifact = await DataDragonResolver(
        transport: transport,
        store: _MemoryStore(),
      ).resolve(_request(locale: LeagueLocale('es_MX')));

      expect(artifact.resolvedVersion.patchKey.value, '16.17');
      expect(artifact.resolvedLocale.value, 'en_US');
      expect(
        transport.requestedPaths,
        contains('/cdn/16.17.2/data/es_MX/item.json'),
      );
    });

    test('historical intent never consults the current realm', () async {
      final transport = _FakeTransport({
        '/api/versions.json': _json(['16.17.3', '16.17.2']),
        '/cdn/16.17.3/data/en_US/item.json': _catalog('Sword'),
      });

      final artifact =
          await DataDragonResolver(
            transport: transport,
            store: _MemoryStore(),
          ).resolve(
            DataDragonResolutionRequest(
              patch: PatchKey('16.17'),
              requestedLocale: LeagueLocale('en_US'),
              resource: DataDragonResource.items,
              intent: DataDragonResolutionIntent.historicalPatch,
            ),
          );

      expect(artifact.resolvedVersion.value, '16.17.3');
      expect(transport.requestedPaths, isNot(contains('/realms/la1.json')));
    });

    test('rejects a manifest that only contains another patch', () async {
      final transport = _FakeTransport({
        '/realms/la1.json': _json({
          'n': {'item': '16.18.1'},
        }),
        '/api/versions.json': _json(['16.18.1']),
      });

      expect(
        () => DataDragonResolver(
          transport: transport,
          store: _MemoryStore(),
        ).resolve(_request()),
        throwsA(isA<DataDragonResolutionException>()),
      );
    });

    test('uses an exact cached resolution without network access', () async {
      final store = _MemoryStore();
      final online = DataDragonResolver(
        transport: _FakeTransport({
          '/realms/la1.json': _json({
            'n': {'item': '16.17.1'},
          }),
          '/api/versions.json': _json(['16.17.1']),
          '/cdn/16.17.1/data/en_US/item.json': _catalog('Sword'),
        }),
        store: store,
      );
      await online.resolve(_request());
      final offlineTransport = _FakeTransport(const {});

      final cached = await DataDragonResolver(
        transport: offlineTransport,
        store: store,
      ).resolve(_request());

      expect(cached.fromCache, isTrue);
      expect(offlineTransport.requestedPaths, isEmpty);
    });
  });

  test('file store detects corrupt content-addressed objects', () async {
    final root = await Directory.systemTemp.createTemp('godsense-ddragon-');
    addTearDown(() => root.delete(recursive: true));
    final store = FileDataDragonArtifactStore(root);
    final request = _request();
    final bytes = _catalog('Sword');
    final resolved = await DataDragonResolver(
      transport: _FakeTransport({
        '/realms/la1.json': _json({
          'n': {'item': '16.17.1'},
        }),
        '/api/versions.json': _json(['16.17.1']),
        '/cdn/16.17.1/data/en_US/item.json': bytes,
      }),
      store: store,
    ).resolve(request);
    final object = root
        .listSync(recursive: true)
        .whereType<File>()
        .firstWhere((file) => file.path.endsWith(resolved.contentHash));
    await object.writeAsString('corrupt');

    expect(await store.readResolution(request.cacheIdentity), isNull);
  });
}

DataDragonResolutionRequest _request({
  ClientVersion? clientVersion,
  LeagueLocale? locale,
}) => DataDragonResolutionRequest(
  clientVersion: clientVersion,
  patch: PatchKey('16.17'),
  platformId: PlatformId('LA1'),
  requestedLocale: locale ?? LeagueLocale('en_US'),
  resource: DataDragonResource.items,
  intent: DataDragonResolutionIntent.currentRegional,
);

List<int> _catalog(String name) => _json({
  'type': 'item',
  'data': {
    '1001': {'name': name},
  },
});

List<int> _json(Object value) => utf8.encode(jsonEncode(value));

class _FakeTransport implements DataDragonTransport {
  _FakeTransport(this.responses);

  final Map<String, List<int>> responses;
  final List<String> requestedPaths = [];

  @override
  Future<List<int>> get(Uri uri) async {
    requestedPaths.add(uri.path);
    final response = responses[uri.path];
    if (response == null) throw HttpException('Not found', uri: uri);
    return response;
  }
}

class _MemoryStore implements DataDragonArtifactStore {
  final Map<String, DataDragonArtifact> artifacts = {};

  @override
  Future<DataDragonArtifact?> readResolution(String resolutionKey) async {
    return artifacts[resolutionKey]?.copyWith(fromCache: true);
  }

  @override
  Future<DataDragonArtifact> writeResolution(
    String resolutionKey,
    DataDragonArtifact artifact,
  ) async {
    artifacts[resolutionKey] = artifact;
    return artifact;
  }
}
