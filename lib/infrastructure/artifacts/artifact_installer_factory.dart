import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../application/artifacts/artifact_downloader.dart';
import '../../application/artifacts/artifact_installer.dart';
import 'background_artifact_downloader.dart';

class ArtifactInstallerFactory {
  ArtifactInstallerFactory({ArtifactDownloader? downloader})
    : _downloader = downloader ?? BackgroundArtifactDownloader();

  final ArtifactDownloader _downloader;

  Future<ArtifactInstaller> create({
    Directory? rootDirectory,
    ArtifactInstallationValidator? validator,
  }) async {
    final root = rootDirectory ?? await _defaultRoot();
    return ArtifactInstaller(
      rootDirectory: root,
      downloader: _downloader,
      validator: validator,
    );
  }

  static Future<Directory> _defaultRoot() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'artifacts'));
  }
}
