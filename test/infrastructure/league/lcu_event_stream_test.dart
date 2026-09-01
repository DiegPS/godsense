import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/league/lcu_event_stream.dart';
import 'package:godsense/infrastructure/league/league_clients.dart';

void main() {
  late HttpServer server;
  late LcuEventStream events;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    events = LcuEventStream(
      credentialsProvider: () => LcuCredentials(
        port: server.port,
        password: 'secret',
        protocol: 'http',
        lockfilePath: 'test-lockfile',
      ),
      reconnectDelay: const Duration(milliseconds: 20),
    );
  });

  tearDown(() async {
    await events.dispose();
    await server.close(force: true);
  });

  test('authenticates, subscribes, and decodes OnJsonApiEvent', () async {
    final serverSide = _accept(server);
    final stateFuture = events.states.firstWhere(
      (state) => state == LcuEventConnectionState.connected,
    );
    final eventFuture = events.events.first;

    events.start();
    final accepted = await serverSide;
    expect(
      accepted.authorization,
      'Basic ${base64Encode(utf8.encode('riot:secret'))}',
    );
    expect(jsonDecode(await accepted.socket.first as String), [
      5,
      'OnJsonApiEvent',
    ]);
    accepted.socket.add(
      jsonEncode([
        8,
        'OnJsonApiEvent',
        {
          'uri': '/lol-gameflow/v1/gameflow-phase',
          'eventType': 'Update',
          'data': 'ChampSelect',
        },
      ]),
    );

    expect(await stateFuture, LcuEventConnectionState.connected);
    final event = await eventFuture;
    expect(event.uri, '/lol-gameflow/v1/gameflow-phase');
    expect(event.eventType, 'Update');
    expect(event.data, 'ChampSelect');
  });

  test('ignores malformed and unrelated websocket frames', () async {
    final serverSide = _accept(server);
    final received = <LcuApiEvent>[];
    final subscription = events.events.listen(received.add);

    events.start();
    final accepted = await serverSide;
    await accepted.socket.first;
    accepted.socket
      ..add('not-json')
      ..add(jsonEncode([1, 'unrelated']))
      ..add(
        jsonEncode([
          8,
          'OnJsonApiEvent',
          {'eventType': 'Update'},
        ]),
      );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(received, isEmpty);
    await subscription.cancel();
  });
}

Future<({WebSocket socket, String? authorization})> _accept(
  HttpServer server,
) async {
  final request = await server.first;
  final authorization = request.headers.value(HttpHeaders.authorizationHeader);
  final socket = await WebSocketTransformer.upgrade(request);
  return (socket: socket, authorization: authorization);
}
