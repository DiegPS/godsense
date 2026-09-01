part of '../../app/godsense_app.dart';

class ScoutPage extends ConsumerStatefulWidget {
  const ScoutPage({super.key});

  @override
  ConsumerState<ScoutPage> createState() => _ScoutPageState();
}

class _ScoutPageState extends ConsumerState<ScoutPage> {
  final _nameController = TextEditingController();
  final _tagController = TextEditingController();
  String _region = 'LAN';

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companionControllerProvider);
    final profile = state.scoutProfile;
    final matches = _asMapList(profile['matches']);
    final detail = state.scoutMatch;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Scout', style: Theme.of(context).textTheme.headlineMedium),
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
                  width: 240,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de invocador',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      labelText: 'Tag',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: _region,
                  items: const ['LAN', 'LAS', 'NA', 'EUW', 'EUNE', 'BR', 'KR']
                      .map(
                        (region) => DropdownMenuItem(
                          value: region,
                          child: Text(region),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _region = value ?? 'LAN'),
                ),
                FilledButton.icon(
                  onPressed:
                      state.operationInProgress ||
                          _nameController.text.trim().isEmpty ||
                          _tagController.text.trim().isEmpty
                      ? null
                      : () => ref
                            .read(companionControllerProvider.notifier)
                            .scoutSummoner(
                              name: _nameController.text.trim(),
                              tag: _tagController.text.trim(),
                              region: _region,
                            ),
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
              ],
            ),
          ),
        ),
        if (profile.isNotEmpty) ...[
          const SizedBox(height: 16),
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
                          icon: const Icon(Icons.chevron_right),
                          onPressed: matchId == null
                              ? null
                              : () => ref
                                    .read(companionControllerProvider.notifier)
                                    .scoutMatch(
                                      matchId: matchId,
                                      region: _region,
                                      name: _nameController.text.trim(),
                                      tag: _tagController.text.trim(),
                                    ),
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
