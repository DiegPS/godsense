import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../domain/data_dragon/data_dragon_models.dart';
import '../../domain/identity/league_identity.dart';

abstract interface class DataDragonArtifactStore {
  Future<DataDragonArtifact?> readResolution(String resolutionKey);

  Future<DataDragonArtifact> writeResolution(
    String resolutionKey,
    DataDragonArtifact artifact,
  );
}

class FileDataDragonArtifactStore implements DataDragonArtifactStore {
  FileDataDragonArtifactStore(this.root);

  final Directory root;

  @override
  Future<DataDragonArtifact?> readResolution(String resolutionKey) async {
    try {
      final manifest = File(_manifestPath(resolutionKey));
      if (!await manifest.exists()) return null;
      final raw = jsonDecode(await manifest.readAsString());
      if (raw is! Map) return null;
      final values = raw.map((key, value) => MapEntry(key.toString(), value));
      final contentHash = values['contentHash']?.toString() ?? '';
      if (!_isSha256(contentHash)) return null;
      final object = File(_objectPath(contentHash));
      if (!await object.exists()) return null;
      final bytes = await object.readAsBytes();
      if (sha256.convert(bytes).toString() != contentHash) return null;
      return DataDragonArtifact(
        clientVersion: values['clientVersion'] == null
            ? null
            : ClientVersion(values['clientVersion'].toString()),
        requestedPatch: PatchKey(values['requestedPatch'].toString()),
        resolvedVersion: DataDragonVersion(
          values['resolvedVersion'].toString(),
        ),
        requestedLocale: LeagueLocale(values['requestedLocale'].toString()),
        resolvedLocale: LeagueLocale(values['resolvedLocale'].toString()),
        resource: DataDragonResource.values.byName(
          values['resource'].toString(),
        ),
        contentHash: contentHash,
        bytes: bytes,
        resolvedAt: DateTime.parse(values['resolvedAt'].toString()).toUtc(),
        validatorVersion: (values['validatorVersion'] as num).toInt(),
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DataDragonArtifact> writeResolution(
    String resolutionKey,
    DataDragonArtifact artifact,
  ) async {
    final computedHash = sha256.convert(artifact.bytes).toString();
    if (computedHash != artifact.contentHash) {
      throw StateError('Artifact content hash does not match its bytes.');
    }
    final object = File(_objectPath(computedHash));
    await object.parent.create(recursive: true);
    if (!await object.exists()) {
      final temporary = File(
        '${object.path}.tmp-$pid-${DateTime.now().microsecondsSinceEpoch}',
      );
      await temporary.writeAsBytes(artifact.bytes, flush: true);
      try {
        await temporary.rename(object.path);
      } on FileSystemException {
        if (!await object.exists()) rethrow;
        await temporary.delete();
      }
    }

    final manifest = File(_manifestPath(resolutionKey));
    await manifest.parent.create(recursive: true);
    final temporary = File(
      '${manifest.path}.tmp-$pid-${DateTime.now().microsecondsSinceEpoch}',
    );
    await temporary.writeAsString(
      jsonEncode({
        'clientVersion': artifact.clientVersion?.value,
        'requestedPatch': artifact.requestedPatch.value,
        'resolvedVersion': artifact.resolvedVersion.value,
        'requestedLocale': artifact.requestedLocale.value,
        'resolvedLocale': artifact.resolvedLocale.value,
        'resource': artifact.resource.name,
        'contentHash': computedHash,
        'resolvedAt': artifact.resolvedAt.toUtc().toIso8601String(),
        'validatorVersion': artifact.validatorVersion,
      }),
      flush: true,
    );
    await temporary.rename(manifest.path);
    return artifact;
  }

  String _objectPath(String hash) =>
      p.join(root.path, 'objects', hash.substring(0, 2), hash);

  String _manifestPath(String resolutionKey) {
    final keyHash = sha256.convert(utf8.encode(resolutionKey)).toString();
    return p.join(root.path, 'resolutions', '$keyHash.json');
  }
}

bool _isSha256(String value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
