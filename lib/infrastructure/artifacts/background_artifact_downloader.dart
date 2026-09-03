import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../application/artifacts/artifact_downloader.dart';

class BackgroundArtifactDownloader implements ControllableArtifactDownloader {
  factory BackgroundArtifactDownloader() => _shared;

  BackgroundArtifactDownloader.withDownloader(FileDownloader downloader)
    : _downloader = downloader;

  static final _shared = BackgroundArtifactDownloader.withDownloader(
    FileDownloader(),
  );

  final FileDownloader _downloader;
  final _registeredGroups = <String>{};
  final _pending = <String, _PendingDownload>{};
  final _tasksByRequestId = <String, DownloadTask>{};
  Future<void>? _startFuture;

  @override
  Future<void> download(
    ArtifactDownloadRequest request, {
    ArtifactDownloadCancellation? cancellation,
    void Function(ArtifactDownloadProgress progress)? onProgress,
  }) async {
    if (request.uri.scheme != 'https') {
      throw const ArtifactDownloadException(
        'Artifact downloads require HTTPS.',
      );
    }
    if (request.group.isEmpty || request.id.isEmpty) {
      throw const ArtifactDownloadException(
        'Artifact downloads require an id and group.',
      );
    }
    cancellation?.throwIfCancelled();
    final destination = File(request.destinationPath).absolute;
    await destination.parent.create(recursive: true);
    final task = await createTask(request);
    final resolved = await task.filePath();
    if (!p.isAbsolute(resolved) ||
        !p.equals(p.normalize(resolved), p.normalize(destination.path))) {
      throw const ArtifactDownloadException(
        'No se pudo resolver la carpeta de descarga. No se inició la transferencia.',
      );
    }
    if (_pending.containsKey(task.taskId)) {
      throw ArtifactDownloadException(
        'Download ${request.id} is already running.',
      );
    }
    final pending = _PendingDownload(request, onProgress);
    _pending[task.taskId] = pending;
    _tasksByRequestId[request.id] = task;
    _registerGroup(request.group);
    var finished = false;
    final removeCancellationListener = cancellation?.addListener(() {
      if (!finished) unawaited(cancel(request.id));
    });
    try {
      await (_startFuture ??= _downloader.start(autoCleanDatabase: true));
      cancellation?.throwIfCancelled();
      final record = await _downloader.database.recordForId(task.taskId);
      if (record?.status == TaskStatus.complete && await destination.exists()) {
        pending.complete();
      } else if (record != null && !record.status.isFinalState) {
        _acceptUpdates(pending);
        if (!pending.done.isCompleted &&
            record.status == TaskStatus.paused &&
            record.task is DownloadTask) {
          final resumed = await _downloader.resume(record.task as DownloadTask);
          if (!resumed) {
            await _downloader.database.deleteRecordWithId(task.taskId);
            await _enqueue(task, pending);
          }
        }
      } else {
        pending.discardDeferredStatus();
        _acceptUpdates(pending);
        if (record != null) {
          await _downloader.database.deleteRecordWithId(task.taskId);
        }
        await _enqueue(task, pending);
      }
      await pending.done.future;
      finished = true;
      cancellation?.throwIfCancelled();
      if (!await destination.exists()) {
        throw ArtifactDownloadException(
          'Download ${request.id} completed without a destination file.',
        );
      }
      final actual = await destination.length();
      if (request.expectedBytes > 0 && actual != request.expectedBytes) {
        await destination.delete();
        throw ArtifactDownloadException(
          'Download ${request.id} has $actual bytes; '
          '${request.expectedBytes} were expected.',
        );
      }
      onProgress?.call(
        ArtifactDownloadProgress(
          receivedBytes: request.expectedBytes > 0
              ? request.expectedBytes
              : actual,
          totalBytes: request.expectedBytes,
        ),
      );
    } finally {
      finished = true;
      removeCancellationListener?.call();
      if (identical(_pending[task.taskId], pending)) {
        _pending.remove(task.taskId);
      }
      if (identical(_tasksByRequestId[request.id], task)) {
        _tasksByRequestId.remove(request.id);
      }
    }
  }

