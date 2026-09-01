// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'league_clients.dart';

enum LcuEventConnectionState { connecting, connected, disconnected }

class LcuApiEvent {
  const LcuApiEvent({
    required this.uri,
    required this.eventType,
    required this.data,
  });

  final String uri;
  final String eventType;
  final Object? data;
}

typedef LcuWebSocketConnector = Future<WebSocket> Function(
  Uri uri,
  Map<String, dynamic> headers,
);

class LcuEventStream {
  LcuEventStream({
    required LcuCredentials? Function() credentialsProvider,
    LcuWebSocketConnector? connector,
    this.reconnectDelay = const Duration(seconds: 2),
  }) : _credentialsProvider = credentialsProvider,
       _connector = connector,
       _httpClient = connector == null
           ? (HttpClient()..badCertificateCallback = (_, _, _) => true)
           : null;

  final LcuCredentials? Function() _credentialsProvider;
  final LcuWebSocketConnector? _connector;
  final HttpClient? _httpClient;
  final Duration reconnectDelay;
  final _events = StreamController<LcuApiEvent>.broadcast();
  final _states = StreamController<LcuEventConnectionState>.broadcast();
  WebSocket? _socket;
  Timer? _reconnectTimer;
  bool _started = false;
  bool _connecting = false;
  bool _disposed = false;
  int _generation = 0;

  Stream<LcuApiEvent> get events => _events.stream;
  Stream<LcuEventConnectionState> get states => _states.stream;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    unawaited(_open());
  }

  Future<void> _open() async {
    if (_disposed || !_started || _connecting || _socket != null) return;
    final credentials = _credentialsProvider();
    if (credentials == null) {
      _emitState(LcuEventConnectionState.disconnected);
      _scheduleReconnect();
      return;
    }
    _connecting = true;
    _emitState(LcuEventConnectionState.connecting);
    final generation = ++_generation;
    try {
      final scheme = credentials.protocol == 'https' ? 'wss' : 'ws';
      final socket = await (_connector ?? _connect)(
        Uri(scheme: scheme, host: '127.0.0.1', port: credentials.port),
        {
          HttpHeaders.authorizationHeader:
              'Basic ${base64Encode(utf8.encode('riot:${credentials.password}'))}',
        },
      );
      if (_disposed || generation != _generation) {
        await socket.close();
        return;
      }
      _socket = socket;
      _emitState(LcuEventConnectionState.connected);
      socket.add(jsonEncode(const [5, 'OnJsonApiEvent']));
      socket.listen(
        (message) => _onMessage(message, generation),
        onError: (_) => _onClosed(generation),
        onDone: () => _onClosed(generation),
        cancelOnError: true,
      );
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _emitState(LcuEventConnectionState.disconnected);
        _scheduleReconnect();
      }
    } finally {
      _connecting = false;
    }
  }

  void _onMessage(Object? message, int generation) {
    if (_disposed || generation != _generation || message is! String) return;
    try {
      final decoded = jsonDecode(message);
      if (decoded is! List || decoded.length < 3 || decoded[0] != 8) return;
      final envelope = decoded[2];
      if (envelope is! Map) return;
      final uri = envelope['uri']?.toString();
      final eventType = envelope['eventType']?.toString();
      if (uri == null || eventType == null || _events.isClosed) return;
      _events.add(
        LcuApiEvent(uri: uri, eventType: eventType, data: envelope['data']),
      );
    } on FormatException {
      // Unknown frames are ignored; periodic REST reconciliation remains active.
    }
  }

  void _onClosed(int generation) {
    if (_disposed || generation != _generation) return;
    _socket = null;
    _emitState(LcuEventConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || !_started || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(reconnectDelay, () => unawaited(_open()));
  }

  void _emitState(LcuEventConnectionState value) {
    if (!_states.isClosed) _states.add(value);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _started = false;
    _generation++;
    _reconnectTimer?.cancel();
    await _socket?.close();
    _httpClient?.close(force: true);
    await _events.close();
    await _states.close();
  }

  Future<WebSocket> _connect(Uri uri, Map<String, dynamic> headers) {
    return WebSocket.connect(
      uri.toString(),
      headers: headers,
      customClient: _httpClient,
    );
  }
}
