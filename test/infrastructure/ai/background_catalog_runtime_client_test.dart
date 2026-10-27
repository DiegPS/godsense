import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_ai_runtime/dart_ai_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/ai/open_code_compatible_runtime_client.dart';

void main() {
  late HttpServer server;
  late BackgroundCatalogRuntimeClient client;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = BackgroundCatalogRuntimeClient(
      endpoint: AiRuntimeEndpoint(
        kind: AiRuntimeKind.kilo,
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        username: 'test-user',
        password: 'test-only-password',
        pid: 1,
      ),
      workspaceDirectory: r'C:\test workspace',
      requestTimeout: const Duration(milliseconds: 500),
    );
  });
  tearDown(() async {
    client.dispose();
    await server.close(force: true);
  });

  test(
    'isolated catalog preserves auth and DTOs and coalesces requests',
    () async {
      var requests = 0;
      final received = <HttpRequest>[];
      server.listen((request) async {
        requests++;
        received.add(request);
        // Leave time for a second consumer to join the first request.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        request.response.write(jsonEncode(_catalog));
        await request.response.close();
      });
      final first = client.providers();
      final second = client.providers();
      expect(identical(first, second), isTrue);
      final providers = await first;
      expect(await second, same(providers));
      expect(requests, 1);
      expect(received.single.uri.path, '/provider');
      expect(
        received.single.uri.queryParameters['directory'],
        r'C:\test workspace',
      );
      expect(
        received.single.headers.value(HttpHeaders.authorizationHeader),
        'Basic ${base64Encode(utf8.encode('test-user:test-only-password'))}',
      );
      expect(providers.single.connected, isTrue);
      expect(providers.single.models.single.key, 'kilo/test-free');
      expect(providers.single.models.single.isFree, isTrue);
      expect(providers.single.models.single.isDefault, isTrue);
      await client.providers();
      expect(requests, 2); // Refresh must observe changed provider connections.
    },
  );

  test(
    'malformed response releases the request so refresh can recover',
    () async {
      var requests = 0;
      server.listen((request) async {
        request.response.write(++requests == 1 ? '{' : jsonEncode(_catalog));
        await request.response.close();
      });
      await expectLater(client.providers(), throwsFormatException);
      expect(await client.providers(), hasLength(1));
      expect(requests, 2);
      client.dispose();
      await expectLater(client.providers(), throwsStateError);
      expect(requests, 2);
    },
  );

  test('a stalled runtime request has a bounded lifetime', () async {
    server.listen((_) {});
    await expectLater(client.providers(), throwsA(isA<TimeoutException>()));
  });

  test('disposing a pending catalog rejects all consumers promptly', () async {
    final requested = Completer<void>();
    server.listen((_) => requested.complete());
    final first = client.providers();
    final second = client.providers();
    final rejected = expectLater(first, throwsStateError);
    expect(identical(first, second), isTrue);
    await requested.future.timeout(const Duration(seconds: 2));
    client.dispose();
    client.dispose();
    await rejected;
    await expectLater(client.providers(), throwsStateError);
  });

  test('disposing immediately cancels before the worker is ready', () async {
    server.listen((_) {});
    final rejected = expectLater(client.providers(), throwsStateError);
    client.dispose();
    await rejected;
    await expectLater(client.providers(), throwsStateError);
  });

  test(
    'HTTP errors preserve their status and allow a subsequent refresh',
    () async {
      var requests = 0;
      server.listen((request) async {
        if (++requests == 1) {
          request.response.statusCode = HttpStatus.serviceUnavailable;
          request.response.write('Temporary fixture failure');
        } else {
          request.response.write(jsonEncode(_catalog));
        }
        await request.response.close();
      });
      await expectLater(
        client.providers(),
        throwsA(
          isA<AiRuntimeApiException>().having(
            (error) => error.statusCode,
            'status',
            503,
          ),
        ),
      );
      expect(await client.providers(), hasLength(1));
      expect(requests, 2);
    },
  );

  test(
    'a slow body shares the request deadline and refresh can recover',
    () async {
      var requests = 0;
      server.listen((request) async {
        final first = ++requests == 1;
        if (first) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          request.response.write('{');
          await request.response.flush();
          // Each phase alone is below 500 ms; their combined time is not.
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        try {
          request.response.write(jsonEncode(_catalog).substring(first ? 1 : 0));
          await request.response.close();
        } catch (_) {
          // A client that enforces the deadline may already have disconnected.
        }
      });
      final watch = Stopwatch()..start();
      await expectLater(client.providers(), throwsA(isA<TimeoutException>()));
      expect(watch.elapsed, lessThan(const Duration(milliseconds: 800)));
      expect(await client.providers(), hasLength(1));
      expect(requests, 2);
    },
  );

  test(
    'initialization allowance ends after the first successful catalog',
    () async {
      client.dispose();
      client = BackgroundCatalogRuntimeClient(
        endpoint: AiRuntimeEndpoint(
          kind: AiRuntimeKind.openCode,
          baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
          username: 'test-user',
          password: 'test-only-password',
          pid: 1,
        ),
        workspaceDirectory: r'C:\test workspace',
        requestTimeout: const Duration(milliseconds: 100),
        initialCatalogTimeout: const Duration(milliseconds: 600),
      );
      var requests = 0;
      server.listen((request) async {
        requests++;
        await Future<void>.delayed(const Duration(milliseconds: 300));
        try {
          request.response.write(jsonEncode(_catalog));
          await request.response.close();
        } catch (_) {}
      });
      expect(await client.providers(), hasLength(1));
      await expectLater(client.providers(), throwsA(isA<TimeoutException>()));
      expect(requests, 2);
    },
  );
}

const _catalog = {
  'connected': ['kilo'],
  'default': {'kilo': 'test-free'},
  'all': [
    {
      'id': 'kilo',
      'name': 'Kilo',
      'models': {
        'test-free': {
          'id': 'test-free',
          'name': 'Test',
          'cost': {'input': 0, 'output': 0},
        },
        'retired': {'status': 'deprecated'},
      },
    },
  ],
};
