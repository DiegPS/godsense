part of '../../app/godsense_app.dart';

class ScoutPage extends ConsumerStatefulWidget {
  const ScoutPage({super.key});

  @override
  ConsumerState<ScoutPage> createState() => _ScoutPageState();
}

class _ScoutPageState extends ConsumerState<ScoutPage> {
  final _gameName = TextEditingController();
  final _tagLine = TextEditingController(text: 'LAN');

  @override
  void dispose() {
    _gameName.dispose();
    _tagLine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    'Scout',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text(
                    'Busca cualquier Riot ID desde el cliente y conserva su historial localmente.',
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _gameName,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de Riot',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _tagLine,
                    textInputAction: TextInputAction.search,
                    onSubmitted: state.loading ? null : (_) => _search(),
                    decoration: const InputDecoration(
                      labelText: 'Tag',
                      prefixText: '#',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: state.loading ? null : _search,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
                OutlinedButton.icon(
                  onPressed: state.loading
                      ? null
                      : () => ref
                            .read(localScoutProvider.notifier)
                            .useConnectedAccount(),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Mi cuenta'),
                ),
              ],
            ),
          ),
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

  void _search() {
    final gameName = _gameName.text.trim();
    final tagLine = _tagLine.text.trim().replaceFirst('#', '');
    if (gameName.isEmpty || tagLine.isEmpty) return;
    ref
        .read(localScoutProvider.notifier)
        .searchRiotId(gameName: gameName, tagLine: tagLine);
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
    final signatures = _asMapList(profile['signature_champions']);
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
                  Text(
                    'Analítica local · ${profile['sample_size'] ?? 0} partidas',
                    style: Theme.of(context).textTheme.bodySmall,
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
                          (item) => Tooltip(
                            message: item['unit']?.toString() ?? '',
                            child: Chip(
                              label: Text(
                                '${item['category']}: ${item['value']}',
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  if (signatures.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Campeones insignia',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: signatures
                          .map(
                            (champion) => Chip(
                              avatar: _NetworkPortrait(
                                url: champion['icon_url']?.toString(),
                                size: 24,
                              ),
                              label: Text(
                                '${champion['name']} · ${champion['games']} partidas · '
                                '${champion['winrate']}% WR · ${champion['kda']} KDA',
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
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
