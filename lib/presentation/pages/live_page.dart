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
        Text(
          'Partida en vivo',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        if (game == null)
          const Card(
            child: ListTile(
              leading: Icon(Icons.hourglass_empty),
              title: Text('Esperando a que empiece la partida…'),
            ),
          )
        else ...[
          if (!nativeLeague.liveApiConnected)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.sync_problem),
                title: const Text('Live Client temporalmente desconectado'),
                subtitle: Text(
                  'Se conserva el último estado válido mientras se reconecta '
                  '(${nativeLeague.consecutiveLiveFailures} intentos).',
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 28,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Metric(
                    label: 'Tiempo',
                    value: _formatGameTime(game.gameTime),
                  ),
                  _Metric(
                    label: 'Fase',
                    value: isEnded ? 'FINALIZADA' : game.phase,
                  ),
                  _Metric(
                    label: 'Estado',
                    value: game.raw['team_state']?.toString() ?? 'EVEN',
                  ),
                  _Metric(
                    label: 'Oro',
                    value: _signedNumber(
                      (game.raw['team_gold_diff'] as num?)?.toInt() ?? 0,
                    ),
                  ),
                  _Metric(
                    label: 'Bajas',
                    value:
                        '${_teamKills(game.allies)} - ${_teamKills(game.enemies)}',
                  ),
                  _Metric(
                    label: 'Oro de equipos',
                    value:
                        '${_teamGold(game.allies)} - ${_teamGold(game.enemies)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Objetivos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: objectives.entries.map((entry) {
              final value = entry.value is Map
                  ? Map<String, dynamic>.from(entry.value as Map)
                  : const <String, dynamic>{};
              final respawn = (value['respawn_in'] as num?)?.toDouble();
              return Chip(
                avatar: const Icon(Icons.timer_outlined, size: 18),
                label: Text(
                  '${entry.key}: ${value['status'] ?? 'unknown'}'
                  '${respawn == null ? '' : ' · ${_formatDuration(respawn)}'}',
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _TeamSection(title: 'Tu equipo', players: game.allies),
          const SizedBox(height: 16),
          _TeamSection(title: 'Equipo enemigo', players: game.enemies),
          const SizedBox(height: 16),
          Text(
            'Tu enfrentamiento',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (activePlayer == null || opponent == null)
            const Card(
              child: ListTile(title: Text('Esperando rival de línea…')),
            )
          else
            _LiveMatchup(activePlayer: activePlayer, opponent: opponent),
        ],
        const SizedBox(height: 20),
        Text(
          'Diferencia de oro',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Card(
          child: SizedBox(
            height: 220,
            child: goldPoints.isEmpty
                ? const Center(child: Text('Esperando puntos del timeline…'))
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
        Text('Eventos', style: Theme.of(context).textTheme.titleLarge),
        Card(
          child: timelineEvents.isEmpty
              ? const ListTile(title: Text('Sin eventos recientes'))
              : Column(
                  children: timelineEvents
                      .map(
                        (event) => ListTile(
                          leading: Icon(
                            event['is_ally'] == false
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                          ),
                          title: Text(
                            event['label']?.toString() ??
                                event['EventName']?.toString() ??
                                'Evento',
                          ),
                          trailing: Text(
                            event['game_time_fmt']?.toString() ??
                                _formatGameTime(
                                  (event['game_time'] as num?)?.toDouble() ??
                                      (event['EventTime'] as num?)
                                          ?.toDouble() ??
                                      0,
                                ),
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.title, required this.players});

  final String title;
  final List<Map<String, dynamic>> players;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(title),
        children: players.isEmpty
            ? const [ListTile(title: Text('Esperando jugadores…'))]
            : players.map((player) => _PlayerTile(player: player)).toList(),
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
    return ExpansionTile(
      leading: _NetworkPortrait(url: player['icon_url']?.toString(), size: 44),
      title: Text(
        '${player['champion_name'] ?? 'Desconocido'} · ${player['role'] ?? ''}',
      ),
      subtitle: Text(
        '${player['summoner_name'] ?? ''}#${player['tag_line'] ?? ''} · '
        'Nv. ${player['level'] ?? 0} · ${kda.join('/')} · ${player['cs'] ?? 0} CS',
      ),
      trailing: player['is_dead'] == true
          ? Text(
              'Muerto ${_formatDuration((player['respawn_timer'] as num?)?.toDouble() ?? 0)}',
            )
          : Text('${player['gold_total'] ?? 0} oro'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...items.map(
                (item) => Tooltip(
                  message: item['displayName']?.toString() ?? 'Objeto',
                  child: _NetworkPortrait(
                    url: item['icon_url']?.toString(),
                    size: 32,
                    fallback: Icons.inventory_2_outlined,
                  ),
                ),
              ),
              ...spells.map(
                (url) => _NetworkPortrait(
                  url: url?.toString(),
                  size: 32,
                  fallback: Icons.flash_on,
                ),
              ),
              if (player['keystone_icon_url'] != null)
                _NetworkPortrait(
                  url: player['keystone_icon_url']?.toString(),
                  size: 32,
                  fallback: Icons.auto_awesome,
                ),
            ],
          ),
        ),
      ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _MatchupPlayer(player: activePlayer)),
                const Padding(padding: EdgeInsets.all(16), child: Text('VS')),
                Expanded(child: _MatchupPlayer(player: opponent)),
              ],
            ),
            if (abilities.isNotEmpty) ...[
              const Divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Habilidades de ${opponent['champion_name']}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final ability in abilities)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  leading: _NetworkPortrait(
                    url: ability['icon_url']?.toString(),
                    size: 36,
                    fallback: Icons.auto_awesome,
                  ),
                  title: Text(
                    '${ability['slot'] ?? ''} · ${ability['name'] ?? ''}',
                  ),
                  subtitle: Text(
                    'CD ${ability['cooldown'] ?? '—'} · Coste ${ability['cost'] ?? '—'} · '
                    'Rango ${ability['range'] ?? '—'}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(ability['description']?.toString() ?? ''),
                    ),
                  ],
                ),
            ],
          ],
        ),
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
