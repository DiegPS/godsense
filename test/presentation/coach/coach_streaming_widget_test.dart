import '../../support/ai_models.dart';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/ai/ai_conversation_controller.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/domain/ai/ai_runtime_api_models.dart';
import 'package:godsense/presentation/coach/live/ai_coach_chat_card.dart';

import '../../application/ai/ai_conversation_controller_test.dart'
    show MockAiRuntimeClient, FakeSupervisor;

void main() {
  testWidgets(
    'real controller renders Markdown chunks before generation ends',
    (tester) async {
      final client = MockAiRuntimeClient();
      final supervisor = FakeSupervisor();
      final controller = AiConversationController(
        supervisor: supervisor,
        clientFactory: () => client,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiModelSelectionProvider.overrideWith(
              (ref) => ReadyModelSelection(),
            ),
            aiRuntimeSupervisorProvider.overrideWithValue(supervisor),
            aiRuntimeSupervisorStateProvider.overrideWith(
              (ref) => Stream.value(supervisor.state),
            ),
            aiConversationProvider.overrideWith((ref) => controller),
            gameContextPromptProvider.overrideWithValue('mock-context'),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: AiCoachChatCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '¿Qué priorizo?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      await tester.pump();
      expect(client.promptsSent, ['¿Qué priorizo?']);
      expect(find.text('Esperando respuesta...'), findsOneWidget);

      void emit(String type, Map<String, dynamic> properties) =>
          client.emitEvent(
            AiRuntimeEvent.fromJson({
              'type': type,
              'properties': {'sessionID': 'mock-session-1', ...properties},
            }),
          );
      emit('session.updated', {
        'info': {'id': 'mock-session-1'},
      });
      emit('message.updated', {
        'info': {'id': 'assistant-current', 'role': 'assistant'},
      });
      emit('message.part.updated', {
        'part': {
          'id': 'text-1',
          'messageID': 'assistant-current',
          'type': 'text',
          'text': '',
        },
      });
      emit('message.part.delta', {
        'messageID': 'assistant-current',
        'partID': 'text-1',
        'field': 'text',
        'delta': '**Controla la visión**.\n\n1. Prepara el objetivo.',
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.state.isBusy, isTrue);
      expect(controller.state.messages, hasLength(1));
      expect(find.byType(MarkdownBody), findsOneWidget);
      final rendered = tester
          .widgetList<SelectableText>(
            find.descendant(
              of: find.byType(MarkdownBody),
              matching: find.byType(SelectableText),
            ),
          )
          .map((w) => w.textSpan)
          .whereType<TextSpan>()
          .toList();
      expect(
        rendered.any(
          (span) => span.toPlainText().contains('Controla la visión'),
        ),
        isTrue,
      );
      expect(
        rendered.any((span) => _hasBold(span, 'Controla la visión')),
        isTrue,
      );
      expect(
        rendered.any((span) => span.toPlainText().contains('**Controla')),
        isFalse,
      );
      expect(find.text('Escribiendo respuesta...'), findsOneWidget);

      emit('message.part.delta', {
        'messageID': 'assistant-current',
        'partID': 'text-1',
        'field': 'text',
        'delta': '\n2. Vuelve con tu equipo.',
      });
      await tester.pump();
      expect(
        tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data,
        contains('2. Vuelve con tu equipo.'),
      );
      expect(controller.state.isBusy, isTrue);
      emit('session.idle', {});
      await tester.pumpAndSettle();
      expect(controller.state.status, AiConversationStatus.idle);
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(
        tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data,
        contains('2. Vuelve con tu equipo.'),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

bool _hasBold(InlineSpan span, String text, [FontWeight? inherited]) {
  if (span is! TextSpan) return false;
  final weight = span.style?.fontWeight ?? inherited;
  if (span.toPlainText().contains(text) && weight == FontWeight.w700) {
    return true;
  }
  return span.children?.any((child) => _hasBold(child, text, weight)) ?? false;
}
