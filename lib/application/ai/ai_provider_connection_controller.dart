// ignore_for_file: prefer_initializing_formals

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ai/ai_runtime_api_models.dart';
import 'ai_runtime_services.dart';

class AiProviderConnectionState {
  const AiProviderConnectionState({
    this.methods = const [],
    this.loading = false,
    this.operatingProvider,
    this.instructions,
    this.authorizationUrl,
    this.error,
  });

  final List<AiAuthMethod> methods;
  final bool loading;
  final String? operatingProvider;
  final String? instructions;
  final Uri? authorizationUrl;
  final String? error;
}

class AiProviderConnectionController
    extends StateNotifier<AiProviderConnectionState> {
  AiProviderConnectionController({required AiProviderAuthClient? client})
    : _client = client,
      super(const AiProviderConnectionState());

  final AiProviderAuthClient? _client;

  Future<void> refresh() async {
    final client = _client;
    if (client == null) return;
    state = AiProviderConnectionState(methods: state.methods, loading: true);
    try {
      state = AiProviderConnectionState(methods: await client.authMethods());
    } catch (error) {
      state = AiProviderConnectionState(error: error.toString());
    }
  }

  Future<void> connectApiKey(String providerId, String apiKey) async {
    await _operate(providerId, () => _client!.setApiKey(providerId, apiKey));
  }

  Future<void> beginOAuth(AiAuthMethod method) async {
    state = AiProviderConnectionState(
      methods: state.methods,
      operatingProvider: method.providerId,
    );
    try {
      final authorization = await _client!.beginOAuth(
        method.providerId,
        methodIndex: method.index,
      );
      state = AiProviderConnectionState(
        methods: state.methods,
        instructions:
            authorization.instructions ??
            'Completa el inicio de sesión en tu navegador.',
        authorizationUrl: authorization.url,
      );
    } catch (error) {
      state = AiProviderConnectionState(
        methods: state.methods,
        error: error.toString(),
      );
    }
  }

  Future<void> disconnect(String providerId) async {
    await _operate(providerId, () => _client!.disconnectProvider(providerId));
  }

  Future<void> _operate(
    String providerId,
    Future<void> Function() operation,
  ) async {
    state = AiProviderConnectionState(
      methods: state.methods,
      operatingProvider: providerId,
    );
    try {
      await operation();
      state = AiProviderConnectionState(methods: state.methods);
    } catch (error) {
      state = AiProviderConnectionState(
        methods: state.methods,
        error: error.toString(),
      );
    }
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }
}
