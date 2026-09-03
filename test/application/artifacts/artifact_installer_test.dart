import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/artifacts/artifact_downloader.dart';
import 'package:godsense/application/artifacts/artifact_installer.dart';
import 'package:godsense/domain/artifacts/artifact_spec.dart';

void main() {
  late Directory root;
  late List<int> archiveBytes;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('godsense-artifacts-');
    archiveBytes = ZipEncoder().encode(
      Archive()..addFile(ArchiveFile('runtime/bin/tool.exe', 3, [1, 2, 3])),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  ArtifactSpec spec(String version, {String? digest}) => ArtifactSpec(
    id: 'coach-runtime',
    version: version,
    group: 'coach',
    archiveRoot: 'runtime',
    payloads: [
      ArtifactPayloadSpec(
        id: 'windows-x64',
        uri: Uri.parse('https://example.test/runtime-$version.zip'),
        sha256: digest ?? sha256.convert(archiveBytes).toString(),
        bytes: archiveBytes.length,
        fileName: 'runtime.zip',
        archiveType: ArtifactArchiveType.zip,
      ),
    ],
    requiredPaths: const ['bin/tool.exe'],
  );

  test('verifies, installs, versions, and activates an artifact', () async {
    final downloader = _MemoryDownloader({
      Uri.parse('https://example.test/runtime-1.zip'): archiveBytes,
    });
    final installer = ArtifactInstaller(
      rootDirectory: root,
      downloader: downloader,
    );

    final installation = await installer.install(spec('1'));

    expect(
      await File('${installation.directoryPath}/bin/tool.exe').readAsBytes(),
      [1, 2, 3],
    );
    expect(await installer.installed(spec('1')), isNotNull);
    final active = jsonDecode(
      await File('${root.path}/coach/coach-runtime/active.json').readAsString(),
    ) as Map<String, dynamic>;
    expect(active['version'], '1');
    expect(downloader.requests.single.group, 'coach');
  });

  test('artifact manifests round-trip without losing typed fields', () {
    final original = spec('1');

    final decoded = ArtifactSpec.fromJson(original.toJson());

    expect(decoded.id, original.id);
    expect(decoded.version, original.version);
    expect(decoded.payloads.single.archiveType, ArtifactArchiveType.zip);
    expect(decoded.payloads.single.bytes, archiveBytes.length);
    expect(decoded.requiredPaths, original.requiredPaths);
  });

  test('a failed validation does not replace the active version', () async {
    final downloader = _MemoryDownloader({
      Uri.parse('https://example.test/runtime-1.zip'): archiveBytes,
      Uri.parse('https://example.test/runtime-2.zip'): archiveBytes,
    });
    final first = ArtifactInstaller(
      rootDirectory: root,
      downloader: downloader,
    );
    await first.install(spec('1'));
    final rejecting = ArtifactInstaller(
      rootDirectory: root,
      downloader: downloader,
      validator: (artifact, _) async {
        if (artifact.version == '2') throw StateError('runtime probe failed');
      },
    );

    await expectLater(rejecting.install(spec('2')), throwsStateError);

    final active = jsonDecode(
      await File('${root.path}/coach/coach-runtime/active.json').readAsString(),
    ) as Map<String, dynamic>;
    expect(active['version'], '1');
    expect(
      await Directory('${root.path}/coach/coach-runtime/versions/2').exists(),
      isFalse,
    );
  });

  test('can roll back by activating an already installed version', () async {
    final downloader = _MemoryDownloader({
      Uri.parse('https://example.test/runtime-1.zip'): archiveBytes,
      Uri.parse('https://example.test/runtime-2.zip'): archiveBytes,
    });
    final installer = ArtifactInstaller(
      rootDirectory: root,
      downloader: downloader,
    );
    await installer.install(spec('1'));
    await installer.install(spec('2'));

    await installer.activateInstalledVersion('coach', 'coach-runtime', '1');

    final active = jsonDecode(
      await File('${root.path}/coach/coach-runtime/active.json').readAsString(),
    ) as Map<String, dynamic>;
    expect(active['version'], '1');
    expect(active['previousVersion'], '2');
  });

  test('recovers an interrupted active pointer replacement', () async {
    final downloader = _MemoryDownloader({
      Uri.parse('https://example.test/runtime-1.zip'): archiveBytes,
    });
    final installer = ArtifactInstaller(
      rootDirectory: root,
      downloader: downloader,
    );
    await installer.install(spec('1'));
    final family = Directory('${root.path}/coach/coach-runtime');
    final active = File('${family.path}/active.json');
    final previous = File('${active.path}.previous');
    await active.rename(previous.path);

    await installer.activateInstalledVersion('coach', 'coach-runtime', '1');

    expect(await active.exists(), isTrue);
    expect(await previous.exists(), isFalse);
    final value =
        jsonDecode(await active.readAsString()) as Map<String, dynamic>;
    expect(value['version'], '1');
  });

  test('rejects invalid digests and paths outside the installation', () async {
    final badDigest = List.filled(64, '0').join();
    final downloader = _MemoryDownloader({
      Uri.parse('https://example.test/runtime-1.zip'): archiveBytes,
    });
    final installer = ArtifactInstaller(
      rootDirectory: root,
      downloader: downloader,
    );
    await expectLater(
      installer.install(spec('1', digest: badDigest)),
      throwsStateError,
    );
    await expectLater(
      installer.install(
        ArtifactSpec(
          id: 'escape',
          version: '1',
          group: 'coach',
          payloads: [
            ArtifactPayloadSpec(
              id: 'file',
              uri: Uri.parse('https://example.test/file'),
              sha256: badDigest,
              bytes: 1,
              fileName: 'file',
              targetPath: '../outside.exe',
            ),
          ],
          requiredPaths: const ['../outside.exe'],
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      installer.install(
        ArtifactSpec(
          id: 'wrong-extension',
          version: '1',
          group: 'coach',
          payloads: [
            ArtifactPayloadSpec(
              id: 'archive',
              uri: Uri.parse('https://example.test/runtime.bin'),
              sha256: badDigest,
              bytes: 1,
              fileName: 'runtime.bin',
              archiveType: ArtifactArchiveType.zip,
            ),
          ],
          requiredPaths: const ['tool.exe'],
        ),
      ),
      throwsArgumentError,
    );
  });
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
    final destination = File(request.destinationPath);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(bytes, flush: true);
    onProgress?.call(
      ArtifactDownloadProgress(
        receivedBytes: bytes.length,
        totalBytes: request.expectedBytes,
      ),
    );
  }
}
