import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/artifacts/artifact_downloader.dart';
import 'package:godsense/domain/artifacts/artifact_spec.dart';
import 'package:godsense/infrastructure/artifacts/artifact_installer_factory.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  final bytes = [1, 2, 3, 4];
  late ArtifactSpec spec;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('godsense-factory-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
    spec = ArtifactSpec(
      id: 'synthetic-runtime',
      group: 'test',
      version: '1',
      payloads: [
        ArtifactPayloadSpec(
          id: 'fixture',
          uri: Uri.parse('https://example.invalid/runtime'),
          sha256: sha256.convert(bytes).toString(),
          bytes: bytes.length,
          fileName: 'runtime.bin',
          targetPath: 'runtime.bin',
        ),
      ],
      requiredPaths: ['runtime.bin'],
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  for (final explicitRoot in [false, true]) {
    test(
      'factory installs under ${explicitRoot ? 'explicit' : 'application support'} root',
      () async {
        final downloader = _FixtureDownloader(bytes);
        final factory = ArtifactInstallerFactory(downloader: downloader);
        var validations = 0;
        final installer = await factory.create(
          rootDirectory: explicitRoot ? root : null,
          validator: (artifact, directory) async {
            expect(artifact.id, spec.id);
            expect(
              await File(p.join(directory.path, 'runtime.bin')).readAsBytes(),
              bytes,
            );
            validations++;
          },
        );
        final installed = await installer.install(spec);
        expect(
          p.isWithin(
            explicitRoot ? root.path : p.join(root.path, 'artifacts'),
            installed.directoryPath,
          ),
          true,
        );
        expect(await installer.installed(spec), isNotNull);
        expect(validations, greaterThanOrEqualTo(2));
        expect(downloader.downloads, 1);
        await installer.install(spec);
        expect(
          downloader.downloads,
          1,
          reason: 'Verified installations must be reused',
        );
      },
    );
  }

  test('validator rejection never activates the downloaded artifact', () async {
    final installer =
        await ArtifactInstallerFactory(downloader: _FixtureDownloader(bytes))
            .create(
              rootDirectory: root,
              validator: (_, _) async =>
                  throw StateError('Synthetic incompatible runtime'),
            );
    await expectLater(installer.install(spec), throwsStateError);
    expect(await installer.installed(spec), isNull);
    expect(
      await File(p.join(root.path, 'test', spec.id, 'active.json')).exists(),
      false,
    );
  });
}

class _FixtureDownloader implements ArtifactDownloader {
  _FixtureDownloader(this.bytes);
  final List<int> bytes;
  int downloads = 0;

  @override
  Future<void> download(
    ArtifactDownloadRequest request, {
    ArtifactDownloadCancellation? cancellation,
    void Function(ArtifactDownloadProgress progress)? onProgress,
  }) async {
    cancellation?.throwIfCancelled();
    downloads++;
    await File(request.destinationPath).writeAsBytes(bytes);
  }
}
