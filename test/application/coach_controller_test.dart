import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/coach_controller.dart';
import 'package:godsense/domain/companion_models.dart';
import 'package:godsense/domain/league/game_session.dart';
import 'package:godsense/domain/tactical/tactical_models.dart';

void main() {
  test(
    'projects native lobby, gold, threats, and voice without foreign states',
    () {
      final controller = CoachController(
        importRunes: (_) async {},
        importItems: () async {},
      );
      addTearDown(controller.dispose);
      final answeredAt = DateTime.utc(2026, 9, 1);

      controller.synchronize(
        CoachInputs(
          gameflowPhase: 'IN_GAME',
          session: const GameSessionState(),
          liveGame: {
            'team_gold_diff': 1200,
            'gold_points': [
              {'game_time': 60, 'value': 200},
            ],
          },
          lobby: LobbyState.fromJson({
            'phase': 'IN_SELECT',
            'snapshot': {
              'my_team': [
                {
                  'champion_id': 22,
                  'champion_name': 'Ashe',
                  'is_local': true,
                  'selection_state': 'locked',
                },
              ],
              'their_team': [
                {
                  'champion_id': 103,
                  'champion_name': 'Ahri',
                  'selection_state': 'locked',
                },
              ],
            },
          }),
          runes: null,
          items: null,
          jungle: null,
          directives: const [],
          threats: [
            CoachThreatViewData(
              isGank: true,
              champion: 'Lee Sin',
              location: 'TOP',
              region: 'top_river',
              observedAt: answeredAt,
              confidence: .9,
            ),
          ],
          voiceProcessing: false,
          voiceQuestion: '¿Qué hago?',
          voiceAdvice: TacticalAdvice(
            id: 'answer',
            title: 'Juega seguro',
            hints: const [],
            rationale: 'Sin visión.',
            ttsText: 'Congela la oleada.',
            priority: 1,
            evidence: const [],
          ),
          voiceAnsweredAt: answeredAt,
        ),
      );

      expect(controller.state.phase, CoachPhase.inGame);
      expect(controller.state.localChampion, 'Ashe');
      expect(controller.state.selectedEnemy, 'Ahri');
      expect(controller.state.goldDifferential, 1200);
      expect(controller.state.goldTimeline.single.value, 200);
      expect(controller.state.threats.single.isGank, isTrue);
      expect(controller.state.voiceHistory.single.answer, 'Congela la oleada.');
    },
  );

  test('keeps bounded voice history and avoids duplicate answers', () {
    final controller = CoachController(
      importRunes: (_) async {},
      importItems: () async {},
    );
    addTearDown(controller.dispose);
    for (var index = 0; index < 25; index++) {
      controller.synchronize(_voiceInput(index));
    }
    controller.synchronize(_voiceInput(24));

    expect(controller.state.voiceHistory, hasLength(20));
    expect(controller.state.voiceHistory.first.question, 'Pregunta 24');
  });

  test('reports failed imports without throwing into presentation', () async {
    final controller = CoachController(
      importRunes: (_) async {},
      importItems: () async => throw StateError('LCU offline'),
    );
    addTearDown(controller.dispose);

    await controller.importItemSet();

    expect(controller.state.importFeedback.status, CoachImportStatus.failed);
    expect(controller.state.importFeedback.message, contains('LCU offline'));
  });
}

CoachInputs _voiceInput(int index) => CoachInputs(
  gameflowPhase: 'None',
  session: const GameSessionState(),
  liveGame: null,
  lobby: null,
  runes: null,
  items: null,
  jungle: null,
  directives: const [],
  threats: const [],
  voiceProcessing: false,
  voiceQuestion: 'Pregunta $index',
  voiceAdvice: TacticalAdvice(
    id: '$index',
    title: 'Respuesta',
    hints: const [],
    rationale: '',
    ttsText: 'Respuesta $index',
    priority: 1,
    evidence: const [],
  ),
  voiceAnsweredAt: DateTime.utc(2026, 1, 1, 0, index),
);
