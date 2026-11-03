import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_theme.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/application/ai/ai_conversation_controller.dart';
import 'package:godsense/presentation/coach/live/ai_coach_chat_card.dart';
import 'package:godsense/presentation/coach/shared/ai_chat_model_picker.dart';

import '../../application/ai/ai_conversation_controller_test.dart'
    show FakeSupervisor;
import '../../support/ai_models.dart';
import 'ai_coach_chat_card_test.dart' show FakeAiConversationNotifier;

void main() {
  for (final config in [(360.0, 2.0), (1200.0, 2.0), (900.0, 1.0)]) {
    final width = config.$1;
    testWidgets(
      'header model picker searches and selects without a permanent row at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = config.$2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final models = ReadyModelSelection();
        final conversation = FakeAiConversationNotifier(
          const AiConversationState(),
        );
        final supervisor = FakeSupervisor();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiRuntimeSupervisorProvider.overrideWithValue(supervisor),
              aiRuntimeSupervisorStateProvider.overrideWith(
                (_) => Stream.value(supervisor.state),
              ),
              aiModelSelectionProvider.overrideWith((_) => models),
              aiConversationProvider.overrideWith((_) => conversation),
              gameContextPromptProvider.overrideWithValue('fixture'),
            ],
            child: MaterialApp(
              theme: godsenseTheme(),
              home: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: AiCoachChatCard(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Proveedor y modelo'), findsNothing);
        expect(find.text('Kilo · Kilo Auto'), findsOneWidget);
        if (config.$2 == 1) {
          final title = tester.getRect(find.text('Coach IA conversacional'));
          final picker = tester.getRect(
            find.byKey(const Key('chat-model-picker')),
          );
          final status = tester.getRect(find.text('CONECTADO'));
          expect(picker.center.dy, closeTo(title.center.dy, 1));
          expect(status.center.dy, closeTo(picker.center.dy, 1));
          expect(picker.left, greaterThan(title.right));
          expect(picker.right, lessThan(status.left));
        }
        await tester.tap(find.byKey(const Key('chat-model-picker')));
        await tester.pumpAndSettle();
        expect(find.text('Elegir modelo'), findsOneWidget);
        expect(
          find.byType(BottomSheet),
          width < 600 ? findsOneWidget : findsNothing,
        );
        if (width < 600) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byType(AiChatModelOptions)).bottom,
            lessThanOrEqualTo(700),
          );
        }
        final search = find.descendant(
          of: find.byType(AiChatModelOptions),
          matching: find.byType(TextField),
        );
        await tester.enterText(search, 'no-such-model');
        await tester.pumpAndSettle();
        expect(
          find.textContaining('No hay modelos que coincidan'),
          findsOneWidget,
        );
        await tester.enterText(search, 'paid-model');
        await tester.pumpAndSettle();
        expect(find.text('Other'), findsOneWidget);
        expect(find.textContaining('Puede consumir saldo'), findsOneWidget);
        await tester.tap(find.text('Premium'));
        await tester.pumpAndSettle();
        expect(models.state.selected, paidModel);
        expect(find.text('Elegir modelo'), findsNothing);
        expect(find.text('Kilo · Premium'), findsOneWidget);
        expect(conversation.sentMessages, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('model picker is disabled during generation', (tester) async {
    final supervisor = FakeSupervisor();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiRuntimeSupervisorProvider.overrideWithValue(supervisor),
          aiRuntimeSupervisorStateProvider.overrideWith(
            (_) => Stream.value(supervisor.state),
          ),
          aiModelSelectionProvider.overrideWith((_) => ReadyModelSelection()),
          aiConversationProvider.overrideWith(
            (_) => FakeAiConversationNotifier(
              const AiConversationState(status: AiConversationStatus.streaming),
            ),
          ),
        ],
        child: MaterialApp(
          theme: godsenseTheme(),
          home: const Scaffold(body: AiChatModelPicker()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('chat-model-picker')))
          .onPressed,
      isNull,
    );
    expect(find.text('Elegir modelo'), findsNothing);
  });
}
