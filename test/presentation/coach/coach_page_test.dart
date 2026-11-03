import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/coach_controller.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/application/native_speech_controller.dart';
import 'package:godsense/infrastructure/speech/shared_preferences_speech_settings_repository.dart';
import 'package:godsense/domain/companion_models.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/game_session.dart';
import 'package:godsense/domain/tactical/tactical_models.dart';
import 'package:godsense/presentation/coach/coach_page.dart';
import 'package:godsense/presentation/coach/live/ai_coach_chat_card.dart';
import 'package:godsense/application/ai/ai_conversation_controller.dart';

import '../../support/ai_models.dart';
import '../../application/ai/ai_conversation_controller_test.dart'
    show FakeSupervisor;
import 'ai_coach_chat_card_test.dart' show FakeAiConversationNotifier;

import 'package:godsense/presentation/coach/shared/coach_section_header.dart';
import 'package:godsense/presentation/coach/setup/item_bundles_view.dart';
import 'package:godsense/presentation/coach/live/gold_timeline_card.dart';

void main() {
  testWidgets(
    'sending works from every manual Coach phase with one conversation',
    (tester) async {
      await _setSize(tester, const Size(1280, 2000));
      final coach = _controller(_inactiveInputs());
      final conversation = _PhaseConversation();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coachControllerProvider.overrideWith((_) => coach),
            nativeSpeechProvider.overrideWith((_) => _ReadySpeech()),
            aiModelSelectionProvider.overrideWith((_) => ReadyModelSelection()),
            aiRuntimeSupervisorProvider.overrideWithValue(FakeSupervisor()),
            aiRuntimeSupervisorStateProvider.overrideWith(
              (_) => Stream.value(FakeSupervisor().state),
            ),
            aiConversationProvider.overrideWith((_) => conversation),
          ],
          child: const MaterialApp(home: Scaffold(body: CoachPage())),
        ),
      );
      await tester.pumpAndSettle();
      for (final phase in CoachPhase.values) {
        coach.showPhase(phase);
        await tester.pumpAndSettle();
        final field = find.byType(TextField);
        await tester.ensureVisible(field);
        await tester.enterText(field, 'Pregunta desde ${phase.name}');
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pump();
        await tester.pump();
        expect(conversation.sentMessages.last, 'Pregunta desde ${phase.name}');
        expect(tester.widget<TextField>(field).controller!.text, isEmpty);
        expect(tester.widget<TextField>(field).enabled, isFalse);
        conversation.finish();
        await tester.pump();
      }
      expect(conversation.sentMessages.length, 4);
      expect(conversation.state.messages.length, 4);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'one chat preserves a draft and pending send across all Coach phases',
    (tester) async {
      await _setSize(tester, const Size(1280, 2000));
      final coach = _controller(_inactiveInputs());
      final conversation = FakeAiConversationNotifier(
        const AiConversationState(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coachControllerProvider.overrideWith((_) => coach),
            nativeSpeechProvider.overrideWith((_) => _ReadySpeech()),
            aiModelSelectionProvider.overrideWith((_) => ReadyModelSelection()),
            aiRuntimeSupervisorProvider.overrideWithValue(FakeSupervisor()),
            aiRuntimeSupervisorStateProvider.overrideWith(
              (_) => Stream.value(FakeSupervisor().state),
            ),
            aiConversationProvider.overrideWith((_) => conversation),
          ],
          child: const MaterialApp(home: Scaffold(body: CoachPage())),
        ),
      );
      await tester.pumpAndSettle();
      final initialChat = tester.state(find.byType(AiCoachChatCard));
      await tester.enterText(find.byType(TextField), 'Mi pregunta sin enviar');
      for (final phase in [
        CoachPhase.inGame,
        CoachPhase.champSelect,
        CoachPhase.postGame,
        CoachPhase.inactive,
      ]) {
        coach.showPhase(phase);
        await tester.pumpAndSettle();
        expect(find.byType(AiCoachChatCard), findsOneWidget);
        expect(
          identical(tester.state(find.byType(AiCoachChatCard)), initialChat),
          isTrue,
          reason: 'Changing to $phase must not replace the chat',
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Mi pregunta sin enviar',
        );
      }
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      await tester.pump();
      expect(conversation.sentMessages, ['Mi pregunta sin enviar']);
      for (final phase in CoachPhase.values) {
        coach.showPhase(phase);
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        expect(
          conversation.state.messages.single.content,
          'Mi pregunta sin enviar',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'live gold updates preserve unrelated Coach cards and phase controls',
    (tester) async {
      await _setSize(tester, const Size(1280, 900));
      CoachInputs live(int gold) => CoachInputs(
        gameflowPhase: 'InProgress',
        session: const GameSessionState(),
        liveGame: {
          'team_gold_diff': gold,
          'gold_points': [
            {'game_time': 60, 'value': 100},
            {'game_time': 120, 'value': gold},
          ],
        },
        lobby: null,
        runes: null,
        items: null,
        jungle: null,
        directives: const [],
        threats: const [],
        voiceProcessing: false,
        voiceQuestion: '',
        voiceAdvice: null,
        voiceAnsweredAt: null,
      );
      final controller = _controller(live(100));
      await tester.pumpWidget(_app(controller));
      await tester.pump();
      final header = tester.widget<CoachSectionHeader>(
        find.byType(CoachSectionHeader),
      );
      final items = tester.widget<ItemBundlesView>(
        find.byType(ItemBundlesView),
      );
      for (final gold in [200, 350, -800]) {
        controller.synchronize(live(gold));
        await tester.pump();
        expect(
          tester
              .widget<GoldTimelineCard>(find.byType(GoldTimelineCard))
              .differential,
          gold,
        );
        expect(
          identical(
            tester.widget<CoachSectionHeader>(find.byType(CoachSectionHeader)),
            header,
          ),
          isTrue,
        );
        expect(
          identical(
            tester.widget<ItemBundlesView>(find.byType(ItemBundlesView)),
            items,
          ),
          isTrue,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders Champ Select at 800 pixels without overflow', (
    tester,
  ) async {
    await _setSize(tester, const Size(800, 900));
    final controller = _controller(_champSelectInputs());

    await tester.pumpWidget(_app(controller));
    await tester.pump();

    expect(find.text('Draft 5v5 y bans'), findsOneWidget);
    expect(find.text('Ashe'), findsWidgets);
    expect(find.text('Ahri'), findsWidgets);
    expect(find.text('CONFIRMADO'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders native live modules at 1280 pixels', (tester) async {
    await _setSize(tester, const Size(1280, 900));
    final controller = _controller(
      CoachInputs(
        gameflowPhase: 'InProgress',
        session: const GameSessionState(),
        liveGame: {
          'team_gold_diff': -900,
          'gold_points': [
            {'game_time': 60, 'value': 100},
            {'game_time': 120, 'value': -900},
          ],
        },
        lobby: null,
        runes: null,
        items: null,
        jungle: null,
        directives: [
          TacticalAdvice(
            id: 'ward',
            title: 'Coloca visión',
            hints: const ['Río superior'],
            rationale: 'Jungla sin localizar.',
            ttsText: 'Coloca visión.',
            priority: 2,
            evidence: const [],
          ),
        ],
        threats: [
          CoachThreatViewData(
            isGank: true,
            champion: 'Lee Sin',
            location: 'TOP',
            region: 'top_river',
            observedAt: DateTime.now(),
            confidence: .92,
          ),
        ],
        voiceProcessing: false,
        voiceQuestion: '',
        voiceAdvice: null,
        voiceAnsweredAt: null,
      ),
    );

    await tester.pumpWidget(_app(controller));
    await tester.pump();

    expect(find.text('Recomendaciones tácticas'), findsOneWidget);
    expect(find.text('Coloca visión'), findsOneWidget);
    expect(find.textContaining('Lee Sin'), findsOneWidget);
    expect(find.text('−900'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders only persisted session facts in post-game', (
    tester,
  ) async {
    final completed = _session(GameSessionPhase.completed);
    final controller = _controller(
      CoachInputs(
        gameflowPhase: 'EndOfGame',
        session: GameSessionState(lastCompleted: completed),
        liveGame: null,
        lobby: null,
        runes: null,
        items: null,
        jungle: null,
        directives: const [],
        threats: const [],
        voiceProcessing: false,
        voiceQuestion: '',
        voiceAdvice: null,
        voiceAnsweredAt: null,
      ),
    );

    await tester.pumpWidget(_app(controller));

    expect(find.text('Resumen de sesión'), findsOneWidget);
    expect(find.text('session-1'), findsOneWidget);
    expect(find.text('Generar análisis AI'), findsNothing);
  });

  testWidgets('secondary phase controls are keyboard-operable buttons', (
    tester,
  ) async {
    final controller = _controller(_inactiveInputs());
    await tester.pumpWidget(_app(controller));

    final liveButton = find.widgetWithText(TextButton, 'En partida');
    expect(liveButton, findsOneWidget);
    await tester.tap(liveButton);
    await tester.pump();

    expect(find.text('Recomendaciones tácticas'), findsOneWidget);
    final semantics = tester.getSemantics(liveButton);
    expect(semantics.flagsCollection.isButton, isTrue);
  });

  test('Coach presentation has no legacy AI/backend dependency', () {
    final files = Directory('lib/presentation/coach')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final source = files.map((file) => file.readAsStringSync()).join('\n');

    expect(source, isNot(contains('opencode')));
    expect(source, isNot(contains('generateLobbyBrief')));
    expect(source, isNot(contains('companionControllerProvider')));
  });
}

Widget _app(CoachController controller) => ProviderScope(
  overrides: [
    coachControllerProvider.overrideWith((_) => controller),
    nativeSpeechProvider.overrideWith((_) => _ReadySpeech()),
  ],
  child: const MaterialApp(home: Scaffold(body: CoachPage())),
);

class _ReadySpeech extends NativeSpeechController {
  _ReadySpeech()
    : super(repository: SharedPreferencesSpeechSettingsRepository()) {
    state = const NativeSpeechState(
      loading: false,
      modelsChecked: true,
      speechModelInstalled: true,
      ttsModelInstalled: true,
    );
  }
}

CoachController _controller(CoachInputs inputs) {
  final controller = CoachController(
    importRunes: (_) async {},
    importItems: () async {},
  );
  controller.synchronize(inputs);
  return controller;
}

CoachInputs _champSelectInputs() => CoachInputs(
  gameflowPhase: 'IN_SELECT',
  session: const GameSessionState(),
  liveGame: null,
  lobby: LobbyState.fromJson({
    'phase': 'IN_SELECT',
    'snapshot': {
      'my_team': [
        {
          'cell_id': 1,
          'champion_id': 22,
          'champion_name': 'Ashe',
          'position': 'BOTTOM',
          'selection_state': 'locked',
          'is_local': true,
        },
      ],
      'their_team': [
        {
          'cell_id': 6,
          'champion_id': 103,
          'champion_name': 'Ahri',
          'position': 'MIDDLE',
          'selection_state': 'locked',
        },
      ],
      'bans': {
        'my_team_bans': [11],
        'their_team_bans': [64],
      },
    },
  }),
  runes: null,
  items: null,
  jungle: null,
  directives: const [],
  threats: const [],
  voiceProcessing: false,
  voiceQuestion: '',
  voiceAdvice: null,
  voiceAnsweredAt: null,
);

CoachInputs _inactiveInputs() => const CoachInputs(
  gameflowPhase: 'None',
  session: GameSessionState(),
  liveGame: null,
  lobby: null,
  runes: null,
  items: null,
  jungle: null,
  directives: [],
  threats: [],
  voiceProcessing: false,
  voiceQuestion: '',
  voiceAdvice: null,
  voiceAnsweredAt: null,
);

GameSession _session(GameSessionPhase phase) => GameSession(
  sessionId: 'session-1',
  generation: GameSessionGeneration(1),
  accountPuuid: Puuid('player'),
  phase: phase,
  startedAt: DateTime.utc(2026, 9, 1, 12),
  lastObservedAt: DateTime.utc(2026, 9, 1, 12, 30),
  lastGameTime: GameTime(const Duration(minutes: 30)),
  endedAt: DateTime.utc(2026, 9, 1, 12, 30),
);

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _PhaseConversation extends FakeAiConversationNotifier {
  _PhaseConversation() : super(const AiConversationState());
  void finish() => state = state.copyWith(
    status: AiConversationStatus.idle,
    streamedText: '',
  );
}
