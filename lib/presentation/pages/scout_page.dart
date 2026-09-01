part of '../../app/godsense_app.dart';

class ScoutPage extends ConsumerWidget {
  const ScoutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localScoutProvider);
    final profile = state.profile;
    final matches = state.matches;
    final detail = state.selectedMatch;

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
                    'Scout local',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text(
                    'Historial de la cuenta conectada, disponible sin abrir League.',
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: 'Actualizar historial local',
              child: IconButton.filledTonal(
                tooltip: 'Actualizar historial local',
                onPressed: state.loading
                    ? null
                    : () => ref.read(localScoutProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (state.loading) const LinearProgressIndicator(),
        if (state.loading) const SizedBox(height: 12),
        if (profile.isEmpty && !state.loading)
          const Card(
            child: ListTile(
              leading: Icon(Icons.account_circle_outlined),
              title: Text('Conecta una cuenta de League'),
              subtitle: Text(
                'GodSense mostrará aquí su rango e historial sincronizado.',
              ),
            ),
          ),
        if (profile.isNotEmpty) ...[
          _ScoutProfileCard(profile: profile),
          const SizedBox(height: 16),
          Text(
            'Partidas recientes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Card(
            child: matches.isEmpty
                ? const ListTile(title: Text('Sin partidas disponibles'))
                : Column(
                    children: matches.map((match) {
                      final champion = match['champion'] is Map
                          ? Map<String, dynamic>.from(match['champion'] as Map)
                          : const <String, dynamic>{};
                      final matchId = (match['match_id'] as num?)?.toInt();
                      return ListTile(
                        leading: _NetworkPortrait(
                          url: champion['icon_url']?.toString(),
                          size: 44,
                        ),
                        title: Text(
                          '${champion['name'] ?? 'Campeón'} · ${match['result'] ?? ''}',
                        ),
                        subtitle: Text(
                          '${match['kills'] ?? 0}/${match['deaths'] ?? 0}/${match['assists'] ?? 0} · '
                          '${match['role'] ?? ''} · ${match['csm'] ?? 0} CS/m',
                        ),
                        trailing: IconButton(
                          tooltip: 'Abrir detalle de partida',
                          icon: const Icon(Icons.chevron_right),
                          onPressed: matchId == null
                              ? null
                              : () => ref
                                    .read(localScoutProvider.notifier)
                                    .selectMatch(matchId),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
        if (detail.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Detalle de partida',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          _ScoutMatchDetail(detail: detail),
        ],
        if (state.lastError != null) ...[
          const SizedBox(height: 12),
          Text(
            state.lastError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _ScoutProfileCard extends StatelessWidget {
  const _ScoutProfileCard({required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final rank = profile['rank'] is Map
        ? Map<String, dynamic>.from(profile['rank'] as Map)
        : const <String, dynamic>{};
    final badges = _asMapList(profile['badges']);
    final gpi = _asMapList(profile['gpi']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NetworkPortrait(url: profile['icon_url']?.toString(), size: 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${profile['game_name'] ?? ''}#${profile['tag_line'] ?? ''}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${rank['tier'] ?? 'UNRANKED'} ${rank['division'] ?? ''} · '
                    '${rank['lp'] ?? 0} LP · ${rank['winrate'] ?? 0}% WR',
                  ),
                  Wrap(
                    spacing: 6,
                    children: badges
                        .map(
                          (badge) => Tooltip(
                            message: badge['description']?.toString() ?? '',
                            child: Chip(
                              label: Text(badge['name']?.toString() ?? 'Badge'),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  Wrap(
                    spacing: 8,
                    children: gpi
                        .map(
                          (item) => Chip(
                            label: Text(
                              '${item['category']}: ${item['value']}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoutMatchDetail extends StatelessWidget {
  const _ScoutMatchDetail({required this.detail});

  final Map<String, dynamic> detail;

  @override
  Widget build(BuildContext context) {
    final teams = _asMapList(detail['teams']);
    final players = _asMapList(detail['players']);
    return Card(
      child: Column(
        children: [
          for (final team in teams)
            ListTile(
              leading: Icon(
                team['win'] == true ? Icons.emoji_events : Icons.close,
              ),
              title: Text('${team['side'] ?? 'Equipo'}'),
              subtitle: Text(
                '${team['kills'] ?? 0} bajas · ${team['barons'] ?? 0} barones · '
                '${team['drakes'] ?? 0} dragones · ${team['towers'] ?? 0} torres',
              ),
            ),
          const Divider(),
          for (final player in players)
            ListTile(
              leading: _NetworkPortrait(
                url: player['champion'] is Map
                    ? (player['champion'] as Map)['icon_url']?.toString()
                    : null,
                size: 40,
              ),
              title: Text('${player['name'] ?? ''}#${player['tag'] ?? ''}'),
              subtitle: Text(
                '${player['role'] ?? ''} · ${player['kills'] ?? 0}/'
                '${player['deaths'] ?? 0}/${player['assists'] ?? 0} · '
                '${player['cs'] ?? 0} CS · ${player['damage'] ?? 0} daño',
              ),
              selected: player['is_subject'] == true,
            ),
        ],
      ),
    );
  }
}
