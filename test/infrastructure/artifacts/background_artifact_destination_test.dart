import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/artifacts/artifact_downloader.dart';
import 'package:godsense/infrastructure/artifacts/background_artifact_downloader.dart';
import 'package:path/path.dart' as p;

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final destination in [
    r'C:\Users\player\AppData\Roaming\GodSense\ai_runtimes\.downloads\opencode.zip',
    r'D:\Mis modelos\GodSense\kilo.zip',
    r'relative\cache\model.zip',
  ]) {
    test(
      'download task preserves the full destination: $destination',
      () async {
        final request = ArtifactDownloadRequest(
          id: 'test-artifact',
          uri: Uri.parse('https://example.test/model.zip'),
          destinationPath: destination,
          expectedBytes: 123,
          group: 'ai',
        );
        final task = await BackgroundArtifactDownloader.createTask(request);
        final expected = File(destination).absolute.path;
        expect(task.baseDirectory, BaseDirectory.root);
        expect(p.equals(await task.filePath(), expected), isTrue);
        expect(p.isAbsolute(await task.filePath()), isTrue);
        expect(task.taskId, startsWith('v2-'));
        final restored = Task.createFromJson(task.toJson());
        expect(p.equals(await restored.filePath(), expected), isTrue);
        expect(task.allowPause, isTrue);
      },
      skip: !Platform.isWindows,
    );
  }

  test('legacy stripped destination is relative on Windows', () async {
    final broken = DownloadTask(
      url: 'https://example.test/file.zip',
      baseDirectory: BaseDirectory.root,
      directory: r'Users\player\cache',
      filename: 'file.zip',
    );
    expect(p.isAbsolute(await broken.filePath()), isFalse);
  }, skip: !Platform.isWindows);
}
