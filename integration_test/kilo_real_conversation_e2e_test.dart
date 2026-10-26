import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:dart_ai_runtime/dart_ai_runtime.dart'
    show HttpArtifactDownloader;
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/ai/ai_conversation_controller.dart';
import 'package:godsense/application/ai/ai_runtime_supervisor.dart';
import 'package:godsense/domain/ai/ai_runtime_models.dart';
import 'package:godsense/domain/ai/ai_runtime_api_models.dart';
import 'package:godsense/infrastructure/ai/ai_runtime_health_client.dart';
import 'package:godsense/infrastructure/ai/ai_runtime_paths.dart';
import 'package:godsense/infrastructure/ai/local_ai_runtime_process_service.dart';
import 'package:godsense/infrastructure/ai/open_code_compatible_runtime_client.dart';
import 'package:godsense/infrastructure/ai/pinned_ai_runtime_installer.dart';

Future<void> waitForConversation(
  AiConversationController controller,
  bool Function(AiConversationState) completed, {
  required String stage,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    final state = controller.state;
    if (state.status == AiConversationStatus.error) {
      fail('$stage: ${state.errorMessage}');
    }
    if (completed(state)) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('$stage timed out: ${controller.state.status}');
}

Future<void> waitForReply(
  AiConversationController controller,
  int previousMessageCount,
) => waitForConversation(
  controller,
  (state) =>
      state.status == AiConversationStatus.idle &&
      state.messages.length > previousMessageCount &&
      state.messages.last.role == 'assistant' &&
      state.messages.last.content.trim().isNotEmpty,
  stage: 'Waiting for a complete assistant reply',
);

void main() {
  final kiloExecutablePath = Platform.environment['GODSENSE_TEST_KILO_EXE'];
  final testKiloAutoFree =
      Platform.environment['GODSENSE_TEST_KILO_AUTO_FREE'] == 'true';

  test(
    'GodSense con Kilo real (7.5.9): streaming progresivo, preguntas repetidas, cancelación y reinicio en caliente',
    () async {
      final root = await Directory.systemTemp.createTemp('godsense-kilo-e2e-');
      final health = AiRuntimeHealthClient();
      final storage = AiRuntimeStorage(
        sharedStoreRoot: Directory('${root.path}\\shared'),
        applicationDataRoot: Directory('${root.path}\\private'),
        applicationId: 'godsense-test',
      );
      final downloader = HttpArtifactDownloader();

      final installer = PinnedAiRuntimeInstaller(
        storage: storage,
        downloader: downloader,
        developmentExecutables: {AiRuntimeKind.kilo: kiloExecutablePath},
      );
      final processes = LocalAiRuntimeProcessService(storage);

      final supervisor = AiRuntimeSupervisor(
        installer: installer,
        processes: processes,
        health: health,
        allowDownloads: false,
      );
      AiConversationController? conversation;

      try {
        // 1. Iniciar Kilo
        await supervisor.start(AiRuntimeKind.kilo);
        expect(supervisor.state.isReady, isTrue);

        final controller = AiConversationController(
          supervisor: supervisor,
          clientFactory: () => _TracedRuntimeClient(
            endpoint: supervisor.state.endpoint!,
            workspaceDirectory: storage.workspace(AiRuntimeKind.kilo).path,
            systemPromptService: processes.systemPromptService,
          ),
        );
        conversation = controller;

        final streamedSnapshots = <String>[];
        controller.addListener((state) {
          if (state.streamedText.isNotEmpty) {
            streamedSnapshots.add(state.streamedText);
          }
        });

        // -------------------------------------------------------------
        // PASO 1: Enviar una pregunta y confirmar texto progresivo
        // -------------------------------------------------------------
        streamedSnapshots.clear();
        final send1 = controller.sendMessage(
          '¿Cuál es el rol de Ahri en League of Legends? Responde brevemente.',
        );

        await send1;
        await waitForReply(controller, 0);

        // ignore: avoid_print
        print(
          'STEP 1 FINISHED: status=${controller.state.status}, error=${controller.state.errorMessage}, msgs=${controller.state.messages.length}',
        );
        expect(controller.state.status, AiConversationStatus.idle);
        expect(controller.state.messages, hasLength(2));
        final response1 = controller.state.messages.last.content;
        expect(response1, isNotEmpty);
        expect(
          streamedSnapshots,
          isNotEmpty,
          reason: 'El texto debe haber aparecido progresivamente',
        );
        if (streamedSnapshots.length > 1) {
          expect(
            streamedSnapshots.last.length,
            greaterThanOrEqualTo(streamedSnapshots.first.length),
          );
        }

        // -------------------------------------------------------------
        // PASO 2: Repetir exactamente la misma pregunta
        // -------------------------------------------------------------
        streamedSnapshots.clear();
        final send2 = controller.sendMessage(
          '¿Cuál es el rol de Ahri en League of Legends? Responde brevemente.',
        );

        await send2;
        await waitForReply(controller, 2);

        expect(controller.state.status, AiConversationStatus.idle);
        expect(controller.state.messages, hasLength(4));
        final response2 = controller.state.messages.last.content;
        expect(response2, isNotEmpty);

        // -------------------------------------------------------------
        // PASO 3: Cancelar una respuesta en curso y volver a preguntar
        // -------------------------------------------------------------
        streamedSnapshots.clear();
        final send3 = controller.sendMessage(
          'Escribe una guía de 1000 palabras sobre macrogame en League of Legends.',
        );

        // Esperar brevemente a que esté en vuelo (sending o streaming)
        await waitForConversation(
          controller,
          (state) =>
              state.sessionId != null &&
              (state.status == AiConversationStatus.sending ||
                  state.status == AiConversationStatus.streaming),
          stage: 'Waiting for an active generation to cancel',
        );

        // Cancelar la generación activa
        await controller.abort();
        await send3;
        await waitForConversation(
          controller,
          (state) => state.status == AiConversationStatus.idle,
          stage: 'Waiting for cancellation to finish',
        );

        expect(controller.state.status, AiConversationStatus.idle);
        // The runtime keeps partial output with an explicit cancellation marker.
        if (controller.state.messages.length == 6) {
          expect(
            controller.state.messages.last.content,
            contains('[Cancelled]'),
          );
        }

        // Volver a preguntar de inmediato tras cancelar
        streamedSnapshots.clear();
        final before4 = controller.state.messages.length;
        final send4 = controller.sendMessage(
          'Dime el nombre de un campeón de League of Legends que use arco. Responde solo con su nombre.',
        );

        await send4;
        await waitForReply(controller, before4);

        expect(controller.state.status, AiConversationStatus.idle);
        final response4 = controller.state.messages.last.content;
        expect(response4, isNotEmpty);
        // Confirmar que no se mezclaron residuos del prompt cancelado
        expect(response4, isNot(contains('macrogame')));

        // -------------------------------------------------------------
        // PASO 4: Apagar y encender Kilo sin reiniciar el controlador
        // -------------------------------------------------------------
        await supervisor.stop();
        expect(supervisor.state.isReady, isFalse);

        // Volver a encender Kilo
        await supervisor.start(AiRuntimeKind.kilo);
        expect(supervisor.state.isReady, isTrue);
        final newPort = supervisor.state.endpoint?.baseUri.port;
        expect(newPort, isNotNull);
        expect(newPort, greaterThan(0));

        // Enviar pregunta al proceso recién reiniciado
        streamedSnapshots.clear();
        final before5 = controller.state.messages.length;
        final send5 = controller.sendMessage(
          '¿Sigues disponible tras reiniciar? Responde con la palabra "afirmativo".',
        );

        await send5;
        await waitForReply(controller, before5);

        expect(controller.state.status, AiConversationStatus.idle);
        final response5 = controller.state.messages.last.content;
        expect(response5, isNotEmpty);

        await supervisor.stop();
      } catch (e, stack) {
        // ignore: avoid_print
        print('E2E TEST ERROR: $e\n$stack');
        rethrow;
      } finally {
        conversation?.dispose();
        await supervisor.dispose();
        health.dispose();
        downloader.dispose();
        if (await root.exists()) {
          try {
            await root.delete(recursive: true);
          } catch (_) {}
        }
      }
    },
    skip: !testKiloAutoFree || kiloExecutablePath == null
        ? 'Set GODSENSE_TEST_KILO_EXE and GODSENSE_TEST_KILO_AUTO_FREE=true.'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _TracedRuntimeClient extends OpenCodeCompatibleRuntimeClient {
  _TracedRuntimeClient({
    required super.endpoint,
    required super.workspaceDirectory,
    super.systemPromptService,
  });

  @override
  Future<void> promptAsync(String sessionId, AiPrompt prompt) async {
    // Metadata only: never log prompts, credentials or system instructions.
    debugPrint('PROMPT DISPATCH ${prompt.messageId}');
    await super.promptAsync(sessionId, prompt);
    debugPrint('PROMPT ACCEPTED ${prompt.messageId}');
  }

  @override
  Future<void> abort(String sessionId) async {
    debugPrint('ABORT DISPATCH');
    await super.abort(sessionId);
    debugPrint('ABORT ACKNOWLEDGED');
  }

  @override
  Future<Stream<AiRuntimeEvent>> connectEvents() async {
    final stream = await super.connectEvents();
    return stream.map((event) {
      final info = event.properties['info'];
      if (event.type == 'message.updated' && info is Map) {
        debugPrint(
          'MESSAGE ${info['id']} role=${info['role']} parent=${info['parentID']} finish=${info['finish']}',
        );
      }
      return event;
    });
  }
}
