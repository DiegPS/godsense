import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../domain/artifacts/artifact_spec.dart';
import 'artifact_downloader.dart';

typedef ArtifactInstallationValidator = Future<void> Function(
  ArtifactSpec spec,
  Directory installation,
);

class ArtifactInstaller {
  ArtifactInstaller({
    required Directory rootDirectory,
    required this._downloader,
    this._validator,
  }) : _root = rootDirectory;

  static const _markerName = '.godsense-artifact.json';

  final Directory _root;
  final ArtifactDownloader _downloader;
  final ArtifactInstallationValidator? _validator;

  Future<ArtifactInstallation?> installed(ArtifactSpec spec) async {
    _validateSpec(spec);
    final directory = _versionDirectory(spec);
    final marker = File(p.join(directory.path, _markerName));
    if (!await marker.exists()) return null;
    try {
      final value = jsonDecode(await marker.readAsString());
      if (value is! Map ||
          value['id'] != spec.id ||
          value['version'] != spec.version ||
          value['fingerprint'] != _fingerprint(spec)) {
        return null;
      }
      if (!await _hasRequiredPaths(directory, spec.requiredPaths)) return null;
      await _validator?.call(spec, directory);
      return ArtifactInstallation(spec: spec, directoryPath: directory.path);
    } catch (_) {
      return null;
    }
  }

