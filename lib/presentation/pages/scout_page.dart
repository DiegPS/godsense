part of '../../app/godsense_app.dart';

class ScoutPage extends ConsumerStatefulWidget {
  const ScoutPage({super.key});

  @override
  ConsumerState<ScoutPage> createState() => _ScoutPageState();
}

class _ScoutPageState extends ConsumerState<ScoutPage> {
  final _gameName = TextEditingController();
  final _tagLine = TextEditingController(text: 'LAN');
  final Set<int> _expandedMatchIds = {};

  @override
  void dispose() {
    _gameName.dispose();
    _tagLine.dispose();
    super.dispose();
  }

  void _toggleExpand(int matchId) {
    setState(() {
      if (_expandedMatchIds.contains(matchId)) {
        _expandedMatchIds.remove(matchId);
      } else {
        _expandedMatchIds.add(matchId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localScoutProvider);
    final subject = state.subjectAccount;
    final analytics = state.analytics;
    final matches = state.typedMatches;
    final activeContextState = ref.watch(nativeLeagueProvider).accountContext;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1020;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            // Page Title Header
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
                        'Analiza perfiles, tendencias y rendimiento reciente por partida.',
                        style: TextStyle(
                          fontSize: 13,
                          color: GsColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Actualizar historial',
                  style: IconButton.styleFrom(
                    side: BorderSide.none,
                    backgroundColor: GsColors.surfaceElevated,
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
                    color: GsColors.cyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. Search Console Bar
            _buildSearchConsole(state),
            const SizedBox(height: 16),

            // 2. Empty State when no profile is available
            if (subject == null && state.profile.isEmpty && !state.loading)
              _buildEmptyState(),

            // 3. Hero Profile Header
            if (subject != null || state.profile.isNotEmpty) ...[
              _buildHeroProfileHeader(state, analytics),
              const SizedBox(height: 20),

              // 4. Main Body: Split or Stacked based on Width
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (Sidebar: Linked account & Relationships)
                    SizedBox(
                      width: 320,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLinkedAccountCard(activeContextState),
                          const SizedBox(height: 16),
                          if (analytics != null &&
                              analytics.recentTeammates.isNotEmpty) ...[
                            _buildRelationshipTable(
                              title: 'Compañeros Recientes',
                              subtitle: 'Aliados en partidas analizadas',
                              icon: Icons.group_outlined,
                              relationships: analytics.recentTeammates,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (analytics != null &&
                              analytics.recentOpponents.isNotEmpty) ...[
                            _buildRelationshipTable(
                              title: 'Rivales Recientes',
                              subtitle:
                                  'Enfrentamientos en partidas analizadas',
                              icon: Icons.sports_kabaddi_outlined,
                              relationships: analytics.recentOpponents,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Right Main Column (Performance Summary & Match History)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (analytics != null) ...[
                            _buildPerformanceSummary(analytics),
                            const SizedBox(height: 20),
                          ],
                          _buildMatchHistorySection(matches, state),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLinkedAccountCard(activeContextState),
                    const SizedBox(height: 16),
                    if (analytics != null) ...[
                      _buildPerformanceSummary(analytics),
                      const SizedBox(height: 16),
                    ],
                    if (analytics != null &&
                        analytics.recentTeammates.isNotEmpty) ...[
                      _buildRelationshipTable(
                        title: 'Compañeros Recientes',
                        subtitle: 'Aliados en partidas analizadas',
                        icon: Icons.group_outlined,
                        relationships: analytics.recentTeammates,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildMatchHistorySection(matches, state),
                  ],
                ),
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
                        'No pudimos actualizar este perfil. Comprueba que '
                        'League esté abierto e inténtalo de nuevo.',
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
      },
    );
  }

  Widget _buildSearchConsole(LocalScoutState state) {
    return Container(
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
                          borderSide: const BorderSide(color: GsColors.cyan),
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
                          borderSide: const BorderSide(color: GsColors.cyan),
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
                      state.loadingLabel ?? 'Consultando datos del invocador…',
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
    );
  }

  Widget _buildEmptyState() {
    return Container(
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
    );
  }

  Widget _buildHeroProfileHeader(
    LocalScoutState state,
    ScoutProfileAnalytics? analytics,
  ) {
    final legacy = state.profile;
    final name =
        state.subjectAccount?.riotId?.gameName ??
        legacy['game_name'] ??
        'Invocador';
    final tag =
        state.subjectAccount?.riotId?.tagLine ?? legacy['tag_line'] ?? 'LAN';
    final iconUrl = state.subjectAccount?.profileIconId != null
        ? 'https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/profile-icons/${state.subjectAccount!.profileIconId}.jpg'
        : legacy['icon_url']?.toString();

    final rankMap = legacy['rank'] is Map ? legacy['rank'] as Map : const {};
    final tier = rankMap['tier']?.toString() ?? 'UNRANKED';
    final division = rankMap['division']?.toString() ?? '';
    final lp = (rankMap['lp'] as num?)?.toInt() ?? 0;

    final recentForm = analytics?.recentForm ?? const <bool>[];
    final formWins = recentForm.where((w) => w).length;
    final formLosses = recentForm.length - formWins;
    final formWr = recentForm.isEmpty
        ? 0
        : (formWins * 100 / recentForm.length).round();

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with Level Badge Overlay
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _NetworkPortrait(url: iconUrl, size: 68),
                  ),
                  Positioned(
                    bottom: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: GsColors.canvas,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: GsColors.border, width: 1),
                      ),
                      child: const Text(
                        'LVL',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: GsColors.cyan,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 18),

              // Name, Tag & Rank Pill
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name#$tag',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: GsColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: GsColors.cyanGlow,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$tier $division · $lp LP',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: GsColors.cyan,
                            ),
                          ),
                        ),
                        if (analytics != null &&
                            analytics.roleDistribution.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: GsColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${analytics.roleDistribution.first.role.label} Main · ${analytics.roleDistribution.first.percentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: GsColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Recent Form Matrix (Últimas 10 partidas)
              if (recentForm.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: GsColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'FORMA RECIENTE (ÚLTIMAS 10)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: GsColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: recentForm.map((won) {
                          return Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: won
                                  ? GsColors.emeraldGlow
                                  : GsColors.crimsonGlow,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Center(
                              child: Text(
                                won ? 'W' : 'L',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: won
                                      ? GsColors.emerald
                                      : GsColors.crimson,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formWins}W - ${formLosses}L · $formWr% WR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: formWr >= 50
                              ? GsColors.emerald
                              : GsColors.crimson,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedAccountCard(AccountContextState? activeContextState) {
    final account = activeContextState?.context?.account;

    return GsCard(
      title: 'Cuenta Conectada',
      icon: Icons.link_rounded,
      padding: const EdgeInsets.all(14),
      child: account != null
          ? Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _NetworkPortrait(
                    url: account.profileIconId != null
                        ? 'https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/profile-icons/${account.profileIconId}.jpg'
                        : null,
                    size: 40,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${account.riotId?.gameName ?? 'Invocador'}#${account.riotId?.tagLine ?? 'LAN'}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: GsColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: activeContextState?.lcuConnected == true
                                  ? GsColors.emerald
                                  : GsColors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            activeContextState?.lcuConnected == true
                                ? 'Cuenta conectada'
                                : 'Desconectado',
                            style: const TextStyle(
                              fontSize: 11,
                              color: GsColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Abre League para conectar tu cuenta.',
                style: TextStyle(fontSize: 12, color: GsColors.textMuted),
              ),
            ),
    );
  }

  Widget _buildRelationshipTable({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<ScoutRelationshipStats> relationships,
  }) {
    return GsCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      padding: EdgeInsets.zero,
      child: Column(
        children: relationships.take(5).map((rel) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0x14FFFFFF), width: 1),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _NetworkPortrait(url: rel.iconUrl, size: 28),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rel.summonerName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: GsColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${rel.games} partidas (${rel.wins}W - ${rel.losses}L)',
                        style: const TextStyle(
                          fontSize: 10,
                          color: GsColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: rel.winrate >= 50
                        ? GsColors.emeraldGlow
                        : GsColors.crimsonGlow,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${rel.winrate.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: rel.winrate >= 50
                          ? GsColors.emerald
                          : GsColors.crimson,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPerformanceSummary(ScoutProfileAnalytics analytics) {
    final kpis = analytics.kpis;

    return GsCard(
      title: 'Resumen de Rendimiento',
      subtitle: 'Calculado sobre ${kpis.sampleSize} partidas disponibles.',
      icon: Icons.query_stats_rounded,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 8 KPI Grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildKpiTile(
                'VICTORIAS RECIENTES',
                '${kpis.recentWinRate.toStringAsFixed(1)}%',
                '${kpis.wins}W · ${kpis.losses}L',
                GsColors.emerald,
              ),
              _buildKpiTile(
                'KDA PROMEDIO',
                kpis.avgKda?.toStringAsFixed(2) ?? 'Sin datos',
                'Ratio K+A/D',
                GsColors.cyan,
              ),
              _buildKpiTile(
                'DAÑO PROMEDIO',
                _formatK(kpis.avgDamage),
                'A campeones',
                GsColors.textPrimary,
              ),
              _buildKpiTile(
                'PARTICIPACIÓN EN BAJAS',
                kpis.killParticipation != null
                    ? '${kpis.killParticipation!.toStringAsFixed(1)}%'
                    : 'Sin datos',
                'Bajas de equipo',
                GsColors.textPrimary,
              ),
              _buildKpiTile(
                'DAÑO A OBJETIVOS',
                _formatK(kpis.avgObjectiveDamage),
                'Daño medio/partida',
                GsColors.textPrimary,
              ),
              _buildKpiTile(
                'ORO POR MINUTO',
                kpis.avgGoldPerMin?.toStringAsFixed(0) ?? 'Sin datos',
                'Oro ganado',
                GsColors.textPrimary,
              ),
              _buildKpiTile(
                'SÚBDITOS POR MINUTO',
                kpis.avgCsPerMin?.toStringAsFixed(1) ?? 'Sin datos',
                'Línea + jungla',
                GsColors.textPrimary,
              ),
              _buildKpiTile(
                'VISIÓN POR MINUTO',
                kpis.avgVisionPerMin?.toStringAsFixed(2) ?? 'Sin datos',
                'Puntos de visión',
                GsColors.textPrimary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0x14FFFFFF)),
          const SizedBox(height: 16),

          // Two Breakdown Columns: Top Champions & Lanes Played
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Champions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOP CAMPEONES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: GsColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...analytics.topChampions.map((champ) {
                      final ratio = analytics.gamesCount == 0
                          ? 0.0
                          : champ.games / analytics.gamesCount;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: _NetworkPortrait(
                                url: champ.iconUrl,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              child: Text(
                                champ.name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: GsColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 6,
                                  backgroundColor: GsColors.surfaceElevated,
                                  color: champ.winrate >= 50
                                      ? GsColors.emerald
                                      : GsColors.crimson,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 75,
                              child: Text(
                                '${champ.kda.toStringAsFixed(1)} KDA · ${champ.winrate.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: champ.winrate >= 50
                                      ? GsColors.emerald
                                      : GsColors.crimson,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Lanes Played
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DISTRIBUCIÓN DE LÍNEAS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: GsColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...analytics.roleDistribution.map((role) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              _roleIcon(role.role),
                              size: 16,
                              color: GsColors.cyan,
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              child: Text(
                                role.role.label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: GsColors.textPrimary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: (role.percentage / 100).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  minHeight: 6,
                                  backgroundColor: GsColors.surfaceElevated,
                                  color: GsColors.cyan,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 75,
                              child: Text(
                                '${role.games}G · ${role.winrate.toStringAsFixed(0)}% WR',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: role.winrate >= 50
                                      ? GsColors.emerald
                                      : GsColors.crimson,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTile(
    String label,
    String value,
    String sub,
    Color valueColor,
  ) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: GsColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: GsColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(fontSize: 10, color: GsColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMatchHistorySection(
    List<ScoutMatchSummary> matches,
    LocalScoutState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded, size: 18, color: GsColors.cyan),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Historial de Partidas Combinado',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: GsColors.textPrimary,
                ),
              ),
            ),
            Text(
              '${matches.length} partidas cargadas',
              style: const TextStyle(fontSize: 12, color: GsColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (matches.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
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
              final isExpanded = _expandedMatchIds.contains(match.matchId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ModernMatchCard(
                  match: match,
                  isExpanded: isExpanded,
                  onToggleExpand: () {
                    _toggleExpand(match.matchId);
                    if (!match.hasFullDetails) {
                      ref
                          .read(localScoutProvider.notifier)
                          .selectMatch(match.matchId);
                    }
                  },
                ),
              );
            }).toList(),
          ),
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

  IconData _roleIcon(ScoutRole role) => switch (role) {
    ScoutRole.top => Icons.shield_outlined,
    ScoutRole.jungle => Icons.forest_outlined,
    ScoutRole.mid => Icons.bolt_outlined,
    ScoutRole.bottom => Icons.ads_click_outlined,
    ScoutRole.support => Icons.favorite_border_rounded,
    _ => Icons.help_outline_rounded,
  };

  String _formatK(num? val) {
    if (val == null || val == 0) return 'Sin datos';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toStringAsFixed(0);
  }
}

class _ModernMatchCard extends StatelessWidget {
  const _ModernMatchCard({
    required this.match,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  final ScoutMatchSummary match;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final isWin = match.isWin;
    final score = match.performanceScore?.value ?? 50;

    return Container(
      decoration: BoxDecoration(
        color: GsColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            // Collapsed Row
            InkWell(
              onTap: onToggleExpand,
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Solid Left Accent Stripe
                    Container(
                      width: 5,
                      color: isWin ? GsColors.emerald : GsColors.crimson,
                    ),
                    const SizedBox(width: 14),

                    // Result & Queue Info
                    SizedBox(
                      width: 130,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isWin
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                size: 13,
                                color: isWin
                                    ? GsColors.emerald
                                    : GsColors.crimson,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isWin ? 'VICTORIA' : 'DERROTA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                  color: isWin
                                      ? GsColors.emerald
                                      : GsColors.crimson,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            match.queueLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: GsColors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${match.durationMinutes.toStringAsFixed(0)} min',
                            style: const TextStyle(
                              fontSize: 10,
                              color: GsColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Champion Portrait with Level
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _NetworkPortrait(
                            url: match.championIconUrl,
                            size: 42,
                          ),
                        ),
                        if (match.championLevel != null)
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: GsColors.canvas,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '${match.championLevel}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: GsColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Spells / Loadout
                    if (match.spell1IconUrl != null ||
                        match.spell2IconUrl != null)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (match.spell1IconUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: _NetworkPortrait(
                                url: match.spell1IconUrl,
                                size: 16,
                              ),
                            ),
                          const SizedBox(height: 2),
                          if (match.spell2IconUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: _NetworkPortrait(
                                url: match.spell2IconUrl,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(width: 12),

                    // KDA & Main Stats
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${match.kills} / ',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: GsColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${match.deaths}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: GsColors.crimson,
                                ),
                              ),
                              Text(
                                ' / ${match.assists}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: GsColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${match.kdaRatio.toStringAsFixed(2)} KDA',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: GsColors.cyan,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 8,
                            children: [
                              Text(
                                '${match.cs} CS (${match.csm} CS/m)',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: GsColors.textSecondary,
                                ),
                              ),
                              if (match.killParticipation != null)
                                Text(
                                  '${match.killParticipation}% KP',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: GsColors.textSecondary,
                                  ),
                                ),
                              if (match.damage != null)
                                Text(
                                  '${(match.damage! / 1000).toStringAsFixed(1)}K DMG',
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

                    // 7-Item Build Row
                    Wrap(
                      spacing: 3,
                      children: match.items.map((itemId) {
                        return Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: GsColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: itemId > 0
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: _NetworkPortrait(
                                    url: match.patch == null
                                        ? null
                                        : 'https://ddragon.leagueoflegends.com/cdn/${match.patch}/img/item/$itemId.png',
                                    size: 22,
                                  ),
                                )
                              : null,
                        );
                      }).toList(),
                    ),
                    const SizedBox(width: 14),

                    // Performance Score Badge
                    Tooltip(
                      message:
                          match.performanceScore?.heuristicLabel ??
                          'GodSense Rating',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: score >= 70
                              ? GsColors.emeraldGlow
                              : score >= 50
                              ? GsColors.cyanGlow
                              : GsColors.crimsonGlow,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$score',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: score >= 70
                                    ? GsColors.emerald
                                    : score >= 50
                                    ? GsColors.cyan
                                    : GsColors.crimson,
                              ),
                            ),
                            const Text(
                              'SCORE',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: GsColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Expand / Collapse Chevron Button
                    Tooltip(
                      message: isExpanded
                          ? 'Ocultar equipos'
                          : 'Abrir detalle de partida',
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: GsColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Expanded 5v5 Scoreboard
            if (isExpanded) ...[
              const Divider(height: 1, color: Color(0x14FFFFFF)),
              if (match.participants.isNotEmpty)
                _buildExpandedScoreboard(match)
              else
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Detalles completos de participantes no sincronizados para esta partida histórica.',
                    style: TextStyle(fontSize: 11, color: GsColors.textMuted),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedScoreboard(ScoutMatchSummary match) {
    final allies = match.participants.where((p) => p.isAlly).toList();
    final enemies = match.participants.where((p) => !p.isAlly).toList();

    Widget teamColumn(
      String title,
      List<ScoutMatchParticipant> team,
      bool isWin,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: isWin ? const Color(0x1A10B981) : const Color(0x1AEF4444),
            child: Row(
              children: [
                Icon(
                  isWin ? Icons.emoji_events_rounded : Icons.close_rounded,
                  size: 14,
                  color: isWin ? GsColors.emerald : GsColors.crimson,
                ),
                const SizedBox(width: 6),
                Text(
                  '$title · ${isWin ? 'VICTORIA' : 'DERROTA'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isWin ? GsColors.emerald : GsColors.crimson,
                  ),
                ),
              ],
            ),
          ),
          ...team.map((player) {
            return Container(
              color: player.isSubject ? GsColors.cyanGlow : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: _NetworkPortrait(
                      url: player.championIconUrl,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${player.name}#${player.tag}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: player.isSubject
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: player.isSubject
                            ? GsColors.cyan
                            : GsColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${player.kills}/${player.deaths}/${player.assists}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: GsColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${player.cs} CS',
                    style: const TextStyle(
                      fontSize: 10,
                      color: GsColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(player.damage / 1000).toStringAsFixed(1)}K',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: GsColors.cyan,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: teamColumn('Tu Equipo', allies, match.isWin)),
          const SizedBox(width: 12),
          Expanded(child: teamColumn('Equipo Rival', enemies, !match.isWin)),
        ],
      ),
    );
  }
}
