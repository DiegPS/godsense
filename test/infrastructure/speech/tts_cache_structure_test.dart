import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/artifacts/artifact_downloader.dart';
import 'package:godsense/infrastructure/speech/tts/tts_model_catalog.dart';
import 'package:godsense/infrastructure/speech/tts_model_cache.dart';

void main() {
  late Directory root;
  setUp(
    () async => root = await Directory.systemTemp.createTemp(
      'godsense-cache-structure-',
    ),
  );
  tearDown(() async => root.delete(recursive: true));

  test('a required directory verifies every nested file and rejects later corruption', () async {
    final fixture = _Fixture(
      {
        'fixture/voices/es/model.onnx': [1, 2],
        'fixture/voices/en/model.onnx': [3, 4],
      },
      required: ['voices'],
    );
    final cache = fixture.cache(root);
    final installed = await cache.ensureAvailable(fixture.model);
    final manifest = jsonDecode(
      await File('${installed.directory.path}/.godsense-integrity.json')
          .readAsString(),
    ) as Map;
    expect((manifest['files'] as List).map((entry) => (entry as Map)['path']), [
      'voices/en/model.onnx',
      'voices/es/model.onnx',
    ]);
    expect(await fixture.cache(root).installed(fixture.model), isNotNull);
    await File(installed.file('voices/es/model.onnx')).writeAsBytes([9, 9]);
    expect(await fixture.cache(root).installed(fixture.model), isNull);
  });

  test(
    'a disappeared nested file invalidates an installed directory model',
    () async {
      final fixture = _Fixture(
        {
          'fixture/voices/es/model.onnx': [1, 2],
        },
        required: ['voices'],
      );
      final installed = await fixture
          .cache(root)
          .ensureAvailable(fixture.model);
      await File(installed.file('voices/es/model.onnx')).delete();
      expect(await fixture.cache(root).installed(fixture.model), isNull);
    },
  );

  for (final scenario in [
    (
      files: {
        'unexpected/model.onnx': [1],
      },
      required: ['model.onnx'],
      message: 'unexpected structure',
    ),
    (
      files: {
        'fixture/other.onnx': [1],
      },
      required: ['model.onnx'],
      message: 'missing model.onnx',
    ),
  ]) {
    test('failed archive ${scenario.message} is cleaned up without publishing', () async {
      final fixture = _Fixture(scenario.files, required: scenario.required);
      final cache = fixture.cache(root);
      await expectLater(
        cache.ensureAvailable(fixture.model),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains(scenario.message),
          ),
        ),
      );
      expect(await cache.installed(fixture.model), isNull);
      expect(
        await Directory('${root.path}/.${fixture.model.storageKey}.staging')
            .exists(),
        isFalse,
      );
      expect(
        await File(
          '${root.path}/.downloads/${fixture.model.storageKey}.verified.tar.bz2',
        ).exists(),
        isFalse,
      );
    });
  }

  for (final scenario in [
    (name: 'malformed JSON', content: '{invalid'),
    (name: 'wrong metadata type', content: '[]'),
    (
      name: 'wrong model',
      content: jsonEncode({'id': 'other', 'version': '1', 'integrity': 'bad'}),
    ),
    (
      name: 'wrong version',
      content: jsonEncode({
        'id': 'structure-fixture',
        'version': '2',
        'integrity': 'bad',
      }),
    ),
  ]) {
    test('installation marker ${scenario.name} is rejected', () async {
      final fixture = _Fixture({
        'fixture/model.onnx': [1],
      });
      final installed = await fixture
          .cache(root)
          .ensureAvailable(fixture.model);
      await File('${installed.directory.path}/.godsense-model.json')
          .writeAsString(scenario.content);
      expect(await fixture.cache(root).installed(fixture.model), isNull);
    });
  }

  test('a removed integrity manifest is rejected even when all required files remain', () async {
    final fixture = _Fixture({
      'fixture/model.onnx': [1],
    });
    final installed = await fixture.cache(root).ensureAvailable(fixture.model);
    await File('${installed.directory.path}/.godsense-integrity.json').delete();
    expect(await fixture.cache(root).installed(fixture.model), isNull);
  });

  test('speech packages use the STT download group', () async {
    final fixture = _Fixture({
      'fixture/model.onnx': [1],
    }, id: 'speech-structure-fixture');
    await fixture.cache(root).ensureAvailable(fixture.model);
    expect(fixture.downloader.requests.single.group, 'voice-stt');
  });
}

class _Fixture {
  _Fixture(
    Map<String, List<int>> files, {
    List<String> required = const ['model.onnx'],
    String id = 'structure-fixture',
  }) {
    final archive = Archive();
    for (final file in files.entries) {
      archive.addFile(ArchiveFile(file.key, file.value.length, file.value));
    }
    final bytes = BZip2Encoder().encode(TarEncoder().encode(archive));
    downloader = _Downloader(bytes);
    model = TtsModelDefinition(
      id: id,
      version: '1',
      name: 'Structure fixture',
      description: 'Synthetic model',
      family: TtsModelFamily.vits,
      downloads: [
        TtsModelDownload(
          uri: Uri.parse('https://example.test/$id.tar.bz2'),
          fileName: '$id.tar.bz2',
          bytes: bytes.length,
          sha256: sha256.convert(bytes).toString(),
          isArchive: true,
        ),
      ],
      installedBytes: files.values.fold(0, (sum, bytes) => sum + bytes.length),
      archiveRoot: 'fixture',
      requiredFiles: required,
      modelFiles: const {'model': 'model.onnx'},
      languages: const [TtsLanguageOption('es', 'Español')],
      voices: const [TtsVoiceOption('test', 'Test', 0)],
      licenseName: 'Test',
      licenseUri: Uri.parse('https://example.test/license'),
    );
  }
  late final TtsModelDefinition model;
  late final _Downloader downloader;
  TtsModelCache cache(Directory root) =>
      TtsModelCache(rootDirectory: root, downloader: downloader);
}

class _Downloader implements ArtifactDownloader {
  _Downloader(this.bytes);
  final List<int> bytes;
  final requests = <ArtifactDownloadRequest>[];
  @override
  Future<void> download(
    ArtifactDownloadRequest request, {
    ArtifactDownloadCancellation? cancellation,
    void Function(ArtifactDownloadProgress)? onProgress,
  }) async {
    requests.add(request);
    cancellation?.throwIfCancelled();
    final file = File(request.destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }
}
