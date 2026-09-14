import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
          final process = await LocalAiRuntimeProcessService(storage).start(
            AiRuntimeInstallation(
              definition: const PinnedAiRuntimeCatalog().definition(kind),
              directoryPath: File(path!).parent.path,
            ),
            password: 'catalog-test-only',
          );
          try {
            final ready = await health.waitUntilReady(process.endpoint);
            expect(ready.healthy, isTrue);
            final client = OpenCodeCompatibleRuntimeClient(
              endpoint: process.endpoint,
              workspaceDirectory: storage.workspace(kind).path,
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
                '${kind.id} ${ready.version}: ${connected.length} connected providers, ${models.length} models, ${models.where((m) => m.isFree).length} free. No inference sent.',
              );
            } finally {
              client.dispose();
            }
          } finally {
            await process.stop();
          }
        } finally {
          health.dispose();
          await root.delete(recursive: true);
        }
      },
      skip: path == null
          ? 'Set GODSENSE_TEST_*_EXE to opt into local catalog checks.'
          : false,
      timeout: const Timeout(Duration(seconds: 55)),
    );
  }
}
