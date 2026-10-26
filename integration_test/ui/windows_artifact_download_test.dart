import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:godsense/application/artifacts/artifact_downloader.dart';
import 'package:godsense/infrastructure/artifacts/background_artifact_downloader.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Windows artifact transport downloads HTTPS data and rejects a size mismatch',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'godsense-download-e2e-',
      );
      // Isolate the plugin's records from the user's real download database.
      final storage = _Storage();
      final native = FileDownloader(persistentStorage: storage);
      final downloader = BackgroundArtifactDownloader();
      final uri = Uri.parse(
        'https://raw.githubusercontent.com/flutter/flutter/3.47.2/LICENSE',
      );
      try {
        final request = ArtifactDownloadRequest(
          id: 'synthetic-fixture',
          uri: uri,
          destinationPath: '${directory.path}/license.txt',
          expectedBytes: 1519,
          group: 'godsense-download-e2e',
          retries: 0,
        );
        await downloader.download(request).timeout(const Duration(seconds: 30));
        final bytes = await File(request.destinationPath).readAsBytes();
        expect(bytes, hasLength(1519));
        expect(
          sha256.convert(bytes).toString(),
          'a598db94b6290ffbe10b5ecf911057b6a943351c727fdda9e5f2891d68700a20',
        );
        final mismatch = ArtifactDownloadRequest(
          id: 'synthetic-mismatch',
          uri: uri,
          destinationPath: '${directory.path}/mismatch.txt',
          expectedBytes: 1518,
          group: 'godsense-download-e2e',
          retries: 0,
        );
        await expectLater(
          downloader.download(mismatch).timeout(const Duration(seconds: 30)),
          throwsA(isA<ArtifactDownloadException>()),
        );
        final cachedTask = await BackgroundArtifactDownloader.createTask(
          request,
        );
        await native.database.deleteRecordWithId(cachedTask.taskId);
        final failedTask = await BackgroundArtifactDownloader.createTask(
          mismatch,
        );
        await native.database.deleteRecordWithId(failedTask.taskId);
      } finally {
        await directory.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _Storage implements PersistentStorage {
  final records = <String, TaskRecord>{};
  final paused = <String, Task>{};
  final resume = <String, ResumeData>{};
  @override
  (String, int) get currentDatabaseVersion => ('isolated-e2e', 1);
  @override
  Future<(String, int)> get storedDatabaseVersion async =>
      currentDatabaseVersion;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> storeTaskRecord(TaskRecord record) async {
    records[record.taskId] = record;
  }

  @override
  Future<TaskRecord?> retrieveTaskRecord(String taskId) async =>
      records[taskId];
  @override
  Future<List<TaskRecord>> retrieveAllTaskRecords() async =>
      records.values.toList();
  @override
  Future<void> removeTaskRecord(String? taskId) async {
    taskId == null ? records.clear() : records.remove(taskId);
  }

  @override
  Future<void> storePausedTask(Task task) async {
    paused[task.taskId] = task;
  }

  @override
  Future<Task?> retrievePausedTask(String taskId) async => paused[taskId];
  @override
  Future<List<Task>> retrieveAllPausedTasks() async => paused.values.toList();
  @override
  Future<void> removePausedTask(String? taskId) async {
    taskId == null ? paused.clear() : paused.remove(taskId);
  }

  @override
  Future<void> storeResumeData(ResumeData data) async {
    resume[data.taskId] = data;
  }

  @override
  Future<ResumeData?> retrieveResumeData(String taskId) async => resume[taskId];
  @override
  Future<List<ResumeData>> retrieveAllResumeData() async =>
      resume.values.toList();
  @override
  Future<void> removeResumeData(String? taskId) async {
    taskId == null ? resume.clear() : resume.remove(taskId);
  }
}
