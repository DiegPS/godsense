import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:godsense/domain/ai/ai_runtime_models.dart';
import 'package:godsense/infrastructure/ai/open_code_compatible_runtime_client.dart';

void main() {
  for (final kind in AiRuntimeKind.values) {
    test('${kind.name} sends OAuth inputs and callback contract', () async {
      final requests = <http.Request>[];
      final httpClient = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/authorize')) {
          return http.Response(
            jsonEncode({
              'url': 'https://example.com',
              'method': 'code',
              'instructions': 'Code',
            }),
            200,
          );
        }
        return http.Response('true', 200);
      });
      addTearDown(httpClient.close);
      final client = OpenCodeCompatibleRuntimeClient(
        endpoint: AiRuntimeEndpoint(
          kind: kind,
          baseUri: Uri.parse('http://127.0.0.1:5000'),
          username: 'test',
          password: 'test',
          pid: 1,
        ),
        workspaceDirectory: 'test',
        client: httpClient,
      );
      await client.beginOAuth(
        'provider',
        methodIndex: 2,
        inputs: {'kind': 'enterprise'},
      );
      await client.completeOAuth('provider', methodIndex: 2, code: ' code ');
      expect(requests.last.url.path, '/provider/provider/oauth/callback');
      expect(jsonDecode(requests.first.body), {
        'method': 2,
        'inputs': {'kind': 'enterprise'},
      });
      expect(jsonDecode(requests.last.body), {'method': 2, 'code': 'code'});
    });
  }
}
