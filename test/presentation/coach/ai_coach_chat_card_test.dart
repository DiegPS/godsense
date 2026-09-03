import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/ai/ai_conversation_controller.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/presentation/coach/live/ai_coach_chat_card.dart';

import '../../application/ai/ai_conversation_controller_test.dart'
    show FakeSupervisor;

class FakeAiConversationNotifier extends StateNotifier<AiConversationState>
    implements AiConversationController {
  FakeAiConversationNotifier(super.state);

  int abortCallCount = 0;
  List<String> sentMessages = [];

  @override
  Future<void> sendMessage(String text, {String? systemPrompt}) async {
    sentMessages.add(text);
    state = state.copyWith(
      status: AiConversationStatus.streaming,
      streamedText: 'Generando respuesta...',
      messages: [
        ...state.messages,
        AiChatMessage(
          id: 'user-1',
          role: 'user',
          content: text,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  @override
  Future<void> abort() async {
    abortCallCount++;
    state = state.copyWith(
      status: AiConversationStatus.idle,
      streamedText: '',
      messages: [
        ...state.messages,
        AiChatMessage(
          id: 'assistant-1',
          role: 'assistant',
          content: 'Generando respuesta... [Cancelado]',
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  @override
  Future<void> clearConversation() async {
    state = const AiConversationState();
  }

  @override
  void clearError() {
    state = state.copyWith(clearError: true, status: AiConversationStatus.idle);
  }
}

void main() {
  testWidgets('AiCoachChatCard renders idle state with suggestion chips', (
    tester,
  ) async {
    final fakeController = FakeAiConversationNotifier(
      const AiConversationState(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiRuntimeSupervisorProvider.overrideWithValue(FakeSupervisor()),
          aiRuntimeSupervisorStateProvider.overrideWith(
            (ref) => Stream.value(FakeSupervisor().state),
          ),
          aiConversationProvider.overrideWith((ref) => fakeController),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: AiCoachChatCard())),
        ),
      ),
    );

    expect(find.text('Coach IA conversacional'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets(
    'AiCoachChatCard shows streaming indicator and abort button when streaming',
    (tester) async {
      final fakeController = FakeAiConversationNotifier(
        AiConversationState(
          status: AiConversationStatus.streaming,
          streamedText: 'Para la fase de líneas, prioriza el farm.',
          messages: [
            AiChatMessage(
              id: 'u1',
              role: 'user',
              content: '¿Cómo juego fase de líneas?',
              timestamp: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiRuntimeSupervisorProvider.overrideWithValue(FakeSupervisor()),
            aiRuntimeSupervisorStateProvider.overrideWith(
              (ref) => Stream.value(FakeSupervisor().state),
            ),
            aiConversationProvider.overrideWith((ref) => fakeController),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: AiCoachChatCard()),
            ),
          ),
        ),
      );

      expect(find.text('Cancelar generación'), findsOneWidget);
      expect(find.textContaining('prioriza el farm'), findsOneWidget);

      // Tap Cancelar generación
      await tester.tap(find.text('Cancelar generación'));
      await tester.pump();

      expect(fakeController.abortCallCount, 1);
      expect(find.textContaining('[Cancelado]'), findsOneWidget);
    },
  );

  testWidgets('AiCoachChatCard renders error banner and allows closing it', (
    tester,
  ) async {
    final fakeController = FakeAiConversationNotifier(
      const AiConversationState(
        status: AiConversationStatus.error,
        errorMessage: 'Fallo de conexión al puerto 0',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiRuntimeSupervisorProvider.overrideWithValue(FakeSupervisor()),
          aiRuntimeSupervisorStateProvider.overrideWith(
            (ref) => Stream.value(FakeSupervisor().state),
          ),
          aiConversationProvider.overrideWith((ref) => fakeController),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: AiCoachChatCard())),
        ),
      ),
    );

    expect(find.text('Fallo de conexión al puerto 0'), findsOneWidget);
    expect(find.text('Cerrar'), findsOneWidget);

    await tester.tap(find.text('Cerrar'));
    await tester.pump();

    expect(fakeController.state.errorMessage, isNull);
  });
}
