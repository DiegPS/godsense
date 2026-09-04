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
    this.authorizationMethod,
    this.pendingMethod,
    this.connected = const {},
    this.error,
  });
  final List<AiAuthMethod> methods;
  final bool loading;
  final String? operatingProvider;
  final String? instructions;
  final Uri? authorizationUrl;
  final String? authorizationMethod;
  final AiAuthMethod? pendingMethod;
  final Set<String> connected;
  final String? error;
}

class AiProviderConnectionController
    extends StateNotifier<AiProviderConnectionState> {
  AiProviderConnectionController({required AiProviderAuthClient? client})
    : _client = client,
      super(const AiProviderConnectionState());
  final AiProviderAuthClient? _client;
  int _revision = 0;

  Future<void> refresh() async {
    if (!mounted || _client == null || state.operatingProvider != null) return;
    final revision = ++_revision;
    state = AiProviderConnectionState(
      methods: state.methods,
      connected: state.connected,
      loading: true,
    );
    try {
      final methods = await _client.authMethods();
      final connected = await _connected();
      if (!mounted || revision != _revision) return;
      state = AiProviderConnectionState(methods: methods, connected: connected);
    } catch (_) {
      if (mounted && revision == _revision) {
        state = AiProviderConnectionState(
          methods: state.methods,
          error: 'No se pudo consultar la conexión. Vuelve a intentarlo.',
        );
      }
    }
  }

  Future<Set<String>> _connected() async => (await _client!.providers())
      .where((provider) => provider.connected)
      .map((provider) => provider.id)
      .toSet();

  Future<void> connectApiKey(String providerId, String apiKey) => _operate(
    providerId,
    () => _client!.setApiKey(providerId, apiKey),
    shouldConnect: true,
  );

  Future<void> beginOAuth(
    AiAuthMethod method, {
    Map<String, String> inputs = const {},
  }) async {
    if (!mounted || _client == null || state.operatingProvider != null) return;
    final revision = ++_revision;
    state = AiProviderConnectionState(
      methods: state.methods,
      connected: state.connected,
      operatingProvider: method.providerId,
    );
    try {
      final authorization = await _client
          .beginOAuth(
            method.providerId,
            methodIndex: method.index,
            inputs: inputs,
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted || revision != _revision) return;
      final url = authorization.url;
      if (url == null ||
          !['https', 'http'].contains(url.scheme) ||
          url.host.isEmpty) {
        throw const FormatException('Invalid authorization URL');
      }
      if (!['auto', 'code'].contains(authorization.method)) {
        throw const FormatException('Unsupported authorization method');
      }
      state = AiProviderConnectionState(
        methods: state.methods,
        connected: state.connected,
        pendingMethod: method,
        authorizationMethod: authorization.method,
        authorizationUrl: url,
        instructions:
            authorization.instructions ??
            'Completa el inicio de sesión en tu navegador.',
      );
    } catch (_) {
      if (mounted && revision == _revision) {
        state = AiProviderConnectionState(
          methods: state.methods,
          connected: state.connected,
          error: 'No se pudo iniciar el acceso. Revisa los campos y vuelve a intentarlo.',
        );
      }
    }
  }

  Future<void> completeOAuth({String? code}) async {
    final method = state.pendingMethod;
    if (method == null) return;
    if (state.authorizationMethod == 'code' && (code?.trim().isEmpty ?? true)) {
      return;
    }
    await _operate(method.providerId, () async {
      // Some runtimes complete device login themselves. Do not replay it.
      if (!(await _connected()).contains(method.providerId)) {
        await _client!.completeOAuth(
          method.providerId,
          methodIndex: method.index,
          code: code,
        );
      }
    }, shouldConnect: true);
  }

  Future<void> disconnect(String providerId) => _operate(
    providerId,
    () => _client!.disconnectProvider(providerId),
    shouldConnect: false,
  );

  Future<void> _operate(
    String providerId,
    Future<void> Function() operation, {
    required bool shouldConnect,
  }) async {
    if (!mounted || _client == null || state.operatingProvider != null) return;
    final previous = state;
    final revision = ++_revision;
    state = AiProviderConnectionState(
      methods: previous.methods,
      connected: previous.connected,
      operatingProvider: providerId,
    );
    try {
      await operation().timeout(const Duration(seconds: 90));
      final connected = await _connected();
      if (!mounted || revision != _revision) return;
      if (connected.contains(providerId) != shouldConnect) {
        throw StateError('Connection not confirmed');
      }
      state = AiProviderConnectionState(
        methods: previous.methods,
        connected: connected,
      );
    } catch (_) {
      if (!mounted || revision != _revision) return;
      state = AiProviderConnectionState(
        methods: previous.methods,
        connected: previous.connected,
        pendingMethod: previous.pendingMethod,
        authorizationUrl: previous.authorizationUrl,
        authorizationMethod: previous.authorizationMethod,
        instructions: previous.instructions,
        error: 'El motor no confirmó el cambio. Completa el acceso o vuelve a intentarlo.',
      );
    }
  }

  @override
  void dispose() {
    _revision++;
    _client?.dispose();
    super.dispose();
  }
}
