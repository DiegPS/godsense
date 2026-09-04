import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/ai/game_context_prompt_builder.dart';
import 'package:godsense/application/coach_controller.dart';
import 'package:godsense/domain/companion_models.dart';
import 'package:godsense/domain/league/draft_models.dart';
import 'package:godsense/domain/tactical/tactical_models.dart';

void main() {
  const builder = GameContextPromptBuilder();

  test('formats in-game live context with champion, KDA, items and enemy team', () {
    const coachState = CoachState(
      phase: CoachPhase.inGame,
      goldDifferential: 1500,
      directives: [
        TacticalAdvice(
          id: '1',
          title: 'Presión en Dragón',
          hints: ['Agrupa con el jungla'],
          rationale: 'El dragón sale en 40s',
          ttsText: 'Dragón',
          priority: 1,
          evidence: [],
        ),
      ],
    );

    final liveGame = {
      'game_time': 915.0, // 15:15
      'team_gold_diff': 1500,
      'active_player': {
        'champion_name': 'Ahri',
        'level': 11,
        'kda': [4, 1, 3],
        'cs': 130,
        'gold_current': 1200,
        'role': 'MIDDLE',
        'is_dead': false,
        'summoner_name': 'Player',
        'tag_line': 'LAN',
        'items': [
          {'name': 'Luden\'s Companion'},
          {'name': 'Sorcerer\'s Shoes'},
        ],
      },
      'allies': [
        {
          'champion_name': 'Ahri',
          'kda': [4, 1, 3],
          'is_dead': false,
          'summoner_name': 'Player',
          'tag_line': 'LAN',
        },
        {
          'champion_name': 'Lee Sin',
          'kda': [2, 2, 5],
          'is_dead': true,
          'respawn_timer': 18,
        },
      ],
      'enemies': [
        {
          'champion_name': 'Zed',
          'kda': [3, 3, 1],
          'is_dead': false,
        },
      ],
    };

    final prompt = builder.buildSystemPrompt(
      coachState: coachState,
      liveGame: liveGame,
    );

    expect(prompt, contains('ESTADO ACTUAL: Partida en Curso (In Game)'));
    expect(prompt, contains('Tiempo de partida transcurrido: 15:15'));
    expect(prompt, contains('Diferencia de oro del equipo: +1500 de oro'));
    expect(prompt, contains('Tu campeón: Ahri (Nivel 11)'));
    expect(
      prompt,
      contains(
        '4/1/3 (K/D/A) | Súbditos (CS): 130 | Oro disponible en bolsillo: 1200',
      ),
    );
    expect(prompt, contains('Tu estado: vivo | Rol: MIDDLE'));
    expect(
      prompt,
      contains('Tus objetos actuales: Luden\'s Companion, Sorcerer\'s Shoes'),
    );
    expect(prompt, contains('Ahri (4/1/3, vivo) [TÚ]'));
    expect(prompt, contains('Lee Sin (2/2/5, muerto, reaparece en 18 s)'));
    expect(prompt, contains('Equipo Rival: Zed (3/3/1, vivo)'));
    expect(
      prompt,
      contains('[Prioridad 1] Presión en Dragón: Agrupa con el jungla'),
    );
    expect(prompt, contains('NUNCA digas "no veo tu pantalla"'));
  });

  test('formats champ select context with draft allies, enemies and bans', () {
    final coachState = CoachState(
      phase: CoachPhase.champSelect,
      localChampion: 'Ahri',
      lobby: LobbyState(
        phase: 'ChampSelect',
        briefReady: true,
        myTeam: const [],
        enemyTeam: const [],
        allLocked: false,
        draft: const DraftSnapshot(
          allies: [
            DraftPlayer(
              cellId: 1,
              championId: 103,
              championName: 'Ahri',
              position: 'MIDDLE',
              side: DraftSide.ally,
              selectionState: DraftSelectionState.locked,
              isLocal: true,
            ),
          ],
          enemies: [
            DraftPlayer(
              cellId: 6,
              championId: 238,
              championName: 'Zed',
              position: 'MIDDLE',
              side: DraftSide.enemy,
              selectionState: DraftSelectionState.locked,
              isLocal: false,
            ),
          ],
          bans: [DraftBan(championId: 7, side: DraftSide.ally)],
          allLocked: false,
        ),
      ),
    );

    final prompt = builder.buildSystemPrompt(
      coachState: coachState,
      liveGame: null,
    );

    expect(
      prompt,
      contains('ESTADO ACTUAL: Selección de Campeones (Champ Select)'),
    );
    expect(prompt, contains('Tu campeón seleccionado/hover: Ahri'));
    expect(prompt, contains('Aliados en lobby: Ahri (MIDDLE) [locked] [TÚ]'));
    expect(prompt, contains('Enemigos en lobby: Zed (MIDDLE) [locked]'));
    expect(prompt, contains('Bloqueos (Bans IDs): 7'));
    expect(prompt, contains('NUNCA digas "no veo tu pantalla"'));
  });
}
