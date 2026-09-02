part of '../../app/godsense_app.dart';

class LivePage extends ConsumerWidget {
  const LivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nativeLeague = ref.watch(nativeLeagueProvider);
    final game = ref.watch(effectiveGameProvider);
    final isEnded = game?.gameEnded == true;
    final derived = game?.raw['derived'] is Map
        ? Map<String, dynamic>.from(game!.raw['derived'] as Map)
        : const <String, dynamic>{};
    final objectives = derived['objectives'] is Map
        ? Map<String, dynamic>.from(derived['objectives'] as Map)
        : const <String, dynamic>{};
    final goldPoints = nativeLeague.timeline['gold_points'] is List
        ? nativeLeague.timeline['gold_points'] as List
        : const [];
    final timelineEvents = _asMapList(nativeLeague.timeline['events']);
    final activePlayer = game?.raw['active_player'] is Map
        ? Map<String, dynamic>.from(game!.raw['active_player'] as Map)
        : null;
    final opponent = activePlayer == null
        ? null
        : game?.enemies
              .where((enemy) => enemy['role'] == activePlayer['role'])
              .firstOrNull;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Partida en vivo',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text(
                    'Estado de la partida, objetivos y enfrentamiento de línea.',
                    style: TextStyle(
                      fontSize: 13,
                      color: GsColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (game != null)
              GsBadge(
                label: isEnded ? 'FINALIZADA' : _gamePhaseLabel(game.phase),
                variant: isEnded ? GsBadgeVariant.neutral : GsBadgeVariant.info,
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (game == null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: GsColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: GsColors.border),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.hourglass_empty_rounded,
                    size: 32,
                    color: GsColors.textMuted,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Esperando a que empiece la partida…',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: GsColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'El oro, los objetivos y el estado de línea aparecerán al entrar al juego.',
                    style: TextStyle(
                      fontSize: 12,
                      color: GsColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          if (!nativeLeague.liveApiConnected)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GsColors.crimsonGlow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x4DEF4444)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sync_problem_rounded,
                    color: GsColors.crimson,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Actualización de partida interrumpida',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: GsColors.crimson,
                          ),
                        ),
                        Text(
                          'Conservamos la última información mientras restablecemos la conexión automáticamente.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: GsColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          GsCard(
            child: Wrap(
              spacing: 28,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                GsMetricStat(
                  label: 'Tiempo',
                  value: _formatGameTime(game.gameTime),
                  icon: Icons.timer_outlined,
                ),
                GsMetricStat(
                  label: 'Fase',
                  value: isEnded ? 'FINALIZADA' : _gamePhaseLabel(game.phase),
                  icon: Icons.flag_outlined,
                  valueColor: GsColors.cyan,
                ),
                GsMetricStat(
                  label: 'Estado',
                  value: _teamStateLabel(game.raw['team_state']),
                  icon: Icons.insights_rounded,
                ),
                GsMetricStat(
                  label: 'Diferencia Oro',
                  value: _signedNumber(
                    (game.raw['team_gold_diff'] as num?)?.toInt() ?? 0,
                  ),
                  icon: Icons.monetization_on_outlined,
                  valueColor:
                      ((game.raw['team_gold_diff'] as num?)?.toInt() ?? 0) >= 0
                      ? GsColors.emerald
                      : GsColors.crimson,
                ),
                GsMetricStat(
                  label: 'Bajas Totales',
                  value:
                      '${_teamKills(game.allies)} - ${_teamKills(game.enemies)}',
                  icon: Icons.sports_kabaddi_outlined,
                ),
                GsMetricStat(
                  label: 'Oro de Equipos',
                  value:
                      '${_teamGold(game.allies)}k - ${_teamGold(game.enemies)}k',
                  icon: Icons.pie_chart_outline_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'OBJETIVOS DE MAPA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: GsColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: objectives.entries.map((entry) {
              final value = entry.value is Map
                  ? Map<String, dynamic>.from(entry.value as Map)
                  : const <String, dynamic>{};
              final respawn = (value['respawn_in'] as num?)?.toDouble();
              final isAlive = respawn == null || respawn <= 0;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: GsColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isAlive ? const Color(0x3310B981) : GsColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: isAlive ? GsColors.emerald : GsColors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_objectiveLabel(entry.key)}: ${_objectiveStatusLabel(value['status'], isAlive)}'
                      '${respawn == null ? '' : ' · ${_formatDuration(respawn)}'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: GsColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _TeamSection(title: 'Tu equipo', players: game.allies),
          const SizedBox(height: 12),
          _TeamSection(title: 'Equipo enemigo', players: game.enemies),
          const SizedBox(height: 16),
          const Text(
            'ENFRENTAMIENTO DE LÍNEA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: GsColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          if (activePlayer == null || opponent == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: GsColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GsColors.border),
              ),
              child: const Text(
                'Esperando rival de línea…',
                style: TextStyle(color: GsColors.textSecondary, fontSize: 12),
              ),
            )
          else
            _LiveMatchup(activePlayer: activePlayer, opponent: opponent),
        ],
        const SizedBox(height: 20),
        const Text(
          'DIFERENCIA DE ORO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: GsColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        GsCard(
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 220,
            child: goldPoints.isEmpty
                ? const Center(
                    child: Text(
                      'La evolución del oro aparecerá durante la partida.',
                      style: TextStyle(
                        color: GsColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: CustomPaint(
                      painter: _GoldChartPainter(goldPoints),
                      child: const SizedBox.expand(),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'REGISTRO DE EVENTOS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: GsColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        GsCard(
          padding: const EdgeInsets.all(8),
          child: timelineEvents.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Sin eventos recientes registrados.',
                    style: TextStyle(
                      color: GsColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                )
              : Column(
                  children: timelineEvents
                      .map(
                        (event) => Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: GsColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                event['is_ally'] == false
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                size: 16,
                                color: event['is_ally'] == false
                                    ? GsColors.crimson
                                    : GsColors.emerald,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _eventLabel(event),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: GsColors.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                event['game_time_fmt']?.toString() ??
                                    _formatGameTime(
                                      (event['game_time'] as num?)
                                              ?.toDouble() ??
                                          (event['EventTime'] as num?)
                                              ?.toDouble() ??
                                          0,
                                    ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: GsColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

String _gamePhaseLabel(String value) => switch (value.toLowerCase()) {
  'inprogress' || 'in_progress' || 'live' => 'EN PARTIDA',
  'champselect' || 'champ_select' => 'SELECCIÓN',
  'endofgame' || 'postgame' || 'completed' => 'FINALIZADA',
  _ => 'ACTIVA',
};

String _teamStateLabel(Object? value) =>
    switch (value?.toString().toUpperCase()) {
      'AHEAD' || 'WINNING' => 'Con ventaja',
      'BEHIND' || 'LOSING' => 'En desventaja',
      'EVEN' => 'Igualada',
      _ => 'Sin determinar',
    };

String _objectiveLabel(Object? value) =>
    switch (value?.toString().toLowerCase()) {
      'dragon' => 'Dragón',
      'baron' || 'baron_nashor' => 'Barón Nashor',
      'herald' || 'rift_herald' => 'Heraldo',
      'atakhan' => 'Atakhan',
      'elder' || 'elder_dragon' => 'Dragón anciano',
      final value when value != null && value.isNotEmpty => value,
      _ => 'Objetivo',
    };

String _objectiveStatusLabel(Object? value, bool isAlive) {
  final status = value?.toString().toLowerCase();
  if (isAlive || status == 'alive' || status == 'available') {
    return 'Disponible';
  }
  return switch (status) {
    'respawning' || 'dead' => 'Reapareciendo',
    'killed' || 'taken' => 'Eliminado',
    _ => 'No disponible',
  };
}

String _eventLabel(Map<String, dynamic> event) {
  final provided = event['label']?.toString();
  if (provided != null && provided.isNotEmpty) return provided;
  return switch (event['EventName']?.toString()) {
    'ChampionKill' => 'Campeón eliminado',
    'DragonKill' => 'Dragón eliminado',
    'BaronKill' => 'Barón Nashor eliminado',
    'HeraldKill' => 'Heraldo eliminado',
    'TurretKilled' => 'Torre destruida',
    'InhibKilled' => 'Inhibidor destruido',
    'GameEnd' => 'Partida finalizada',
    _ => 'Evento de partida',
  };
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.title, required this.players});

  final String title;
  final List<Map<String, dynamic>> players;

  @override
  Widget build(BuildContext context) {
    return GsCard(
      title: title,
      padding: EdgeInsets.zero,
      child: players.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Esperando jugadores…',
                style: TextStyle(color: GsColors.textSecondary, fontSize: 12),
              ),
            )
          : Column(
              children: players
                  .map((player) => _PlayerTile(player: player))
                  .toList(),
            ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player});

  final Map<String, dynamic> player;

  @override
  Widget build(BuildContext context) {
    final kda = player['kda'] is List ? player['kda'] as List : const [];
    final items = _asMapList(player['items']);
    final spells = player['spell_icons'] is List
        ? player['spell_icons'] as List
        : const [];
    final isDead = player['is_dead'] == true;

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x14FFFFFF), width: 1)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: _NetworkPortrait(
            url: player['icon_url']?.toString(),
            size: 38,
          ),
        ),
        title: Text(
          '${player['champion_name'] ?? 'Desconocido'} · ${player['role'] ?? ''}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: GsColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${player['summoner_name'] ?? ''}#${player['tag_line'] ?? ''} · '
          'Nv. ${player['level'] ?? 0} · ${kda.join('/')} · ${player['cs'] ?? 0} CS',
          style: const TextStyle(fontSize: 11, color: GsColors.textSecondary),
        ),
        trailing: isDead
            ? GsBadge(
                label:
                    'MUERTO ${_formatDuration((player['respawn_timer'] as num?)?.toDouble() ?? 0)}',
                variant: GsBadgeVariant.danger,
              )
            : Text(
                '${player['gold_total'] ?? 0} oro',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: GsColors.amber,
                ),
              ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(64, 0, 16, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...items.map(
                  (item) => Tooltip(
                    message: item['displayName']?.toString() ?? 'Objeto',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: _NetworkPortrait(
                        url: item['icon_url']?.toString(),
                        size: 28,
                        fallback: Icons.inventory_2_outlined,
                      ),
                    ),
                  ),
                ),
                ...spells.map(
                  (url) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: _NetworkPortrait(
                      url: url?.toString(),
                      size: 28,
                      fallback: Icons.flash_on,
                    ),
                  ),
                ),
                if (player['keystone_icon_url'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: _NetworkPortrait(
                      url: player['keystone_icon_url']?.toString(),
                      size: 28,
                      fallback: Icons.auto_awesome,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMatchup extends StatelessWidget {
  const _LiveMatchup({required this.activePlayer, required this.opponent});

  final Map<String, dynamic> activePlayer;
  final Map<String, dynamic> opponent;

  @override
  Widget build(BuildContext context) {
    final abilities = _asMapList(opponent['abilities']);
    return GsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _MatchupPlayer(player: activePlayer)),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: GsColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: GsColors.cyan,
                  ),
                ),
              ),
              Expanded(child: _MatchupPlayer(player: opponent)),
            ],
          ),
          if (abilities.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0x14FFFFFF)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Habilidades de ${opponent['champion_name']}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: GsColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            for (final ability in abilities)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: GsColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: _NetworkPortrait(
                      url: ability['icon_url']?.toString(),
                      size: 30,
                      fallback: Icons.auto_awesome,
                    ),
                  ),
                  title: Text(
                    '${ability['slot'] ?? ''} · ${ability['name'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GsColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'CD ${ability['cooldown'] ?? '—'} · Coste ${ability['cost'] ?? '—'} · '
                    'Rango ${ability['range'] ?? '—'}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: GsColors.textSecondary,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Text(
                        ability['description']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: GsColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MatchupPlayer extends StatelessWidget {
  const _MatchupPlayer({required this.player});

  final Map<String, dynamic> player;

  @override
  Widget build(BuildContext context) {
    final kda = player['kda'] is List ? player['kda'] as List : const [];
    final items = _asMapList(player['items']);
    return Column(
      children: [
        _NetworkPortrait(url: player['icon_url']?.toString(), size: 72),
        const SizedBox(height: 6),
        Text(
          player['champion_name']?.toString() ?? '—',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text('${player['summoner_name'] ?? ''}#${player['tag_line'] ?? ''}'),
        LiveRankBadge(
          profile: player['ranked_profile'] is Map
              ? Map<String, dynamic>.from(player['ranked_profile'] as Map)
              : null,
        ),
        Text(
          'Nv. ${player['level'] ?? 0} · ${kda.join('/')} · ${player['cs'] ?? 0} CS',
        ),
        Wrap(
          spacing: 4,
          children: items
              .map(
                (item) => _NetworkPortrait(
                  url: item['icon_url']?.toString(),
                  size: 28,
                  fallback: Icons.inventory_2_outlined,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _GoldChartPainter extends CustomPainter {
  const _GoldChartPainter(this.points);

  final List<dynamic> points;

  @override
  void paint(Canvas canvas, Size size) {
    final parsed = points
        .whereType<List>()
        .where((point) => point.length >= 2)
        .map(
          (point) => Offset(
            (point[0] as num?)?.toDouble() ?? 0,
            (point[1] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList();
    if (parsed.length < 2) return;
    final minX = parsed.first.dx;
    final maxX = parsed.last.dx;
    final maxAbsY = parsed
        .map((point) => point.dy.abs())
        .fold<double>(200, (max, value) => value > max ? value : max);
    final zeroY = size.height / 2;
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()..color = Colors.grey.withValues(alpha: 0.5),
    );
    final path = Path();
    for (var index = 0; index < parsed.length; index++) {
      final point = parsed[index];
      final x = maxX == minX
          ? 0.0
          : ((point.dx - minX) / (maxX - minX)) * size.width;
      final y = zeroY - (point.dy / maxAbsY) * (size.height / 2 - 8);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = parsed.last.dy >= 0 ? Colors.green : Colors.red
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_GoldChartPainter oldDelegate) =>
      oldDelegate.points != points;
}
