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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            IconButton.outlined(
              tooltip: 'Actualizar historial local',
              style: IconButton.styleFrom(
                side: const BorderSide(color: Color(0x1AFFFFFF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: state.loading
                  ? null
                  : () => ref.read(localScoutProvider.notifier).refresh(),
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 1. Modern Floating Search Console
        Container(
          decoration: BoxDecoration(
            color: GsColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _gameName,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            fontSize: 13,
                            color: GsColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            labelText: 'Nombre de Riot',
                            hintText: 'Invocador…',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: GsColors.textMuted,
                            ),
                            filled: true,
                            fillColor: GsColors.surfaceElevated,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: GsColors.cyan,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _tagLine,
                          textInputAction: TextInputAction.search,
                          onSubmitted: state.loading ? null : (_) => _search(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: GsColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            labelText: 'Tag',
                            prefixText: '# ',
                            prefixStyle: const TextStyle(
                              color: GsColors.cyan,
                              fontWeight: FontWeight.bold,
                            ),
                            filled: true,
                            fillColor: GsColors.surfaceElevated,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: GsColors.cyan,
                              ),
                            ),
                          ),
                        ),
                      ),
                      GsButton(
                        label: 'Buscar',
                        icon: Icons.search_rounded,
                        onPressed: state.loading ? null : _search,
                      ),
                      GsButton(
                        label: 'Mi Cuenta',
                        icon: Icons.account_circle_outlined,
                        variant: GsButtonVariant.secondary,
                        onPressed: state.loading
                            ? null
                            : () => ref
                                  .read(localScoutProvider.notifier)
                                  .useConnectedAccount(),
                      ),
                    ],
                  ),
                ),
                if (state.loading) ...[
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    color: GsColors.cyan,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    color: GsColors.cyanGlow,
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: GsColors.cyan,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.loadingLabel ??
                              'Consultando datos del invocador…',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: GsColors.cyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 3. Empty Profile State
        if (profile.isEmpty && !state.loading)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: BoxDecoration(
              color: GsColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: GsColors.cyanGlow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.travel_explore_rounded,
                    size: 36,
                    color: GsColors.cyan,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Conecta una cuenta de League',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: GsColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'GodSense mostrará aquí su rango e historial sincronizado cuando busques un Riot ID o conectes tu cliente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: GsColors.textSecondary),
                ),
              ],
            ),
          ),

        // 4. Player Profile Card
        if (profile.isNotEmpty) ...[
          _ScoutProfileCard(profile: profile),
          const SizedBox(height: 20),

          // Matches Section Header
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 18, color: GsColors.cyan),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Partidas Recientes Analizadas',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: GsColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${matches.length} partidas en registro local',
                style: const TextStyle(fontSize: 12, color: GsColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (matches.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: GsColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Sin partidas registradas para este invocador.',
                  style: TextStyle(color: GsColors.textMuted),
                ),
              ),
            )
          else
            Column(
              children: matches.map((match) {
                final champion = match['champion'] is Map
                    ? Map<String, dynamic>.from(match['champion'] as Map)
                    : const <String, dynamic>{};
                final matchId = (match['match_id'] as num?)?.toInt();
                final isWin = (match['result']?.toString().toUpperCase() ?? '')
                    .contains('WIN');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ScoutMatchCard(
                    match: match,
                    champion: champion,
                    isWin: isWin,
                    onTap: matchId == null
                        ? null
                        : () => ref
                              .read(localScoutProvider.notifier)
                              .selectMatch(matchId),
                  ),
                );
              }).toList(),
            ),
        ],

        // 5. Match Detail View
        if (detail.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(
                Icons.scoreboard_outlined,
                size: 18,
                color: GsColors.cyan,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Scorecard 5v5 y Estadísticas de Partida',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: GsColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: GsColors.textSecondary,
                ),
                tooltip: 'Cerrar detalle',
                onPressed: () => ref
                    .read(localScoutProvider.notifier)
                    .selectMatch(
                      (detail['match_id'] as num?)?.toInt() ??
                          (detail['game_id'] as num?)?.toInt() ??
                          0,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ScoutMatchDetail(detail: detail),
        ],

        if (state.lastError != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GsColors.crimsonGlow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: GsColors.crimson,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.lastError!,
                    style: const TextStyle(
                      color: GsColors.crimson,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
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
    final winrate = (rank['winrate'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GsColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Profile Top Info (Avatar, Name, Rank Badge, KPIs)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _NetworkPortrait(
                  url: profile['icon_url']?.toString(),
                  size: 64,
                ),
              ),
              const SizedBox(width: 16),

              // Summoner Name & Server
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile['game_name'] ?? 'Invocador'}#${profile['tag_line'] ?? 'LAN'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: GsColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: GsColors.cyanGlow,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${rank['tier'] ?? 'UNRANKED'} ${rank['division'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: GsColors.cyan,
                            ),
                          ),
                        ),
                        Text(
                          '${rank['lp'] ?? 0} LP · ${profile['sample_size'] ?? 0} partidas analizadas',
                          style: const TextStyle(
                            fontSize: 12,
                            color: GsColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Win Rate Visual Ring/Card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: GsColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      '${winrate.toStringAsFixed(1)}% WR',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: winrate >= 50
                            ? GsColors.emerald
                            : GsColors.crimson,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Rendimiento Global',
                      style: TextStyle(fontSize: 10, color: GsColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Row 2: Badges & GPI Capability Tags
          if (badges.isNotEmpty || gpi.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0x14FFFFFF), height: 1),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...badges.map(
                  (badge) => Tooltip(
                    message: badge['description']?.toString() ?? '',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: GsColors.cyanGlow,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_outlined,
                            size: 12,
                            color: GsColors.cyan,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            badge['name']?.toString() ?? 'Badge',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: GsColors.cyanLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ...gpi.map(
                  (item) => Tooltip(
                    message: item['unit']?.toString() ?? '',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: GsColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item['category']}: ${item['value']}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: GsColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Row 3: Signature Champions Pool Grid
          if (signatures.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0x14FFFFFF), height: 1),
            const SizedBox(height: 14),
            const Text(
              'Campeones Insignia & Dominio',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: GsColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: signatures.map((champ) {
                final cWinrate = (champ['winrate'] as num?)?.toDouble() ?? 0.0;
                return Container(
                  width: 220,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GsColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _NetworkPortrait(
                          url: champ['icon_url']?.toString(),
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              champ['name']?.toString() ?? 'Campeón',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: GsColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${champ['games']} partidas · ${champ['kda']} KDA',
                              style: const TextStyle(
                                fontSize: 10,
                                color: GsColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${cWinrate.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: cWinrate >= 50
                              ? GsColors.emerald
                              : GsColors.crimson,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoutMatchCard extends StatelessWidget {
  const _ScoutMatchCard({
    required this.match,
    required this.champion,
    required this.isWin,
    required this.onTap,
  });

  final Map<String, dynamic> match;
  final Map<String, dynamic> champion;
  final bool isWin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kills = match['kills'] ?? 0;
    final deaths = match['deaths'] ?? 0;
    final assists = match['assists'] ?? 0;
    final csm = match['csm'] ?? 0;
    final role = match['role']?.toString() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: isWin ? const Color(0xFF0B1917) : const Color(0xFF190F12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left Color Stripe
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: isWin ? GsColors.emerald : GsColors.crimson,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(9),
                      bottomLeft: Radius.circular(9),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Match Result & Queue
                SizedBox(
                  width: 100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isWin ? 'VICTORIA' : 'DERROTA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isWin ? GsColors.emerald : GsColors.crimson,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Clasificatoria',
                        style: TextStyle(
                          fontSize: 11,
                          color: GsColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Champion Portrait & Role
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _NetworkPortrait(
                    url: champion['icon_url']?.toString(),
                    size: 42,
                  ),
                ),
                const SizedBox(width: 12),

                // Champion Name & Role Tag
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${champion['name'] ?? 'Campeón'} · ${match['result'] ?? (isWin ? 'Victoria' : 'Derrota')}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: GsColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (role.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: GsColors.cyanGlow,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: GsColors.cyan,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // KDA Stats
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$kills / ',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: GsColors.textPrimary,
                          ),
                        ),
                        Text(
                          '$deaths',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: GsColors.crimson,
                          ),
                        ),
                        Text(
                          ' / $assists',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: GsColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$csm CS/m',
                      style: const TextStyle(
                        fontSize: 11,
                        color: GsColors.textMuted,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 16),

                // Open detail button
                const Tooltip(
                  message: 'Abrir detalle de partida',
                  child: Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: GsColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
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

    return Container(
      decoration: BoxDecoration(
        color: GsColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Teams Summary
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: teams.map((team) {
                final isWin = team['win'] == true;
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isWin
                          ? const Color(0x1A10B981)
                          : const Color(0x1AEF4444),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isWin
                              ? Icons.emoji_events_rounded
                              : Icons.close_rounded,
                          size: 18,
                          color: isWin ? GsColors.emerald : GsColors.crimson,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${team['side'] ?? 'Equipo'} · ${isWin ? 'VICTORIA' : 'DERROTA'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isWin
                                    ? GsColors.emerald
                                    : GsColors.crimson,
                              ),
                            ),
                            Text(
                              '${team['kills'] ?? 0} Bajas · ${team['drakes'] ?? 0} Dragones · ${team['barons'] ?? 0} Barones',
                              style: const TextStyle(
                                fontSize: 10,
                                color: GsColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(color: Color(0x14FFFFFF), height: 1),

          // Players List
          ...players.map((player) {
            final isSubject = player['is_subject'] == true;
            return Container(
              color: isSubject ? GsColors.cyanGlow : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _NetworkPortrait(
                      url: player['champion'] is Map
                          ? (player['champion'] as Map)['icon_url']?.toString()
                          : null,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Text(
                          '${player['name'] ?? ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSubject
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSubject
                                ? GsColors.cyan
                                : GsColors.textPrimary,
                          ),
                        ),
                        Text(
                          '#${player['tag'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: GsColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${player['role'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: GsColors.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      '${player['kills'] ?? 0}/${player['deaths'] ?? 0}/${player['assists'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: GsColors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${player['cs'] ?? 0} CS',
                      style: const TextStyle(
                        fontSize: 11,
                        color: GsColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${player['damage'] ?? 0} DMG',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: GsColors.cyan,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
