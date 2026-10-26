import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/artifacts/artifact_downloader.dart';
import 'package:godsense/infrastructure/speech/tts_model_cache.dart';
import 'package:path/path.dart' as p;

import '../test/support/voice_model_cases.dart';

void main() {
  test(
    'install every native voice fixture using the production verified cache',
    () async {
      final fixtureRoot = Directory('build/testing/voice-models').absolute;
      final original = TtsModelCache(
        rootDirectory: Directory(
          p.join(
            Platform.environment['APPDATA']!,
            'com.godsense',
            'godsense',
            'tts',
            'models',
          ),
        ),
      );
      final cache = TtsModelCache(
        rootDirectory: fixtureRoot,
        downloader: _PrefetchedModels(),
      );
      final installations = <String, String>{};
      final failures = <String>[];
      try {
        for (final item in voiceModelCases) {
          try {
            final existing = await original.installed(item.model);
            final installation =
                existing ?? await cache.ensureAvailable(item.model);
            expect(await installation.directory.exists(), true);
            if (existing == null) {
              expect(await cache.installed(item.model), isNotNull);
            }
            installations[item.environmentKey] = installation.directory.path;
          } catch (error) {
            failures.add('${item.model.id}: $error');
          }
        }
        await File('build/testing/voice-test-models.json')
            .writeAsString(jsonEncode(installations));
        expect(failures, isEmpty, reason: failures.join('\n'));
      } finally {
        original.dispose();
        cache.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

class _PrefetchedModels implements ArtifactDownloader {
  @override
  Future<void> download(
    ArtifactDownloadRequest request, {
    ArtifactDownloadCancellation? cancellation,
    void Function(ArtifactDownloadProgress)? onProgress,
  }) async {
    cancellation?.throwIfCancelled();
    for (final item in voiceModelCases) {
      for (final download in item.model.downloads) {
        if (download.uri != request.uri) continue;
        final source = File(
          p.join(
            'build',
            'testing',
            'model-downloads',
            item.model.storageKey,
            download.fileName,
          ),
        );
        if (!await source.exists()) {
          throw StateError(
            'Run tool/prefetch_voice_test_models.ps1 before preparing ${item.model.id}.',
          );
        }
        await source.copy(request.destinationPath);
        cancellation?.throwIfCancelled();
        onProgress?.call(
          ArtifactDownloadProgress(
            receivedBytes: await source.length(),
            totalBytes: request.expectedBytes,
          ),
        );
        return;
      }
    }
    throw StateError('Unknown pinned fixture download.');
  }
}
