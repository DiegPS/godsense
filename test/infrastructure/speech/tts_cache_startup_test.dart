import 'dart:io';
import 'dart:isolate';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:godsense/infrastructure/speech/tts/tts_model_catalog.dart';
import 'package:godsense/infrastructure/speech/tts_model_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('checking cached models does not initialize native downloader storage', () async {
    final directory = await Directory.systemTemp.createTemp(
      'godsense-cache-startup-',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    addTearDown(() => directory.delete(recursive: true));
    final cache = TtsModelCache(rootDirectory: directory);
    for (final model in TtsModelCatalog.models) {
      expect(await cache.installed(model), isNull);
    }
    expect(await Isolate.run(() => 42), 42);
    // The downloader accepts injected storage only before its first creation.
    // This fails if a cache lookup has already started its native persistence.
    final storage = _Storage();
    final downloader = FileDownloader(persistentStorage: storage);
    expect(await downloader.ready, true);
    expect(storage.initializations, 1);
    downloader.destroy();
    await Future<void>.delayed(Duration.zero);
  });
}

class _Storage implements PersistentStorage {
  int initializations = 0;
  @override
  Future<void> initialize() async {
    initializations++;
  }

  @override
  Future<void> removeResumeData(String? taskId) async {}
  @override
  Future<void> removePausedTask(String? taskId) async {}
  @override
  Future<void> removeTaskRecord(String? taskId) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
