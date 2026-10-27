import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

// Owned by the app isolate so losing the async proxy cannot orphan inference.
class SpeechProcessHost {
  SpeechProcessHost(this.executable) {
    _requests.listen((dynamic reply) {
      if (reply is! SendPort) return;
      if (_closed || _starting != null) {
        reply.send({
          'error': 'Speech process host is closed or already started.',
        });
        return;
      }
      _starting = _start(reply);
    });
  }
  final String executable;
  final _requests = ReceivePort();
  final _commands = ReceivePort();
  Process? _process;
  Future<void>? _starting;
  Future<void>? _closing;
  Future<void>? _outputDone;
  Future<void>? _stderrDone;
  bool _closed = false;
  Future<void> _writes = Future<void>.value();
  SendPort get requests => _requests.sendPort;
  int? get processId => _process?.pid;

  Future<void> _start(SendPort reply) async {
    try {
      final child = await Process.start(
        executable,
        const [],
        runInShell: false,
        includeParentEnvironment: false,
        environment: {
          for (final entry in Platform.environment.entries)
            if (const {
              'systemroot',
              'systemdrive',
              'windir',
              'temp',
              'tmp',
            }.contains(entry.key.toLowerCase()))
              entry.key: entry.value,
        },
      );
      _process = child;
      _stderrDone = child.stderr
          .drain<void>(); // Never expose native text/input.
      if (_closed) {
        child.kill();
        _outputDone = child.stdout.drain<void>();
        reply.send({'error': 'Speech process host was closed during startup.'});
        return;
      }
      _outputDone = child.stdout
          .forEach((bytes) {
            reply.send(
              TransferableTypedData.fromList([Uint8List.fromList(bytes)]),
            );
          })
          .then(
            (_) => reply.send({'stdoutDone': true}),
            onError: (Object _) {
              reply.send({'error': 'Speech process output failed.'});
            },
          );
      unawaited(child.exitCode.then((code) => reply.send({'exitCode': code})));
      _commands.listen((dynamic command) {
        if (_closed || command is! Map) return;
        if (command['data'] case final TransferableTypedData bytes) {
          final payload = bytes.materialize().asUint8List();
          _writes = _writes
              .then((_) async {
                if (_closed) return;
                child.stdin.add(payload);
                await child.stdin.flush();
              })
              .catchError((Object _) {
                if (!_closed) {
                  reply.send({'error': 'Speech process input failed.'});
                }
              });
        } else if (command['kill'] == true) {
          child.kill();
        } else if (command['closeInput'] == true) {
          unawaited(child.stdin.close().catchError((Object _) {}));
        }
      });
      reply.send({'commands': _commands.sendPort, 'pid': child.pid});
    } catch (_) {
      reply.send({'error': 'Speech helper could not be started.'});
    }
  }

  void terminate() => _process?.kill();
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    _requests.close();
    _commands.close();
    _process?.kill();
    await _starting;
    final child = _process;
    if (child != null) {
      child.kill();
      await child.exitCode;
      try {
        await child.stdin.close();
      } catch (_) {}
    }
    await _outputDone;
    await _stderrDone;
  }
}

class SpeechProcessConnection {
  SpeechProcessConnection._() {
    _events.listen((dynamic event) {
      if (event is TransferableTypedData) {
        _output.add(event.materialize().asUint8List());
      } else if (event is Map) {
        if (event['commands'] case final SendPort commands) {
          _commands = commands;
          processId = event['pid'] as int;
          _ready.complete();
        } else if (event['error'] case final String message) {
          if (!_ready.isCompleted) {
            _ready.completeError(StateError(message));
          } else if (!_output.isClosed) {
            _output.addError(StateError(message));
          }
        } else if (event['stdoutDone'] == true) {
          unawaited(_output.close());
        } else if (event['exitCode'] case final int code) {
          _exit.complete(code);
        }
      }
    });
  }
  static Future<SpeechProcessConnection> connect(SendPort host) async {
    final connection = SpeechProcessConnection._();
    host.send(connection._events.sendPort);
    try {
      await connection._ready.future;
      return connection;
    } catch (_) {
      connection._events.close();
      rethrow;
    }
  }

  final _events = ReceivePort();
  final _output = StreamController<List<int>>();
  final _ready = Completer<void>();
  final _exit = Completer<int>();
  late final SendPort _commands;
  late final int processId;
  Stream<List<int>> get stdout => _output.stream;
  Future<int> get exitCode => _exit.future;
  void add(List<int> bytes) => _commands.send({
    'data': TransferableTypedData.fromList([Uint8List.fromList(bytes)]),
  });
  void kill() => _commands.send({'kill': true});
  void closeInput() => _commands.send({'closeInput': true});
  Future<void> close() async {
    _events.close();
    if (!_output.isClosed) await _output.close();
  }
}
