import 'dart:async';

import 'package:dart_ai_runtime/dart_ai_runtime.dart' as runtime;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  final List<runtime.AiAuthMethod> methods;
  final bool loading;
  final String? operatingProvider;
  final String? instructions;
  final Uri? authorizationUrl;
  final String? authorizationMethod;
  final runtime.AiAuthMethod? pendingMethod;
  final Set<String> connected;
  final String? error;
}

/// Riverpod/UI adapter over dart_ai_runtime's authentication controller.
class AiProviderConnectionController
    extends StateNotifier<AiProviderConnectionState> {
  AiProviderConnectionController({required AiProviderAuthClient? client})
    : _core = client == null
          ? null
          : runtime.AiProviderConnectionController(client: client),
      super(const AiProviderConnectionState()) {
    _subscription = _core?.states.listen(_apply);
  }

  final runtime.AiProviderConnectionController? _core;
  StreamSubscription<runtime.AiProviderConnectionState>? _subscription;
  bool _disposed = false;

  Future<void> refresh() async {
    final core = _core;
    if (core == null || _disposed) return;
    await core.refresh();
    _sync();
  }

  Future<void> connectApiKey(String providerId, String apiKey) =>
      _operate(() => _core?.connectApiKey(providerId, apiKey));

  Future<void> beginOAuth(
    runtime.AiAuthMethod method, {
    Map<String, String> inputs = const {},
  }) => _operate(() => _core?.beginOAuth(method, inputs: inputs));

  Future<void> completeOAuth({String? code}) =>
      _operate(() => _core?.completeOAuth(code: code));

  Future<void> disconnect(String providerId) =>
      _operate(() => _core?.disconnect(providerId));

  Future<void> _operate(Future<Object?>? Function() operation) async {
    if (_core == null || _disposed) return;
    try {
      await operation();
    } catch (_) {
      if (_disposed) return;
    }
    _sync();
  }

  void _sync() {
    final core = _core;
    if (core != null && !_disposed) _apply(core.state);
  }

  void _apply(runtime.AiProviderConnectionState value) {
    if (_disposed || !mounted) return;
    final authorization = value.authorization;
    state = AiProviderConnectionState(
      methods: value.methods,
      loading: value.loading,
      operatingProvider: value.operatingProviderId,
      instructions: authorization?.instructions,
      authorizationUrl: authorization?.url,
      authorizationMethod: authorization?.method,
      pendingMethod: value.pendingMethod,
      connected: value.connectedProviderIds,
      error: value.error?.toString(),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_subscription?.cancel());
    final core = _core;
    if (core != null) unawaited(core.dispose(disposeClient: true));
    super.dispose();
  }
}
