import '../domain/tactical/tactical_models.dart';
import 'champion_composition_analyzer.dart';

class NativeTacticalEngine {
  NativeTacticalEngine({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  TacticalAdvice answer({
    required String question,
    Map<String, dynamic>? game,
    Map<String, dynamic>? lobby,
    List<TacticalSighting> sightings = const [],
  }) {
    final now = _now().toUtc();
    final normalized = _normalize(question);
    final context = _coachingContext(lobby, game);
    final gameTime = (game?['game_time'] as num?)?.toDouble();
    final userEvidence = _evidence(
      'voice_question',
      FactSource.user,
      now,
      gameTime,
    );

    if (_containsAny(normalized, const [
      'compro',
      'comprar',
      'compra',
      'build',
      'objeto',
      'item',
    ])) {
      return _buildAnswer(_map(context['builds']), userEvidence, now, gameTime);
    }

    if (_containsAny(normalized, const [
      'como voy',
      'estado',
      'marcador',
      'oro',
      'ventaja',
      'desventaja',
      'kda',
    ])) {
      return _gameStateAnswer(game, userEvidence, now, gameTime);
    }

    if (_containsAny(normalized, const [
      'mi linea',
      'la linea',
      'estado de linea',
      'estado del carril',
      'mi carril',
      'fase de lineas',
    ])) {
      return _laneStateAnswer(game, userEvidence, now, gameTime);
    }

    if (_containsAny(normalized, const [
      'matchup',
      'enfrentamiento',
      'contra quien',
      'mi rival',
      'rival de linea',
    ])) {
      return _matchupAnswer(context, userEvidence, now, gameTime);
    }

    if (_containsAny(normalized, const ['jungla', 'jungler'])) {
      final recent = [...sightings]
        ..sort((left, right) => right.observedAt.compareTo(left.observedAt));
      final sighting = recent.firstOrNull;
      if (sighting == null) {
        return TacticalAdvice(
          id: 'voice_jungler_unknown',
          title: 'Jungla sin localizar',
          hints: const [
            'Juega hacia tu visión disponible.',
            'No cruces el río sin prioridad.',
          ],
          rationale: 'No existe un avistamiento local fiable del jungla.',
          ttsText:
              'No tengo un avistamiento fiable del jungla. Juega con cautela.',
          priority: 85,
          evidence: [userEvidence],
        );
      }
      final age = now.difference(sighting.observedAt.toUtc());
      final seconds = age.isNegative ? 0 : age.inSeconds;
      final stale = seconds > 30;
      return TacticalAdvice(
        id: 'voice_jungler_location',
        title: stale ? 'Último avistamiento del jungla' : 'Jungla localizado',
        hints: [
          stale
              ? 'La posición ya es antigua; úsala sólo como contexto.'
              : 'Ajusta tu presión según el lado del mapa donde fue visto.',
        ],
        rationale:
            '${sighting.champion} fue observado en ${sighting.location} hace $seconds segundos.',
        ttsText:
            '${sighting.champion} fue visto en ${sighting.location} hace $seconds segundos${stale ? '. La información puede estar desactualizada.' : '.'}',
        priority: stale ? 70 : 95,
        evidence: [
          userEvidence,
          TacticalEvidence(
            factType: 'enemy_jungler_sighting',
            source: FactSource.vision,
            observedAt: sighting.observedAt,
            confidence: sighting.confidence.clamp(0, 1),
            gameTimeSeconds: gameTime,
          ),
        ],
      );
    }

    if (_containsAny(normalized, const [
      'dragon',
      'baron',
      'heraldo',
      'objetivo',
    ])) {
      return _objectiveAnswer(normalized, game, userEvidence, now, gameTime);
    }

    final current = directives(game);
    if (current.isEmpty) {
      return TacticalAdvice(
        id: 'voice_no_live_game',
        title: 'Sin partida activa',
        hints: const [
          'Inicia una partida para recibir contexto en tiempo real.',
        ],
        rationale: 'Live Client no aporta una partida activa.',
        ttsText: 'No tengo una partida activa para responder con contexto.',
        priority: 20,
        evidence: [userEvidence],
      );
    }
    return _withQuestionEvidence(current.first, userEvidence);
  }

  Map<String, dynamic> analyze({
    Map<String, dynamic>? lobby,
    Map<String, dynamic>? game,
    String? selectedEnemy,
  }) {
    final normalizedLobby = _coachingContext(lobby, game);
    final snapshot = _map(normalizedLobby['snapshot']);
    final allies = _mapList(snapshot['my_team']);
    final enemies = _mapList(snapshot['their_team']);
    final local = allies
        .where((player) => player['is_local'] == true)
        .firstOrNull;
    final localChampion = _champion(local);
    final opponent = enemies.any((enemy) => _champion(enemy) == selectedEnemy)
        ? selectedEnemy
        : _laneOpponent(local, enemies);
    final matchup = localChampion.isEmpty || opponent == null
        ? null
        : _matchup(localChampion, opponent);
    const composition = ChampionCompositionAnalyzer();
    final comp = composition.analyze(allies, enemies);
    final builds = _map(normalizedLobby['builds']);
    return {
      'matchup': ?matchup,
      if (builds.isNotEmpty) 'builds': builds,
      'team_comp': comp,
      'comp_analysis': {
        'ally': composition.profile(allies),
        'enemy': composition.profile(enemies),
      },
      'knowledge': {
        'producer': 'native-tactical-engine',
        'producer_version': '1',
        'builds_withheld': builds.isEmpty,
        'reason': builds.isEmpty
            ? 'Waiting for a patch-exact Riot champion build.'
            : 'Patch-exact Riot champion build loaded.',
      },
      if (game != null) 'live_context': {'phase': game['phase']},
    };
  }

  List<TacticalAdvice> directives(Map<String, dynamic>? game) {
    if (game == null || game['_game_ended'] == true) return const [];
    final now = _now().toUtc();
    final gameTime = (game['game_time'] as num?)?.toDouble();
    final active = _map(game['active_player']);
    final derived = _map(game['derived']);
    final objectiveAdvice = _objectiveDirective(
      _map(derived['objectives']),
      now,
      gameTime,
    );
    if (active['is_dead'] == true) {
      return [
        TacticalAdvice(
          id: 'death_reset',
          title: 'Planifica el siguiente reset',
          hints: const [
            'Revisa el temporizador del próximo objetivo.',
            'Decide la ruta antes de reaparecer.',
          ],
          rationale: 'Estás muerto; comprar y planificar no arriesga recursos.',
          ttsText: 'Mientras reapareces, compra y decide tu ruta al próximo objetivo.',
          priority: 100,
          evidence: [
            _evidence(
              'active_player_dead',
              FactSource.liveClient,
              now,
              gameTime,
            ),
          ],
        ),
      ];
    }
    if (objectiveAdvice != null) return [objectiveAdvice];

    final gold = (game['team_gold_diff'] as num?)?.toInt() ?? 0;
    if (gold <= -1000) {
      return [
        TacticalAdvice(
          id: 'recover_resources',
          title: 'Recupera recursos sin forzar',
          hints: const [
            'Recoge la oleada segura más cercana.',
            'Cede visión profunda si no tienes prioridad.',
          ],
          rationale: 'El equipo está por detrás en oro ($gold).',
          ttsText: 'Están por detrás. Recoge recursos seguros y evita pelear sin ventaja.',
          priority: 70,
          evidence: [
            _evidence('team_gold_deficit', FactSource.derived, now, gameTime),
          ],
        ),
      ];
    }
    if (gold >= 1000) {
      return [
        TacticalAdvice(
          id: 'convert_lead',
          title: 'Convierte la ventaja',
          hints: const [
            'Empuja antes de entrar al río.',
            'Invade sólo con líneas con prioridad.',
          ],
          rationale: 'El equipo tiene una ventaja de oro de $gold.',
          ttsText: 'Tienen ventaja. Empuja y conviértela en visión u objetivo.',
          priority: 60,
          evidence: [
            _evidence('team_gold_lead', FactSource.derived, now, gameTime),
          ],
        ),
      ];
    }
    return [
      TacticalAdvice(
        id: 'neutral_setup',
        title: 'Prepara la siguiente jugada',
        hints: const [
          'Empuja tu oleada antes de moverte.',
          'Comprueba posiciones enemigas en el minimapa.',
        ],
        rationale: 'La diferencia de oro está equilibrada ($gold).',
        ttsText:
            'La partida está pareja. Empuja primero y juega con información.',
        priority: 40,
        evidence: [
          _evidence('team_gold_even', FactSource.derived, now, gameTime),
        ],
      ),
    ];
  }

  TacticalQualityMetrics evaluate(List<TacticalAdvice> advice) {
    if (advice.isEmpty) {
      return const TacticalQualityMetrics(
        evidenceCoverage: 1,
        actionability: 1,
        temporalRelevance: 1,
        contradictionCount: 0,
      );
    }
    final withEvidence = advice
        .where((item) => item.evidence.isNotEmpty)
        .length;
    final actionable = advice
        .where((item) => item.hints.isNotEmpty && item.ttsText.isNotEmpty)
        .length;
    final relevant = advice.where((item) {
      return item.evidence.every((evidence) => evidence.confidence >= 0.5);
    }).length;
    final ids = <String>{};
    var contradictions = 0;
    for (final item in advice) {
      if (!ids.add(item.id)) contradictions++;
    }
    return TacticalQualityMetrics(
      evidenceCoverage: withEvidence / advice.length,
      actionability: actionable / advice.length,
      temporalRelevance: relevant / advice.length,
      contradictionCount: contradictions,
    );
  }

  TacticalAdvice _withQuestionEvidence(
    TacticalAdvice advice,
    TacticalEvidence question,
  ) => TacticalAdvice(
    id: 'voice_${advice.id}',
    title: advice.title,
    hints: advice.hints,
    rationale: advice.rationale,
    ttsText: advice.ttsText,
    priority: advice.priority,
    evidence: [question, ...advice.evidence],
  );

  TacticalAdvice _buildAnswer(
    Map<String, dynamic> builds,
    TacticalEvidence question,
    DateTime now,
    double? gameTime,
  ) {
    if (builds.isEmpty) {
      return TacticalAdvice(
        id: 'voice_build_unavailable',
        title: 'Build todavía no disponible',
        hints: const [
          'Espera a que GodSense confirme campeón, rol y parche.',
          'No se propondrán objetos inventados como sustituto.',
        ],
        rationale: 'No hay una recomendación Riot compatible cargada para este contexto.',
        ttsText: 'Todavía no tengo una build de Riot confirmada para tu campeón, rol y parche.',
        priority: 55,
        evidence: [question],
      );
    }
    final groups = _mapList(builds['items']);
    final start = groups.firstOrNull;
    final purchase = groups.skip(1).firstOrNull;
    final startNames = _itemNames(start);
    final purchaseNames = _itemNames(purchase);
    final patch = builds['patch']?.toString().trim();
    final position = builds['position']?.toString().trim();
    final parts = <String>[
      if (startNames.isNotEmpty) 'Empieza con ${_joinNames(startNames)}.',
      if (purchaseNames.isNotEmpty)
        'La siguiente compra recomendada incluye ${_joinNames(purchaseNames)}.',
    ];
    final context = [
      if (position != null && position.isNotEmpty) position,
      if (patch != null && patch.isNotEmpty) 'parche $patch',
    ].join(', ');
    return TacticalAdvice(
      id: 'voice_riot_build',
      title: 'Build oficial cargada',
      hints: parts.isEmpty
          ? const ['La build está cargada y disponible para importar.']
          : parts,
      rationale:
          'Recomendación extraída de los artefactos de Riot${context.isEmpty ? '' : ' para $context'}.',
      ttsText: parts.isEmpty
          ? 'La build de Riot está cargada y lista para importar.'
          : parts.join(' '),
      priority: 75,
      evidence: [
        question,
        _evidence(
          'riot_item_recommendation',
          FactSource.riotData,
          now,
          gameTime,
        ),
      ],
    );
  }

  TacticalAdvice _gameStateAnswer(
    Map<String, dynamic>? game,
    TacticalEvidence question,
    DateTime now,
    double? gameTime,
  ) {
    if (game == null || game['_game_ended'] == true) {
      return TacticalAdvice(
        id: 'voice_game_state_unavailable',
        title: 'Estado no disponible',
        hints: const ['Inicia una partida para medir el estado en vivo.'],
        rationale: 'Live Client no aporta una partida activa.',
        ttsText: 'No tengo una partida activa para medir cómo vas.',
        priority: 20,
        evidence: [question],
      );
    }
    final active = _map(game['active_player']);
    final kda =
        (active['kda'] as List?)
            ?.whereType<num>()
            .map((value) => value.toInt())
            .toList(growable: false) ??
        const <int>[];
    final cs = (active['cs'] as num?)?.toInt();
    final gold = (game['team_gold_diff'] as num?)?.toInt() ?? 0;
    final state = gold >= 1000
        ? 'Tu equipo lleva $gold de oro de ventaja.'
        : gold <= -1000
        ? 'Tu equipo lleva ${gold.abs()} de oro de desventaja.'
        : 'La diferencia de oro está equilibrada en $gold.';
    final personal = [
      if (kda.length >= 3) 'Tu K D A es ${kda[0]}, ${kda[1]}, ${kda[2]}.',
      if (cs != null) 'Tienes $cs súbditos.',
    ].join(' ');
    final next = directives(game).firstOrNull;
    return TacticalAdvice(
      id: 'voice_game_state',
      title: 'Estado medido de la partida',
      hints: [
        state,
        if (personal.isNotEmpty) personal,
        if (next != null) next.ttsText,
      ],
      rationale: 'Resumen calculado con el snapshot actual de Live Client y la diferencia de oro derivada.',
      ttsText: [
        state,
        personal,
        if (next != null) next.ttsText,
      ].where((part) => part.isNotEmpty).join(' '),
      priority: 80,
      evidence: [
        question,
        _evidence('live_player_state', FactSource.liveClient, now, gameTime),
        _evidence('team_gold_difference', FactSource.derived, now, gameTime),
      ],
    );
  }

  TacticalAdvice _matchupAnswer(
    Map<String, dynamic>? lobby,
    TacticalEvidence question,
    DateTime now,
    double? gameTime,
  ) {
    final snapshot = _map(lobby?['snapshot']);
    final allies = _mapList(snapshot['my_team']);
    final enemies = _mapList(snapshot['their_team']);
    final local = allies
        .where((player) => player['is_local'] == true)
        .firstOrNull;
    final champion = _champion(local);
    final enemy = _laneOpponent(local, enemies);
    if (champion.isEmpty || enemy == null) {
      return TacticalAdvice(
        id: 'voice_matchup_unavailable',
        title: 'Matchup sin confirmar',
        hints: const ['Espera a que ambos campeones estén confirmados.'],
        rationale: 'No hay un rival confirmado para el mismo rol.',
        ttsText: 'Todavía no tengo tu matchup confirmado.',
        priority: 45,
        evidence: [question],
      );
    }
    final matchup = _matchup(champion, enemy);
    final patterns =
        (matchup['trading_patterns'] as List?)?.whereType<String>().toList(
          growable: false,
        ) ??
        const <String>[];
    final winCondition = matchup['win_condition']?.toString() ?? '';
    return TacticalAdvice(
      id: 'voice_matchup_context',
      title: '$champion contra $enemy',
      hints: [...patterns, if (winCondition.isNotEmpty) winCondition],
      rationale: 'Regla general determinista; todavía no es conocimiento específico validado para esta pareja.',
      ttsText:
          '$champion contra $enemy. ${patterns.firstOrNull ?? winCondition}',
      priority: 60,
      evidence: [
        question,
        _evidence(
          lobby?['source'] == 'live_client'
              ? 'live_matchup'
              : 'champ_select_matchup',
          lobby?['source'] == 'live_client'
              ? FactSource.liveClient
              : FactSource.lcu,
          now,
          gameTime,
        ),
        TacticalEvidence(
          factType: 'general_matchup_rule',
          source: FactSource.derived,
          observedAt: now,
          confidence: 0.55,
          gameTimeSeconds: gameTime,
        ),
      ],
    );
  }

  TacticalAdvice _laneStateAnswer(
    Map<String, dynamic>? game,
    TacticalEvidence question,
    DateTime now,
    double? gameTime,
  ) {
    if (game == null || game['_game_ended'] == true) {
      return TacticalAdvice(
        id: 'voice_lane_state_unavailable',
        title: 'Estado de línea no disponible',
        hints: const ['Inicia una partida para medir el carril en vivo.'],
        rationale: 'Live Client no aporta una partida activa.',
        ttsText: 'No tengo una partida activa para medir tu línea.',
        priority: 20,
        evidence: [question],
      );
    }
    final active = _map(game['active_player']);
    final role = active['role']?.toString().toUpperCase() ?? '';
    final laneStates = _map(game['lane_states']);
    final lane = _map(laneStates[role]);
    if (role.isEmpty || lane.isEmpty) {
      return TacticalAdvice(
        id: 'voice_lane_state_unknown',
        title: 'Carril sin pareja comparable',
        hints: const [
          'Live Client todavía no identificó un rival del mismo rol.',
        ],
        rationale: 'No existe una pareja de rol comparable en el snapshot.',
        ttsText:
            'Todavía no puedo comparar tu línea con un rival del mismo rol.',
        priority: 40,
        evidence: [question],
      );
    }
    final state = lane['state']?.toString() ?? 'EVEN';
    final enemy = lane['enemy']?.toString().trim() ?? '';
    final (summary, action) = switch (state) {
      'AHEAD' => (
        'Tu línea está por delante${enemy.isEmpty ? '' : ' frente a $enemy'}.',
        'Presiona sólo después de localizar amenazas y convierte la ventaja.',
      ),
      'BEHIND' => (
        'Tu línea está por detrás${enemy.isEmpty ? '' : ' frente a $enemy'}.',
        'Prioriza experiencia y recursos seguros; no fuerces intercambios largos.',
      ),
      _ => (
        'Tu línea está equilibrada${enemy.isEmpty ? '' : ' frente a $enemy'}.',
        'Gana prioridad antes de abandonar el carril.',
      ),
    };
    return TacticalAdvice(
      id: 'voice_lane_state',
      title: 'Estado comparado del carril',
      hints: [summary, action],
      rationale: 'Comparación heurística de nivel, súbditos, KDA y recursos observables; no es una diferencia de oro exacta.',
      ttsText: '$summary $action',
      priority: 70,
      evidence: [
        question,
        TacticalEvidence(
          factType: 'lane_state_estimate',
          source: FactSource.derived,
          observedAt: now,
          confidence: 0.75,
          gameTimeSeconds: gameTime,
        ),
      ],
    );
  }

  TacticalAdvice _objectiveAnswer(
    String normalizedQuestion,
    Map<String, dynamic>? game,
    TacticalEvidence question,
    DateTime now,
    double? gameTime,
  ) {
    if (game == null || game['_game_ended'] == true) {
      return TacticalAdvice(
        id: 'voice_objective_unavailable',
        title: 'Objetivos no disponibles',
        hints: const ['Inicia una partida para leer temporizadores en vivo.'],
        rationale: 'Live Client no aporta una partida activa.',
        ttsText: 'No tengo una partida activa para consultar objetivos.',
        priority: 20,
        evidence: [question],
      );
    }
    final objectives = _map(_map(game['derived'])['objectives']);
    final requested = _requestedObjectiveKey(normalizedQuestion);
    MapEntry<String, dynamic>? selected;
    if (requested != null && objectives.containsKey(requested)) {
      selected = MapEntry(requested, objectives[requested]);
    } else {
      final candidates = objectives.entries.where((entry) {
        final value = _map(entry.value);
        return value['status'] == 'alive' || value['respawn_in'] is num;
      }).toList();
      candidates.sort((left, right) {
        final leftState = _map(left.value);
        final rightState = _map(right.value);
        final leftTime = leftState['status'] == 'alive'
            ? 0.0
            : (leftState['respawn_in'] as num?)?.toDouble() ?? double.infinity;
        final rightTime = rightState['status'] == 'alive'
            ? 0.0
            : (rightState['respawn_in'] as num?)?.toDouble() ?? double.infinity;
        return leftTime.compareTo(rightTime);
      });
      selected = candidates.firstOrNull;
    }
    if (selected == null) {
      return TacticalAdvice(
        id: 'voice_objective_unknown',
        title: 'Objetivo sin estado confirmado',
        hints: const ['Mantén visión y prioridad antes de moverte.'],
        rationale: 'No existe un estado de objetivo utilizable en el snapshot.',
        ttsText: 'No tengo un estado de objetivo confirmado.',
        priority: 50,
        evidence: [question],
      );
    }
    final key = selected.key;
    final value = _map(selected.value);
    final label = _objectiveLabel(key);
    final status = value['status']?.toString() ?? '';
    final seconds = (value['respawn_in'] as num?)?.toDouble().round();
    if (status == 'alive') {
      return TacticalAdvice(
        id: 'voice_${key}_alive',
        title: '$label disponible',
        hints: const [
          'Comprueba prioridad y posiciones antes de iniciarlo.',
          'Controla visión de los accesos y la entrada del jungla rival.',
        ],
        rationale: '$label está vivo según el estado derivado de Live Client.',
        ttsText:
            '$label está disponible ahora. Comprueba prioridad y posiciones antes de iniciarlo.',
        priority: 90,
        evidence: [
          question,
          _evidence('${key}_alive', FactSource.derived, now, gameTime),
        ],
      );
    }
    if (seconds != null) {
      return TacticalAdvice(
        id: 'voice_${key}_timer',
        title: 'Temporizador de $label',
        hints: [
          if (seconds <= 75)
            'Empuja y prepara visión antes de que aparezca.'
          else
            'Aún hay tiempo para recoger recursos sin abandonar el plan.',
        ],
        rationale: '$label estará disponible en $seconds segundos.',
        ttsText:
            '$label estará disponible en $seconds segundos.${seconds <= 75 ? ' Empuja y prepara visión.' : ''}',
        priority: seconds <= 75 ? 90 : 60,
        evidence: [
          question,
          _evidence('${key}_timer', FactSource.derived, now, gameTime),
        ],
      );
    }
    return TacticalAdvice(
      id: 'voice_${key}_unavailable',
      title: '$label no disponible',
      hints: const ['Reorienta el plan al siguiente objetivo disponible.'],
      rationale: '$label no volverá a aparecer en esta partida.',
      ttsText: '$label ya no está disponible en esta partida.',
      priority: 45,
      evidence: [
        question,
        _evidence('${key}_unavailable', FactSource.derived, now, gameTime),
      ],
    );
  }

  TacticalAdvice? _objectiveDirective(
    Map<String, dynamic> objectives,
    DateTime now,
    double? gameTime,
  ) {
    final candidates = <(String, double)>[];
    for (final entry in objectives.entries) {
      final value = _map(entry.value);
      final seconds = (value['respawn_in'] as num?)?.toDouble();
      if (seconds != null && seconds > 0 && seconds <= 75) {
        candidates.add((entry.key, seconds));
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.$2.compareTo(b.$2));
    final target = candidates.first;
    final label = _objectiveLabel(target.$1);
    final seconds = target.$2.round();
    return TacticalAdvice(
      id: 'prepare_${target.$1}',
      title: 'Prepara $label',
      hints: [
        'Empuja la línea antes de moverte.',
        'Limpia y coloca visión en los accesos.',
      ],
      rationale: '$label estará disponible en $seconds segundos.',
      ttsText: '$label en $seconds segundos. Empuja y prepara visión.',
      priority: 90,
      evidence: [
        _evidence('${target.$1}_timer', FactSource.derived, now, gameTime),
      ],
    );
  }
}

List<String> _itemNames(Map<String, dynamic>? group) =>
    _mapList(group?['items'])
        .map((item) => item['name']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .take(4)
        .toList(growable: false);

String _joinNames(List<String> names) => switch (names) {
  [] => '',
  [final only] => only,
  _ => '${names.sublist(0, names.length - 1).join(', ')} y ${names.last}',
};

bool _containsAny(String value, List<String> terms) =>
    terms.any(value.contains);

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàäâ]'), 'a')
    .replaceAll(RegExp('[éèëê]'), 'e')
    .replaceAll(RegExp('[íìïî]'), 'i')
    .replaceAll(RegExp('[óòöô]'), 'o')
    .replaceAll(RegExp('[úùüû]'), 'u');

TacticalEvidence _evidence(
  String fact,
  FactSource source,
  DateTime observedAt,
  double? gameTime,
) => TacticalEvidence(
  factType: fact,
  source: source,
  observedAt: observedAt,
  confidence: 1,
  gameTimeSeconds: gameTime,
);

Map<String, dynamic> _matchup(String champion, String enemy) => {
  'trading_patterns': [
    'Busca intercambios después de que $enemy gaste su habilidad principal.',
    'Conserva una salida hasta localizar al jungla enemigo.',
  ],
  'power_spikes': ['Nivel 6 de $champion.', 'Primer objeto completo.'],
  'win_condition':
      'Controla la oleada y fuerza acciones sólo con información del jungla.',
  'avoid': [
    'Intercambiar dentro de una oleada enemiga grande.',
    'Entrar al río sin prioridad ni visión.',
  ],
  'matchup_intel_n': 0,
  'confidence': 0.55,
  'source': 'deterministic_general_rule',
};

String _champion(Map<String, dynamic>? player) =>
    player?['champion_name']?.toString().trim() ?? '';

Map<String, dynamic> _coachingContext(
  Map<String, dynamic>? lobby,
  Map<String, dynamic>? game,
) {
  if (game == null || game['_game_ended'] == true) return lobby ?? const {};
  final active = _map(game['active_player']);
  return {
    'source': 'live_client',
    'builds': game['builds'],
    'snapshot': {
      'my_team': [
        for (final player in _mapList(game['allies']))
          {
            ...player,
            'position': player['role'],
            'is_local':
                player['summoner_name'] == active['summoner_name'] &&
                player['tag_line'] == active['tag_line'],
          },
      ],
      'their_team': [
        for (final player in _mapList(game['enemies']))
          {...player, 'position': player['role']},
      ],
    },
  };
}

String? _laneOpponent(
  Map<String, dynamic>? local,
  List<Map<String, dynamic>> enemies,
) {
  final role = local?['position']?.toString().toUpperCase() ?? '';
  if (role.isEmpty || role == 'UNKNOWN') return null;
  return enemies
      .where((enemy) => enemy['position']?.toString().toUpperCase() == role)
      .map(_champion)
      .where((name) => name.isNotEmpty)
      .firstOrNull;
}

String _objectiveLabel(String key) => switch (key) {
  'dragon' => 'dragón',
  'baron' => 'Barón',
  'herald' => 'Heraldo',
  'void_grubs' => 'larvas del Vacío',
  _ => key,
};

String? _requestedObjectiveKey(String question) {
  if (question.contains('dragon')) return 'dragon';
  if (question.contains('baron')) return 'baron';
  if (question.contains('heraldo')) return 'herald';
  if (question.contains('larva') ||
      question.contains('vacío') ||
      question.contains('vacio')) {
    return 'void_grubs';
  }
  return null;
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : const {};

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false)
    : const [];
