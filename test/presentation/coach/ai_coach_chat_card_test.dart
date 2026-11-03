import 'dart:async';

import '../../support/ai_models.dart';

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
  bool rejectDispatch = false;
  Completer<void>? dispatchGate;
  List<String> sentMessages = [];

  @override
  Future<void> sendMessage(String text, {String? systemPrompt}) async {
    await dispatchGate?.future;
    if (rejectDispatch) {
      state = state.copyWith(
        status: AiConversationStatus.error,
        errorMessage: 'Selecciona un modelo disponible antes de enviar.',
      );
      return;
    }
    sentMessages.add(text);
    state = state.copyWith(
      status: AiConversationStatus.streaming,
      streamedText: 'Generando respuesta...',
      messages: [
        ...state.messages,
        AiChatMessage(
          id: 'user-${sentMessages.length}',
          role: 'user',
          content: text,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  @override
  Future<String> sendAndWait(
    String text, {
    String? systemPrompt,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    await sendMessage(text, systemPrompt: systemPrompt);
    return 'Generando respuesta...';
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
  Future<void> bootDraftTest(
    WidgetTester tester,
    FakeAiConversationNotifier controller,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiModelSelectionProvider.overrideWith((_) => ReadyModelSelection()),
          aiRuntimeSupervisorProvider.overrideWithValue(FakeSupervisor()),
          aiRuntimeSupervisorStateProvider.overrideWith(
            (_) => Stream.value(FakeSupervisor().state),
          ),
          aiConversationProvider.overrideWith((_) => controller),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: AiCoachChatCard())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'resizing a chat with history does not schedule builds during layout',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = FakeAiConversationNotifier(
        AiConversationState(
          messages: List.generate(
            24,
            (i) => AiChatMessage(
              id: 'history-$i',
              role: i.isEven ? 'user' : 'assistant',
              content: 'Mensaje de historial $i. ' * 8,
              timestamp: DateTime.utc(2026, 1, 1, 0, i),
            ),
          ),
        ),
      );
      await bootDraftTest(tester, controller);
      final list = tester.widget<ListView>(find.byType(ListView).first);
      list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
      await tester.pump();
      for (final width in [500.0, 1000.0, 600.0, 1100.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      expect(controller.state.messages.length, 24);
    },
  );

  testWidgets(
    'rejected send preserves the draft instead of silently clearing it',
    (tester) async {
      final controller = FakeAiConversationNotifier(const AiConversationState())
        ..rejectDispatch = true;
      await bootDraftTest(tester, controller);
      final input = find.byType(TextField);
      await tester.enterText(input, 'No pierdas mi pregunta');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(input).controller!.text,
        'No pierdas mi pregunta',
      );
      expect(controller.sentMessages, isEmpty);
      expect(
        find.text('Selecciona un modelo disponible antes de enviar.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'draft clears only after the user message enters conversation history',
    (tester) async {
      final gate = Completer<void>();
      final controller = FakeAiConversationNotifier(const AiConversationState())
        ..dispatchGate = gate;
      await bootDraftTest(tester, controller);
      final input = find.byType(TextField);
      await tester.enterText(input, 'Pregunta confirmada');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(
        tester.widget<TextField>(input).controller!.text,
        'Pregunta confirmada',
      );
      expect(controller.sentMessages, isEmpty);
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(controller.state.messages.single.content, 'Pregunta confirmada');
      expect(find.text('Pregunta confirmada'), findsOneWidget);
    },
  );

  testWidgets('cancelled history stays visible with an explicit label', (
    tester,
  ) async {
    final controller = FakeAiConversationNotifier(
      AiConversationState(
        messages: [
          AiChatMessage(
            id: 'cancelled',
            role: 'user',
            content: 'Pregunta cancelada',
            timestamp: DateTime.utc(2026),
            isCancelled: true,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiModelSelectionProvider.overrideWith((_) => ReadyModelSelection()),
          aiRuntimeSupervisorProvider.overrideWithValue(FakeSupervisor()),
          aiRuntimeSupervisorStateProvider.overrideWith(
            (_) => Stream.value(FakeSupervisor().state),
          ),
          aiConversationProvider.overrideWith((_) => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: AiCoachChatCard())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pregunta cancelada'), findsOneWidget);
    expect(find.text('Cancelado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('AiCoachChatCard renders idle state with suggestion chips', (
    tester,
  ) async {
    final fakeController = FakeAiConversationNotifier(
      const AiConversationState(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiModelSelectionProvider.overrideWith((ref) => ReadyModelSelection()),
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
            aiModelSelectionProvider.overrideWith(
              (ref) => ReadyModelSelection(),
            ),
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
          aiModelSelectionProvider.overrideWith((ref) => ReadyModelSelection()),
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
