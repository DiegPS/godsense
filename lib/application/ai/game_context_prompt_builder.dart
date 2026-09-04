import '../coach_controller.dart';

class GameContextPromptBuilder {
  const GameContextPromptBuilder();

  String buildSystemPrompt({
    required CoachState coachState,
    Map<String, dynamic>? liveGame,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Eres el Asistente Táctico y Coach de League of Legends en tiempo real de GodSense.',
    );
    buffer.writeln(
      'Tu objetivo es asesorar al jugador con análisis conciso, estratégico y adaptado a la fase de la partida.',
    );
    buffer.writeln(
      'Responde siempre en español, de forma directa y táctica, usando formato Markdown limpio.',
    );
    buffer.writeln();

    buffer.writeln('=== TELEMETRÍA EN VIVO DE GODSENSE ===');
    switch (coachState.phase) {
      case CoachPhase.champSelect:
        buffer.writeln('ESTADO ACTUAL: Selección de Campeones (Champ Select)');
        _appendChampSelectContext(buffer, coachState);
        break;
      case CoachPhase.inGame:
        buffer.writeln('ESTADO ACTUAL: Partida en Curso (In Game)');
        _appendInGameContext(buffer, coachState, liveGame);
        break;
      case CoachPhase.postGame:
        buffer.writeln('ESTADO ACTUAL: Fin de Partida (Post Game)');
        _appendPostGameContext(buffer, coachState);
        break;
      case CoachPhase.inactive:
        buffer.writeln('ESTADO ACTUAL: Fuera de partida / En el Cliente');
        break;
    }

    buffer.writeln('======================================');
    buffer.writeln('INSTRUCCIÓN CRÍTICA:');
    buffer.writeln('Tienes visión completa de la telemetría anterior.');
    buffer.writeln(
      'NUNCA digas "no veo tu pantalla" ni "no tengo acceso a tu cliente", porque SÍ tienes todos los datos del cliente proporcionados arriba.',
    );
    buffer.writeln(
      'Responde preguntas como "¿qué elijo?", "¿cómo voy?", "¿qué compro?" o "¿qué hago ahora?" utilizando directamente los campeones, oro, KDA, minuto, items y rivales detallados.',
    );

    return buffer.toString();
  }

  void _appendInGameContext(
    StringBuffer buffer,
    CoachState coachState,
    Map<String, dynamic>? liveGame,
  ) {
    if (liveGame == null) {
      buffer.writeln(
        '- Partida en curso detectada. Esperando paquetes de telemetría de Live Client.',
      );
      return;
    }

    final gameTimeSec = (liveGame['game_time'] as num?)?.toDouble() ?? 0;
    final minutes = (gameTimeSec / 60).floor();
    final seconds = (gameTimeSec % 60).round().toString().padLeft(2, '0');
    buffer.writeln('- Tiempo de partida transcurrido: $minutes:$seconds');

    final goldDiff =
        (liveGame['team_gold_diff'] as num?)?.toInt() ??
        coachState.goldDifferential;
    final goldSign = goldDiff >= 0 ? '+$goldDiff' : '$goldDiff';
    buffer.writeln('- Diferencia de oro del equipo: $goldSign de oro');

    // Datos del jugador local activo
    final active = _map(liveGame['active_player']);
    if (active.isNotEmpty) {
      final champ = _champion(active);
      final level = active['level'] ?? 1;
      final kda = _kda(active);
      final cs = _cs(active);
      final currentGold = active['gold_current'] ?? active['currentGold'] ?? 0;

      buffer.writeln('- Tu campeón: $champ (Nivel $level)');
      buffer.writeln(
        '- Tu rendimiento actual: ${kda.join('/')} (K/D/A) | Súbditos (CS): $cs | Oro disponible en bolsillo: $currentGold',
      );
      buffer.writeln(
        '- Tu estado: ${_lifeState(active)} | Rol: ${active['role'] ?? 'desconocido'}',
      );

      // Objetos del jugador local
      if (active['items'] is List) {
        final items = (active['items'] as List)
            .whereType<Map>()
            .map(
              (item) =>
                  item['name']?.toString() ??
                  item['displayName']?.toString() ??
                  '',
            )
            .where((name) => name.isNotEmpty)
            .toList();
        if (items.isNotEmpty) {
          buffer.writeln('- Tus objetos actuales: ${items.join(', ')}');
        }
      }
    }

    // Equipo aliado
    final allies = _mapList(liveGame['allies']);
    if (allies.isNotEmpty) {
      final allyList = allies
          .map((player) => _describePlayer(player, active: active))
          .join('; ');
      buffer.writeln('- Equipo Aliado: $allyList');
    }

    // Equipo enemigo
    final enemies = _mapList(liveGame['enemies']);
    if (enemies.isNotEmpty) {
      final enemyList = enemies.map(_describePlayer).join('; ');
      buffer.writeln('- Equipo Rival: $enemyList');
    }

    // Directivas tácticas calculadas
    if (coachState.directives.isNotEmpty) {
      buffer.writeln('- Directivas tácticas activas:');
      for (final directive in coachState.directives.take(3)) {
        final hintText = directive.hints.isNotEmpty
            ? directive.hints.join(' ')
            : directive.rationale;
        buffer.writeln(
          '  * [Prioridad ${directive.priority}] ${directive.title}: $hintText',
        );
      }
    }

    // Alertas de amenazas y avistamientos recientes
    if (coachState.threats.isNotEmpty) {
      buffer.writeln('- Alertas recientes de mapa y visión:');
      for (final threat in coachState.threats.take(3)) {
        buffer.writeln(
          '  * ${threat.isGank ? '¡ALERTA DE GANK!' : 'Avistamiento'}: ${threat.champion} en ${threat.region} (${threat.location})',
        );
      }
    }
  }

