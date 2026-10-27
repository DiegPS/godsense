import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../application/artifacts/artifact_downloader.dart';
import '../artifacts/background_artifact_downloader.dart';
import 'tts/tts_model_catalog.dart';

enum TtsInstallPhase {
  idle,
  checking,
  downloading,
  verifying,
  extracting,
  installed,
  error,
}

class TtsInstallProgress {
  final TtsInstallPhase phase;
  final String message;
  final int receivedBytes;
  final int totalBytes;
  final String? path;
  const TtsInstallProgress({
    required this.phase,
    required this.message,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.path,
  });
  double? get fraction =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0, 1) : null;
}

class TtsDownloadCancellation implements ArtifactDownloadCancellation {
  bool _cancelled = false;
  final _listeners = <void Function()>{};
  final _cancelledCompleter = Completer<void>();
  @override
  bool get isCancelled => _cancelled;
  @override
  Future<void> get whenCancelled => _cancelledCompleter.future;
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    if (!_cancelledCompleter.isCompleted) _cancelledCompleter.complete();
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  @override
  void Function() addListener(void Function() listener) {
    if (_cancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  @override
  void throwIfCancelled() {
    if (_cancelled) throw const TtsDownloadCancelledException();
  }
}

class TtsDownloadCancelledException implements Exception {
  const TtsDownloadCancelledException();
  @override
  String toString() => 'TTS model download cancelled.';
}

class TtsModelInstallation {
  final TtsModelDefinition model;
  final Directory directory;
  const TtsModelInstallation(this.model, this.directory);
  String file(String relativePath) =>
      p.joinAll([directory.path, ...relativePath.split('/')]);
}

class TtsModelCache {
  static const _integrityManifestName = '.godsense-integrity.json';
  final ArtifactDownloader _artifactDownloader;
  final Directory? _rootOverride;
  final _verifiedInstallations = <String>{};

  TtsModelCache({ArtifactDownloader? downloader, Directory? rootDirectory})
    : _artifactDownloader = downloader ?? BackgroundArtifactDownloader(),
      _rootOverride = rootDirectory;

  Future<Directory> get rootDirectory async {
    final override = _rootOverride;
    if (override != null) return override;
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'tts', 'models'));
  }

