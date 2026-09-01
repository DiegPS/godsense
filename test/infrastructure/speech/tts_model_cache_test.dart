import 'dart:async';
import 'dart:io';

import 'package:godsense/infrastructure/speech/tts/tts_model_catalog.dart';
import 'package:godsense/infrastructure/speech/tts_model_cache.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory root;
  late List<int> archiveBytes;
  late TtsModelDefinition model;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('godsense-tts-cache-test-');
    final archive = Archive()
      ..addFile(ArchiveFile('fixture/model.onnx', 5, [1, 2, 3, 4, 5]));
    archiveBytes = BZip2Encoder().encode(TarEncoder().encode(archive));
    model = TtsModelDefinition(
      id: 'fixture',
      version: '1',
      name: 'Fixture',
      description: 'Test model',
      family: TtsModelFamily.vits,
      downloads: [
        TtsModelDownload(
          uri: Uri.parse('https://example.test/model.tar.bz2'),
          fileName: 'model.tar.bz2',
          bytes: archiveBytes.length,
          sha256: sha256.convert(archiveBytes).toString(),
          isArchive: true,
        ),
      ],
      installedBytes: 5,
      archiveRoot: 'fixture',
      requiredFiles: const ['model.onnx'],
      modelFiles: const {'model': 'model.onnx'},
      languages: const [TtsLanguageOption('es', 'Español')],
      voices: const [TtsVoiceOption('voice', 'Voice', 0)],
      licenseName: 'Test',
      licenseUri: Uri.parse('https://example.test/license'),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('installs only after hash verification and extraction', () async {
    final client = MockClient(
      (request) async => http.Response.bytes(archiveBytes, HttpStatus.ok),
    );
    final cache = TtsModelCache(client: client, rootDirectory: root);

    final installation = await cache.ensureAvailable(model);

    expect(await File(installation.file('model.onnx')).readAsBytes(), [
      1,
      2,
      3,
      4,
      5,
    ]);
    expect(await cache.installed(model), isNotNull);
  });

  test('resumes a partial archive with an HTTP range request', () async {
    final split = archiveBytes.length ~/ 2;
    final downloads = Directory(
      '${root.path}${Platform.pathSeparator}.downloads',
    );
    await downloads.create(recursive: true);
    await File(
      '${downloads.path}${Platform.pathSeparator}${model.storageKey}.tar.bz2.part',
    ).writeAsBytes(archiveBytes.take(split).toList());
    final client = MockClient((request) async {
      expect(request.headers[HttpHeaders.rangeHeader], 'bytes=$split-');
      return http.Response.bytes(
        archiveBytes.skip(split).toList(),
        HttpStatus.partialContent,
      );
    });

    final installation = await TtsModelCache(
      client: client,
      rootDirectory: root,
    ).ensureAvailable(model);

    expect(await File(installation.file('model.onnx')).exists(), isTrue);
  });

  test('uses four resumable ranges for large model downloads', () async {
    final ranges = <String>[];
    final client = MockClient((request) async {
      final range = request.headers[HttpHeaders.rangeHeader]!;
      ranges.add(range);
      final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range)!;
      final start = int.parse(match.group(1)!);
      final end = match.group(2)!.isEmpty
          ? archiveBytes.length - 1
          : int.parse(match.group(2)!);
      return http.Response.bytes(
        archiveBytes.sublist(start, end + 1),
        HttpStatus.partialContent,
        headers: {
          HttpHeaders.contentRangeHeader:
              'bytes $start-$end/${archiveBytes.length}',
        },
      );
    });

    final installation = await TtsModelCache(
      client: client,
      rootDirectory: root,
      segmentedDownloadThreshold: 1,
    ).ensureAvailable(model);

    expect(await File(installation.file('model.onnx')).exists(), isTrue);
    expect(ranges, contains('bytes=0-0'));
    expect(ranges.where((range) => range != 'bytes=0-0'), hasLength(4));
  });

  test('installs supplementary files and removes replaced artifacts', () async {
    const vocoderBytes = [9, 8, 7, 6];
    final archive = Archive()
      ..addFile(ArchiveFile('fixture/model.onnx', 1, [1]))
      ..addFile(ArchiveFile('fixture/old-vocoder.onnx', 1, [2]));
    final bytes = BZip2Encoder().encode(TarEncoder().encode(archive));
    final multiFileModel = TtsModelDefinition(
      id: 'multi-file-fixture',
      version: '1',
      name: 'Multi-file fixture',
      description: 'Test model',
      family: TtsModelFamily.matcha,
      downloads: [
        TtsModelDownload(
          uri: Uri.parse('https://example.test/model.tar.bz2'),
          fileName: 'model.tar.bz2',
          bytes: bytes.length,
          sha256: sha256.convert(bytes).toString(),
          isArchive: true,
        ),
        TtsModelDownload(
          uri: Uri.parse('https://example.test/vocoder.onnx'),
          fileName: 'vocoder.onnx',
          targetPath: 'vocoder.onnx',
          bytes: vocoderBytes.length,
          sha256: sha256.convert(vocoderBytes).toString(),
        ),
      ],
      installedBytes: 5,
      archiveRoot: 'fixture',
      requiredFiles: const ['model.onnx', 'vocoder.onnx'],
      removeAfterExtract: const ['old-vocoder.onnx'],
      modelFiles: const {
        'acousticModel': 'model.onnx',
        'vocoder': 'vocoder.onnx',
      },
      languages: const [TtsLanguageOption('en', 'English')],
      voices: const [TtsVoiceOption('voice', 'Voice', 0)],
      licenseName: 'Test',
      licenseUri: Uri.parse('https://example.test/license'),
    );
    final client = MockClient((request) async {
      return http.Response.bytes(
        request.url.path.endsWith('vocoder.onnx') ? vocoderBytes : bytes,
        HttpStatus.ok,
      );
    });

    final installation = await TtsModelCache(
      client: client,
      rootDirectory: root,
    ).ensureAvailable(multiFileModel);

    expect(
      await File(installation.file('vocoder.onnx')).readAsBytes(),
      vocoderBytes,
    );
    expect(await File(installation.file('old-vocoder.onnx')).exists(), isFalse);
  });

  test('rejects and removes an archive with the wrong digest', () async {
    final corrupt = [...archiveBytes]..[archiveBytes.length ~/ 2] ^= 0xff;
    final client = MockClient(
      (request) async => http.Response.bytes(corrupt, HttpStatus.ok),
    );
    final cache = TtsModelCache(client: client, rootDirectory: root);

    await expectLater(cache.ensureAvailable(model), throwsStateError);

    expect(await cache.installed(model), isNull);
    expect(
      await File(
        '${root.path}${Platform.pathSeparator}.downloads${Platform.pathSeparator}'
        '${model.storageKey}.tar.bz2.part',
      ).exists(),
      isFalse,
    );
  });

  test('cancels safely while preserving resumable partial data', () async {
    final cancellation = TtsDownloadCancellation();
    final client = MockClient(
      (request) async => http.Response.bytes(archiveBytes, HttpStatus.ok),
    );
    final cache = TtsModelCache(client: client, rootDirectory: root);

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

    final partial = File(
      '${root.path}${Platform.pathSeparator}.downloads${Platform.pathSeparator}'
      '${model.storageKey}.tar.bz2.part',
    );
    expect(await partial.exists(), isTrue);
  });

  test('fails a download whose response stops sending bytes', () async {
    final stalled = StreamController<List<int>>();
    final client = _StreamingClient(
      (_) async => http.StreamedResponse(
        stalled.stream,
        HttpStatus.ok,
        contentLength: archiveBytes.length,
      ),
    );
    final cache = TtsModelCache(
      client: client,
      rootDirectory: root,
      inactivityTimeout: const Duration(milliseconds: 80),
      downloadAttempts: 1,
    );

    await expectLater(
      cache.ensureAvailable(model),
      throwsA(isA<TimeoutException>()),
    );

    await stalled.close();
  });

  test('cancelling interrupts a connection that never responds', () async {
    final cancellation = TtsDownloadCancellation();
    final client = _StreamingClient(
      (_) => Completer<http.StreamedResponse>().future,
    );
    final cache = TtsModelCache(
      client: client,
      rootDirectory: root,
      connectionTimeout: const Duration(seconds: 5),
      downloadAttempts: 1,
    );
    final stopwatch = Stopwatch()..start();
    final operation = cache.ensureAvailable(model, cancellation: cancellation);
    Timer(const Duration(milliseconds: 50), cancellation.cancel);

    await expectLater(operation, throwsA(isA<TtsDownloadCancelledException>()));

    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('rejects an installed model whose required file was modified', () async {
    final client = MockClient(
      (_) async => http.Response.bytes(archiveBytes, HttpStatus.ok),
    );
    final cache = TtsModelCache(client: client, rootDirectory: root);
    final installation = await cache.ensureAvailable(model);
    await File(installation.file('model.onnx')).writeAsBytes([1, 2]);

    final freshProcessCache = TtsModelCache(
      client: client,
      rootDirectory: root,
    );

    expect(await freshProcessCache.installed(model), isNull);
  });
}

class _StreamingClient extends http.BaseClient {
  _StreamingClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}