  Future<ArtifactInstallation> install(
    ArtifactSpec spec, {
    ArtifactDownloadCancellation? cancellation,
    void Function(ArtifactInstallProgress progress)? onProgress,
  }) async {
    _validateSpec(spec);
    onProgress?.call(
      const ArtifactInstallProgress(
        phase: ArtifactInstallPhase.checking,
        message: 'Checking artifact…',
      ),
    );
    final existing = await installed(spec);
    if (existing != null) {
      await _activate(spec);
      return existing;
    }

    cancellation?.throwIfCancelled();
    final totalBytes = spec.payloads.fold<int>(
      0,
      (sum, file) => sum + file.bytes,
    );
    final family = _familyDirectory(spec);
    final versions = Directory(p.join(family.path, 'versions'));
    final downloads = Directory(
      p.join(
        _root.path,
        '.downloads',
        _safe(spec.group),
        _safe(spec.id),
        _safe(spec.version),
      ),
    );
    final staging = Directory(
      p.join(
        family.path,
        '.staging-${_safe(spec.version)}-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await versions.create(recursive: true);
    await downloads.create(recursive: true);
    await staging.create(recursive: true);

    final received = <String, int>{};
    final localFiles = <ArtifactPayloadSpec, File>{};
    try {
      for (var index = 0; index < spec.payloads.length; index++) {
        final payload = spec.payloads[index];
        cancellation?.throwIfCancelled();
        final local = File(
          p.join(
            downloads.path,
            '${index.toString().padLeft(2, '0')}-${_safeFile(payload.fileName)}',
          ),
        );
        localFiles[payload] = local;
        if (!await _matchesPayload(local, payload)) {
          if (await local.exists()) await local.delete();
          await _downloader.download(
            ArtifactDownloadRequest(
              id: '${spec.id}-${spec.version}-${payload.id}',
              uri: payload.uri,
              destinationPath: local.path,
              expectedBytes: payload.bytes,
              group: spec.group,
              headers: payload.headers,
            ),
            cancellation: cancellation,
            onProgress: (progress) {
              received[payload.id] = progress.receivedBytes;
              onProgress?.call(
                ArtifactInstallProgress(
                  phase: ArtifactInstallPhase.downloading,
                  message: 'Downloading ${payload.fileName}…',
                  receivedBytes: received.values.fold(0, (a, b) => a + b),
                  totalBytes: totalBytes,
                ),
              );
            },
          );
        }
        onProgress?.call(
          ArtifactInstallProgress(
            phase: ArtifactInstallPhase.verifying,
            message: 'Verifying ${payload.fileName}…',
            receivedBytes: received.values.fold(0, (a, b) => a + b),
            totalBytes: totalBytes,
          ),
        );
        if (!await _matchesPayload(local, payload)) {
          if (await local.exists()) await local.delete();
          throw StateError(
            '${payload.fileName} failed integrity verification.',
          );
        }
        received[payload.id] = payload.bytes;
      }

      cancellation?.throwIfCancelled();
      final unpacked = Directory(p.join(staging.path, 'unpacked'));
      await unpacked.create(recursive: true);
      for (final entry in localFiles.entries) {
        final payload = entry.key;
        if (payload.archiveType == ArtifactArchiveType.none) continue;
        onProgress?.call(
          ArtifactInstallProgress(
            phase: ArtifactInstallPhase.extracting,
            message: 'Extracting ${payload.fileName}…',
            receivedBytes: totalBytes,
            totalBytes: totalBytes,
          ),
        );
        await extractFileToDisk(entry.value.path, unpacked.path);
      }

      final archiveRoot = spec.archiveRoot;
      final content = archiveRoot == null
          ? unpacked
          : Directory(_inside(unpacked.path, archiveRoot));
      if (!await content.exists()) {
        throw StateError('Artifact archive has an unexpected structure.');
      }
      for (final entry in localFiles.entries) {
        final payload = entry.key;
        if (payload.archiveType != ArtifactArchiveType.none) continue;
        final relativeTarget = payload.targetPath;
        if (relativeTarget == null || relativeTarget.isEmpty) {
          throw StateError('${payload.fileName} has no installation path.');
        }
        final target = File(_inside(content.path, relativeTarget));
        await target.parent.create(recursive: true);
        await entry.value.copy(target.path);
      }
      for (final relativePath in spec.removeAfterExtract) {
        final path = _inside(content.path, relativePath);
        final type = await FileSystemEntity.type(path);
        if (type == FileSystemEntityType.file) {
          await File(path).delete();
        } else if (type == FileSystemEntityType.directory) {
          await Directory(path).delete(recursive: true);
        }
      }

      onProgress?.call(
        ArtifactInstallProgress(
          phase: ArtifactInstallPhase.validating,
          message: 'Validating installation…',
          receivedBytes: totalBytes,
          totalBytes: totalBytes,
        ),
      );
      if (!await _hasRequiredPaths(content, spec.requiredPaths)) {
        throw StateError('Artifact installation is incomplete.');
      }
      await _validator?.call(spec, content);
      await File(p.join(content.path, _markerName)).writeAsString(
        jsonEncode({
          'id': spec.id,
          'version': spec.version,
          'fingerprint': _fingerprint(spec),
          'installedAt': DateTime.now().toUtc().toIso8601String(),
        }),
        flush: true,
      );

      cancellation?.throwIfCancelled();
      onProgress?.call(
        ArtifactInstallProgress(
          phase: ArtifactInstallPhase.activating,
          message: 'Activating ${spec.id}…',
          receivedBytes: totalBytes,
          totalBytes: totalBytes,
        ),
      );
      final target = _versionDirectory(spec);
      final backup = Directory('${target.path}.rollback');
      if (await backup.exists()) await backup.delete(recursive: true);
      if (await target.exists()) await target.rename(backup.path);
      try {
        await content.rename(target.path);
      } catch (_) {
        if (!await target.exists() && await backup.exists()) {
          await backup.rename(target.path);
        }
        rethrow;
      }
      await _activate(spec);
      if (await backup.exists()) await backup.delete(recursive: true);
      if (await downloads.exists()) await downloads.delete(recursive: true);
      onProgress?.call(
        ArtifactInstallProgress(
          phase: ArtifactInstallPhase.installed,
          message: '${spec.id} is ready.',
          receivedBytes: totalBytes,
          totalBytes: totalBytes,
        ),
      );
      return ArtifactInstallation(spec: spec, directoryPath: target.path);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Future<void> activateInstalledVersion(
    String group,
    String id,
    String version,
  ) async {
    final specDirectory = Directory(
      p.join(_root.path, _safe(group), _safe(id), 'versions', _safe(version)),
    );
    if (!await File(p.join(specDirectory.path, _markerName)).exists()) {
      throw StateError('$id $version is not installed.');
    }
    await _writeActive(
      Directory(p.join(_root.path, _safe(group), _safe(id))),
      id,
      version,
    );
  }

  Directory _familyDirectory(ArtifactSpec spec) =>
      Directory(p.join(_root.path, _safe(spec.group), _safe(spec.id)));

  Directory _versionDirectory(ArtifactSpec spec) => Directory(
    p.join(_familyDirectory(spec).path, 'versions', _safe(spec.version)),
  );

  Future<void> _activate(ArtifactSpec spec) =>
      _writeActive(_familyDirectory(spec), spec.id, spec.version);

  Future<void> _writeActive(Directory family, String id, String version) async {
    await family.create(recursive: true);
    final active = File(p.join(family.path, 'active.json'));
    final previous = File('${active.path}.previous');
    final next = File('${active.path}.next');
    if (!await active.exists() && await previous.exists()) {
      await previous.rename(active.path);
    }
    String? previousVersion;
    if (await active.exists()) {
      try {
        final value = jsonDecode(await active.readAsString());
        if (value is Map) previousVersion = value['version']?.toString();
      } catch (_) {}
    }
    if (await next.exists()) await next.delete();
    await next.writeAsString(
      jsonEncode({
        'id': id,
        'version': version,
        if (previousVersion != null && previousVersion != version)
          'previousVersion': previousVersion,
        'activatedAt': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
    if (await previous.exists()) await previous.delete();
    if (await active.exists()) await active.rename(previous.path);
    try {
      await next.rename(active.path);
    } catch (_) {
      if (!await active.exists() && await previous.exists()) {
        await previous.rename(active.path);
      }
      rethrow;
    }
    if (await previous.exists()) await previous.delete();
  }

  static Future<bool> _matchesPayload(
    File file,
    ArtifactPayloadSpec payload,
  ) async {
    if (!await file.exists() || await file.length() != payload.bytes) {
      return false;
    }
    return (await sha256.bind(file.openRead()).first).toString() ==
        payload.sha256.toLowerCase();
  }

  static Future<bool> _hasRequiredPaths(
    Directory root,
    List<String> paths,
  ) async {
    for (final relative in paths) {
      if (await FileSystemEntity.type(_inside(root.path, relative)) ==
          FileSystemEntityType.notFound) {
        return false;
      }
    }
    return true;
  }

  static String _fingerprint(ArtifactSpec spec) => sha256
      .convert(
        utf8.encode(
          '${spec.id}|${spec.version}|${spec.payloads.map((item) => '${item.id}:${item.sha256}:${item.targetPath ?? ''}').join('|')}',
        ),
      )
      .toString();

  static void _validateSpec(ArtifactSpec spec) {
    if (spec.id.isEmpty || spec.version.isEmpty || spec.group.isEmpty) {
      throw ArgumentError('Artifact id, version, and group are required.');
    }
    if (spec.payloads.isEmpty || spec.requiredPaths.isEmpty) {
      throw ArgumentError('Artifact payloads and required paths are required.');
    }
    final ids = <String>{};
    for (final payload in spec.payloads) {
      if (!ids.add(payload.id)) throw ArgumentError('Duplicate payload id.');
      if (payload.uri.scheme != 'https' || payload.bytes <= 0) {
        throw ArgumentError('Artifact payloads require HTTPS and a byte size.');
      }
      if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(payload.sha256)) {
        throw ArgumentError('Artifact payloads require a SHA-256 digest.');
      }
      if (!_matchesArchiveExtension(payload.fileName, payload.archiveType)) {
        throw ArgumentError(
          '${payload.fileName} does not match ${payload.archiveType.name}.',
        );
      }
    }
    for (final path in [
      ...spec.requiredPaths,
      ...spec.removeAfterExtract,
      if (spec.archiveRoot != null) spec.archiveRoot!,
      ...spec.payloads.map((item) => item.targetPath).whereType<String>(),
    ]) {
      _inside('C:${p.separator}godsense-artifact-root', path);
    }
  }

  static String _inside(String root, String relative) {
    if (relative.isEmpty || p.isAbsolute(relative)) {
      throw ArgumentError('Artifact paths must be non-empty and relative.');
    }
    final resolved = p.normalize(p.join(root, relative));
    if (!p.isWithin(p.normalize(root), resolved)) {
      throw ArgumentError('Artifact path escapes its installation directory.');
    }
    return resolved;
  }

  static String _safe(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  static String _safeFile(String value) => _safe(p.basename(value));

  static bool _matchesArchiveExtension(
    String fileName,
    ArtifactArchiveType type,
  ) {
    final name = fileName.toLowerCase();
    return switch (type) {
      ArtifactArchiveType.none => true,
      ArtifactArchiveType.zip => name.endsWith('.zip'),
      ArtifactArchiveType.tar => name.endsWith('.tar'),
      ArtifactArchiveType.tarGzip =>
        name.endsWith('.tar.gz') || name.endsWith('.tgz'),
      ArtifactArchiveType.tarBzip2 =>
        name.endsWith('.tar.bz2') || name.endsWith('.tbz2'),
      ArtifactArchiveType.tarXz =>
        name.endsWith('.tar.xz') || name.endsWith('.txz'),
    };
  }
}
