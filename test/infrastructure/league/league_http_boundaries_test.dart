import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/league/lcu_probe_transport.dart';
import 'package:godsense/infrastructure/league/league_clients.dart';

void main() {
  late HttpServer server;
  late LcuClient lcu;
  late LiveClientApi live;
  late _LoopbackClient transport;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    lcu = LcuClient(
      credentialsProvider: () => LcuCredentials(
        port: port,
        password: 'synthetic-only',
        protocol: 'http',
        lockfilePath: 'fixture',
      ),
      maxResponseBytes: 128,
      requestTimeout: const Duration(milliseconds: 300),
    );
    transport = _LoopbackClient(server.port);
    live = LiveClientApi(
      httpClient: transport,
      maxResponseBytes: 128,
      requestTimeout: const Duration(milliseconds: 300),
    );
  });
  tearDown(() async {
    lcu.dispose();
    live.dispose();
    await server.close(force: true);
  });

  test('missing League credentials produce a disconnected result and a legacy socket error', () async {
    lcu.dispose();
    lcu = LcuClient(credentialsProvider: () => null);
    expect(
      (await lcu.getDetailed('/fixture')).failureKind,
      LcuProbeFailureKind.disconnected,
    );
    await expectLater(lcu.get('/fixture'), throwsA(isA<SocketException>()));
  });

  test(
    'connection refusal is classified without escaping the detailed API',
    () async {
      await server.close(force: true);
      final result = await lcu.getDetailed('/fixture');
      expect(result.failureKind, LcuProbeFailureKind.disconnected);
      expect(result.error, isNotEmpty);
    },
  );

  for (final (status, kind) in [
    (401, LcuProbeFailureKind.unauthorized),
    (403, LcuProbeFailureKind.unauthorized),
    (409, LcuProbeFailureKind.clientError),
  ]) {
    test('LCU classifies HTTP $status and preserves its response', () async {
      final serving = _respond(server, status, '{"reason":"synthetic"}');
      final response = await lcu.getDetailed('/fixture');
      expect(response.failureKind, kind);
      expect(response.statusCode, status);
      expect(response.body, {'reason': 'synthetic'});
      await serving;
    });
  }

  for (final method in ['POST', 'PUT', 'DELETE']) {
    test(
      'LCU $method preserves method, JSON payload and empty acknowledgement',
      () async {
        final seen = Completer<(String, String, String?)>();
        final serving = () async {
          final request = await server.first;
          final body = await utf8.decoder.bind(request).join();
          seen.complete((
            request.method,
            body,
            request.headers.contentType?.mimeType,
          ));
          request.response.statusCode = 204;
          await request.response.close();
        }();
        final result = switch (method) {
          'POST' => await lcu.post('/fixture', {
            'selected': [1, 2],
          }),
          'PUT' => await lcu.put('/fixture', {
            'selected': [1, 2],
          }),
          _ => await lcu.delete('/fixture'),
        };
        expect(result, isEmpty);
        final request = await seen.future;
        expect(request.$1, method);
        if (method == 'DELETE') {
          expect(request.$2, isEmpty);
        } else {
          expect(jsonDecode(request.$2), {
            'selected': [1, 2],
          });
          expect(request.$3, 'application/json');
        }
        await serving;
      },
    );
  }

  test(
    'LCU oversized payload fails closed and later requests recover',
    () async {
      final responses = server.listen((request) async {
        request.response.write(
          request.uri.path == '/large' ? 'x' * 129 : '{"ok":true}',
        );
        await request.response.close();
      });
      try {
        final response = await lcu.getDetailed('/large');
        expect(response.failureKind, LcuProbeFailureKind.clientError);
        expect(response.error, contains('safety limit'));
        expect(await lcu.get('/small'), {'ok': true});
      } finally {
        await responses.cancel();
      }
    },
  );

  for (final (body, expected) in <(String, Map<String, dynamic>?)>[
    ('{"gameTime":12}', {'gameTime': 12}),
    ('[]', null),
    ('broken', null),
    ('x' * 129, null),
  ]) {
    test(
      'Live Client handles a bounded response: ${expected == null ? body.substring(0, body.length.clamp(0, 12)) : "object"}',
      () async {
        final serving = _respond(server, 200, body);
        expect(await live.allGameData(), expected);
        expect(
          transport.requested.single.toString(),
          'https://127.0.0.1:2999/liveclientdata/allgamedata',
        );
        await serving;
      },
    );
  }

  test('Live Client ignores non-success responses', () async {
    final serving = _respond(server, 503, 'not ready');
    expect(await live.allGameData(), isNull);
    await serving;
  });

  test(
    'Live Client bounds a response that sends headers then stalls',
    () async {
      final started = Completer<void>();
      final serving = () async {
        final request = await server.first;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{');
        await request.response.flush();
        started.complete();
      }();
      final timer = Stopwatch()..start();
      final operation = live.allGameData();
      await started.future;
      expect(await operation, isNull);
      expect(timer.elapsed, lessThan(const Duration(seconds: 2)));
      await serving;
    },
  );
}

Future<void> _respond(HttpServer server, int status, String body) async {
  final request = await server.first;
  request.response
    ..statusCode = status
    ..write(body);
  await request.response.close();
}

// Redirect only the real local Live Client endpoint to our ephemeral HTTP server.
// The production parser, limits, response stream and timeout still execute.
class _LoopbackClient implements HttpClient {
  _LoopbackClient(this.port);
  final int port;
  final _client = HttpClient();
  final requested = <Uri>[];
  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    requested.add(url);
    if (url.scheme != 'https' || url.host != '127.0.0.1' || url.port != 2999) {
      throw StateError('Unexpected destination');
    }
    return _client.getUrl(url.replace(scheme: 'http', port: port));
  }

  @override
  void close({bool force = false}) => _client.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
