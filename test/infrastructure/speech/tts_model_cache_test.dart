import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/artifacts/artifact_downloader.dart';
import 'package:godsense/infrastructure/speech/tts/tts_model_catalog.dart';
import 'package:godsense/infrastructure/speech/tts_model_cache.dart';

void main() {
  late Directory root;
  late List<int> archiveBytes;
  late TtsModelDefinition model;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('godsense-tts-cache-test-');
    final archive = Archive()
      ..addFile(ArchiveFile('fixture/model.onnx', 5, [1, 2, 3, 4, 5]));
    archiveBytes = BZip2Encoder().encode(TarEncoder().encode(archive));
    model = _model(archiveBytes);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'installs through the shared downloader after integrity checks',
    () async {
      final downloader = _MemoryDownloader({
        model.downloads.single.uri: archiveBytes,
      });
      final cache = TtsModelCache(downloader: downloader, rootDirectory: root);

      final installation = await cache.ensureAvailable(model);

      expect(await File(installation.file('model.onnx')).readAsBytes(), [
        1,
        2,
        3,
        4,
        5,
      ]);
      expect(await cache.installed(model), isNotNull);
      expect(downloader.requests, hasLength(1));
      expect(downloader.requests.single.group, 'voice-tts');
    },
  );

  test('installs supplementary files and removes replaced artifacts', () async {
    const vocoderBytes = [9, 8, 7, 6];
    final archive = Archive()
      ..addFile(ArchiveFile('fixture/model.onnx', 1, [1]))
      ..addFile(ArchiveFile('fixture/old-vocoder.onnx', 1, [2]));
    final bytes = BZip2Encoder().encode(TarEncoder().encode(archive));
    final multiFileModel = _model(
      bytes,
      id: 'multi-file-fixture',
      extraDownloads: [
        TtsModelDownload(
          uri: Uri.parse('https://example.test/vocoder.onnx'),
          fileName: 'vocoder.onnx',
          targetPath: 'vocoder.onnx',
          bytes: vocoderBytes.length,
          sha256: sha256.convert(vocoderBytes).toString(),
        ),
      ],
      requiredFiles: const ['model.onnx', 'vocoder.onnx'],
      removeAfterExtract: const ['old-vocoder.onnx'],
    );
    final downloader = _MemoryDownloader({
      multiFileModel.downloads.first.uri: bytes,
      multiFileModel.downloads.last.uri: vocoderBytes,
    });

    final installation = await TtsModelCache(
      downloader: downloader,
      rootDirectory: root,
    ).ensureAvailable(multiFileModel);

    expect(
      await File(installation.file('vocoder.onnx')).readAsBytes(),
      vocoderBytes,
    );
    expect(await File(installation.file('old-vocoder.onnx')).exists(), isFalse);
  });

  test('rejects and removes a payload with the wrong digest', () async {
    final corrupt = [...archiveBytes]..[archiveBytes.length ~/ 2] ^= 0xff;
    final downloader = _MemoryDownloader({model.downloads.single.uri: corrupt});
    final cache = TtsModelCache(downloader: downloader, rootDirectory: root);

    await expectLater(cache.ensureAvailable(model), throwsStateError);

    expect(await cache.installed(model), isNull);
    expect(
      await File(
        '${root.path}${Platform.pathSeparator}.downloads'
        '${Platform.pathSeparator}${model.storageKey}.tar.bz2.part',
      ).exists(),
      isFalse,
    );
  });

  test('cancellation stops installation without publishing a model', () async {
    final cancellation = TtsDownloadCancellation();
    final downloader = _MemoryDownloader({
      model.downloads.single.uri: archiveBytes,
    });
    final cache = TtsModelCache(downloader: downloader, rootDirectory: root);

    await expectLater(
      cache.ensureAvailable(
        model,
        cancellation: cancellation,
        onProgress: (progress) {
          if (progress.phase == TtsInstallPhase.downloading) {
            cancellation.cancel();
          }
        },
      ),
      throwsA(isA<TtsDownloadCancelledException>()),
    );

    expect(await cache.installed(model), isNull);
  });

  test('detects modifications to an installed required file', () async {
    final downloader = _MemoryDownloader({
      model.downloads.single.uri: archiveBytes,
    });
    final cache = TtsModelCache(downloader: downloader, rootDirectory: root);
    final installation = await cache.ensureAvailable(model);
    await File(installation.file('model.onnx')).writeAsBytes([1, 2]);

    final freshProcessCache = TtsModelCache(
      downloader: downloader,
      rootDirectory: root,
    );

    expect(await freshProcessCache.installed(model), isNull);
  });
}

TtsModelDefinition _model(
  List<int> archiveBytes, {
  String id = 'fixture',
  List<TtsModelDownload> extraDownloads = const [],
  List<String> requiredFiles = const ['model.onnx'],
  List<String> removeAfterExtract = const [],
}) {
  return TtsModelDefinition(
    id: id,
    version: '1',
    name: 'Fixture',
    description: 'Test model',
    family: TtsModelFamily.vits,
    downloads: [
      TtsModelDownload(
        uri: Uri.parse('https://example.test/$id.tar.bz2'),
        fileName: '$id.tar.bz2',
        bytes: archiveBytes.length,
        sha256: sha256.convert(archiveBytes).toString(),
        isArchive: true,
      ),
      ...extraDownloads,
    ],
    installedBytes: 5,
    archiveRoot: 'fixture',
    requiredFiles: requiredFiles,
    removeAfterExtract: removeAfterExtract,
    modelFiles: const {'model': 'model.onnx'},
    languages: const [TtsLanguageOption('es', 'Español')],
    voices: const [TtsVoiceOption('voice', 'Voice', 0)],
    licenseName: 'Test',
    licenseUri: Uri.parse('https://example.test/license'),
  );
}

class _MemoryDownloader implements ArtifactDownloader {
  _MemoryDownloader(this.responses);

  final Map<Uri, List<int>> responses;
  final requests = <ArtifactDownloadRequest>[];

  @override
  Future<void> download(
    ArtifactDownloadRequest request, {
    ArtifactDownloadCancellation? cancellation,
    void Function(ArtifactDownloadProgress progress)? onProgress,
  }) async {
    requests.add(request);
    cancellation?.throwIfCancelled();
    final bytes = responses[request.uri];
    if (bytes == null) throw StateError('Missing fixture for ${request.uri}');
    final file = File(request.destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    onProgress?.call(
      ArtifactDownloadProgress(
        receivedBytes: bytes.length,
        totalBytes: request.expectedBytes,
      ),
    );
    cancellation?.throwIfCancelled();
  }
}
