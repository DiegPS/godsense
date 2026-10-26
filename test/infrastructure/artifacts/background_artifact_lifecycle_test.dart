import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/artifacts/artifact_downloader.dart';
import 'package:godsense/infrastructure/artifacts/background_artifact_downloader.dart';

void main() {
  late Directory root;
  late File destination;
  late _Downloader native;
  late BackgroundArtifactDownloader downloader;
  late ArtifactDownloadRequest request;
  setUp(() async {
    root = await Directory.systemTemp.createTemp(
      'godsense-download-lifecycle-',
    );
    destination = File('${root.path}/model.bin');
    request = ArtifactDownloadRequest(
      id: 'synthetic-model',
      uri: Uri.parse('https://example.invalid/model.bin'),
      destinationPath: destination.path,
      expectedBytes: 4,
      group: 'test-models',
    );
    native = _Downloader(destination);
    downloader = BackgroundArtifactDownloader.withDownloader(native);
  });
  tearDown(() async => root.delete(recursive: true));

  test(
    'fresh download reports bounded progress and verifies the file',
    () async {
      final progress = <ArtifactDownloadProgress>[];
      await downloader.download(request, onProgress: progress.add);
      expect(await destination.readAsBytes(), [1, 2, 3, 4]);
      expect(progress.map((entry) => entry.receivedBytes), [2, 4]);
      expect(native.enqueued, 1);
    },
  );
  test(
    'rejects insecure URLs and missing identifiers before starting native work',
    () async {
      for (final invalid in [
        ArtifactDownloadRequest(
          id: 'id',
          uri: Uri.parse('http://example.invalid'),
          destinationPath: destination.path,
          expectedBytes: 4,
          group: 'group',
        ),
        ArtifactDownloadRequest(
          id: '',
          uri: request.uri,
          destinationPath: destination.path,
          expectedBytes: 4,
          group: 'group',
        ),
        ArtifactDownloadRequest(
          id: 'id',
          uri: request.uri,
          destinationPath: destination.path,
          expectedBytes: 4,
          group: '',
        ),
      ]) {
        await expectLater(
          downloader.download(invalid),
          throwsA(isA<ArtifactDownloadException>()),
        );
      }
      expect(native.starts, 0);
    },
  );
  test(
    'already cancelled downloads never initialize the native downloader',
    () async {
      final cancellation = ArtifactDownloadCancellationToken()..cancel();
      await expectLater(
        downloader.download(request, cancellation: cancellation),
        throwsA(isA<ArtifactDownloadCancelledException>()),
      );
      expect(native.starts, 0);
    },
  );
  test('native enqueue rejection is reported and permits retry', () async {
    native.accept = false;
    await expectLater(
      downloader.download(request),
      throwsA(isA<ArtifactDownloadException>()),
    );
    native.accept = true;
    await downloader.download(request);
    expect(native.enqueued, 2);
  });
  test('native initialization failure permits a later retry', () async {
    native.startFailures = 1;
    await expectLater(downloader.download(request), throwsStateError);
    await downloader.download(request);
    expect(native.starts, 2);
    expect(await destination.length(), 4);
  });
  test('wrong file size is rejected and the partial file is removed', () async {
    native.bytes = [1, 2];
    await expectLater(
      downloader.download(request),
      throwsA(isA<ArtifactDownloadException>()),
    );
    expect(await destination.exists(), false);
  });
  test('complete callback without a file is rejected', () async {
    native.writeFile = false;
    await expectLater(
      downloader.download(request),
      throwsA(isA<ArtifactDownloadException>()),
    );
  });
  test(
    'a completed persisted task is reused without another transfer',
    () async {
      final task = await BackgroundArtifactDownloader.createTask(request);
      native.database.record = TaskRecord(task, TaskStatus.complete, 1, 4);
      await destination.writeAsBytes([1, 2, 3, 4]);
      await downloader.download(request);
      expect(native.enqueued, 0);
    },
  );
  test(
    'failed resumption removes stale task metadata and starts a fresh transfer',
    () async {
      final task = await BackgroundArtifactDownloader.createTask(request);
      native.database.record = TaskRecord(task, TaskStatus.paused, .5, 4);
      native.canResume = false;
      await downloader.download(request);
      expect(native.resumes, 1);
      expect(native.database.deleted, [task.taskId]);
      expect(native.enqueued, 1);
    },
  );
  test('stale startup callbacks cannot fail a newly queued transfer', () async {
    final task = await BackgroundArtifactDownloader.createTask(request);
    native.onStart = () =>
        native.status!(TaskStatusUpdate(task, TaskStatus.failed));
    await downloader.download(request);
    expect(native.enqueued, 1);
  });
  test('completion arriving during startup is accepted for a persisted paused task', () async {
    final task = await BackgroundArtifactDownloader.createTask(request);
    native.database.record = TaskRecord(task, TaskStatus.paused, .5, 4);
    await destination.writeAsBytes([1, 2, 3, 4]);
    native.onStart = () =>
        native.status!(TaskStatusUpdate(task, TaskStatus.complete));
    await downloader.download(request);
    expect(native.resumes, 0);
    expect(native.enqueued, 0);
  });
  test(
    'duplicate requests are rejected; cancellation unblocks the original',
    () async {
      native.hold = true;
      final cancellation = ArtifactDownloadCancellationToken();
      final first = downloader.download(request, cancellation: cancellation);
      final outcome = expectLater(
        first,
        throwsA(isA<ArtifactDownloadCancelledException>()),
      );
      await native.started.future;
      await expectLater(
        downloader.download(request),
        throwsA(isA<ArtifactDownloadException>()),
      );
      expect(await downloader.pause(request.id), true);
      expect(await downloader.resume(request.id), true);
      cancellation.cancel();
      await outcome;
      expect(native.enqueued, 1);
      expect(native.cancels, 1);
    },
  );
  test('controls return false for an unknown task', () async {
    expect(await downloader.pause('unknown'), false);
    expect(await downloader.resume('unknown'), false);
    expect(await downloader.cancel('unknown'), false);
    expect(native.starts, 1);
  });
}

