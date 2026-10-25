import 'dart:isolate';

import 'package:dart_ai_runtime/dart_ai_runtime.dart' as runtime;

export 'package:dart_ai_runtime/dart_ai_runtime.dart'
    show OpenCodeCompatibleRuntimeClient;

// Provider catalogs contain thousands of models, including disconnected
// providers. Fetch, decode and construct the shared DTOs away from the UI.
class BackgroundCatalogRuntimeClient
    extends runtime.OpenCodeCompatibleRuntimeClient {
  BackgroundCatalogRuntimeClient({
    required super.endpoint,
    required super.workspaceDirectory,
    super.systemPromptService,
    super.requestTimeout,
  });

  Future<List<runtime.AiProviderInfo>>? _catalog;
  bool _disposed = false;

  @override
  Future<List<runtime.AiProviderInfo>> providers() {
    if (_disposed) return Future.error(StateError('Runtime client is closed.'));
    return _catalog ??= _backgroundCatalog(
      endpoint,
      workspaceDirectory,
      requestTimeout,
    ).whenComplete(() => _catalog = null);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// Keep the closure outside the client so it cannot capture an HttpClient,
// prompt bridge, subscription or other UI-owned unsendable resource.
Future<List<runtime.AiProviderInfo>> _backgroundCatalog(
  runtime.AiRuntimeEndpoint endpoint,
  String workspace,
  Duration timeout,
) => Isolate.run(() async {
  final client = runtime.OpenCodeCompatibleRuntimeClient(
    endpoint: endpoint,
    workspaceDirectory: workspace,
    requestTimeout: timeout,
  );
  try {
    return await client.providers();
  } finally {
    client.dispose();
  }
}, debugName: 'ai-provider-catalog');
