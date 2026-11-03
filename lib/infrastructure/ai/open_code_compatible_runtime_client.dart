import 'dart:async';
import 'dart:isolate';

import 'package:dart_ai_runtime/dart_ai_runtime.dart' as runtime;

export 'package:dart_ai_runtime/dart_ai_runtime.dart'
    show OpenCodeCompatibleRuntimeClient;

// Delegates protocol selection to dart_ai_runtime for all operations.
// Provider catalogs contain thousands of models, including disconnected
// providers. Fetch, decode and construct the shared DTOs away from the UI.
class BackgroundCatalogRuntimeClient
    implements runtime.AiRuntimeClient, runtime.AiProviderAuthClient {
  static const defaultRequestTimeout = Duration(seconds: 30);
  // OpenCode initializes its workspace and installs its internal npm
  // dependencies on the first provider request, after global health is ready.
  // Keep that allowance separate from normal API calls and warm refreshes.
  static const defaultInitialCatalogTimeout = Duration(seconds: 60);

  BackgroundCatalogRuntimeClient({
    required this.endpoint,
    required this.workspaceDirectory,
    runtime.AiRuntimeSystemPromptService? systemPromptService,
    Duration? requestTimeout,
    Duration? initialCatalogTimeout,
  }) : initialCatalogTimeout =
           initialCatalogTimeout ??
           requestTimeout ??
           defaultInitialCatalogTimeout,
       requestTimeout = requestTimeout ?? defaultRequestTimeout,
       _delegate = runtime.createAiRuntimeClient(
         endpoint: endpoint,
         workspaceDirectory: workspaceDirectory,
         systemPromptService: systemPromptService,
         requestTimeout: requestTimeout ?? defaultRequestTimeout,
       );

  final runtime.AiRuntimeEndpoint endpoint;
  final String workspaceDirectory;
  final Duration requestTimeout;
  final runtime.AiRuntimeClient _delegate;
  final Duration initialCatalogTimeout;
  _CatalogRequest? _catalog;
  bool _initialized = false;
  bool _disposed = false;

  @override
  Future<List<runtime.AiProviderInfo>> providers() {
    if (_disposed) return Future.error(StateError('Runtime client is closed.'));
    final pending = _catalog;
    if (pending != null) return pending.result;
    final request = _CatalogRequest(
      endpoint,
      workspaceDirectory,
      _initialized ? requestTimeout : initialCatalogTimeout,
    );
    _catalog = request;
    void clear() {
      if (identical(_catalog, request)) _catalog = null;
    }

    unawaited(
      request.result.then<void>((_) {
        _initialized = true;
        clear();
      }, onError: (Object _, StackTrace _) => clear()),
    );
    return request.result;
  }

  @override
  void dispose() {
    _disposed = true;
    _catalog?.cancel();
    _delegate.dispose();
  }

  runtime.AiProviderAuthClient get _auth {
    final Object client = _delegate;
    if (client is runtime.AiProviderAuthClient) return client;
    throw UnsupportedError(
      'Este motor administra las conexiones de proveedores desde su configuración nativa.',
    );
  }

  @override
  Future<List<runtime.AiAuthMethod>> authMethods() => _delegate.authMethods();
  @override
  Future<runtime.AiSession> createSession({String? title}) =>
      _delegate.createSession(title: title);
  @override
  Future<runtime.AiSession> session(String id) => _delegate.session(id);
  @override
  Future<List<Map<String, dynamic>>> messages(String id) =>
      _delegate.messages(id);
  @override
  Future<void> promptAsync(String id, runtime.AiPrompt prompt) =>
      _delegate.promptAsync(id, prompt);
  @override
  Future<void> abort(String id) => _delegate.abort(id);
  @override
  Future<void> deleteSession(String id) => _delegate.deleteSession(id);
  @override
  Future<Stream<runtime.AiRuntimeEvent>> connectEvents() =>
      _delegate.connectEvents();
  @override
  Stream<runtime.AiRuntimeEvent> events() => _delegate.events();
  @override
  Future<void> setApiKey(String providerId, String apiKey) =>
      _auth.setApiKey(providerId, apiKey);
  @override
  Future<runtime.AiOAuthAuthorization> beginOAuth(
    String providerId, {
    required int methodIndex,
    Map<String, String> inputs = const {},
  }) => _auth.beginOAuth(providerId, methodIndex: methodIndex, inputs: inputs);
  @override
  Future<void> completeOAuth(
    String providerId, {
    required int methodIndex,
    String? code,
  }) => _auth.completeOAuth(providerId, methodIndex: methodIndex, code: code);
  @override
  Future<void> disconnectProvider(String providerId) =>
      _auth.disconnectProvider(providerId);
}

class _CatalogRequest {
  _CatalogRequest(
    runtime.AiRuntimeEndpoint endpoint,
    String workspace,
    Duration timeout,
  ) {
    _port.handler = (dynamic message) {
      if (message is List && message.length == 1) {
        _finish(
          providers: (message.single as List).cast<runtime.AiProviderInfo>(),
        );
      } else if (message is List && message.length == 2) {
        final error = message.first;
        _finish(
          error: error is String
              ? RemoteError(error, '${message.last}')
              : error,
          stack: StackTrace.fromString('${message.last}'),
        );
      } else {
        _finish(
          error: StateError('Provider catalog worker exited without a result.'),
        );
      }
    };
    _deadline = Timer(
      timeout,
      () => _finish(
        error: TimeoutException('Provider catalog did not complete.', timeout),
      ),
    );
    unawaited(
      Isolate.spawn(
        _catalogWorker,
        <Object>[_port.sendPort, endpoint, workspace, timeout],
        onError: _port.sendPort,
        onExit: _port.sendPort,
        errorsAreFatal: true,
        debugName: 'ai-provider-catalog',
      ).then<void>(
        (worker) {
          _worker = worker;
          if (_result.isCompleted) worker.kill(priority: Isolate.immediate);
        },
        onError: (Object error, StackTrace stack) =>
            _finish(error: error, stack: stack),
      ),
    );
  }

  final _result = Completer<List<runtime.AiProviderInfo>>();
  final _port = RawReceivePort();
  Timer? _deadline;
  Isolate? _worker;

  Future<List<runtime.AiProviderInfo>> get result => _result.future;

  void cancel() => _finish(error: StateError('Runtime client is closed.'));

  void _finish({
    List<runtime.AiProviderInfo>? providers,
    Object? error,
    StackTrace? stack,
  }) {
    if (_result.isCompleted) return;
    _deadline?.cancel();
    _port.close();
    // This worker owns only async HTTP and JSON parsing, with no native FFI
    // callbacks. Ending it also releases pending sockets when cancelled.
    _worker?.kill(priority: Isolate.immediate);
    if (error != null) {
      _result.completeError(error, stack);
    } else {
      _result.complete(providers!);
    }
  }
}

// A top-level entrypoint cannot capture the client's HTTP or prompt resources.
Future<void> _catalogWorker(List<Object> input) async {
  final reply = input[0] as SendPort;
  final client = runtime.createAiRuntimeClient(
    endpoint: input[1] as runtime.AiRuntimeEndpoint,
    workspaceDirectory: input[2] as String,
    requestTimeout: input[3] as Duration,
  );
  try {
    final providers = await client.providers();
    client.dispose();
    Isolate.exit(reply, <Object>[providers]);
  } catch (error, stack) {
    client.dispose();
    Isolate.exit(reply, <Object>[error, stack.toString()]);
  }
}
