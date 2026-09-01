import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_tactical_engine.dart';
import 'package:godsense/domain/tactical/tactical_models.dart';

void main() {
  final observedAt = DateTime.utc(2026, 9, 1, 12);
  late NativeTacticalEngine engine;

  setUp(() => engine = NativeTacticalEngine(now: () => observedAt));

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
    expect((result['team_comp'] as Map)['ally_profile'], isNotNull);
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

    expect(answer.id, 'voice_prepare_dragon');
    expect(answer.ttsText, contains('25 segundos'));
    expect(answer.evidence.first.source, FactSource.user);
    expect(answer.evidence.last.source, FactSource.derived);
  });
}

Map<String, dynamic> _game({
  int gold = 0,
  bool dead = false,
  Map<String, dynamic> objectives = const {},
}) => {
  'game_time': 600.0,
  'phase': 'MID',
  'team_gold_diff': gold,
  'active_player': {'champion_name': 'Ahri', 'is_dead': dead},
  'derived': {'objectives': objectives},
  '_game_ended': false,
};