  Future<TtsModelInstallation?> installed(TtsModelDefinition model) async {
    final root = await rootDirectory;
    final directory = Directory(p.join(root.path, model.storageKey));
    final marker = File(p.join(directory.path, '.godsense-model.json'));
    if (!await marker.exists()) return null;
    try {
      final metadata = jsonDecode(await marker.readAsString());
      if (metadata is! Map ||
          metadata['id'] != model.id ||
          metadata['version'] != model.version ||
          metadata['integrity'] != model.integrityKey) {
        return null;
      }
      for (final relativePath in model.requiredFiles) {
        final path = p.joinAll([directory.path, ...relativePath.split('/')]);
        if (!await FileSystemEntity.isFile(path) &&
            !await FileSystemEntity.isDirectory(path)) {
          return null;
        }
      }
      final verificationKey = '${directory.path}|${model.integrityKey}';
      if (!_verifiedInstallations.contains(verificationKey)) {
        final manifest = File(p.join(directory.path, _integrityManifestName));
        if (!await manifest.exists()) return null;
        final decoded = jsonDecode(await manifest.readAsString());
        if (decoded is! Map || decoded['files'] is! List) return null;
        final entries = (decoded['files'] as List)
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false);
        final valid = await _verifyIntegrityInWorker(directory.path, entries);
        if (!valid) return null;
        _verifiedInstallations.add(verificationKey);
      }
      return TtsModelInstallation(model, directory);
    } catch (_) {
      return null;
    }
  }

  Future<TtsModelInstallation> ensureAvailable(
    TtsModelDefinition model, {
    void Function(TtsInstallProgress progress)? onProgress,
    TtsDownloadCancellation? cancellation,
  }) async {
    final activeCancellation = cancellation ?? TtsDownloadCancellation();
    activeCancellation.throwIfCancelled();
    onProgress?.call(
      const TtsInstallProgress(
        phase: TtsInstallPhase.checking,
        message: 'Checking installed model…',
      ),
    );
    activeCancellation.throwIfCancelled();
    final existing = await installed(model);
    activeCancellation.throwIfCancelled();
    if (existing != null) {
      onProgress?.call(
        TtsInstallProgress(
          phase: TtsInstallPhase.installed,
          message: '${model.name} is installed.',
          receivedBytes: model.downloadBytes,
          totalBytes: model.downloadBytes,
          path: existing.directory.path,
        ),
      );
      return existing;
    }
    final root = await rootDirectory;
    activeCancellation.throwIfCancelled();
    await root.create(recursive: true);
    final downloads = Directory(p.join(root.path, '.downloads'));
    await downloads.create(recursive: true);
    final receivedByFile = <String, int>{};
    final partials = <TtsModelDownload, File>{};
    await Future.wait(
      model.downloads.map((download) async {
        final partial = _partialFile(downloads, model, download);
        partials[download] = partial;
        void reportProgress(int received) {
          receivedByFile[download.fileName] = received;
          final totalReceived = receivedByFile.values.fold(0, (a, b) => a + b);
          onProgress?.call(
            TtsInstallProgress(
              phase: TtsInstallPhase.downloading,
              message: 'Downloading ${download.fileName}…',
              receivedBytes: totalReceived,
              totalBytes: model.downloadBytes,
              path: partial.path,
            ),
          );
        }

        try {
          await _artifactDownloader.download(
            ArtifactDownloadRequest(
              id: '${model.storageKey}-${download.fileName}',
              uri: download.uri,
              destinationPath: partial.path,
              expectedBytes: download.bytes,
              group: model.id.startsWith('speech-') ? 'voice-stt' : 'voice-tts',
            ),
            cancellation: activeCancellation,
            onProgress: (progress) => reportProgress(progress.receivedBytes),
          );
        } on ArtifactDownloadCancelledException {
          throw const TtsDownloadCancelledException();
        }
      }),
    );
    activeCancellation.throwIfCancelled();
    var verifiedBytes = 0;
    for (final download in model.downloads) {
      onProgress?.call(
        TtsInstallProgress(
          phase: TtsInstallPhase.verifying,
          message: 'Verifying ${download.fileName}…',
          receivedBytes: verifiedBytes,
          totalBytes: model.downloadBytes,
        ),
      );
      final partial = partials[download]!;
      final digest = await sha256.bind(partial.openRead()).first;
      if (digest.toString() != download.sha256) {
        if (await partial.exists()) await partial.delete();
        throw StateError('${download.fileName} failed its SHA-256 check.');
      }
      verifiedBytes += download.bytes;
      activeCancellation.throwIfCancelled();
    }
    final archiveDownload = model.downloads.singleWhere(
      (download) => download.isArchive,
    );
    final verifiedArchive = partials[archiveDownload]!;
    // `archive_io` selects the decoder from the filename extension. Keep the
    // resumable `.part` file untouched and extract from a verified copy whose
    // name retains the real archive extension.
    final extractionArchive = File(
      p.join(downloads.path, '${model.storageKey}.verified.tar.bz2'),
    );
    if (await extractionArchive.exists()) await extractionArchive.delete();
    await verifiedArchive.copy(extractionArchive.path);
    final staging = Directory(
      p.join(root.path, '.${model.storageKey}.staging'),
    );
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    onProgress?.call(
      TtsInstallProgress(
        phase: TtsInstallPhase.extracting,
        message: 'Installing ${model.name}…',
        receivedBytes: model.downloadBytes,
        totalBytes: model.downloadBytes,
      ),
    );
    try {
      await _extractArchive(
        extractionArchive.path,
        staging.path,
        activeCancellation,
      );
      activeCancellation.throwIfCancelled();
      final extracted = Directory(p.join(staging.path, model.archiveRoot));
      if (!await extracted.exists()) {
        throw StateError('The model archive has an unexpected structure.');
      }
      for (final download in model.downloads.where((item) => !item.isArchive)) {
        final targetPath = download.targetPath;
        if (targetPath == null || targetPath.isEmpty) {
          throw StateError('${download.fileName} has no installation path.');
        }
        final target = File(
          p.joinAll([extracted.path, ...targetPath.split('/')]),
        );
        await target.parent.create(recursive: true);
        await partials[download]!.copy(target.path);
      }
      for (final relativePath in model.removeAfterExtract) {
        final entityPath = p.joinAll([
          extracted.path,
          ...relativePath.split('/'),
        ]);
        final type = await FileSystemEntity.type(entityPath);
        if (type == FileSystemEntityType.file) {
          await File(entityPath).delete();
        } else if (type == FileSystemEntityType.directory) {
          await Directory(entityPath).delete(recursive: true);
        }
      }
      for (final relativePath in model.requiredFiles) {
        final path = p.joinAll([extracted.path, ...relativePath.split('/')]);
        if (!await FileSystemEntity.isFile(path) &&
            !await FileSystemEntity.isDirectory(path)) {
          throw StateError('The model archive is missing $relativePath.');
        }
      }
      final integrityEntries = await _buildIntegrityInWorker(
        extracted.path,
        model.requiredFiles,
      );
      await File(p.join(extracted.path, _integrityManifestName))
          .writeAsString(jsonEncode({'files': integrityEntries}), flush: true);
      await File(p.join(extracted.path, '.godsense-model.json')).writeAsString(
        jsonEncode({
          'id': model.id,
          'version': model.version,
          'integrity': model.integrityKey,
          'installedAt': DateTime.now().toUtc().toIso8601String(),
        }),
        flush: true,
      );
      final target = Directory(p.join(root.path, model.storageKey));
      if (await target.exists()) await target.delete(recursive: true);
      await extracted.rename(target.path);
      _verifiedInstallations.add('${target.path}|${model.integrityKey}');
      await staging.delete(recursive: true);
      if (await extractionArchive.exists()) await extractionArchive.delete();
      for (final partial in partials.values) {
        if (await partial.exists()) await partial.delete();
      }
      onProgress?.call(
        TtsInstallProgress(
          phase: TtsInstallPhase.installed,
          message: '${model.name} is ready.',
          receivedBytes: model.downloadBytes,
          totalBytes: model.downloadBytes,
          path: target.path,
        ),
      );
      return TtsModelInstallation(model, target);
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      if (await extractionArchive.exists()) await extractionArchive.delete();
      rethrow;
    }
  }

  Future<void> _extractArchive(
    String archivePath,
    String outputPath,
    TtsDownloadCancellation cancellation,
  ) async {
    final messages = ReceivePort();
    final errors = ReceivePort();
    final completion = Completer<void>();
    late final StreamSubscription<dynamic> messageSubscription;
    late final StreamSubscription<dynamic> errorSubscription;
    final isolate = await Isolate.spawn(
      _extractWorker,
      {
        'archive': archivePath,
        'output': outputPath,
        'reply': messages.sendPort,
      },
      onError: errors.sendPort,
      errorsAreFatal: true,
    );
    messageSubscription = messages.listen((dynamic message) {
      if (completion.isCompleted) return;
      if (message is String) {
        completion.completeError(StateError(message));
      } else {
        completion.complete();
      }
    });
    errorSubscription = errors.listen((dynamic error) {
      if (!completion.isCompleted) {
        completion.completeError(StateError('Model extraction failed: $error'));
      }
    });
    final timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (cancellation.isCancelled && !completion.isCompleted) {
        isolate.kill(priority: Isolate.immediate);
        completion.completeError(const TtsDownloadCancelledException());
      }
    });
    try {
      await completion.future;
    } finally {
      timer.cancel();
      isolate.kill(priority: Isolate.immediate);
      await messageSubscription.cancel();
      await errorSubscription.cancel();
      messages.close();
      errors.close();
    }
  }

  static Future<void> _extractWorker(Map<String, Object> message) async {
    final reply = message['reply']! as SendPort;
    try {
      await extractFileToDisk(
        message['archive']! as String,
        message['output']! as String,
      );
      reply.send(true);
    } catch (error, stack) {
      reply.send('$error\n$stack');
    }
  }

  File _partialFile(
    Directory downloads,
    TtsModelDefinition model,
    TtsModelDownload download,
  ) {
    final suffix = download.isArchive
        ? 'tar.bz2'
        : download.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return File(p.join(downloads.path, '${model.storageKey}.$suffix.part'));
  }

  Future<void> remove(TtsModelDefinition model) async {
    final root = await rootDirectory;
    final target = Directory(p.join(root.path, model.storageKey));
    if (await target.exists()) await target.delete(recursive: true);
    _verifiedInstallations.removeWhere(
      (key) => key.startsWith('${target.path}|'),
    );
  }

  static Future<List<Map<String, Object>>> _buildIntegrityInWorker(
    String directoryPath,
    List<String> requiredPaths,
  ) async {
    final result = await _runIntegrityWorker({
      'type': 'build',
      'directory': directoryPath,
      'requiredPaths': List<String>.from(requiredPaths),
    });
    return (result as List)
        .map((entry) => Map<String, Object>.from(entry as Map))
        .toList(growable: false);
  }

  static Future<bool> _verifyIntegrityInWorker(
    String directoryPath,
    List<Map<String, dynamic>> entries,
  ) async {
    final result = await _runIntegrityWorker({
      'type': 'verify',
      'directory': directoryPath,
      'entries': entries,
    });
    return result == true;
  }

  static Future<Object?> _runIntegrityWorker(Map<String, Object> job) async {
    final messages = ReceivePort();
    final errors = ReceivePort();
    final isolate = await Isolate.spawn(
      _integrityWorker,
      {...job, 'reply': messages.sendPort},
      errorsAreFatal: true,
      onError: errors.sendPort,
    );
    try {
      final result = await Future.any<Object?>([
        messages.first,
        errors.first.then<Object?>(
          (error) => throw StateError('Integrity worker failed: $error'),
        ),
      ]);
      if (result is Map && result['error'] != null) {
        throw StateError(result['error'] as String);
      }
      return result;
    } finally {
      isolate.kill(priority: Isolate.immediate);
      messages.close();
      errors.close();
    }
  }

  static Future<void> _integrityWorker(Map<String, Object> job) async {
    final reply = job['reply']! as SendPort;
    try {
      final directory = job['directory']! as String;
      if (job['type'] == 'build') {
        reply.send(
          await _buildIntegrityManifest(
            directory,
            List<String>.from(job['requiredPaths']! as List),
          ),
        );
      } else {
        reply.send(
          await _verifyIntegrityManifest(
            directory,
            (job['entries']! as List)
                .map((entry) => Map<String, dynamic>.from(entry as Map))
                .toList(growable: false),
          ),
        );
      }
    } catch (error, stack) {
      reply.send({'error': '$error\n$stack'});
    }
  }

  static Future<List<Map<String, Object>>> _buildIntegrityManifest(
    String directoryPath,
    List<String> requiredPaths,
  ) async {
    final directory = Directory(directoryPath);
    final files = <String, File>{};
    for (final requiredPath in requiredPaths) {
      final entityPath = p.joinAll([
        directory.path,
        ...requiredPath.split('/'),
      ]);
      final type = FileSystemEntity.typeSync(entityPath);
      if (type == FileSystemEntityType.file) {
        final file = File(entityPath);
        files[p.relative(file.path, from: directory.path)] = file;
      } else if (type == FileSystemEntityType.directory) {
        for (final entity in Directory(entityPath).listSync(recursive: true)) {
          if (entity is File) {
            files[p.relative(entity.path, from: directory.path)] = entity;
          }
        }
      }
    }
    final entries = <Map<String, Object>>[];
    final paths = files.keys.toList()..sort();
    for (final relativePath in paths) {
      final file = files[relativePath]!;
      final digest = await sha256.bind(file.openRead()).first;
      entries.add({
        'path': relativePath.replaceAll('\\', '/'),
        'bytes': await file.length(),
        'sha256': digest.toString(),
      });
    }
    return entries;
  }

  static Future<bool> _verifyIntegrityManifest(
    String directoryPath,
    List<Map<String, dynamic>> entries,
  ) async {
    if (entries.isEmpty) return false;
    final root = p.canonicalize(directoryPath);
    for (final entry in entries) {
      final relativePath = entry['path'];
      final expectedBytes = entry['bytes'];
      final expectedDigest = entry['sha256'];
      if (relativePath is! String ||
          expectedBytes is! int ||
          expectedDigest is! String) {
        return false;
      }
      final filePath = p.canonicalize(
        p.joinAll([directoryPath, ...relativePath.split('/')]),
      );
      if (!p.isWithin(root, filePath)) return false;
      final file = File(filePath);
      if (!await file.exists() || await file.length() != expectedBytes) {
        return false;
      }
      final digest = await sha256.bind(file.openRead()).first;
      if (digest.toString() != expectedDigest) return false;
    }
    return true;
  }

  void dispose() {}
}
