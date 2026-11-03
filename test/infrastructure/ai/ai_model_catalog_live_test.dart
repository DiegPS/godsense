import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dart_ai_runtime/dart_ai_runtime.dart' as runtime;
import 'package:godsense/domain/ai/ai_runtime_models.dart';
import 'package:godsense/infrastructure/ai/ai_runtime_health_client.dart';
import 'package:godsense/infrastructure/ai/ai_runtime_paths.dart';
import 'package:godsense/infrastructure/ai/local_ai_runtime_process_service.dart';
import 'package:godsense/infrastructure/ai/open_code_compatible_runtime_client.dart';
import 'package:godsense/infrastructure/ai/pinned_ai_runtime_catalog.dart';

void main() {
  for (final kind in AiRuntimeKind.values) {
    final path =
        Platform.environment[kind == AiRuntimeKind.kilo
            ? 'GODSENSE_TEST_KILO_EXE'
            : 'GODSENSE_TEST_OPENCODE_EXE'];
    test(
      'live ${kind.id} catalog supplies selectable connected models',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'godsense-model-catalog-',
        );
        final health = AiRuntimeHealthClient();
        try {
          final storage = AiRuntimeStorage(
            sharedStoreRoot: Directory('${root.path}\\shared'),
            applicationDataRoot: Directory('${root.path}\\private'),
            applicationId: 'godsense-test',
          );
          final processes = LocalAiRuntimeProcessService(storage);
          final supervisor = runtime.AiRuntimeSupervisor(
            installer: _ExistingInstallation(kind, File(path!).parent.path),
            processes: processes,
            health: health,
          );
          final endpoint = await supervisor.start(kind);
          try {
            final ready = await health.waitUntilReady(endpoint);
            expect(ready.healthy, isTrue);
            final client = BackgroundCatalogRuntimeClient(
              endpoint: endpoint,
              workspaceDirectory: storage.workspace(kind).path,
              systemPromptService: processes.systemPromptService,
            );
            try {
              final providers = await client.providers();
              final connected = providers.where((p) => p.connected).toList();
              final models = connected.expand((p) => p.models).toList();
              expect(models, isNotEmpty);
              expect(
                models.every((m) => m.id.isNotEmpty && m.providerId.isNotEmpty),
                isTrue,
              );
              // ignore: avoid_print
              print(
                '${kind.id} ${ready.version}: ${connected.length} connected providers, ${models.length} models, ${models.where((m) => m.isFree).length} free.',
              );
              if (Platform.environment['GODSENSE_TEST_AI_INFERENCE'] == '1') {
                final model = models.firstWhere(
                  (model) =>
                      model.isFree &&
                      model.id ==
                          (kind == AiRuntimeKind.openCode
                              ? 'big-pickle'
                              : 'kilo-auto/free'),
                );
                final conversation = runtime.AiConversationController(
                  supervisor: supervisor,
                  clientFactory: (_) => client,
                );
                try {
                  final watch = Stopwatch()..start();
                  final answer = await conversation.sendAndWait(
                    text: 'Hola',
                    providerId: model.providerId,
                    modelId: model.id,
                    systemPrompt: 'Responde brevemente en español. No utilices herramientas.',
                    timeout: const Duration(seconds: 45),
                  );
                  expect(answer.trim(), isNotEmpty);
                  // ignore: avoid_print
                  print(
                    '${kind.id} real inference: ${watch.elapsedMilliseconds} ms; answer: $answer',
                  );
                } finally {
                  await conversation.dispose();
                }
              }
            } finally {
              client.dispose();
            }
          } finally {
            await supervisor.dispose();
          }
        } finally {
          health.dispose();
          await root.delete(recursive: true);
        }
      },
      skip: path == null
          ? 'Set GODSENSE_TEST_*_EXE to opt into local catalog checks.'
          : false,
      // Endpoint startup (15s), health (25s), first catalog (60s), and cleanup.
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}

class _ExistingInstallation implements runtime.AiRuntimeInstallService {
  _ExistingInstallation(this.kind, this.directory);
  final AiRuntimeKind kind;
  final String directory;
  @override
  runtime.AiRuntimeDefinition definition(AiRuntimeKind kind) =>
      const PinnedAiRuntimeCatalog().definition(kind);
  @override
  Future<AiRuntimeInstallation?> installed(AiRuntimeKind requested) async =>
      requested == kind
      ? AiRuntimeInstallation(
          definition: definition(kind),
          directoryPath: directory,
        )
      : null;
  @override
  Future<AiRuntimeInstallation> install(
    AiRuntimeKind kind, {
    runtime.ArtifactDownloadCancellation? cancellation,
    void Function(runtime.ArtifactInstallProgress progress)? onProgress,
  }) => throw UnsupportedError('Live tests require an existing binary.');
}
