import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/ai/ai_runtime_api_models.dart';
import 'package:godsense/domain/ai/ai_runtime_models.dart';
import 'package:godsense/infrastructure/ai/ai_runtime_health_client.dart';
import 'package:godsense/infrastructure/ai/ai_runtime_paths.dart';
import 'package:godsense/infrastructure/ai/local_ai_runtime_process_service.dart';
import 'package:godsense/infrastructure/ai/open_code_compatible_runtime_client.dart';
import 'package:godsense/infrastructure/ai/pinned_ai_runtime_catalog.dart';
import 'package:path/path.dart' as p;

void main() {
  for (final fixture in [
    (AiRuntimeKind.openCode, 'GODSENSE_TEST_OPENCODE_EXE'),
    (AiRuntimeKind.kilo, 'GODSENSE_TEST_KILO_EXE'),
  ]) {
    final executablePath = Platform.environment[fixture.$2];
    test(
      '${fixture.$1.displayName} starts securely and reports healthy',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'godsense-${fixture.$1.id}-runtime-',
        );
        final health = AiRuntimeHealthClient();
        final definition = const PinnedAiRuntimeCatalog().definition(
          fixture.$1,
        );
        final storage = AiRuntimeStorage(
          sharedStoreRoot: Directory('${root.path}\\shared'),
          applicationDataRoot: Directory('${root.path}\\private'),
          applicationId: 'godsense-test',
        );
        final service = LocalAiRuntimeProcessService(storage);
        try {
          final process = await service.start(
            AiRuntimeInstallation(
              definition: definition,
              directoryPath: p.dirname(executablePath!),
            ),
            password: 'integration-test-password',
          );
          try {
            expect(process.endpoint.baseUri.host, '127.0.0.1');
            expect(process.endpoint.baseUri.port, greaterThan(0));
            expect(process.endpoint.password, 'integration-test-password');
            final result = await health.waitUntilReady(
              process.endpoint,
              timeout: const Duration(seconds: 25),
            );
            expect(result.healthy, isTrue, reason: result.message);
            final client = OpenCodeCompatibleRuntimeClient(
              endpoint: process.endpoint,
              workspaceDirectory: storage.workspace(fixture.$1).path,
              systemPromptService: service.systemPromptService,
            );
            try {
              final events = await client.connectEvents();
              final eventSubscription = events.listen((_) {});
              final providers = await client.providers();
              expect(providers, isNotEmpty);
              await client.authMethods();
              final session = await client.createSession(
                title: 'GodSense integration test',
              );
              expect((await client.session(session.id)).id, session.id);
              expect(await client.messages(session.id), isEmpty);
              await client.abort(session.id);
              await client.deleteSession(session.id);
              await eventSubscription.cancel();
            } finally {
              client.dispose();
            }
          } finally {
            await process.stop();
          }
        } finally {
          health.dispose();
          if (await root.exists()) await root.delete(recursive: true);
        }
      },
      skip: executablePath == null
          ? 'Set ${fixture.$2} to an installed standalone runtime.'
          : false,
      timeout: const Timeout(Duration(minutes: 1)),
    );
  }

  final kiloExecutablePath = Platform.environment['GODSENSE_TEST_KILO_EXE'];
  final testKiloAutoFree =
      Platform.environment['GODSENSE_TEST_KILO_AUTO_FREE'] == 'true';
  test(
    'Kilo sends and receives a real kilo-auto/free prompt',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'godsense-kilo-auto-free-',
      );
      final health = AiRuntimeHealthClient();
      final definition = const PinnedAiRuntimeCatalog().definition(
        AiRuntimeKind.kilo,
      );
      final storage = AiRuntimeStorage(
        sharedStoreRoot: Directory('${root.path}\\shared'),
        applicationDataRoot: Directory('${root.path}\\private'),
        applicationId: 'godsense-test',
      );
      final service = LocalAiRuntimeProcessService(storage);
      try {
        final process = await service.start(
          AiRuntimeInstallation(
            definition: definition,
            directoryPath: p.dirname(kiloExecutablePath!),
          ),
          password: 'integration-test-password',
        );
        try {
          final ready = await health.waitUntilReady(
            process.endpoint,
            timeout: const Duration(seconds: 25),
          );
          expect(ready.healthy, isTrue, reason: ready.message);
          final client = OpenCodeCompatibleRuntimeClient(
            endpoint: process.endpoint,
            workspaceDirectory: storage.workspace(AiRuntimeKind.kilo).path,
            systemPromptService: service.systemPromptService,
          );
          try {
            final providers = await client.providers();
            final freeModels = providers
                .expand((provider) => provider.models)
                .where(
                  (model) =>
                      model.providerId == 'kilo' &&
                      model.id == 'kilo-auto/free' &&
                      model.isFree,
                )
                .toList(growable: false);
            expect(
              freeModels,
              hasLength(1),
              reason: 'Kilo must expose exactly kilo/kilo-auto/free; paid fallback is forbidden.',
            );
            final model = freeModels.single;
            final session = await client.createSession(
              title: 'GodSense Kilo Auto Free smoke test',
            );
            try {
              await client.promptAsync(
                session.id,
                AiPrompt(
                  providerId: model.providerId,
                  modelId: model.id,
                  system: 'Respond with only the exact JSON requested. Do not use tools.',
                  text: 'Return exactly {"godsense":"ok"} and nothing else.',
                ),
              );

              String? answer;
              final deadline = DateTime.now().add(const Duration(seconds: 90));
              while (DateTime.now().isBefore(deadline)) {
                final messages = await client.messages(session.id);
                answer = _latestAssistantText(messages);
                if (answer != null && answer.isNotEmpty) break;
                await Future<void>.delayed(const Duration(milliseconds: 500));
              }

              expect(
                answer,
                isNotNull,
                reason: 'Kilo returned no assistant text.',
              );
              expect(answer, contains('"godsense":"ok"'));
            } finally {
              await client.abort(session.id);
              await client.deleteSession(session.id);
            }
          } finally {
            client.dispose();
          }
        } finally {
          await process.stop();
        }
      } finally {
        health.dispose();
        if (await root.exists()) await root.delete(recursive: true);
      }
    },
    skip: !testKiloAutoFree || kiloExecutablePath == null
        ? 'Set GODSENSE_TEST_KILO_EXE and GODSENSE_TEST_KILO_AUTO_FREE=true.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

String? _latestAssistantText(List<Map<String, dynamic>> messages) {
  for (final message in messages.reversed) {
    final info = message['info'];
    if (info is! Map || info['role'] != 'assistant') continue;
    final parts = message['parts'];
    if (parts is! List) continue;
    final text = parts
        .whereType<Map>()
        .where((part) => part['type'] == 'text')
        .map((part) => part['text']?.toString() ?? '')
        .join();
    if (text.isNotEmpty) return text;
  }
  return null;
}
