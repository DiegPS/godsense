import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/coach_controller.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/domain/companion_models.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/game_session.dart';
import 'package:godsense/domain/tactical/tactical_models.dart';
import 'package:godsense/presentation/coach/coach_page.dart';

void main() {
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
    expect(find.text('LOCKED'), findsNWidgets(2));
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

    expect(find.text('Directivas tácticas locales'), findsOneWidget);
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

    final liveButton = find.widgetWithText(OutlinedButton, 'En partida');
    expect(liveButton, findsOneWidget);
    await tester.tap(liveButton);
    await tester.pump();

    expect(find.text('Directivas tácticas locales'), findsOneWidget);
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
  overrides: [coachControllerProvider.overrideWith((_) => controller)],
  child: const MaterialApp(home: Scaffold(body: CoachPage())),
);

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
