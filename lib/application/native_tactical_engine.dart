import '../domain/tactical/tactical_models.dart';
import 'champion_composition_analyzer.dart';

class NativeTacticalEngine {
  NativeTacticalEngine({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<String, ({double deadline, String label})> _voiceTimers = {};
  String? _timerSession;
  double? _timerGameTime;

  void _synchronizeTimerSession(Map<String, dynamic>? game) {
    final time = (game?['game_time'] as num?)?.toDouble();
    final session = game?['session_id']?.toString();
    if (game == null ||
        game['_game_ended'] == true ||
        session != _timerSession ||
        (time != null && _timerGameTime != null && time < _timerGameTime!)) {
      _voiceTimers.clear();
    }
    _timerSession = session;
    _timerGameTime = time;
  }

  List<String> takeTimerReminders(Map<String, dynamic>? game) {
    _synchronizeTimerSession(game);
    final time = _timerGameTime;
    if (time == null) return const [];
    final due = _voiceTimers.entries
        .where((e) => e.value.deadline - time <= 30)
        .toList();
    final reminders = <String>[];
    for (final entry in due) {
      _voiceTimers.remove(entry.key);
      final remaining = (entry.value.deadline - time).round();
      if (remaining >= 0) {
        reminders.add(
          '${entry.value.label}: $remaining segundos, según tu marca.',
        );
      }
    }
    return reminders;
  }

  /// Whether this engine can answer the question from verified local data.
  /// Unknown intents can be delegated to the configured AI coach, while known
  /// intents stay fast, deterministic and available offline.
  bool supportsQuestion(String question) {
    final normalized = _normalize(question);
    return _containsAny(normalized, const [
      'que hago ahora',
      'consejo ahora',
      'que deberia hacer',
      'compro',
      'comprar',
      'compra',
      'build',
      'objeto',
      'item',
      'penetracion',
      'como voy',
      'estado',
      'marcador',
      'oro',
      'ventaja',
      'desventaja',
      'kda',
      'mi linea',
      'la linea',
      'estado de linea',
      'estado del carril',
      'mi carril',
      'fase de lineas',
      'matchup',
      'enfrentamiento',
      'contra quien',
      'mi rival',
      'rival de linea',
      'all in',
      'intercambio',
      'trade',
      'jungla',
      'jungler',
      'invade',
      'invadir',
      'invasion',
      'dragon',
      'baron',
      'heraldo',
      'objetivo',
      'flash',
      'destello',
      'hechizo de invocador',
      'hechizos de invocador',
      'larva',
      'vacio',
      'teleport',
      'smite',
    ]);
  }

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
    if (_containsAny(normalized, const [
      'flash',
      'destello',
      'teleport',
      'smite',
    ])) {
      final timestamp = RegExp(r'\b(\d{1,3}):([0-5]\d)\b').firstMatch(question);
      if (timestamp != null &&
          gameTime != null &&
          game?['_game_ended'] != true) {
        final deadline =
            int.parse(timestamp[1]!) * 60 + int.parse(timestamp[2]!);
        final label = question
            .substring(0, timestamp.start)
            .replaceAll(RegExp(r'[¿?]'), '')
            .trim();
        if (label.isNotEmpty && deadline > gameTime) {
          _synchronizeTimerSession(game);
          _voiceTimers[_normalize(label)] = (
            deadline: deadline.toDouble(),
            label: label,
          );
          return TacticalAdvice(
            id: 'voice_timer_recorded',
            title: 'Temporizador registrado',
            hints: ['Aviso hasta 30 segundos antes de ${timestamp[0]}.'],
            rationale:
                'Hora indicada por el usuario; no verificada por Live Client.',
            ttsText: '$label registrado para ${timestamp[0]}.',
            priority: 70,
            evidence: [
              _evidence(
                'user_cooldown_deadline',
                FactSource.user,
                now,
                gameTime,
              ),
            ],
          );
        }
      }
      if (normalized.contains('sin flash') ||
          normalized.contains('sin destello')) {
        return TacticalAdvice(
          id: 'voice_timer_needs_deadline',
          title: 'Indica cuándo vuelve',
          hints: const ['Ejemplo: Flash Viktor 18:20.'],
          rationale: 'Los modificadores de enfriamiento no están confirmados.',
          ttsText: 'Indica la hora: Flash Viktor, dieciocho veinte.',
          priority: 60,
          evidence: [
            _evidence('voice_question', FactSource.user, now, gameTime),
          ],
        );
      }
    }
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
      'penetracion',
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
      'all in',
      'intercambio',
      'trade',
    ])) {
      return _matchupAnswer(context, userEvidence, now, gameTime);
    }

    if (_containsAny(normalized, const [
      'jungla',
      'jungler',
      'invade',
      'invadir',
      'invasion',
    ])) {
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
      'larva',
      'vacio',
    ])) {
      return _objectiveAnswer(normalized, game, userEvidence, now, gameTime);
    }

    if (_containsAny(normalized, const [
      'flash',
      'destello',
      'hechizo de invocador',
      'hechizos de invocador',
      'teleport',
      'smite',
    ])) {
      return _summonerSpellAnswer(
        game,
        userEvidence,
        now,
        gameTime,
        normalized,
      );
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
    final opponent = selectedEnemy == null
        ? _laneOpponentPlayer(local, enemies)
        : enemies
              .where((enemy) => _champion(enemy) == selectedEnemy)
              .firstOrNull;
    final matchup = localChampion.isEmpty || opponent == null
        ? null
        : _matchup(local!, opponent);
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
    final numericalAdvice = _numericalAdvantageDirective(game, now, gameTime);
    if (numericalAdvice?.id == 'avoid_outnumbered_fight') {
      return [numericalAdvice!];
    }
    final health = (active['health_ratio'] as num?)?.toDouble();
    if (health != null && health <= .2) {
      return [
        TacticalAdvice(
          id: 'recover_health',
          title: 'Recupera vida antes de pelear',
          hints: const [
            'Busca una retirada segura antes de disputar objetivos.',
          ],
          rationale: 'Vida local observada por debajo del 20%.',
          ttsText: 'Vida crítica. Retírate y recupera.',
          priority: 96,
          evidence: [
            _evidence('local_health', FactSource.liveClient, now, gameTime),
          ],
        ),
      ];
    }
    final cash = (active['gold_current'] as num?)?.toInt() ?? 0;
    if (cash >= 1500 && objectiveAdvice != null) {
      return [
        TacticalAdvice(
          id: 'spend_before_objective',
          title: 'Convierte tu oro antes del objetivo',
          hints: const [
            'Compra si puedes regresar a tiempo; evita un regreso a base tardío.',
          ],
          rationale:
              'Tienes $cash de oro disponible. No conocemos el bolsillo del equipo.',
          ttsText: 'Tienes oro sin gastar. Compra si llegas a tiempo.',
          priority: 91,
          evidence: [
            _evidence(
              'local_current_gold',
              FactSource.liveClient,
              now,
              gameTime,
            ),
          ],
        ),
      ];
    }
    if (objectiveAdvice != null) return [objectiveAdvice];
    if (numericalAdvice != null) return [numericalAdvice];

    final gold = (game['team_gold_diff'] as num?)?.toInt() ?? 0;
    final threshold =
        (game['team_state_threshold'] as num?)?.toInt().abs() ?? 1000;
    final relativeGold = _relativeGoldDifference(game, gold);
    if (gold <= -threshold) {
      return [
        TacticalAdvice(
          id: 'recover_resources',
          title: 'Recupera recursos sin forzar',
          hints: const [
            'Recoge la oleada segura más cercana.',
            'Cede visión profunda si no tienes prioridad.',
          ],
          rationale:
              'El equipo está por detrás en oro ($gold; ${relativeGold.abs().toStringAsFixed(1)}% respecto al oro rival). El umbral dinámico actual es $threshold.',
          ttsText: 'Están por detrás. Recoge recursos seguros y evita pelear sin ventaja.',
          priority: 70,
          evidence: [
            _evidence('team_gold_deficit', FactSource.derived, now, gameTime),
          ],
        ),
      ];
    }
    if (gold >= threshold) {
      return [
        TacticalAdvice(
          id: 'convert_lead',
          title: 'Convierte la ventaja',
          hints: const [
            'Empuja antes de entrar al río.',
            'Invade sólo con líneas con prioridad.',
          ],
          rationale:
              'El equipo tiene una ventaja de oro de $gold (${relativeGold.toStringAsFixed(1)}% respecto al oro rival). El umbral dinámico actual es $threshold.',
          ttsText: 'Tienen ventaja. Empuja y conviértela en visión u objetivo.',
          priority: 60,
          evidence: [
            _evidence('team_gold_lead', FactSource.derived, now, gameTime),
          ],
        ),
      ];
    }
    final scalingAdvice = _compositionScalingDirective(game, now, gameTime);
    if (scalingAdvice != null) return [scalingAdvice];
    return [
      TacticalAdvice(
        id: 'neutral_setup',
        title: 'Prepara la siguiente jugada',
        hints: const [
          'Empuja tu oleada antes de moverte.',
          'Comprueba posiciones enemigas en el minimapa.',
        ],
        rationale:
            'La diferencia de oro está dentro del umbral dinámico ±$threshold ($gold).',
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
    final enemyPlayer = _laneOpponentPlayer(local, enemies);
    final enemy = _champion(enemyPlayer);
    if (champion.isEmpty || enemyPlayer == null || enemy.isEmpty) {
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
    final matchup = _matchup(local!, enemyPlayer);
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
      rationale: matchup['rationale']?.toString() ?? 'Regla general determinista; no hay semántica específica disponible para esta pareja.',
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
          factType: matchup['source']?.toString() ?? 'general_matchup_rule',
          source: FactSource.derived,
          observedAt: now,
          confidence: (matchup['confidence'] as num?)?.toDouble() ?? 0.55,
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
      'VULNERABLE' => (
        'Tu estado actual es vulnerable${enemy.isEmpty ? '' : ' frente a $enemy'}.',
        'Conserva vida, evita el intercambio y busca una ventana segura para reiniciar.',
      ),
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
        ttsText: '$label disponible ahora. Comprueba prioridad.',
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
        ttsText: '$label estará disponible en $seconds segundos.',
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

  TacticalAdvice _summonerSpellAnswer(
    Map<String, dynamic>? game,
    TacticalEvidence question,
    DateTime now,
    double? gameTime,
    String questionText,
  ) {
    if (game == null || game['_game_ended'] == true) {
      return TacticalAdvice(
        id: 'voice_summoner_spells_unavailable',
        title: 'Hechizos no disponibles',
        hints: const ['Inicia una partida para leer los hechizos equipados.'],
        rationale: 'Live Client no aporta una partida activa.',
        ttsText: 'No tengo una partida activa para consultar los hechizos.',
        priority: 20,
        evidence: [question],
      );
    }
    final spellLabel = questionText.contains('teleport')
        ? 'Teleportación'
        : questionText.contains('smite')
        ? 'Aplastar'
        : 'Destello';
    final terms = questionText.contains('teleport')
        ? const ['teleport', 'teleportacion']
        : questionText.contains('smite')
        ? const ['smite', 'aplastar']
        : const ['flash', 'destello'];
    final enemies = _mapList(game['enemies']);
    final withFlash = enemies
        .where((player) {
          final spells =
              (player['summoner_spells'] as List?)?.map(
                (spell) => _normalize(spell.toString()),
              ) ??
              const Iterable<String>.empty();
          return spells.any((spell) => terms.any(spell.contains));
        })
        .toList(growable: false);
    final champions = withFlash
        .map(_champion)
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final summary = champions.isEmpty
        ? 'No veo $spellLabel entre los hechizos enemigos cargados.'
        : 'Llevan $spellLabel: ${_joinNames(champions)}.';
    return TacticalAdvice(
      id: 'voice_summoner_spells',
      title: 'Hechizos enemigos observados',
      hints: [
        summary,
        'GodSense conoce la selección, pero no confirma todavía si el hechizo está disponible o en enfriamiento.',
      ],
      rationale: 'Los nombres proceden del snapshot de Live Client; esa fuente no expone el cooldown actual del hechizo enemigo.',
      ttsText:
          '$summary No puedo confirmar todavía si está disponible o en enfriamiento.',
      priority: 65,
      evidence: [
        question,
        _evidence(
          'enemy_summoner_spell_selection',
          FactSource.liveClient,
          now,
          gameTime,
        ),
      ],
    );
  }

  TacticalAdvice? _numericalAdvantageDirective(
    Map<String, dynamic> game,
    DateTime now,
    double? gameTime,
  ) {
    final allies = _mapList(game['allies']);
    final enemies = _mapList(game['enemies']);
    if (allies.length < 3 || enemies.length < 3) return null;
    final alliesAlive = allies.where((player) => player['is_dead'] != true);
    final enemiesAlive = enemies.where((player) => player['is_dead'] != true);
    final difference = alliesAlive.length - enemiesAlive.length;
    if (difference == 0) return null;

    final deadEnemies = enemies.where((player) => player['is_dead'] == true);
    final deadAllies = allies.where((player) => player['is_dead'] == true);
    final window = difference > 0
        ? _shortestRespawn(deadEnemies)
        : _shortestRespawn(deadAllies);
    final windowLabel = window == null ? '' : ' durante unos $window segundos';
    if (difference < 0) {
      return TacticalAdvice(
        id: 'avoid_outnumbered_fight',
        title: '${alliesAlive.length} vs ${enemiesAlive.length}: no fuerces',
        hints: const [
          'Limpia la oleada desde una posición segura.',
          'Espera reapariciones antes de disputar río o estructuras.',
        ],
        rationale:
            'El equipo está en desventaja numérica observable$windowLabel.',
        ttsText:
            'Están ${alliesAlive.length} contra ${enemiesAlive.length}. No pelees hasta recuperar jugadores.',
        priority: 92,
        evidence: [
          _evidence(
            'live_number_disadvantage',
            FactSource.liveClient,
            now,
            gameTime,
          ),
        ],
      );
    }

    final objectives = _map(_map(game['derived'])['objectives']);
    final alliedJunglerAlive = alliesAlive.any(
      (player) => player['role']?.toString().toUpperCase() == 'JUNGLE',
    );
    final target = alliedJunglerAlive
        ? _availablePowerPlayObjective(objectives, gameTime ?? 0)
        : null;
    final action = target == null
        ? 'Empuja una línea y convierte la ventaja en estructura o visión profunda.'
        : 'Evalúa ${_objectiveLabel(target)} con prioridad, recursos y control de accesos.';
    return TacticalAdvice(
      id: 'convert_number_advantage',
      title:
          '${alliesAlive.length} vs ${enemiesAlive.length}: ventana de poder',
      hints: [action, 'No persigas bajas fuera del tiempo de reaparición.'],
      rationale:
          'El equipo tiene superioridad numérica observable$windowLabel${alliedJunglerAlive ? '' : '; el jungla aliado no está disponible para asegurar un objetivo neutral'}.',
      ttsText:
          'Están ${alliesAlive.length} contra ${enemiesAlive.length}$windowLabel. $action',
      priority: 94,
      evidence: [
        _evidence(
          'live_number_advantage',
          FactSource.liveClient,
          now,
          gameTime,
        ),
      ],
    );
  }

  TacticalAdvice? _compositionScalingDirective(
    Map<String, dynamic> game,
    DateTime now,
    double? gameTime,
  ) {
    if ((gameTime ?? 0) < 1200) return null;
    final allyCurve = _teamPowerCurve(_mapList(game['allies']));
    final enemyCurve = _teamPowerCurve(_mapList(game['enemies']));
    if (allyCurve == null || enemyCurve == null) return null;
    final difference = allyCurve - enemyCurve;
    if (difference.abs() < 0.45) return null;
    final alliesScaleLater = difference > 0;
    return TacticalAdvice(
      id: alliesScaleLater ? 'protect_scaling_window' : 'force_before_falloff',
      title: alliesScaleLater
          ? 'Tu composición escala mejor'
          : 'Tu ventana de composición se reduce',
      hints: alliesScaleLater
          ? const [
              'Evita una pelea pareja sin objetivo que la justifique.',
              'Conserva recursos y obliga al rival a entrar en tu preparación.',
            ]
          : const [
              'Crea prioridad y fuerza una jugada con información antes del siguiente escalado rival.',
              'No intercambies tiempo sin obtener estructura, visión u objetivo.',
            ],
      rationale: 'La partida está igualada después del minuto 20 y al menos tres perfiles confirmados por equipo muestran curvas diferentes.',
      ttsText: alliesScaleLater
          ? 'Tu composición escala mejor. Evita regalar una pelea pareja y conserva recursos.'
          : 'La composición rival escala mejor. Convierte prioridad pronto sin forzar a ciegas.',
      priority: 65,
      evidence: [
        _evidence(
          'confirmed_team_power_curves',
          FactSource.derived,
          now,
          gameTime,
        ),
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

double _relativeGoldDifference(Map<String, dynamic> game, int difference) {
  final enemyGold = _mapList(game['enemies']).fold<int>(
    0,
    (total, player) => total + ((player['gold_total'] as num?)?.toInt() ?? 0),
  );
  return enemyGold <= 0 ? 0 : difference / enemyGold * 100;
}

double? _teamPowerCurve(List<Map<String, dynamic>> players) {
  final values = players
      .map((player) => _knownPowerCurve(_map(player['champion_profile'])))
      .whereType<String>()
      .map(
        (curve) => switch (curve) {
          'early' => -1.0,
          'late' => 1.0,
          _ => 0.0,
        },
      )
      .toList(growable: false);
  if (values.length < 3) return null;
  return values.fold<double>(0, (sum, value) => sum + value) / values.length;
}

int? _shortestRespawn(Iterable<Map<String, dynamic>> players) {
  final timers =
      players
          .map((player) => (player['respawn_timer'] as num?)?.round())
          .whereType<int>()
          .where((seconds) => seconds > 0)
          .toList()
        ..sort();
  return timers.firstOrNull;
}

String? _availablePowerPlayObjective(
  Map<String, dynamic> objectives,
  double gameTime,
) {
  bool alive(String key) => _map(objectives[key])['status'] == 'alive';
  final dragon = _map(objectives['dragon']);
  if (alive('dragon') &&
      (dragon['soul_point'] == true || dragon['elder_expected'] == true)) {
    return 'dragon';
  }
  if (gameTime >= 1200 && alive('baron')) return 'baron';
  if (alive('dragon')) return 'dragon';
  if (alive('herald')) return 'herald';
  if (alive('void_grubs')) return 'void_grubs';
  return null;
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
    .replaceAll(RegExp('[úùüû]'), 'u')
    .replaceAll(RegExp(r'[^a-z0-9ñ]+'), ' ')
    .replaceAll(RegExp(r'\b(nash|nashor)\b'), 'baron')
    .replaceAll(RegExp(r'\b(drake|draco)\b'), 'dragon')
    .replaceAll(RegExp(r'\bgrubs\b'), 'larvas')
    .replaceAll(RegExp(r'\btp\b'), 'teleport')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

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

Map<String, dynamic> _matchup(
  Map<String, dynamic> local,
  Map<String, dynamic> opponent,
) {
  final champion = _champion(local);
  final enemy = _champion(opponent);
  final localProfile = _map(local['champion_profile']);
  final enemyProfile = _map(opponent['champion_profile']);
  final localStyle = _map(localProfile['playstyle']);
  final enemyStyle = _map(enemyProfile['playstyle']);
  final localTactical = _map(localProfile['tactical']);
  final enemyTactical = _map(enemyProfile['tactical']);
  final localRange = _attackRange(localProfile);
  final enemyRange = _attackRange(enemyProfile);
  final localRangeClass = _rangeClass(localRange);
  final enemyRangeClass = _rangeClass(enemyRange);
  final directEnemyAbilities = _mapList(opponent['abilities']);
  final enemyAbilities =
      (directEnemyAbilities.isNotEmpty
              ? directEnemyAbilities
              : _mapList(enemyProfile['abilities']))
          .where((ability) => ability['slot'] != 'P')
          .toList(growable: false);
  final enemyBasicAbilities = enemyAbilities
      .where((ability) => ability['slot'] != 'R')
      .toList(growable: false);
  final enemyCommitment =
      enemyBasicAbilities
          .where(
            (ability) =>
                ability['matchup_threat'] == true ||
                (ability['matchup_priority'] as num? ?? 0) > 0,
          )
          .toList()
        ..sort(
          (left, right) => (right['matchup_priority'] as num? ?? 0).compareTo(
            left['matchup_priority'] as num? ?? 0,
          ),
        );
  final commitmentName = enemyCommitment.firstOrNull?['name']
      ?.toString()
      .trim();

  final tradingPatterns = <String>[];
  if (localRangeClass == 'melee' && enemyRangeClass == 'ranged') {
    tradingPatterns.add(
      'Cede súbditos antes que vida, deja que la oleada se acerque y entra sólo cuando $enemy pierda espacio o una habilidad clave.',
    );
  } else if (localRangeClass == 'ranged' && enemyRangeClass == 'melee') {
    tradingPatterns.add(
      'Usa tu rango para castigar súbditos sin romper la distancia de seguridad frente a $enemy.',
    );
  }
  if (commitmentName != null && commitmentName.isNotEmpty) {
    tradingPatterns.add(
      'La ventana teórica más amplia aparece después de que $enemy use $commitmentName; GodSense no confirma aún el lanzamiento ni su cooldown actual.',
    );
  }
  if (_axis(enemyStyle, 'crowdControl') >= 2) {
    tradingPatterns.add(
      'Conserva tu movilidad hasta ver el control principal de $enemy.',
    );
  } else if (_axis(localStyle, 'mobility') >= 2) {
    tradingPatterns.add(
      'Usa tu movilidad para intercambiar sin perder la ruta de salida.',
    );
  }
  if (_axis(enemyStyle, 'durability') >= 2) {
    tradingPatterns.add(
      '$enemy tiene resistencia alta: no elijas intercambio corto o extendido sólo por esa etiqueta; confirma escudos, sustain y recursos antes de entrar.',
    );
  }
  if (tradingPatterns.isEmpty) {
    tradingPatterns.add(
      'Busca intercambios después de que $enemy comprometa una habilidad básica.',
    );
  }
  tradingPatterns.add('Conserva una salida hasta localizar al jungla enemigo.');

  final ultimate = enemyAbilities
      .where((ability) => ability['slot'] == 'R')
      .firstOrNull;
  final ultimateName = ultimate?['name']?.toString().trim();
  final powerSpikes = <String>[
    if (localRangeClass == 'melee' && enemyRangeClass == 'ranged')
      'Niveles 2-3: evalúa la entrada sólo después de conservar vida y acercar la oleada; no se conoce la XP exacta del próximo súbdito.'
    else if (localRangeClass == 'ranged' && enemyRangeClass == 'melee')
      'Niveles 2-3: protege la distancia mientras disputas la prioridad de oleada; no se conoce la XP exacta del próximo súbdito.',
    if (ultimateName != null && ultimateName.isNotEmpty)
      'Respeta $ultimateName de $enemy cuando su definitiva esté disponible.'
    else
      'Confirma visualmente cuándo la definitiva de $enemy esté disponible.',
    'Primer objeto completo.',
  ];

  final enemyDamageType = enemyTactical['damageType']?.toString().trim();
  final localClasses = _stringList(localProfile['classes']);
  final enemyClasses = _stringList(enemyProfile['classes']);
  final knownInputs = <Object?>[
    if (localStyle.isNotEmpty) localStyle,
    if (enemyStyle.isNotEmpty) enemyStyle,
    if (localClasses.isNotEmpty) localClasses,
    if (enemyClasses.isNotEmpty) enemyClasses,
    if (localTactical.isNotEmpty) localTactical,
    if (enemyTactical.isNotEmpty) enemyTactical,
    ...enemyAbilities,
  ].length;
  final hasSemantics = knownInputs > 0;
  final confidence =
      (0.55 +
              (localProfile.isNotEmpty ? 0.08 : 0) +
              (enemyProfile.isNotEmpty ? 0.12 : 0) +
              (enemyAbilities.isNotEmpty ? 0.1 : 0))
          .clamp(0.55, 0.85);
  final profileSummary = [
    if (enemyDamageType != null && enemyDamageType.isNotEmpty)
      'daño $enemyDamageType',
    if (enemyClasses.isNotEmpty) enemyClasses.join('/'),
  ].join(' · ');
  final localPowerCurve = _knownPowerCurve(localProfile);
  final enemyPowerCurve = _knownPowerCurve(enemyProfile);
  final winCondition = _matchupWinCondition(
    champion: champion,
    enemy: enemy,
    localRangeClass: localRangeClass,
    enemyRangeClass: enemyRangeClass,
    localPowerCurve: localPowerCurve,
    enemyPowerCurve: enemyPowerCurve,
  );

  return {
    'trading_patterns': tradingPatterns,
    'power_spikes': powerSpikes,
    'win_condition': winCondition,
    'range_context': {
      'local': localRange,
      'enemy': enemyRange,
      'local_class': localRangeClass,
      'enemy_class': enemyRangeClass,
      'source': localRange != null || enemyRange != null
          ? 'lcu_champion_data'
          : 'unknown',
    },
    'scaling_context': {
      'local': localPowerCurve,
      'enemy': enemyPowerCurve,
      'source': localPowerCurve != null || enemyPowerCurve != null
          ? 'lcu_champion_data'
          : 'unknown',
    },
    'ability_context': {
      'known_basic_abilities': enemyBasicAbilities
          .map((ability) => ability['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList(growable: false),
      'classified_matchup_threat': commitmentName,
      'selection_basis': commitmentName == null
          ? 'unclassified; no ability is guessed from cooldown alone'
          : 'explicit_matchup_metadata',
    },
    'avoid': [
      'Intercambiar dentro de una oleada enemiga grande.',
      'Entrar al río sin prioridad ni visión.',
    ],
    'matchup_intel_n': knownInputs,
    'confidence': confidence,
    'source': hasSemantics
        ? 'riot_champion_semantics'
        : 'deterministic_general_rule',
    'rationale': hasSemantics
        ? 'Consejo derivado de atributos oficiales de $champion y $enemy${profileSummary.isEmpty ? '' : ' ($profileSummary)'}; no afirma estadísticas históricas de la pareja ni detecta lanzamientos de habilidades.'
        : 'Regla general determinista; no hay semántica específica disponible para esta pareja.',
  };
}

double? _attackRange(Map<String, dynamic> profile) {
  final raw = profile['attack_range'];
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}

String _rangeClass(double? range) {
  if (range == null || range <= 0) return 'unknown';
  return range <= 300 ? 'melee' : 'ranged';
}

String? _knownPowerCurve(Map<String, dynamic> profile) {
  final raw = profile['power_curve']?.toString().trim().toLowerCase();
  if (raw == null || raw.isEmpty) return null;
  return switch (raw) {
    'early' || 'early_game' || 'temprano' => 'early',
    'mid' || 'mid_game' || 'medio' => 'mid',
    'late' || 'late_game' || 'tardio' || 'tardío' => 'late',
    _ => null,
  };
}

String _matchupWinCondition({
  required String champion,
  required String enemy,
  required String localRangeClass,
  required String enemyRangeClass,
  required String? localPowerCurve,
  required String? enemyPowerCurve,
}) {
  final rangePlan = localRangeClass == 'melee' && enemyRangeClass == 'ranged'
      ? 'Conserva vida, recibe la oleada y busca una entrada cuando $enemy pierda distancia.'
      : localRangeClass == 'ranged' && enemyRangeClass == 'melee'
      ? 'Construye ventaja de vida y súbditos manteniendo a $enemy fuera de su rango de entrada.'
      : 'Controla la oleada y compromete recursos sólo con una ruta de salida y el jungla localizado.';
  if (localPowerCurve == null || enemyPowerCurve == null) return rangePlan;
  if (localPowerCurve == 'early' && enemyPowerCurve == 'late') {
    return '$rangePlan Tu curva confirmada es más temprana: convierte prioridad antes del escalado rival.';
  }
  if (localPowerCurve == 'late' && enemyPowerCurve == 'early') {
    return '$rangePlan Tu curva confirmada es más tardía: reduce intercambios volátiles y conserva recursos.';
  }
  return '$rangePlan Las curvas confirmadas de $champion y $enemy no exigen alterar ese plan base.';
}

double _axis(Map<String, dynamic> style, String key) =>
    (style[key] as num?)?.toDouble() ?? 0;

List<String> _stringList(Object? value) => value is List
    ? value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
    : const [];

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

Map<String, dynamic>? _laneOpponentPlayer(
  Map<String, dynamic>? local,
  List<Map<String, dynamic>> enemies,
) {
  final role = local?['position']?.toString().toUpperCase() ?? '';
  if (role.isEmpty || role == 'UNKNOWN') return null;
  return enemies
      .where((enemy) => enemy['position']?.toString().toUpperCase() == role)
      .where((enemy) => _champion(enemy).isNotEmpty)
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
