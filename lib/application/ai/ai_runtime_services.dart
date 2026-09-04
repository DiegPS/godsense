import '../../domain/ai/ai_runtime_models.dart';
import '../../domain/ai/ai_runtime_api_models.dart';
import '../../domain/artifacts/artifact_spec.dart';
import '../artifacts/artifact_downloader.dart';

abstract interface class AiRuntimeInstallService {
  AiRuntimeDefinition definition(AiRuntimeKind kind);

  Future<AiRuntimeInstallation?> installed(AiRuntimeKind kind);

  Future<AiRuntimeInstallation> install(
    AiRuntimeKind kind, {
    ArtifactDownloadCancellation? cancellation,
    void Function(ArtifactInstallProgress progress)? onProgress,
  });
}

abstract interface class AiRuntimeProcessHandle {
  AiRuntimeEndpoint get endpoint;
  Stream<String> get logs;
  Future<int> get exitCode;
  Future<void> stop();
}

abstract interface class AiRuntimeProcessService {
  Future<AiRuntimeProcessHandle> start(
    AiRuntimeInstallation installation, {
    required String password,
  });
}

abstract interface class AiRuntimeHealthService {
  Future<AiRuntimeHealth> waitUntilReady(
    AiRuntimeEndpoint endpoint, {
    Duration timeout,
  });
}

abstract interface class AiRuntimeClient {
  Future<List<AiProviderInfo>> providers();
  Future<List<AiAuthMethod>> authMethods();
  Future<AiSession> createSession({String? title});
  Future<AiSession> session(String sessionId);
  Future<List<Map<String, dynamic>>> messages(String sessionId);
  Future<void> promptAsync(String sessionId, AiPrompt prompt);
  Future<void> abort(String sessionId);
  Future<void> deleteSession(String sessionId);
  Stream<AiRuntimeEvent> events();
  Future<Stream<AiRuntimeEvent>> connectEvents();
  void dispose();
}

abstract interface class AiProviderAuthClient {
  Future<List<AiProviderInfo>> providers();
  Future<void> completeOAuth(
    String providerId, {
    required int methodIndex,
    String? code,
  });
  Future<List<AiAuthMethod>> authMethods();
  Future<void> setApiKey(String providerId, String apiKey);
  Future<AiOAuthAuthorization> beginOAuth(
    String providerId, {
    required int methodIndex,
    Map<String, String> inputs,
  });
  Future<void> disconnectProvider(String providerId);
  void dispose();
}
