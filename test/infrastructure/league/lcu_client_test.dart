import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/league/lcu_probe_transport.dart';
import 'package:godsense/infrastructure/league/league_clients.dart';

void main() {
  late HttpServer server;
  late LcuClient client;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = LcuClient(
      credentialsProvider: () => LcuCredentials(
        port: server.port,
        password: 'test-password',
        protocol: 'http',
        lockfilePath: 'test-lockfile',
      ),
    );
  });

  tearDown(() async {
    client.dispose();
    await server.close(force: true);
  });

  test(
    'keeps the existing get contract for successful JSON responses',
    () async {
      final response = _respondOnce(
        server,
        status: 200,
        body: '{"phase":"Lobby"}',
      );

      final result = await client.get('/lol-gameflow/v1/session');

      expect(result, {'phase': 'Lobby'});
      final request = await response;
      expect(request.uri.path, '/lol-gameflow/v1/session');
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Basic ${base64Encode(utf8.encode('riot:test-password'))}',
      );
    },
  );

  test('keeps the existing get contract of returning null for 404', () async {
    final response = _respondOnce(server, status: 404, body: 'missing');

    expect(await client.get('/contextual-resource'), isNull);
    await response;
  });

  test('returns detailed failure classification without throwing', () async {
    final response = _respondOnce(server, status: 503, body: 'restarting');

    final result = await client.getDetailed('/health');

    expect(result.isSuccess, isFalse);
    expect(result.statusCode, 503);
    expect(result.failureKind, LcuProbeFailureKind.serverError);
    await response;
  });

  test('legacy get still throws for non-404 failures', () async {
    final response = _respondOnce(server, status: 500, body: 'broken');

    expect(() => client.get('/broken'), throwsA(isA<HttpException>()));
    await response;
  });

  test('a stalled response times out without freezing the caller', () async {
    client.dispose();
    client = LcuClient(
      credentialsProvider: () => LcuCredentials(
        port: server.port,
        password: 'test-password',
        protocol: 'http',
        lockfilePath: 'test-lockfile',
      ),
      requestTimeout: const Duration(milliseconds: 100),
    );
    final received = server.first;
    final stopwatch = Stopwatch()..start();

    final result = await client.getDetailed('/never-finishes');

    stopwatch.stop();
    expect(result.failureKind, LcuProbeFailureKind.disconnected);
    expect(result.error, contains('exceeded'));
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    expect((await received).uri.path, '/never-finishes');
  });
}

Future<HttpRequest> _respondOnce(
  HttpServer server, {
  required int status,
  required String body,
}) async {
  final request = await server.first;
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(body);
  await request.response.close();
  return request;
}
