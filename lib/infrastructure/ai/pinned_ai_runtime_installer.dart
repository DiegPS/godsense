// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import '../../application/ai/ai_runtime_services.dart';
import '../../application/artifacts/artifact_downloader.dart';
import '../../application/artifacts/artifact_installer.dart';
import '../../domain/ai/ai_runtime_models.dart';
import '../../domain/artifacts/artifact_spec.dart';
import '../artifacts/background_artifact_downloader.dart';
import 'ai_runtime_paths.dart';
import 'pinned_ai_runtime_catalog.dart';

class PinnedAiRuntimeInstaller implements AiRuntimeInstallService {
  PinnedAiRuntimeInstaller({
    required AiRuntimePaths paths,
    ArtifactDownloader? downloader,
    Map<AiRuntimeKind, String?> devExecutablePaths = const {},
  }) : _devExecutablePaths = devExecutablePaths,
       _installer = ArtifactInstaller(
         rootDirectory: paths.root,
         downloader: downloader ?? BackgroundArtifactDownloader(),
         validator: _validateExecutable,
       );

  static const _catalog = PinnedAiRuntimeCatalog();
  final ArtifactInstaller _installer;
  final Map<AiRuntimeKind, String?> _devExecutablePaths;

  @override
  AiRuntimeDefinition definition(AiRuntimeKind kind) =>
      _catalog.definition(kind);

  @override
  Future<AiRuntimeInstallation?> installed(AiRuntimeKind kind) async {
    final runtime = definition(kind);
    final installation = await _installer.installed(runtime.package);
    if (installation != null) {
      return AiRuntimeInstallation(
        definition: runtime,
        directoryPath: installation.directoryPath,
      );
    }
    final devPath = _devExecutablePaths[kind];
    if (devPath != null && devPath.isNotEmpty && await File(devPath).exists()) {
      return AiRuntimeInstallation(
        definition: runtime,
        directoryPath: File(devPath).parent.path,
      );
    }
    return null;
  }

  @override
  Future<AiRuntimeInstallation> install(
    AiRuntimeKind kind, {
    ArtifactDownloadCancellation? cancellation,
    void Function(ArtifactInstallProgress progress)? onProgress,
  }) async {
    final runtime = definition(kind);
    final installation = await _installer.install(
      runtime.package,
      cancellation: cancellation,
      onProgress: onProgress,
    );
    return AiRuntimeInstallation(
      definition: runtime,
      directoryPath: installation.directoryPath,
    );
  }

  static Future<void> _validateExecutable(
    ArtifactSpec artifact,
    Directory installation,
  ) async {
    final executable = File(
      '${installation.path}${Platform.pathSeparator}'
      '${artifact.requiredPaths.single}',
    );
    if (!await executable.exists() || await executable.length() < 1024 * 1024) {
      throw StateError('The runtime executable is missing or incomplete.');
    }
    final signature = await executable
        .openRead(0, 2)
        .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
    if (signature.length != 2 || signature[0] != 0x4d || signature[1] != 0x5a) {
      throw StateError('The runtime executable is not a Windows PE file.');
    }
  }
}
