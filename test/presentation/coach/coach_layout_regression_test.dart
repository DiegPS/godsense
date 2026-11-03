import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/application/ai/ai_conversation_controller.dart';
import 'package:godsense/presentation/coach/live/ai_coach_chat_card.dart';
import 'package:godsense/presentation/coach/live/coach_message_body.dart';
import 'package:godsense/presentation/coach/live/threat_and_sightings_card.dart';
import 'package:godsense/presentation/coach/live/voice_coach_card.dart';
import 'package:godsense/application/coach_controller.dart';

import '../../support/ai_models.dart';
import '../../application/ai/ai_conversation_controller_test.dart'
    show MockAiRuntimeClient, FakeSupervisor;

class FixtureChat extends AiConversationController {
  FixtureChat(AiConversationState initial)
    : super(
        supervisor: FakeSupervisor(),
        clientFactory: () => MockAiRuntimeClient(),
      ) {
    state = initial;
  }
  void publish(AiConversationState value) => state = value;
}

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      'chat preserves reading position and reserves scrollbar space $direction',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final supervisor = FakeSupervisor();
        final chat = FixtureChat(
          AiConversationState(
            messages: List.generate(
              24,
              (index) => AiChatMessage(
                id: 'message-$index',
                role: 'assistant',
                content:
                    'Mensaje $index. Información táctica para conservar la posición de lectura mientras llega una respuesta nueva.',
                timestamp: DateTime.utc(2026),
              ),
            ),
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiRuntimeSupervisorProvider.overrideWithValue(supervisor),
              aiRuntimeSupervisorStateProvider.overrideWith(
                (_) => Stream.value(supervisor.state),
              ),
              aiModelSelectionProvider.overrideWith(
                (_) => ReadyModelSelection(),
              ),
              aiConversationProvider.overrideWith((_) => chat),
              gameContextPromptProvider.overrideWithValue('fixture'),
            ],
            child: MaterialApp(
              theme: godsenseTheme(),
              home: Directionality(
                textDirection: direction,
                child: const Scaffold(
                  body: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: AiCoachChatCard(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final history = find.byKey(const Key('coach-chat-history'));
        final list = tester.widget<ListView>(history);
        final position = list.controller!.position;
        expect(position.maxScrollExtent, greaterThan(0));
        expect(position.extentAfter, lessThan(1));
        final bubble = find
            .ancestor(
              of: find.text('Coach IA').last,
              matching: find.byType(Container),
            )
            .first;
        final bubbleRect = tester.getRect(bubble);
        final viewport = tester.getRect(history);
        final gutter = direction == TextDirection.ltr
            ? viewport.right - bubbleRect.right
            : bubbleRect.left - viewport.left;
        expect(gutter, greaterThanOrEqualTo(20));
        expect(
          tester.widget<Scrollbar>(find.byType(Scrollbar)).controller,
          same(list.controller),
        );
        await tester.drag(history, const Offset(0, 200));
        await tester.pumpAndSettle();
        final readingOffset = position.pixels;
        expect(find.text('Ir al último mensaje'), findsOneWidget);
        chat.publish(
          chat.state.copyWith(
            streamedText: 'Una nueva respuesta que no debe mover la lectura.',
          ),
        );
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(readingOffset, 1));
        await tester.tap(find.text('Ir al último mensaje'));
        await tester.pumpAndSettle();
        expect(position.extentAfter, lessThan(1));
        chat.publish(
          chat.state.copyWith(
            streamedText: List.filled(30, 'La respuesta continúa.').join(' '),
          ),
        );
        await tester.pumpAndSettle();
        expect(position.extentAfter, lessThan(1));
        expect(find.text('Ir al último mensaje'), findsNothing);
        // Desktop wheel direction is announced BEFORE the offset changes.
        // A single small notch must suspend following even within 32px of end.
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: tester.getCenter(history));
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(history),
            scrollDelta: const Offset(0, -20),
          ),
        );
        await tester.pumpAndSettle();
        expect(position.extentAfter, greaterThan(10));
        final wheelOffset = position.pixels;
        chat.publish(
          chat.state.copyWith(
            streamedText:
                '${chat.state.streamedText}\n\nUn fragmento nuevo después de subir con la rueda.',
          ),
        );
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(wheelOffset, 1));
        expect(find.text('Ir al último mensaje'), findsOneWidget);
        await mouse.removePointer();
        await tester.tap(find.text('Ir al último mensaje'));
        await tester.pumpAndSettle();
        final edge = tester.getRect(history);
        await tester.dragFrom(
          Offset(
            direction == TextDirection.ltr ? edge.right - 4 : edge.left + 4,
            edge.bottom - 12,
          ),
          const Offset(0, -80),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(position.extentAfter, greaterThan(10));
        final thumbOffset = position.pixels;
        chat.publish(
          chat.state.copyWith(
            streamedText:
                '${chat.state.streamedText}\nOtra actualización después de mover la barra.',
          ),
        );
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(thumbOffset, 1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final scale in [1.0, 2.0]) {
    for (final threats in [true, false]) {
      testWidgets('other Coach cards scale=$scale threats=$threats', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          MaterialApp(
            theme: godsenseTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: threats
                    ? ThreatAndSightingsCard(
                        threats: [
                          CoachThreatViewData(
                            isGank: true,
                            champion: 'Fiddlesticks',
                            location: 'Río superior',
                            region: 'Top River',
                            observedAt: DateTime.now(),
                            confidence: .9,
                          ),
                        ],
                      )
                    : VoiceCoachCard(
                        processing: false,
                        history: [
                          VoiceCoachEntry(
                            question: '¿Cómo debo preparar la próxima pelea por el dragón?',
                            answer: 'Controla la visión y prepara la oleada antes de acercarte al objetivo.',
                            answeredAt: DateTime.now(),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final width in [360.0, 640.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final streaming in [false, true]) {
        testWidgets('chat width=$width scale=$scale streaming=$streaming', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final supervisor = FakeSupervisor();
          final chat = FixtureChat(
            AiConversationState(
              status: streaming
                  ? AiConversationStatus.streaming
                  : AiConversationStatus.idle,
              streamedText: streaming
                  ? 'Una respuesta larga para comprobar sus límites y la lectura.'
                  : '',
            ),
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                aiRuntimeSupervisorProvider.overrideWithValue(supervisor),
                aiRuntimeSupervisorStateProvider.overrideWith(
                  (_) => Stream.value(supervisor.state),
                ),
                aiModelSelectionProvider.overrideWith(
                  (_) => ReadyModelSelection(),
                ),
                aiConversationProvider.overrideWith((_) => chat),
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
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  testWidgets('Markdown wide table inside a 280 logical pixel chat', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: godsenseTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 280,
              child: CoachMessageBody(
                text: '| Campeón | Recomendación | Motivo |\n|---|---|---|\n| Aatrox | Controla la oleada y espera refuerzos antes de iniciar | Necesitas proteger los objetivos y conservar tus recursos |',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