  static Future<DownloadTask> createTask(
    ArtifactDownloadRequest request,
  ) async {
    final destination = File(request.destinationPath).absolute;
    // Task.split in background_downloader 9.5.9 strips the Windows drive.
    // BaseDirectory.root on Windows requires the COMPLETE absolute directory.
    final split = Platform.isWindows
        ? (
            BaseDirectory.root,
            destination.parent.path,
            p.basename(destination.path),
          )
        : await Task.split(file: destination);
    return DownloadTask(
      taskId: _taskId(request.id),
      url: request.uri.toString(),
      filename: split.$3,
      directory: split.$2,
      baseDirectory: split.$1,
      group: request.group,
      headers: request.headers,
      retries: request.retries.clamp(0, 10),
      allowPause: true,
      updates: Updates.statusAndProgress,
      displayName: request.id,
      metaData: request.id,
    );
  }

  Future<void> _enqueue(DownloadTask task, _PendingDownload pending) async {
    if (!await _downloader.enqueue(task)) {
      pending.completeError(
        ArtifactDownloadException('Could not enqueue ${pending.request.id}.'),
      );
    }
  }

  void _registerGroup(String group) {
    if (!_registeredGroups.add(group)) return;
    _downloader.registerCallbacks(
      group: group,
      taskStatusCallback: _handleStatus,
      taskProgressCallback: _handleProgress,
    );
  }

  void _handleStatus(TaskStatusUpdate update) {
    if (!update.status.isFinalState) return;
    final pending = _pending[update.task.taskId];
    if (pending == null) return;
    if (!pending.acceptingUpdates) {
      pending.deferStatus(update);
      return;
    }
    if (update.status == TaskStatus.complete) {
      pending.complete();
      return;
    }
    if (update.status == TaskStatus.canceled) {
      pending.completeError(const ArtifactDownloadCancelledException());
      return;
    }
    pending.completeError(
      ArtifactDownloadException(
        'Download ${pending.request.id} ended with ${update.status.name}'
        '${update.exception == null ? '.' : ': ${update.exception}'}',
      ),
    );
  }

  void _acceptUpdates(_PendingDownload pending) {
    final deferred = pending.acceptUpdates();
    if (deferred != null) _handleStatus(deferred);
  }

  void _handleProgress(TaskProgressUpdate update) {
    if (update.progress < 0) return;
    final pending = _pending[update.task.taskId];
    if (pending == null) return;
    final expected = pending.request.expectedBytes;
    final received = expected > 0
        ? (expected * update.progress.clamp(0, 1)).round()
        : 0;
    pending.onProgress?.call(
      ArtifactDownloadProgress(receivedBytes: received, totalBytes: expected),
    );
  }

  @override
  Future<bool> pause(String requestId) async {
    final task = await _findTask(requestId);
    return task == null ? false : _downloader.pause(task);
  }

  @override
  Future<bool> resume(String requestId) async {
    final task = await _findTask(requestId);
    return task == null ? false : _downloader.resume(task);
  }

  @override
  Future<bool> cancel(String requestId) async {
    final task = await _findTask(requestId);
    return task == null ? false : _downloader.cancel(task);
  }

  Future<DownloadTask?> _findTask(String requestId) async {
    final current = _tasksByRequestId[requestId];
    if (current != null) return current;
    await (_startFuture ??= _downloader.start(autoCleanDatabase: true));
    final record = await _downloader.database.recordForId(_taskId(requestId));
    return record?.task is DownloadTask ? record!.task as DownloadTask : null;
  }

  static String _taskId(String value) {
    final safe = value.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '-');
    final prefix = safe.length > 40 ? safe.substring(0, 40) : safe;
    final digest = sha256
        .convert(utf8.encode(value))
        .toString()
        .substring(0, 12);
    // Ignore persisted tasks created with the old drive-stripping destination.
    return 'v2-$prefix-$digest';
  }
}

class _PendingDownload {
  _PendingDownload(this.request, this.onProgress);

  final ArtifactDownloadRequest request;
  final void Function(ArtifactDownloadProgress progress)? onProgress;
  final done = Completer<void>();
  bool acceptingUpdates = false;
  TaskStatusUpdate? _deferredStatus;

  void deferStatus(TaskStatusUpdate update) => _deferredStatus = update;

  TaskStatusUpdate? acceptUpdates() {
    acceptingUpdates = true;
    final status = _deferredStatus;
    _deferredStatus = null;
    return status;
  }

  void discardDeferredStatus() => _deferredStatus = null;

  void complete() {
    if (!done.isCompleted) done.complete();
  }

  void completeError(Object error) {
    if (!done.isCompleted) done.completeError(error);
  }
}
