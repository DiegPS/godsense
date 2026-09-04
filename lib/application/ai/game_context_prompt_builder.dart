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
    final active = liveGame['active_player'] is Map
        ? liveGame['active_player'] as Map<String, dynamic>
        : null;
    if (active != null) {
      final champ =
          active['championName'] ?? active['champion'] ?? 'Desconocido';
      final level = active['level'] ?? 1;
      final scores = active['scores'] is Map ? active['scores'] as Map : {};
      final k = scores['kills'] ?? 0;
      final d = scores['deaths'] ?? 0;
      final a = scores['assists'] ?? 0;
      final cs = scores['creepScore'] ?? 0;
      final currentGold = active['currentGold'] ?? 0;

      buffer.writeln('- Tu campeón: $champ (Nivel $level)');
      buffer.writeln(
        '- Tu rendimiento actual: $k/$d/$a (K/D/A) | Súbditos (CS): $cs | Oro disponible en bolsillo: $currentGold',
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
    final allies =
        (liveGame['allies'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    if (allies.isNotEmpty) {
      final allyList = allies
          .map((p) {
            final champ = p['championName'] ?? p['champion'] ?? 'Desconocido';
            final scores = p['scores'] is Map ? p['scores'] as Map : {};
            final k = scores['kills'] ?? 0;
            final d = scores['deaths'] ?? 0;
            final a = scores['assists'] ?? 0;
            final isLocal = p['is_local'] == true;
            return '$champ ($k/$d/$a)${isLocal ? ' [TÚ]' : ''}';
          })
          .join('; ');
      buffer.writeln('- Equipo Aliado: $allyList');
    }

    // Equipo enemigo
    final enemies =
        (liveGame['enemies'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    if (enemies.isNotEmpty) {
      final enemyList = enemies
          .map((p) {
            final champ = p['championName'] ?? p['champion'] ?? 'Desconocido';
            final scores = p['scores'] is Map ? p['scores'] as Map : {};
            final k = scores['kills'] ?? 0;
            final d = scores['deaths'] ?? 0;
            final a = scores['assists'] ?? 0;
            return '$champ ($k/$d/$a)';
          })
          .join('; ');
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
