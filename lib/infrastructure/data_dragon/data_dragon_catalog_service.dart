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
}
