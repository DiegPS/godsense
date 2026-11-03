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
  bool _showSearchErrors = false;

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
    final hasRelationships =
        analytics != null &&
        (analytics.recentTeammates.isNotEmpty ||
            analytics.recentOpponents.isNotEmpty);
    final matches = state.typedMatches;
    final subjectKey = subject == null
        ? null
        : '${subject.puuid.value}:${subject.platformId.value}';
    if (_visibleSubjectKey != subjectKey) {
      _visibleSubjectKey = subjectKey;
      _visibleMatchCount = _matchPageSize;
      _expandedMatchIds.clear();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GsFeaturePage(
          children: [
            const ScoutProfileSelector(),
            const SizedBox(height: 16),
            _buildSearchAndProfile(state, analytics),
            const SizedBox(height: 14),

            // 2. Empty State when no profile is available
            if (subject == null && state.profile.isEmpty && !state.loading)
              _buildEmptyState(),

            if (subject != null || state.profile.isNotEmpty) ...[
              UiSplitView(
                breakpoint: hasRelationships ? 1020 : double.infinity,
                primaryFraction: .66,
                spacing: 20,
                primary: UiFormFields(
                  children: [
                    if (analytics != null) _buildPerformanceSummary(analytics),
                    _buildMatchHistorySection(matches, state),
                  ],
                ),
                secondary: !hasRelationships
                    ? const SizedBox.shrink()
                    : UiFormFields(
                        children: [
                          if (analytics.recentTeammates.isNotEmpty)
                            _buildRelationshipTable(
                              title: 'Compañeros Recientes',
                              subtitle: 'Aliados en partidas analizadas',
                              icon: Icons.group_outlined,
                              relationships: analytics.recentTeammates,
                            ),
                          if (analytics.recentOpponents.isNotEmpty)
                            _buildRelationshipTable(
                              title: 'Rivales Recientes',
                              subtitle:
                                  'Enfrentamientos en partidas analizadas',
                              icon: Icons.sports_kabaddi_outlined,
                              relationships: analytics.recentOpponents,
                            ),
                        ],
                      ),
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
                        'No pudimos actualizar este perfil. ${state.lastError}',
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

  Widget _buildSearchAndProfile(
    LocalScoutState state,
    ScoutProfileAnalytics? analytics,
  ) {
    final search = KeyedSubtree(
      key: const ValueKey('scout-search-console'),
      child: _buildSearchConsole(state),
    );
    if (state.subjectAccount == null && state.profile.isEmpty) return search;
    final profile = _buildHeroProfileHeader(state, analytics);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (constraints.maxWidth >= 820 * scale) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: profile),
              const SizedBox(width: 16),
              SizedBox(width: 460 * scale, child: search),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [search, const SizedBox(height: 14), profile],
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
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            GsInput(
              width: 200,
              controller: _gameName,
              labelText: 'Nombre de Riot',
              hintText: 'Ej. Hide on bush',
              errorText: _showSearchErrors && _gameName.text.trim().isEmpty
                  ? 'Escribe el nombre de Riot.'
                  : null,
              onChanged: (_) => _clearSearchErrors(),
              prefixIcon: Icons.sports_esports_outlined,
              textInputAction: TextInputAction.next,
            ),
            GsInput(
              width: 90,
              controller: _tagLine,
              labelText: 'Tag',
              hintText: 'Ej. LAN',
              errorText:
                  _showSearchErrors &&
                      _tagLine.text.trim().replaceFirst('#', '').isEmpty
                  ? 'Escribe el tag.'
                  : null,
              onChanged: (_) => _clearSearchErrors(),
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
                    color: GsColors.accent,
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
                  color: GsColors.accent,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return const GsCard(
      padding: EdgeInsets.zero,
      child: UiEmptyState(
        icon: Icons.travel_explore_rounded,
        title: 'Selecciona un perfil para comenzar',
        description: 'Elige un perfil guardado para consultar sus datos sin conexión. Para buscar un Riot ID nuevo o actualizar su historial, abre League.',
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

    final identity = Row(
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
                      color: GsColors.accent,
                    ),
                  ),
                  if (analytics != null &&
                      analytics.roleDistribution.isNotEmpty) ...[
                    const Text(
                      '·',
                      style: TextStyle(color: GsColors.textMuted, fontSize: 11),
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
      ],
    );
    final form = recentForm.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                      color: formWr >= 50 ? GsColors.emerald : GsColors.crimson,
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
                      color: won ? GsColors.emerald : GsColors.crimson,
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
          );
    return Container(
      key: const ValueKey('scout-profile-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: GsColors.surface,
        borderRadius: BorderRadius.circular(GsSizes.radius + 2),
        border: Border.all(color: GsColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          if (form != null && constraints.maxWidth >= 540 * scale) {
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 16),
                form,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              identity,
              if (form != null) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: form),
              ],
            ],
          );
        },
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
                bottom: BorderSide(color: GsColors.border, width: 1),
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
          UiMetricGrid(
            minimumItemWidth: 180,
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
                GsColors.accent,
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
          const Divider(height: 1, color: GsColors.border),
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
                              color: GsColors.accent,
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
                                  color: GsColors.accent,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: GsColors.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          sub,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: GsColors.textSecondary),
        ),
      ],
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
            const Icon(Icons.history_rounded, size: 18, color: GsColors.accent),
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
    if (gameName.isEmpty || tagLine.isEmpty) {
      setState(() => _showSearchErrors = true);
      return;
    }
    if (_showSearchErrors) setState(() => _showSearchErrors = false);
    ref
        .read(localScoutProvider.notifier)
        .searchRiotId(gameName: gameName, tagLine: tagLine);
  }

  void _clearSearchErrors() {
    if (_showSearchErrors) setState(() => _showSearchErrors = false);
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
    final accentColor = isWin ? GsColors.emerald : GsColors.crimson;
    final cardBg = GsColors.surface;
    final cardBorder = GsColors.border;

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
            ColoredBox(
              color: isWin ? GsColors.emeraldGlow : GsColors.crimsonGlow,
              child: _buildSummary(context, score, accentColor),
            ),

            // Expanded 5v5 Scoreboard
            if (isExpanded) ...[
              const Divider(height: 1, color: GsColors.border),
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

  Widget _buildSummary(BuildContext context, int score, Color accentColor) {
    final isWin = match.isWin;
    final result = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isWin ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 13,
              color: isWin ? GsColors.emerald : GsColors.crimson,
            ),
            const SizedBox(width: 4),
            Text(
              isWin ? 'VICTORIA' : 'DERROTA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: isWin ? GsColors.emerald : GsColors.crimson,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          match.queueLabel,
          style: const TextStyle(fontSize: 10, color: GsColors.textMuted),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${match.durationMinutes.toStringAsFixed(0)} min',
          style: const TextStyle(fontSize: 10, color: GsColors.textSecondary),
        ),
      ],
    );
    final portrait = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _NetworkPortrait(url: match.championIconUrl, size: 42),
        ),
        if (match.championLevel != null)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
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
    );
    final spells = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (match.spell1IconUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: _NetworkPortrait(
              url: match.spell1IconUrl,
              size: 16,
              fallback: Icons.bolt_outlined,
            ),
          ),
        const SizedBox(height: 2),
        if (match.spell2IconUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: _NetworkPortrait(
              url: match.spell2IconUrl,
              size: 16,
              fallback: Icons.bolt_outlined,
            ),
          ),
      ],
    );
    final stats = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
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
                color: GsColors.accent,
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
    );
    final items = Wrap(
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
                    url: scoutItemIcon(itemId),
                    fallbackUrls: [
                      if (match.patch != null)
                        'https://ddragon.leagueoflegends.com/cdn/'
                            '${match.patch!.split('.').length == 2 ? '${match.patch}.1' : match.patch}'
                            '/img/item/$itemId.png',
                    ],
                    size: 22,
                    fallback: Icons.inventory_2_outlined,
                  ),
                )
              : null,
        );
      }).toList(),
    );
    final rating = Tooltip(
      message: match.performanceScore?.heuristicLabel ?? 'GodSense Rating',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: score >= 70
              ? GsColors.emeraldGlow
              : score >= 50
              ? GsColors.accentTint
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
                    ? GsColors.accent
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
    );
    final chevron = Tooltip(
      message: isExpanded ? 'Ocultar equipos' : 'Abrir detalle de partida',
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
    );
    final loadout = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        portrait,
        if (match.spell1IconUrl != null || match.spell2IconUrl != null) ...[
          const SizedBox(width: 8),
          spells,
        ],
      ],
    );
    return InkWell(
      onTap: onToggleExpand,
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accentColor, width: 4)),
        ),
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 760 ||
                MediaQuery.textScalerOf(context).scale(14) > 18;
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: result),
                      const SizedBox(width: 12),
                      rating,
                      const SizedBox(width: 10),
                      chevron,
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      loadout,
                      const SizedBox(width: 12),
                      Expanded(child: stats),
                    ],
                  ),
                  const SizedBox(height: 12),
                  items,
                ],
              );
            }
            return Row(
              children: [
                SizedBox(width: 130, child: result),
                loadout,
                const SizedBox(width: 12),
                Expanded(child: stats),
                const SizedBox(width: 12),
                items,
                const SizedBox(width: 14),
                rating,
                const SizedBox(width: 10),
                chevron,
              ],
            );
          },
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
    final axisWidth = 48 * MediaQuery.textScalerOf(context).scale(10) / 10;
    final chartHeight = 112 * MediaQuery.textScalerOf(context).scale(10) / 10;

    Widget teamColumn(
      String title,
      List<ScoutMatchParticipant> team,
      bool isWin,
    ) {
      final color = isWin ? GsColors.emerald : GsColors.crimson;
      final tint = isWin ? GsColors.emeraldGlow : GsColors.crimsonGlow;
      final teamKills = team.fold<int>(0, (sum, p) => sum + p.kills);
      return LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
          final detailed = constraints.maxWidth >= 360 * scale;
          Widget metric(
            String text,
            double width, {
            Color? color,
            bool bold = false,
          }) => SizedBox(
            width: width * scale,
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                color: color ?? GsColors.textSecondary,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          );
          return Container(
            key: ValueKey('scout-team-$title-${match.matchId}'),
            decoration: BoxDecoration(
              color: GsColors.surface,
              border: Border.all(color: GsColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  color: tint,
                  child: Row(
                    children: [
                      Icon(
                        isWin
                            ? Icons.emoji_events_outlined
                            : Icons.shield_outlined,
                        color: color,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$title · ${isWin ? 'VICTORIA' : 'DERROTA'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Eliminaciones del equipo',
                        child: Text(
                          '$teamKills',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'JUGADOR',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: GsColors.textMuted,
                            letterSpacing: .6,
                          ),
                        ),
                      ),
                      metric('K / D / A', 76),
                      if (detailed) metric('CS', 42),
                      metric('DAÑO', 52),
                    ],
                  ),
                ),
                for (var index = 0; index < team.length; index++)
                  Container(
                    decoration: BoxDecoration(
                      color: team[index].isSubject
                          ? GsColors.accentTint
                          : index.isOdd
                          ? GsColors.surfaceElevated
                          : GsColors.surface,
                      border: Border(
                        left: BorderSide(
                          width: 3,
                          color: team[index].isSubject
                              ? GsColors.accent
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(9, 9, 12, 9),
                    child: Row(
                      children: [
                        _NetworkPortrait(
                          url: team[index].championIconUrl,
                          size: 30,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Tooltip(
                            message: '${team[index].name}#${team[index].tag}',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${team[index].name}#${team[index].tag}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: team[index].isSubject
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: team[index].isSubject
                                        ? GsColors.accent
                                        : GsColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  team[index].role.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: GsColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        metric(
                          '${team[index].kills}/${team[index].deaths}/${team[index].assists}',
                          76,
                          color: GsColors.textPrimary,
                          bold: true,
                        ),
                        if (detailed) metric('${team[index].cs}', 42),
                        metric(
                          '${(team[index].damage / 1000).toStringAsFixed(1)}K',
                          52,
                          color: GsColors.accent,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final ownTeam = teamColumn('Tu Equipo', allies, match.isWin);
              final rivalTeam = teamColumn(
                'Equipo Rival',
                enemies,
                !match.isWin,
              );
              final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
              if (constraints.maxWidth < 740 * scale) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [ownTeam, const SizedBox(height: 12), rivalTeam],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ownTeam),
                  const SizedBox(width: 12),
                  Expanded(child: rivalTeam),
                ],
              );
            },
          ),
          if (match.goldTimeline.isNotEmpty ||
              match.timelineEvents.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: GsColors.border),
            const SizedBox(height: 12),
            Text(
              'DESARROLLO DE LA PARTIDA',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: GsColors.textMuted, letterSpacing: 0.5),
            ),
            if (match.goldTimeline.length > 1) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GsColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: GsColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        const Text(
                          'Diferencia de oro',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: GsColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${match.goldTimeline.last.difference >= 0 ? '+' : ''}'
                          '${match.goldTimeline.last.difference} oro',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: match.goldTimeline.last.difference >= 0
                                ? GsColors.emerald
                                : GsColors.crimson,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        SizedBox(
                          width: axisWidth,
                          height: chartHeight,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '+${(_scoutGoldRange(match.goldTimeline) / 1000).toStringAsFixed(1)}k',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: GsColors.textMuted,
                                ),
                              ),
                              const Text(
                                '0',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: GsColors.textMuted,
                                ),
                              ),
                              Text(
                                '−${(_scoutGoldRange(match.goldTimeline) / 1000).toStringAsFixed(1)}k',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: GsColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: RepaintBoundary(
                            child: SizedBox(
                              height: chartHeight,
                              child: CustomPaint(
                                painter: _ScoutGoldTimelinePainter(
                                  match.goldTimeline,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: axisWidth, top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _timelineClock(
                              match.goldTimeline.first.timestampMilliseconds,
                            ),
                            style: const TextStyle(
                              fontSize: 10,
                              color: GsColors.textMuted,
                            ),
                          ),
                          const Flexible(
                            child: Text(
                              'Ventaja de tu equipo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: GsColors.textMuted,
                              ),
                            ),
                          ),
                          Text(
                            _timelineClock(
                              match.goldTimeline.last.timestampMilliseconds,
                            ),
                            style: const TextStyle(
                              fontSize: 10,
                              color: GsColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                      (event) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: GsColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: GsColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              event.type == 'CHAMPION_KILL'
                                  ? Icons.sports_martial_arts_rounded
                                  : Icons.flag_outlined,
                              size: 13,
                              color: event.isAlly == true
                                  ? GsColors.emerald
                                  : event.isAlly == false
                                  ? GsColors.crimson
                                  : GsColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${_timelineClock(event.timestampMilliseconds)} · ${event.label}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: GsColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
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

double _scoutGoldRange(List<ScoutGoldTimelinePoint> points) => points
    .fold<int>(
      500,
      (maximum, point) =>
          point.difference.abs() > maximum ? point.difference.abs() : maximum,
    )
    .toDouble();

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
    final maxDifference = _scoutGoldRange(points);
    final center = size.height / 2;
    final line = Path();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final offset = Offset(
        point.timestampMilliseconds / maxTime * size.width,
        center - point.difference / maxDifference * (center - 6),
      );
      if (index == 0) {
        line.moveTo(offset.dx, offset.dy);
      } else {
        line.lineTo(offset.dx, offset.dy);
      }
    }
    final area = Path.from(line)
      ..lineTo(points.last.timestampMilliseconds / maxTime * size.width, center)
      ..lineTo(
        points.first.timestampMilliseconds / maxTime * size.width,
        center,
      )
      ..close();
    for (final upper in [true, false]) {
      final color = upper ? GsColors.emerald : GsColors.crimson;
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(
          0,
          upper ? 0 : center,
          size.width,
          upper ? center : size.height,
        ),
      );
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: .10));
      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
    for (final y in [6.0, center, size.height - 6]) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = GsColors.border
          ..strokeWidth = y == center ? 1 : .5,
      );
    }
  }

  @override
  bool shouldRepaint(_ScoutGoldTimelinePainter oldDelegate) =>
      oldDelegate.points != points;
}
