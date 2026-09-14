import 'dart:io';

import 'package:dart_ai_runtime/dart_ai_runtime.dart'
    show HttpArtifactDownloader;
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/ai/ai_conversation_controller.dart';
import 'package:godsense/application/ai/ai_runtime_supervisor.dart';
import 'package:godsense/domain/ai/ai_runtime_models.dart';
import 'package:godsense/infrastructure/ai/ai_runtime_health_client.dart';
import 'package:godsense/infrastructure/ai/ai_runtime_paths.dart';
import 'package:godsense/infrastructure/ai/local_ai_runtime_process_service.dart';
import 'package:godsense/infrastructure/ai/open_code_compatible_runtime_client.dart';
import 'package:godsense/infrastructure/ai/pinned_ai_runtime_installer.dart';

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

      try {
        // 1. Iniciar Kilo
        await supervisor.start(AiRuntimeKind.kilo);
        expect(supervisor.state.isReady, isTrue);

        final controller = AiConversationController(
          supervisor: supervisor,
          clientFactory: () => OpenCodeCompatibleRuntimeClient(
            endpoint: supervisor.state.endpoint!,
            workspaceDirectory: storage.workspace(AiRuntimeKind.kilo).path,
            systemPromptService: processes.systemPromptService,
          ),
        );

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

        final deadline1 = DateTime.now().add(const Duration(seconds: 90));
        while (controller.state.isBusy && DateTime.now().isBefore(deadline1)) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        await send1;

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

        final deadline2 = DateTime.now().add(const Duration(seconds: 90));
        while (controller.state.isBusy && DateTime.now().isBefore(deadline2)) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        await send2;

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
        await Future<void>.delayed(const Duration(milliseconds: 300));
        while (!controller.state.isBusy) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }

        // Cancelar la generación activa
        await controller.abort();
        await send3;

        expect(controller.state.status, AiConversationStatus.idle);
        // Si había texto parcial, incluye [Cancelado]; si se abortó antes de recibir tokens, se mantiene limpio
        if (controller.state.messages.length == 6) {
          expect(
            controller.state.messages.last.content,
            contains('[Cancelado]'),
          );
        }

        // Volver a preguntar de inmediato tras cancelar
        streamedSnapshots.clear();
        final send4 = controller.sendMessage(
          'Dime el nombre de un campeón de League of Legends que use arco. Responde solo con su nombre.',
        );

        final deadline4 = DateTime.now().add(const Duration(seconds: 90));
        while (controller.state.isBusy && DateTime.now().isBefore(deadline4)) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        await send4;

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
        final send5 = controller.sendMessage(
          '¿Sigues disponible tras reiniciar? Responde con la palabra "afirmativo".',
        );

        final deadline5 = DateTime.now().add(const Duration(seconds: 90));
        while (controller.state.isBusy && DateTime.now().isBefore(deadline5)) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        await send5;

        expect(controller.state.status, AiConversationStatus.idle);
        final response5 = controller.state.messages.last.content;
        expect(response5, isNotEmpty);

        controller.dispose();
        await supervisor.stop();
      } catch (e, stack) {
        // ignore: avoid_print
        print('E2E TEST ERROR: $e\n$stack');
        rethrow;
      } finally {
        supervisor.dispose();
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
