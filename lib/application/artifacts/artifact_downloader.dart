import 'dart:async';

class ArtifactDownloadRequest {
  const ArtifactDownloadRequest({
    required this.id,
    required this.uri,
    required this.destinationPath,
    required this.expectedBytes,
    required this.group,
    this.headers = const {},
    this.retries = 3,
  });

  final String id;
  final Uri uri;
  final String destinationPath;
  final int expectedBytes;
  final String group;
  final Map<String, String> headers;
  final int retries;
}

class ArtifactDownloadProgress {
  const ArtifactDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int totalBytes;

  double? get fraction =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0, 1) : null;
}

abstract interface class ArtifactDownloadCancellation {
  bool get isCancelled;
  Future<void> get whenCancelled;
  void throwIfCancelled();
  void Function() addListener(void Function() listener);
}

abstract interface class ArtifactDownloader {
  Future<void> download(
    ArtifactDownloadRequest request, {
    ArtifactDownloadCancellation? cancellation,
    void Function(ArtifactDownloadProgress progress)? onProgress,
  });
}

abstract interface class ControllableArtifactDownloader
    implements ArtifactDownloader {
  Future<bool> pause(String requestId);
  Future<bool> resume(String requestId);
  Future<bool> cancel(String requestId);
}

class ArtifactDownloadException implements Exception {
  const ArtifactDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ArtifactDownloadCancelledException extends ArtifactDownloadException {
  const ArtifactDownloadCancelledException()
    : super('Artifact download cancelled.');
}

class ArtifactDownloadCancellationToken
    implements ArtifactDownloadCancellation {
  bool _cancelled = false;
  final _listeners = <void Function()>{};
  final _cancelledCompleter = Completer<void>();

  @override
  bool get isCancelled => _cancelled;

  @override
  Future<void> get whenCancelled => _cancelledCompleter.future;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancelledCompleter.complete();
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  @override
  void Function() addListener(void Function() listener) {
    if (_cancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  @override
  void throwIfCancelled() {
    if (_cancelled) throw const ArtifactDownloadCancelledException();
  }
}
