import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/ai/ai_provider_connection_controller.dart';
import 'package:godsense/application/ai/ai_runtime_services.dart';
import 'package:godsense/domain/ai/ai_runtime_api_models.dart';

const method = AiAuthMethod(
  providerId: 'provider',
  type: 'oauth',
  label: 'Login',
  index: 2,
);

void main() {
  test(
    'OAuth code and prompt inputs complete only after provider confirmation',
    () async {
      final client = _AuthClient();
      final controller = AiProviderConnectionController(client: client);
      addTearDown(controller.dispose);
      await controller.refresh();
      await controller.beginOAuth(method, inputs: {'domain': 'example.com'});
      expect(client.inputs, {'domain': 'example.com'});
      expect(controller.state.connected, isEmpty);
      expect(controller.state.authorizationMethod, 'code');
      await controller.completeOAuth(code: 'test-code');
      expect(client.code, 'test-code');
      expect(controller.state.connected, {'provider'});
      expect(controller.state.pendingMethod, isNull);
      await controller.disconnect('provider');
      expect(controller.state.connected, isEmpty);
    },
  );
  test(
    'callback without connection confirmation keeps retry information',
    () async {
      final client = _AuthClient()..confirm = false;
      final controller = AiProviderConnectionController(client: client);
      addTearDown(controller.dispose);
      await controller.beginOAuth(method);
      await controller.completeOAuth(code: 'test-code');
      expect(controller.state.error, isNotNull);
      expect(controller.state.pendingMethod, method);
      expect(controller.state.connected, isEmpty);
    },
  );
  test('auth response after disposal cannot change state', () async {
    final client = _AuthClient()..delay = Completer<AiOAuthAuthorization>();
    final controller = AiProviderConnectionController(client: client);
    final pending = controller.beginOAuth(method);
    controller.dispose();
    client.delay!.complete(
      AiOAuthAuthorization(
        method: 'auto',
        url: Uri.parse('https://example.com'),
      ),
    );
    await pending;
  });
  test('prompt visibility follows selected provider fields', () {
    final prompt = AiAuthPrompt.fromJson({
      'key': 'domain',
      'type': 'text',
      'message': 'Dominio',
      'when': {'key': 'kind', 'op': 'eq', 'value': 'enterprise'},
    });
    expect(prompt.visible({'kind': 'public'}), isFalse);
    expect(prompt.visible({'kind': 'enterprise'}), isTrue);
  });
}

class _AuthClient implements AiProviderAuthClient {
  bool connected = false;
  bool confirm = true;
  String? code;
  Map<String, String>? inputs;
  Completer<AiOAuthAuthorization>? delay;
  @override
  Future<List<AiProviderInfo>> providers() async => [
    AiProviderInfo(
      id: 'provider',
      name: 'Provider',
      connected: connected,
      models: const [],
    ),
  ];
  @override
  Future<List<AiAuthMethod>> authMethods() async => [method];
  @override
  Future<void> setApiKey(String providerId, String apiKey) async {
    connected = confirm;
  }

  @override
  Future<AiOAuthAuthorization> beginOAuth(
    String providerId, {
    required int methodIndex,
    Map<String, String> inputs = const {},
  }) async {
    this.inputs = inputs;
    return delay != null
        ? delay!.future
        : AiOAuthAuthorization(
            method: 'code',
            url: Uri.parse('https://example.com/login'),
            instructions: 'Pega el código',
          );
  }

  @override
  Future<void> completeOAuth(
    String providerId, {
    required int methodIndex,
    String? code,
  }) async {
    this.code = code;
    connected = confirm;
  }

  @override
  Future<void> disconnectProvider(String providerId) async {
    connected = false;
  }

  @override
  void dispose() {}
}
