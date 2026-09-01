// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:isolate';

typedef NativeWorkerFailureCallback = FutureOr<void> Function(
  Object error,
  bool failedAfterReady,
);

/// Keeps isolate error and exit listeners alive for the worker's full lifetime.
class NativeWorkerGuard {
  NativeWorkerGuard({
    required this.label,
    required NativeWorkerFailureCallback onFailure,
  }) : _onFailure = onFailure {
    _errorSubscription = errorPort.listen(_handleError);
    _exitSubscription = exitPort.listen(_handleExit);
  }

  final String label;
  final NativeWorkerFailureCallback _onFailure;
  final ReceivePort errorPort = ReceivePort();
  final ReceivePort exitPort = ReceivePort();
  final Completer<Object> _failure = Completer<Object>();
  final Completer<void> _exited = Completer<void>();

  StreamSubscription<dynamic>? _errorSubscription;
  StreamSubscription<dynamic>? _exitSubscription;
  bool _ready = false;
  bool _expectedExit = false;
  bool _failed = false;
  Future<void>? _disposeFuture;

  Future<Object> get failure => _failure.future;
  Future<void> get exited => _exited.future;

  void markReady() => _ready = true;

  void reportFailure(Object error) {
    if (_expectedExit || _failed) return;
    _failed = true;
    final failure = StateError('$label failed: ${_formatError(error)}');
    if (!_failure.isCompleted) _failure.complete(failure);
    unawaited(Future<void>.sync(() => _onFailure(failure, _ready)));
  }

  void _handleError(dynamic error) => reportFailure(
    error is Object ? error : StateError('$label emitted an empty error.'),
  );

  void _handleExit(dynamic _) {
    if (!_exited.isCompleted) _exited.complete();
    reportFailure(StateError('$label exited unexpectedly.'));
  }

  Future<void> dispose({required bool expectedExit}) async {
    if (expectedExit) _expectedExit = true;
    final inFlight = _disposeFuture;
    if (inFlight != null) return inFlight;
    final operation = _disposePorts();
    _disposeFuture = operation;
    return operation;
  }

  Future<void> _disposePorts() async {
    await _errorSubscription?.cancel();
    await _exitSubscription?.cancel();
    _errorSubscription = null;
    _exitSubscription = null;
    errorPort.close();
    exitPort.close();
  }

  static String _formatError(Object error) {
    if (error is List && error.isNotEmpty) return error.first.toString();
    return error.toString();
  }
}
