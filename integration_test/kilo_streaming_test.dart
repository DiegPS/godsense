import 'dart:async';
import 'dart:io';

import 'package:dart_ai_runtime/dart_ai_runtime.dart'
    show HttpArtifactDownloader;
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/ai/ai_conversation_controller.dart';
import 'package:godsense/application/ai/ai_runtime_supervisor.dart';
import 'package:godsense/domain/ai/ai_runtime_api_models.dart';
import 'package:godsense/domain/ai/ai_runtime_models.dart';
import 'package:godsense/infrastructure/ai/ai_runtime_health_client.dart';
import 'package:godsense/infrastructure/ai/ai_runtime_paths.dart';
import 'package:godsense/infrastructure/ai/local_ai_runtime_process_service.dart';
import 'package:godsense/infrastructure/ai/open_code_compatible_runtime_client.dart';
import 'package:godsense/infrastructure/ai/pinned_ai_runtime_installer.dart';

class StreamingOnlyClient extends OpenCodeCompatibleRuntimeClient {
  StreamingOnlyClient({
    required super.endpoint,
    required super.workspaceDirectory,
    required super.systemPromptService,
  });

  int reads = 0;
  final seenTypes = <String>{};
  int deltas = 0;

  @override
  Future<List<Map<String, dynamic>>> messages(String sessionId) {
    // Permit the pre-prompt baseline only. Polling cannot make this test pass.
    if (++reads > 1) throw StateError('Polling disabled in streaming test');
    return super.messages(sessionId);
  }

  @override
  Future<Stream<AiRuntimeEvent>> connectEvents() async {
    final stream = await super.connectEvents();
    return stream.map((event) {
      if (event.textDelta != null) deltas++;
      if (seenTypes.add(event.type)) {
        // Synthetic test conversation only; never log production chat here.
        // ignore: avoid_print
        print('SSE ${event.type}');
      }
      return event;
    });
  }
}

void main() {
  final executable = Platform.environment['GODSENSE_TEST_KILO_EXE'];
  test(
    'real Kilo shows multiple partial responses without polling',
    () async {
      final root = await Directory.systemTemp.createTemp('godsense-streaming-');
      final storage = AiRuntimeStorage(
        sharedStoreRoot: Directory('${root.path}\\shared'),
        applicationDataRoot: Directory('${root.path}\\private'),
        applicationId: 'godsense-test',
      );
      final downloader = HttpArtifactDownloader();
      final health = AiRuntimeHealthClient();
      final processes = LocalAiRuntimeProcessService(storage);
      final supervisor = AiRuntimeSupervisor(
        installer: PinnedAiRuntimeInstaller(
          storage: storage,
          downloader: downloader,
          developmentExecutables: {AiRuntimeKind.kilo: executable},
        ),
        processes: processes,
        health: health,
        allowDownloads: false,
      );
      AiConversationController? controller;
      try {
        await supervisor.start(AiRuntimeKind.kilo);
        final client = StreamingOnlyClient(
          endpoint: supervisor.state.endpoint!,
          workspaceDirectory: storage.workspace(AiRuntimeKind.kilo).path,
          systemPromptService: processes.systemPromptService,
        );
        controller = AiConversationController(
          supervisor: supervisor,
          clientFactory: () => client,
        );
        final partials = <String>{};
        controller.addListener((state) {
          if (state.isBusy && state.streamedText.isNotEmpty) {
            partials.add(state.streamedText);
          }
        });
        await controller.sendMessage(
          'Explica en español en 180 palabras cómo practicar ajedrez. '
          'Incluye un título Markdown, palabras en negrita y una lista numerada.',
        );
        final deadline = DateTime.now().add(const Duration(seconds: 75));
        while (controller.state.isBusy && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        // ignore: avoid_print
        print(
          'STREAM RESULT: deltas=${client.deltas} partials=${partials.length} '
          'status=${controller.state.status} error=${controller.state.errorMessage}',
        );
        expect(partials.length, greaterThan(2));
        expect(client.deltas, greaterThan(2));
        expect(controller.state.status, AiConversationStatus.idle);
        expect(controller.state.messages.last.role, 'assistant');
        expect(
          partials.any(
            (text) =>
                text.length < controller!.state.messages.last.content.length,
          ),
          isTrue,
        );
      } finally {
        controller?.dispose();
        await supervisor.dispose();
        health.dispose();
        downloader.dispose();
        await root.delete(recursive: true);
      }
    },
    skip:
        executable == null ||
        Platform.environment['GODSENSE_TEST_KILO_AUTO_FREE'] != 'true',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