class _Database implements Database {
  TaskRecord? record;
  final deleted = <String>[];
  @override
  Future<TaskRecord?> recordForId(String taskId) async => record;
  @override
  Future<void> deleteRecordWithId(String taskId) async {
    deleted.add(taskId);
    record = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

class _Downloader implements FileDownloader {
  _Downloader(this.destination);
  final File destination;
  @override
  final _Database database = _Database();
  TaskStatusCallback? status;
  TaskProgressCallback? progress;
  void Function()? onStart;
  final started = Completer<void>();
  bool accept = true, canResume = true, writeFile = true, hold = false;
  List<int> bytes = [1, 2, 3, 4];
  int starts = 0, enqueued = 0, resumes = 0, cancels = 0;
  int startFailures = 0;
  @override
  FileDownloader registerCallbacks({
    String group = 'default',
    TaskStatusCallback? taskStatusCallback,
    TaskProgressCallback? taskProgressCallback,
    TaskNotificationTapCallback? taskNotificationTapCallback,
  }) {
    status = taskStatusCallback;
    progress = taskProgressCallback;
    return this;
  }

  @override
  Future<void> start({
    bool doTrackTasks = true,
    bool markDownloadedComplete = true,
    bool doRescheduleKilledTasks = true,
    bool autoCleanDatabase = false,
  }) async {
    starts++;
    if (startFailures-- > 0) {
      throw StateError('Synthetic native startup failure');
    }
    onStart?.call();
  }

  @override
  Future<bool> enqueue(Task task) async {
    enqueued++;
    if (!started.isCompleted) started.complete();
    if (!accept || hold) return accept;
    if (writeFile) await destination.writeAsBytes(bytes);
    progress?.call(TaskProgressUpdate(task, -.5));
    progress?.call(TaskProgressUpdate(task, .5));
    status?.call(TaskStatusUpdate(task, TaskStatus.complete));
    return true;
  }

  @override
  Future<bool> pause(DownloadTask task) async => true;
  @override
  Future<bool> resume(DownloadTask task) async {
    resumes++;
    return canResume;
  }

  @override
  Future<bool> cancel(Task task) async {
    cancels++;
    status?.call(TaskStatusUpdate(task, TaskStatus.canceled));
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}
