import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_tactical_engine.dart';
import 'package:godsense/domain/tactical/tactical_models.dart';

void main() {
  final observedAt = DateTime.utc(2026, 9, 1, 12);
  late NativeTacticalEngine engine;

  setUp(() => engine = NativeTacticalEngine(now: () => observedAt));

  test('retains live matchup and build after champion select disappears', () {
    const local = {
      'champion_name': 'Ahri',
      'summoner_name': 'Local',
      'tag_line': 'LAN',
      'role': 'MIDDLE',
    };
    final game = <String, dynamic>{
      'active_player': local,
      'allies': [local],
      'enemies': [
        {'champion_name': 'Vi', 'role': 'JUNGLE'},
        {'champion_name': 'Vex', 'role': 'MIDDLE'},
      ],
      'builds': {'build_type': 'RIOT_GENERAL', 'items': <Object?>[]},
    };
    final result = engine.analyze(game: game);
    expect(result['matchup'], isNotNull);
    expect(result['builds'], isNotEmpty);
    final advice = engine.answer(question: 'mi rival de linea', game: game);
    expect(advice.title, 'Ahri contra Vex');
    expect(
      advice.evidence.map((entry) => entry.source),
      contains(FactSource.liveClient),
    );
  });

  test('prioritizes imminent objective setup over generic gold advice', () {
    final advice = engine.directives(
      _game(
        gold: 2000,
        objectives: {
          'dragon': {'respawn_in': 45, 'status': 'respawning'},
          'baron': {'respawn_in': 300, 'status': 'respawning'},
        },
      ),
    );

    expect(advice.single.id, 'prepare_dragon');
    expect(advice.single.priority, 90);
    expect(advice.single.evidence.single.source, FactSource.derived);
    expect(advice.single.evidence.single.gameTimeSeconds, 600);
  });

  test('never tells a dead player to force an objective', () {
    final advice = engine.directives(
      _game(
        dead: true,
        objectives: {
          'dragon': {'respawn_in': 10},
        },
      ),
    );

    expect(advice.single.id, 'death_reset');
    expect(advice.single.priority, 100);
  });

  test('changes recovery and conversion advice with measured gold state', () {
    expect(
      engine.directives(_game(gold: -1500)).single.id,
      'recover_resources',
    );
    expect(engine.directives(_game(gold: 1500)).single.id, 'convert_lead');
    expect(engine.directives(_game(gold: 0)).single.id, 'neutral_setup');
  });

  test('uses the dynamic gold threshold produced by live processing', () {
    expect(
      engine.directives(_game(gold: 900, goldThreshold: 800)).single.id,
      'convert_lead',
    );
    expect(
      engine.directives(_game(gold: 900, goldThreshold: 1200)).single.id,
      'neutral_setup',
    );
  });

  test('adjusts an even late game using only confirmed team power curves', () {
    Map<String, dynamic> player(String curve) => {
      'is_dead': false,
      'champion_profile': {'power_curve': curve},
    };
    final advice = engine
        .directives(
          _game(
            gameTime: 1500,
            allies: [
              player('early'),
              player('early'),
              player('early'),
              player('mid'),
              player('mid'),
            ],
            enemies: [
              player('late'),
              player('late'),
              player('late'),
              player('mid'),
              player('mid'),
            ],
          ),
        )
        .single;

    expect(advice.id, 'force_before_falloff');
    expect(advice.evidence.single.factType, 'confirmed_team_power_curves');
  });

  test('converts a safe numerical advantage into an available objective', () {
    final advice = engine
        .directives(
          _game(
            gameTime: 1300,
            allies: [
              {'role': 'TOP', 'is_dead': false},
              {'role': 'JUNGLE', 'is_dead': false},
              {'role': 'MIDDLE', 'is_dead': false},
              {'role': 'BOTTOM', 'is_dead': false},
              {'role': 'UTILITY', 'is_dead': false},
            ],
            enemies: [
              {'is_dead': false},
              {'is_dead': false},
              {'is_dead': false},
              {'is_dead': true, 'respawn_timer': 28},
              {'is_dead': true, 'respawn_timer': 35},
            ],
            objectives: {
              'baron': {'status': 'alive', 'respawn_in': 0},
            },
          ),
        )
        .single;

    expect(advice.id, 'convert_number_advantage');
    expect(advice.title, contains('5 vs 3'));
    expect(advice.hints.first, contains('Barón'));
    expect(advice.evidence.single.source, FactSource.liveClient);
  });

  test('refuses fights while the team is observably outnumbered', () {
    final advice = engine
        .directives(
          _game(
            allies: [
              {'is_dead': false},
              {'is_dead': false},
              {'is_dead': false},
              {'is_dead': true, 'respawn_timer': 12},
              {'is_dead': true, 'respawn_timer': 20},
            ],
            enemies: List.generate(5, (_) => {'is_dead': false}),
          ),
        )
        .single;

    expect(advice.id, 'avoid_outnumbered_fight');
    expect(advice.title, contains('3 vs 5'));
  });

  test('withholds fabricated builds while producing transparent analysis', () {
    final result = engine.analyze(
      lobby: {
        'snapshot': {
          'my_team': [
            {'champion_name': 'Ahri', 'position': 'MIDDLE', 'is_local': true},
            {'champion_name': 'Vi', 'position': 'JUNGLE'},
          ],
          'their_team': [
            {'champion_name': 'Vex', 'position': 'MIDDLE'},
          ],
        },
      },
      selectedEnemy: 'Vex',
    );

    expect((result['matchup'] as Map)['source'], 'deterministic_general_rule');
    expect((result['knowledge'] as Map)['builds_withheld'], isTrue);
    expect(result.containsKey('builds'), isFalse);
    expect((result['team_comp'] as Map)['ally_profile'], isNull);
    expect((result['team_comp'] as Map)['identity'], 'Composición pendiente');
  });

  test('publishes a loaded Riot build to every tactical consumer', () {
    final build = {
      'build_type': 'RIOT_GENERAL',
      'patch': '16.17',
      'items': [
        {
          'category': 'Inicio 1',
          'items': [
            {'item_id': 1056, 'name': "Doran's Ring"},
          ],
        },
      ],
    };
    final result = engine.analyze(
      lobby: {
        'builds': build,
        'snapshot': {
          'my_team': [
            {'champion_name': 'Ahri', 'position': 'MIDDLE', 'is_local': true},
          ],
          'their_team': [
            {'champion_name': 'Vex', 'position': 'MIDDLE'},
          ],
        },
      },
    );

    expect(result['builds'], build);
    expect((result['knowledge'] as Map)['builds_withheld'], isFalse);
  });

  test('quality metrics make evidence and contradictions measurable', () {
    final advice = engine.directives(_game(gold: -2000));
    final clean = engine.evaluate(advice);
    final duplicate = engine.evaluate([...advice, ...advice]);

    expect(clean.evidenceCoverage, 1);
    expect(clean.actionability, 1);
    expect(clean.temporalRelevance, 1);
    expect(clean.contradictionCount, 0);
    expect(clean.score, 1);
    expect(duplicate.contradictionCount, 1);
    expect(duplicate.score, lessThan(clean.score));
  });

  test('returns no directive after the game has ended', () {
    expect(engine.directives({..._game(), '_game_ended': true}), isEmpty);
  });

  test('answers jungler location from vision with explicit provenance', () {
    final answer = engine.answer(
      question: '¿Dónde está el jungla?',
      game: _game(),
      sightings: [
        TacticalSighting(
          champion: 'Vi',
          location: 'Río superior',
          observedAt: observedAt.subtract(const Duration(seconds: 8)),
          confidence: 0.93,
          role: 'JUNGLE',
        ),
      ],
    );

    expect(answer.id, 'voice_jungler_location');
    expect(answer.ttsText, contains('Río superior'));
    expect(
      answer.evidence.map((item) => item.source),
      containsAll([FactSource.user, FactSource.vision]),
    );
    expect(answer.evidence.last.confidence, 0.93);
  });

  test('recognizes broader offline tactical intents', () {
    expect(engine.supportsQuestion('¿Le gano en all-in?'), isTrue);
    expect(engine.supportsQuestion('¿Me armo penetración mágica?'), isTrue);
    expect(engine.supportsQuestion('¿Cuánto falta para dragón?'), isTrue);
    expect(engine.supportsQuestion('¿Tienen Flash?'), isTrue);
    expect(engine.supportsQuestion('Cuéntame un chiste'), isFalse);
  });

  test('reports enemy summoner spells without inventing cooldown state', () {
    final answer = engine.answer(
      question: '¿Tienen Flash?',
      game: {
        ..._game(),
        'enemies': [
          {
            'champion_name': 'Vex',
            'summoner_spells': ['Flash', 'Ignite'],
          },
          {
            'champion_name': 'Vi',
            'summoner_spells': ['Smite', 'Flash'],
          },
        ],
      },
    );

    expect(answer.id, 'voice_summoner_spells');
    expect(answer.ttsText, contains('Vex y Vi'));
    expect(answer.ttsText, contains('No puedo confirmar'));
    expect(answer.evidence.last.source, FactSource.liveClient);
  });

  test('does not invent a jungler position without vision evidence', () {
    final answer = engine.answer(
      question: '¿Dónde está el jungla?',
      game: _game(),
    );

    expect(answer.id, 'voice_jungler_unknown');
    expect(answer.ttsText, contains('No tengo un avistamiento fiable'));
    expect(answer.evidence.single.source, FactSource.user);
  });

  test('answers objective questions from the measured timer', () {
    final answer = engine.answer(
      question: '¿Qué hacemos con el dragón?',
      game: _game(
        objectives: {
          'dragon': {'respawn_in': 25},
        },
      ),
    );

    expect(answer.id, 'voice_dragon_timer');
    expect(answer.ttsText, contains('25 segundos'));
    expect(answer.evidence.first.source, FactSource.user);
    expect(answer.evidence.last.source, FactSource.derived);
  });

  test('answers the named objective instead of the shortest timer', () {
    final answer = engine.answer(
      question: '¿Cuánto falta para el dragón?',
      game: _game(
        objectives: {
          'dragon': {'status': 'respawning', 'respawn_in': 140},
          'baron': {'status': 'respawning', 'respawn_in': 20},
        },
      ),
    );

    expect(answer.id, 'voice_dragon_timer');
    expect(answer.ttsText, contains('140 segundos'));
    expect(answer.ttsText, isNot(contains('Barón')));
  });

  test('reports an alive objective without a fake zero-second timer', () {
    final answer = engine.answer(
      question: '¿Qué hacemos con Barón?',
      game: _game(
        objectives: {
          'baron': {'status': 'alive', 'respawn_in': 0},
        },
      ),
    );

    expect(answer.id, 'voice_baron_alive');
    expect(answer.ttsText, contains('disponible ahora'));
    expect(answer.ttsText, isNot(contains('0 segundos')));
    expect(
      engine
          .directives(
            _game(
              objectives: {
                'baron': {'status': 'alive', 'respawn_in': 0},
              },
            ),
          )
          .single
          .id,
      'neutral_setup',
    );
  });

  test('answers lane-state questions from the comparable live role', () {
    final answer = engine.answer(
      question: '¿Cómo está mi línea?',
      game: _game(
        laneStates: {
          'MIDDLE': {
            'state': 'BEHIND',
            'advantage_score': -820,
            'ally': 'Ahri',
            'enemy': 'Vex',
          },
        },
      ),
    );

    expect(answer.id, 'voice_lane_state');
    expect(answer.ttsText, contains('por detrás frente a Vex'));
    expect(answer.rationale, contains('no es una diferencia de oro exacta'));
    expect(answer.evidence.last.confidence, 0.75);
  });

  test('answers build questions only from the loaded Riot artifact', () {
    final answer = engine.answer(
      question: '¿Qué objetos compro?',
      game: {
        ..._game(),
        'builds': {
          'patch': '16.17',
          'position': 'MIDDLE',
          'items': [
            {
              'category': 'Inicio 1',
              'items': [
                {'item_id': 1056, 'name': "Doran's Ring"},
                {'item_id': 2003, 'name': 'Health Potion'},
              ],
            },
            {
              'category': 'Compra 1',
              'items': [
                {'item_id': 6657, 'name': 'Rod of Ages'},
              ],
            },
          ],
        },
      },
    );

    expect(answer.id, 'voice_riot_build');
    expect(answer.ttsText, contains("Doran's Ring"));
    expect(answer.ttsText, contains('Rod of Ages'));
    expect(answer.rationale, contains('parche 16.17'));
    expect(answer.evidence.last.source, FactSource.riotData);
  });

  test('does not fabricate a build before Riot data is available', () {
    final answer = engine.answer(question: '¿Qué build hago?', game: _game());

    expect(answer.id, 'voice_build_unavailable');
    expect(answer.ttsText, contains('no tengo una build de Riot'));
    expect(answer.evidence.single.source, FactSource.user);
  });

  test('reports live gold KDA and CS for game-state questions', () {
    final answer = engine.answer(
      question: '¿Cómo voy de oro y KDA?',
      game: _game(gold: -1350),
    );

    expect(answer.id, 'voice_game_state');
    expect(answer.ttsText, contains('1350 de oro de desventaja'));
    expect(answer.ttsText, contains('2, 1, 4'));
    expect(answer.ttsText, contains('83 súbditos'));
    expect(
      answer.evidence.map((item) => item.source),
      containsAll([FactSource.user, FactSource.liveClient, FactSource.derived]),
    );
  });

  test('labels generic matchup coaching with reduced confidence', () {
    final answer = engine.answer(
      question: '¿Cuál es mi matchup?',
      lobby: {
        'snapshot': {
          'my_team': [
            {'champion_name': 'Ahri', 'is_local': true, 'position': 'MIDDLE'},
          ],
          'their_team': [
            {'champion_name': 'Vex', 'position': 'MIDDLE'},
          ],
        },
      },
    );

    expect(answer.id, 'voice_matchup_context');
    expect(answer.title, 'Ahri contra Vex');
    expect(answer.rationale.toLowerCase(), contains('regla general'));
    expect(answer.evidence.last.confidence, 0.55);
  });

  test('uses Riot champion semantics when matchup context is available', () {
    final result = engine.analyze(
      game: {
        'active_player': {
          'champion_name': 'Ahri',
          'summoner_name': 'Local',
          'tag_line': 'LAN',
          'role': 'MIDDLE',
        },
        'allies': [
          {
            'champion_name': 'Ahri',
            'summoner_name': 'Local',
            'tag_line': 'LAN',
            'role': 'MIDDLE',
            'champion_profile': {
              'classes': ['Mage'],
              'playstyle': {'mobility': 3},
              'attack_range': 550,
              'power_curve': 'late',
            },
          },
        ],
        'enemies': [
          {
            'champion_name': 'Vex',
            'role': 'MIDDLE',
            'champion_profile': {
              'classes': ['Mage'],
              'playstyle': {'crowdControl': 3, 'durability': 1},
              'tactical': {'damageType': 'MAGIC_DAMAGE'},
              'attack_range': 125,
              'power_curve': 'early',
            },
            'abilities': [
              {'slot': 'Q', 'name': 'Mistral Misil', 'cooldown': '8 / 7 / 6'},
              {'slot': 'W', 'name': 'Espacio Personal', 'cooldown': '16 / 14'},
              {'slot': 'R', 'name': 'Estallido Sombrío', 'cooldown': '140'},
            ],
          },
        ],
      },
    );

    final matchup = result['matchup'] as Map;
    expect(matchup['source'], 'riot_champion_semantics');
    expect(matchup['matchup_intel_n'], greaterThan(0));
    expect(matchup['confidence'], greaterThan(0.55));
    expect(matchup['trading_patterns'], contains(contains('Espacio Personal')));
    expect(matchup['trading_patterns'], contains(contains('ventana teórica')));
    expect((matchup['range_context'] as Map)['local_class'], 'ranged');
    expect((matchup['range_context'] as Map)['enemy_class'], 'melee');
    expect(
      matchup['win_condition'],
      contains('curva confirmada es más tardía'),
    );
    expect(matchup['rationale'], contains('no afirma estadísticas históricas'));
    expect(matchup['rationale'], contains('ni detecta lanzamientos'));
  });
}

Map<String, dynamic> _game({
  int gold = 0,
  int? goldThreshold,
  double gameTime = 600,
  bool dead = false,
  Map<String, dynamic> objectives = const {},
  Map<String, dynamic> laneStates = const {},
  List<Map<String, dynamic>> allies = const [],
  List<Map<String, dynamic>> enemies = const [],
}) => {
  'game_time': gameTime,
  'phase': 'MID',
  'team_gold_diff': gold,
  'team_state_threshold': ?goldThreshold,
  'allies': allies,
  'enemies': enemies,
  'active_player': {
    'champion_name': 'Ahri',
    'is_dead': dead,
    'kda': [2, 1, 4],
    'cs': 83,
    'role': 'MIDDLE',
  },
  'lane_states': laneStates,
  'derived': {'objectives': objectives},
  '_game_ended': false,
};
