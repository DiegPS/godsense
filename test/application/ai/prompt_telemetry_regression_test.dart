import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/ai/game_context_prompt_builder.dart';
import 'package:godsense/application/coach_controller.dart';

void main() {
  const builder = GameContextPromptBuilder();
  test(
    'fractional telemetry never gives the coach a clock with sixty seconds',
    () {
      for (final (seconds, clock) in [
        (59.9, '0:59'),
        (959.9, '15:59'),
        (960.0, '16:00'),
      ]) {
        final prompt = builder.buildSystemPrompt(
          coachState: const CoachState(phase: CoachPhase.inGame),
          liveGame: {'game_time': seconds},
        );
        expect(prompt, contains('Tiempo de partida transcurrido: $clock'));
        expect(prompt, isNot(contains(':60')));
      }
    },
  );

  test(
    'raw Live Client score schema and item aliases are included in the prompt',
    () {
      final prompt = builder.buildSystemPrompt(
        coachState: const CoachState(
          phase: CoachPhase.inGame,
          goldDifferential: -1200,
        ),
        liveGame: {
          'active_player': {
            'championName': 'Ahri',
            'level': 12,
            'currentGold': 650,
            'scores': {
              'kills': 2,
              'deaths': 3,
              'assists': 7,
              'creepScore': 121,
            },
            'is_dead': true,
            'respawn_timer': 14.0,
            'items': [
              {'displayName': 'Botas'},
              {'unknown': 'ignored'},
            ],
          },
          'enemies': [
            {
              'champion': 'Zed',
              'scores': {'kills': 4, 'deaths': 1, 'assists': 0},
            },
            {'is_dead': true},
          ],
        },
      );
      expect(prompt, contains('Diferencia de oro del equipo: -1200'));
      expect(prompt, contains('Tu campeón: Ahri (Nivel 12)'));
      expect(prompt, contains('2/3/7 (K/D/A) | Súbditos (CS): 121'));
      expect(prompt, contains('Oro disponible en bolsillo: 650'));
      expect(prompt, contains('muerto, reaparece en 14 s'));
      expect(prompt, contains('Tus objetos actuales: Botas'));
      expect(prompt, contains('Zed (4/1/0, vivo)'));
      expect(prompt, contains('Desconocido (0/0/0, muerto)'));
    },
  );

  test(
    'missing live packets explicitly say that telemetry is still pending',
    () {
      final prompt = builder.buildSystemPrompt(
        coachState: const CoachState(phase: CoachPhase.inGame),
        liveGame: null,
      );
      expect(
        prompt,
        contains('Esperando paquetes de telemetría de Live Client'),
      );
      expect(prompt, isNot(contains('Tu campeón:')));
    },
  );
}
