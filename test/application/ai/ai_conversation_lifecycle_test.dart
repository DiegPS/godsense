import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/ai/ai_conversation_controller.dart';

import 'ai_conversation_controller_test.dart'
    show MockAiRuntimeClient, FakeSupervisor;

void main() {
  test(
    'dispatch error reaches voice caller without an unhandled error',
    () async {
      final client = MockAiRuntimeClient()..throwOnPrompt = true;
      final controller = AiConversationController(
        supervisor: FakeSupervisor(),
        clientFactory: () => client,
      );
      addTearDown(controller.dispose);
      await expectLater(controller.sendAndWait('Pregunta'), throwsStateError);
      expect(controller.state.isBusy, isFalse);
    },
  );

  test(
    'timeout while SSE connects cancels and discards late dispatch',
    () async {
      final client = MockAiRuntimeClient()
        ..connectEventsDelay = Completer<void>();
      final controller = AiConversationController(
        supervisor: FakeSupervisor(),
        clientFactory: () => client,
      );
      addTearDown(controller.dispose);
      await expectLater(
        controller.sendAndWait(
          'Pregunta',
          timeout: const Duration(milliseconds: 30),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(controller.state.isBusy, isFalse);
      expect(client.abortedSessions, ['mock-session-1']);
      client.connectEventsDelay!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(client.promptsSent, isEmpty);
    },
  );

  test('cleared history cannot be resurrected by a pending restore', () async {
    final history = _DelayedHistory();
    final controller = AiConversationController(
      supervisor: FakeSupervisor(),
      clientFactory: MockAiRuntimeClient.new,
      historyStore: history,
    );
    addTearDown(controller.dispose);
    await controller.clearConversation();
    history.pending.complete([
      AiChatMessage(
        id: 'old',
        role: 'user',
        content: 'old question',
        timestamp: DateTime.utc(2026),
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.messages, isEmpty);
  });
}

class _DelayedHistory implements AiConversationHistoryStore {
  final pending = Completer<List<AiChatMessage>>();
  @override
  Future<List<AiChatMessage>> load() => pending.future;
  @override
  Future<void> save(List<AiChatMessage> messages) async {}
  @override
  Future<void> clear() async {}
}