  void _appendChampSelectContext(StringBuffer buffer, CoachState coachState) {
    final lobby = coachState.lobby;
    final draft = lobby?.draft;
    final localChamp = coachState.localChampion;
    if (localChamp.isNotEmpty) {
      buffer.writeln('- Tu campeón seleccionado/hover: $localChamp');
    }
    if (coachState.selectedEnemy != null) {
      buffer.writeln(
        '- Rival de línea seleccionado: ${coachState.selectedEnemy}',
      );
    }
    final matchup = coachState.matchup;
    if (matchup != null) {
      if (matchup.winCondition.isNotEmpty) {
        buffer.writeln('- Condición de línea: ${matchup.winCondition}');
      }
      if (matchup.tradingPatterns.isNotEmpty) {
        buffer.writeln(
          '- Patrones de intercambio: ${matchup.tradingPatterns.join(' ')}',
        );
      }
      if (matchup.powerSpikes.isNotEmpty) {
        buffer.writeln('- Picos relevantes: ${matchup.powerSpikes.join(' ')}');
      }
    }

    if (draft != null) {
      if (draft.allies.isNotEmpty) {
        final allyDesc = draft.allies
            .map((p) {
              final pos = p.position.isNotEmpty ? ' (${p.position})' : '';
              final status = p.selectionState.name;
              return '${p.championName}$pos [$status]${p.isLocal ? ' [TÚ]' : ''}';
            })
            .join(', ');
        buffer.writeln('- Aliados en lobby: $allyDesc');
      }

      if (draft.enemies.isNotEmpty) {
        final enemyDesc = draft.enemies
            .map((p) {
              final pos = p.position.isNotEmpty ? ' (${p.position})' : '';
              final status = p.selectionState.name;
              return '${p.championName}$pos [$status]';
            })
            .join(', ');
        buffer.writeln('- Enemigos en lobby: $enemyDesc');
      }

      if (draft.bans.isNotEmpty) {
        buffer.writeln(
          '- Bloqueos (Bans IDs): ${draft.bans.map((b) => b.championId).join(', ')}',
        );
      }
    }

    if (coachState.pickAdvice.isNotEmpty) {
      buffer.writeln('- Recomendaciones de pick de GodSense:');
      for (final advice in coachState.pickAdvice.take(3)) {
        buffer.writeln(
          '  * ${advice.champion} (${advice.scoreLabel ?? 'Recomendado'}): ${advice.reasons.join('; ')}',
        );
      }
    }

    if (coachState.runeRecommendations.isNotEmpty) {
      final primary = coachState.runeRecommendations.first;
      buffer.writeln(
        '- Configuración de runas sugerida: Posición ${primary.variant.position.lcuValue}',
      );
    }
  }

  void _appendPostGameContext(StringBuffer buffer, CoachState coachState) {
    final session = coachState.lastCompletedSession;
    if (session != null) {
      buffer.writeln('- Última partida completada: ${session.phase.name}');
    }
  }
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : const {};

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? value.whereType<Map>().map(_map).toList(growable: false)
    : const [];

String _champion(Map<String, dynamic> player) =>
    player['champion_name']?.toString().trim().isNotEmpty == true
    ? player['champion_name'].toString()
    : player['championName']?.toString().trim().isNotEmpty == true
    ? player['championName'].toString()
    : player['champion']?.toString().trim().isNotEmpty == true
    ? player['champion'].toString()
    : 'Desconocido';

List<int> _kda(Map<String, dynamic> player) {
  final normalized = player['kda'];
  if (normalized is List && normalized.length >= 3) {
    return normalized
        .take(3)
        .map((value) => (value as num?)?.toInt() ?? 0)
        .toList(growable: false);
  }
  final scores = _map(player['scores']);
  return [
    (scores['kills'] as num?)?.toInt() ?? 0,
    (scores['deaths'] as num?)?.toInt() ?? 0,
    (scores['assists'] as num?)?.toInt() ?? 0,
  ];
}

int _cs(Map<String, dynamic> player) =>
    (player['cs'] as num?)?.toInt() ??
    (_map(player['scores'])['creepScore'] as num?)?.toInt() ??
    0;

String _lifeState(Map<String, dynamic> player) {
  if (player['is_dead'] != true) return 'vivo';
  final seconds = (player['respawn_timer'] as num?)?.round() ?? 0;
  return seconds > 0 ? 'muerto, reaparece en $seconds s' : 'muerto';
}

String _describePlayer(
  Map<String, dynamic> player, {
  Map<String, dynamic> active = const {},
}) {
  final kda = _kda(player).join('/');
  final isLocal =
      player['is_local'] == true ||
      (active.isNotEmpty &&
          player['summoner_name'] == active['summoner_name'] &&
          player['tag_line'] == active['tag_line']);
  return '${_champion(player)} ($kda, ${_lifeState(player)})'
      '${isLocal ? ' [TÚ]' : ''}';
}
