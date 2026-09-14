part of '../../app/godsense_app.dart';

class ScoutPage extends ConsumerStatefulWidget {
  const ScoutPage({super.key});

  @override
  ConsumerState<ScoutPage> createState() => _ScoutPageState();
}

class _ScoutPageState extends ConsumerState<ScoutPage> {
  static const _matchPageSize = 3;

  final _gameName = TextEditingController();
  final _tagLine = TextEditingController(text: 'LAN');
  final Set<int> _expandedMatchIds = {};
  int _visibleMatchCount = _matchPageSize;
  String? _visibleSubjectKey;

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
    final subjectKey = subject == null
        ? null
        : '${subject.puuid.value}:${subject.platformId.value}';
    if (_visibleSubjectKey != subjectKey) {
      _visibleSubjectKey = subjectKey;
      _visibleMatchCount = _matchPageSize;
      _expandedMatchIds.clear();
    }
    final activeAccount = ref.watch(
      nativeLeagueProvider.select(
        (league) => league.accountContext?.context?.account,
      ),
    );
    final leagueConnected = ref.watch(
      nativeLeagueProvider.select(
        (league) => league.accountContext?.lcuConnected ?? false,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1020;

        return ListView(
          padding: GsSizes.pageInsets(context),
          children: [
            // 1. Search Console Bar
            _buildSearchConsole(state),
            const SizedBox(height: 14),

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
                          _buildLinkedAccountCard(
                            activeAccount,
                            leagueConnected,
                          ),
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
                    _buildLinkedAccountCard(activeAccount, leagueConnected),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GsInput(
              width: 200,
              controller: _gameName,
              hintText: 'Nombre de Riot',
              prefixIcon: Icons.sports_esports_outlined,
              textInputAction: TextInputAction.next,
            ),
            GsInput(
              width: 90,
              controller: _tagLine,
              hintText: 'Tag',
              prefixText: '# ',
              textInputAction: TextInputAction.search,
              onSubmitted: state.loading ? null : (_) => _search(),
            ),
            GsButton(
              label: 'Buscar',
              icon: Icons.search_rounded,
              loading: state.loading,
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
            GsIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Actualizar historial local',
              onPressed: state.loading || state.refreshing
                  ? null
                  : () => ref.read(localScoutProvider.notifier).refresh(),
            ),
          ],
        ),
        if (state.loading || state.refreshing) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RepaintBoundary(
                child: SizedBox.square(
                  dimension: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: GsColors.cyan,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                state.loadingLabel ??
                    (state.refreshing
                        ? 'Actualizando en segundo plano'
                        : 'Cargando datos locales'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: GsColors.cyan,
                ),
              ),
            ],
          ),
        ],
      ],
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
    final profileData = state.profile;
    final name =
        state.subjectAccount?.riotId?.gameName ??
        profileData['game_name'] ??
        'Invocador';
    final tag =
        state.subjectAccount?.riotId?.tagLine ??
        profileData['tag_line'] ??
        'LAN';
    final iconUrl = state.subjectAccount?.profileIconId != null
        ? 'https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/profile-icons/${state.subjectAccount!.profileIconId}.jpg'
        : profileData['icon_url']?.toString();

    final rankMap = profileData['rank'] is Map
        ? profileData['rank'] as Map
        : const {};
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: GsColors.surface,
        borderRadius: BorderRadius.circular(GsSizes.radius + 2),
        border: Border.all(color: GsColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _NetworkPortrait(url: iconUrl, size: 52),
          ),
          const SizedBox(width: 14),

          // Name, Tag & Rank info (Clean flat typography, zero nested cards)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$name#$tag',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: GsColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '$tier $division · $lp LP',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                    if (analytics != null &&
                        analytics.roleDistribution.isNotEmpty) ...[
                      const Text(
                        '·',
                        style: TextStyle(
                          color: GsColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '${analytics.roleDistribution.first.role.label} Main (${analytics.roleDistribution.first.percentage.toStringAsFixed(0)}%)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: GsColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Recent Form (Streak Bar: clean flat segments, zero nested cards)
          if (recentForm.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'FORMA RECIENTE: ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: GsColors.textMuted,
                      ),
                    ),
                    Text(
                      '${formWins}W ${formLosses}L ($formWr% WR)',
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
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: recentForm.map((won) {
                    return Container(
                      width: 14,
                      height: 16,
                      margin: const EdgeInsets.only(left: 2),
                      decoration: BoxDecoration(
                        color: won
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        won ? 'W' : 'L',
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLinkedAccountCard(
    LeagueAccountProfile? account,
    bool leagueConnected,
  ) {
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
                              color: leagueConnected
                                  ? GsColors.emerald
                                  : GsColors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            leagueConnected
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
                Text(
                  '${rel.winrate.toStringAsFixed(0)}% WR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: rel.winrate >= 50
                        ? GsColors.emerald
                        : GsColors.crimson,
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
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildKpiTile(
                'RECENT WIN RATE',
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
                'DAÑO POR MINUTO',
                kpis.damagePerMinute?.toStringAsFixed(0) ?? 'Sin datos',
                'A campeones · ${_formatK(kpis.avgDamage)} por partida',
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
                'OBJETIVOS POR MINUTO',
                kpis.objectiveDamagePerMinute?.toStringAsFixed(0) ??
                    'Sin datos',
                '${_formatK(kpis.avgObjectiveDamage)} por partida',
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
              _buildKpiTile(
                'DAÑO DEL EQUIPO',
                kpis.damageShare == null
                    ? 'Sin datos'
                    : '${kpis.damageShare!.toStringAsFixed(1)}%',
                'Solo partidas con equipo completo',
                GsColors.textPrimary,
              ),
              _buildKpiTile(
                'ORO DEL EQUIPO',
                kpis.goldShare == null
                    ? 'Sin datos'
                    : '${kpis.goldShare!.toStringAsFixed(1)}%',
                'Proporción de recursos ganados',
                GsColors.textPrimary,
              ),
              _buildKpiTile(
                'EFICIENCIA DE DAÑO',
                kpis.damageEfficiency?.toStringAsFixed(2) ?? 'Sin datos',
                'Proporción de daño / proporción de oro',
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
    return SizedBox(
      width: 125,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: GsColors.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 1),
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
    final visibleMatches = matches
        .take(_visibleMatchCount)
        .toList(growable: false);
    final remainingMatches = matches.length - visibleMatches.length;
    final nextPageSize = remainingMatches.clamp(0, _matchPageSize);
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
            children: visibleMatches.map((match) {
              final isExpanded = _expandedMatchIds.contains(match.matchId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ModernMatchCard(
                  match: match,
                  isExpanded: isExpanded,
                  loadingDetails: state.loadingMatchIds.contains(match.matchId),
                  detailError: state.matchDetailErrors[match.matchId],
                  onRetryDetails: () => ref
                      .read(localScoutProvider.notifier)
                      .selectMatch(match.matchId),
                  onToggleExpand: () {
                    _toggleExpand(match.matchId);
                    if (!isExpanded && !match.hasFullDetails) {
                      ref
                          .read(localScoutProvider.notifier)
                          .selectMatch(match.matchId);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        if (visibleMatches.length < matches.length) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.center,
            child: GsButton(
              label:
                  'Mostrar $nextPageSize ${nextPageSize == 1 ? 'partida' : 'partidas'} más',
              icon: Icons.expand_more_rounded,
              variant: GsButtonVariant.secondary,
              onPressed: () =>
                  setState(() => _visibleMatchCount += _matchPageSize),
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
    required this.loadingDetails,
    required this.detailError,
    required this.onRetryDetails,
  });

  final ScoutMatchSummary match;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final bool loadingDetails;
  final String? detailError;
  final VoidCallback onRetryDetails;

  @override
  Widget build(BuildContext context) {
    final isWin = match.isWin;
    final score = match.performanceScore?.value ?? 50;
    final accentColor = isWin
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final cardBg = isWin ? const Color(0xFF071B14) : const Color(0xFF1C0A0E);
    final cardBorder = isWin
        ? const Color(0x3310B981)
        : const Color(0x33EF4444);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Column(
          children: [
            // Collapsed Row
            InkWell(
              onTap: onToggleExpand,
              child: SizedBox(
                height: 76,
                child: Row(
                  children: [
                    // Solid Left Accent Stripe
                    Container(
                      width: 4,
                      height: double.infinity,
                      color: accentColor,
                    ),
                    const SizedBox(width: 12),

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
                                  fontWeight: FontWeight.w700,
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
                                fontWeight: FontWeight.w700,
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
              if (loadingDetails)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('Cargando detalles de esta partida…'),
                      ),
                    ],
                  ),
                )
              else if (detailError != null || !match.hasFullDetails)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          detailError ?? 'Faltan los detalles de esta partida.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: GsColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: onRetryDetails,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar detalles'),
                      ),
                    ],
                  ),
                ),
              if (match.participants.isNotEmpty)
                _buildExpandedScoreboard(context, match),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedScoreboard(
    BuildContext context,
    ScoutMatchSummary match,
  ) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: teamColumn('Tu Equipo', allies, match.isWin)),
              const SizedBox(width: 12),
              Expanded(
                child: teamColumn('Equipo Rival', enemies, !match.isWin),
              ),
            ],
          ),
          if (match.goldTimeline.isNotEmpty ||
              match.timelineEvents.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0x14FFFFFF)),
            const SizedBox(height: 12),
            Text(
              'DESARROLLO DE LA PARTIDA',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: GsColors.textMuted, letterSpacing: 0.5),
            ),
            if (match.goldTimeline.length > 1) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: CustomPaint(
                  painter: _ScoutGoldTimelinePainter(match.goldTimeline),
                ),
              ),
            ],
            if (match.timelineEvents.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: match.timelineEvents
                    .where((event) => event.type != 'WARD_PLACED')
                    .take(12)
                    .map(
                      (event) => GsBadge(
                        label:
                            '${_timelineClock(event.timestampMilliseconds)} · ${event.label}',
                        variant: event.isAlly == true
                            ? GsBadgeVariant.success
                            : event.isAlly == false
                            ? GsBadgeVariant.danger
                            : GsBadgeVariant.neutral,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

String _timelineClock(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _ScoutGoldTimelinePainter extends CustomPainter {
  const _ScoutGoldTimelinePainter(this.points);

  final List<ScoutGoldTimelinePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final maxTime = points.last.timestampMilliseconds.toDouble().clamp(
      1,
      double.infinity,
    );
    final maxDifference = points
        .map((point) => point.difference.abs())
        .fold<int>(500, (maximum, value) => value > maximum ? value : maximum)
        .toDouble();
    final center = size.height / 2;
    canvas.drawLine(
      Offset(0, center),
      Offset(size.width, center),
      Paint()..color = const Color(0x28FFFFFF),
    );
    final positive = Path();
    final negative = Path();
    var positiveStarted = false;
    var negativeStarted = false;
    for (final point in points) {
      final offset = Offset(
        point.timestampMilliseconds / maxTime * size.width,
        center - point.difference / maxDifference * (center - 6),
      );
      final path = point.difference >= 0 ? positive : negative;
      final started = point.difference >= 0 ? positiveStarted : negativeStarted;
      if (!started) {
        path.moveTo(offset.dx, offset.dy);
        if (point.difference >= 0) {
          positiveStarted = true;
        } else {
          negativeStarted = true;
        }
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(
      positive,
      Paint()
        ..color = GsColors.emerald
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      negative,
      Paint()
        ..color = GsColors.crimson
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_ScoutGoldTimelinePainter oldDelegate) =>
      oldDelegate.points != points;
}
