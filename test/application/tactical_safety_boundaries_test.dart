import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_tactical_engine.dart';
import 'package:godsense/domain/tactical/tactical_models.dart';

void main() {
  late NativeTacticalEngine engine;
  setUp(
    () => engine = NativeTacticalEngine(now: () => DateTime.utc(2026, 10, 26)),
  );
  Map<String, dynamic> game({
    Map<String, dynamic> active = const {},
    Map<String, dynamic> objectives = const {},
  }) => {
    'session_id': 'synthetic',
    'game_time': 1000.0,
    'active_player': {'champion_name': 'Ahri', 'health_ratio': 1.0, ...active},
    'allies': List.generate(5, (_) => {'is_dead': false}),
    'enemies': List.generate(5, (_) => {'is_dead': false}),
    'derived': {'objectives': objectives},
  };

  for (final health in [.0, .2]) {
    test(
      'critical health $health overrides preparation and spending advice',
      () {
        final answer = engine
            .directives(
              game(
                active: {'health_ratio': health, 'gold_current': 2000},
                objectives: {
                  'dragon': {'respawn_in': 30, 'status': 'respawning'},
                },
              ),
            )
            .single;
        expect(answer.id, 'recover_health');
        expect(answer.evidence.single.source, FactSource.liveClient);
      },
    );
  }
  for (final (cash, expected) in [
    (1499, 'prepare_dragon'),
    (1500, 'spend_before_objective'),
  ]) {
    test('objective spending advice respects available local gold $cash', () {
      final answer = engine
          .directives(
            game(
              active: {'gold_current': cash},
              objectives: {
                'dragon': {'respawn_in': 45, 'status': 'respawning'},
              },
            ),
          )
          .single;
      expect(answer.id, expected);
    });
  }
  test('an explicit objective request does not silently answer for a different objective', () {
    final answer = engine.answer(
      question: 'Cuánto falta para el dragón',
      game: game(
        objectives: {
          'baron': {'status': 'alive'},
        },
      ),
    );
    expect(answer.id, 'voice_objective_unknown');
    expect(answer.ttsText, isNot(contains('Barón disponible')));
  });
  test('a generic objective question selects the nearest known opportunity regardless of insertion order', () {
    final entries = <String, dynamic>{
      'dragon': {'status': 'respawning', 'respawn_in': 120},
      'herald': {'status': 'respawning', 'respawn_in': 20},
      'baron': {'status': 'alive'},
      'void_grubs': {'status': 'unknown'},
    }.entries.toList();
    for (var offset = 0; offset < entries.length; offset++) {
      final ordered = Map<String, dynamic>.fromEntries([
        ...entries.skip(offset),
        ...entries.take(offset),
      ]);
      final answer = engine.answer(
        question: 'Qué objetivo está disponible',
        game: game(objectives: ordered),
      );
      expect(answer.id, 'voice_baron_alive');
      expect(
        answer.evidence.map((entry) => entry.source),
        contains(FactSource.derived),
      );
    }
  });
  for (final status in ['', 'unknown', 'unrecognized']) {
    test(
      'an unconfirmed objective state $status is not declared permanently retired',
      () {
        final answer = engine.answer(
          question: 'Cuánto falta para el dragón',
          game: game(
            objectives: {
              'dragon': {'status': status},
            },
          ),
        );
        expect(answer.id, 'voice_objective_unknown');
        expect(answer.ttsText, isNot(contains('ya no está disponible')));
      },
    );
  }
  test('a retired objective is not replaced by another living objective', () {
    final answer = engine.answer(
      question: 'Cuánto falta para el heraldo',
      game: game(
        objectives: {
          'herald': {'status': 'unavailable'},
          'baron': {'status': 'alive'},
        },
      ),
    );
    expect(answer.id, 'voice_herald_unavailable');
  });
  for (final snapshot in <Map<String, dynamic>?>[
    null,
    {'_game_ended': true},
  ]) {
    test(
      'objectives and spells remain unavailable without an active game (${snapshot == null ? "missing" : "ended"})',
      () {
        expect(
          engine
              .answer(question: 'Cuánto falta para dragón', game: snapshot)
              .id,
          'voice_objective_unavailable',
        );
        expect(
          engine
              .answer(question: '¿Mi teleport está listo?', game: snapshot)
              .id,
          'voice_summoner_spells_unavailable',
        );
      },
    );
  }
  test('invalid clock seconds cannot create a voice cooldown reminder', () {
    final snapshot = game();
    expect(
      engine.answer(question: 'Flash Viktor 18:99', game: snapshot).id,
      isNot('voice_timer_recorded'),
    );
    expect(
      engine.takeTimerReminders({...snapshot, 'game_time': 1180.0}),
      isEmpty,
    );
  });
  test(
    'melee matchup advice stays conditional about enemy ability cooldowns',
    () {
      final local = <String, dynamic>{
        'champion_name': 'Local',
        'role': 'MIDDLE',
        'champion_profile': {
          'attack_range': 125,
          'playstyle': {'mobility': 3},
        },
      };
      final opponent = <String, dynamic>{
        'champion_name': 'Rival',
        'role': 'MIDDLE',
        'champion_profile': {
          'attack_range': 550,
          'playstyle': {'durability': 3},
        },
        'abilities': [
          {'slot': 'Q', 'name': 'Amenaza menor', 'matchup_priority': 1},
          {'slot': 'W', 'name': 'Amenaza principal', 'matchup_priority': 5},
          {'slot': 'R', 'name': 'Definitiva rival'},
        ],
      };
      final result = engine.analyze(
        game: {
          'active_player': local,
          'allies': [local],
          'enemies': [opponent],
        },
      );
      final matchup = result['matchup'] as Map;
      final patterns = (matchup['trading_patterns'] as List).join(' ');
      expect(patterns, contains('Cede súbditos antes que vida'));
      expect(patterns, contains('Amenaza principal'));
      expect(
        patterns,
        contains('no confirma aún el lanzamiento ni su cooldown actual'),
      );
      expect(
        patterns,
        contains(
          'no elijas intercambio corto o extendido sólo por esa etiqueta',
        ),
      );
    },
  );
}
