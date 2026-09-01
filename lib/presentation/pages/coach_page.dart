part of '../../app/godsense_app.dart';

class CoachPage extends ConsumerStatefulWidget {
  const CoachPage({super.key});

  @override
  ConsumerState<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends ConsumerState<CoachPage> {
  String? _selectedEnemy;

  @override
  Widget build(BuildContext context) {
    final backend = ref.watch(companionControllerProvider);
    final nativeLeague = ref.watch(nativeLeagueProvider);
    final voiceCoach = ref.watch(nativeVoiceCoachProvider);
    final game = ref.watch(effectiveGameProvider);
    final lobby = ref.watch(effectiveLobbyProvider);
    final matchup = backend.coaching['matchup'];
    final matchupMap = matchup is Map ? matchup : const {};
    final teamComp = backend.coaching['team_comp'];
    final teamCompMap = teamComp is Map ? teamComp : const {};
    final builds =
        lobby?.builds ??
        (backend.coaching['builds'] is Map
            ? Map<String, dynamic>.from(backend.coaching['builds'] as Map)
            : null);
    final model = backend.localCoachHealth['opencode'];
    final modelMap = model is Map ? model : const {};
    final enemies =
        lobby?.enemyTeam
            .map((player) => player['champion_name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList() ??
        const <String>[];
    final selectedEnemy = enemies.contains(_selectedEnemy)
        ? _selectedEnemy
        : enemies.firstOrNull;
    final localChampion = lobby?.localPlayer?['champion_name']?.toString();
    final latestGank = backend.alerts
        .where((alert) => alert.kind == CompanionAlertKind.gank)
        .firstOrNull;
    final goldDifference = game?.raw['team_gold_diff'];
    final analysisWaiting =
        'Esperando análisis — elige un enemigo y pulsa Generar informe';
    final nativeSetupReady =
        nativeLeague.runeRecommendations != null ||
        nativeLeague.itemRecommendations != null;

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
                    'Coach',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    '${lobby?.phase ?? 'NO_LCU'} · ${lobby?.timerPhase ?? 'Esperando cliente'}',
                  ),
                  if (lobby?.timeLeftMilliseconds != null)
                    Text(
                      'Tiempo restante: ${_formatDuration(lobby!.timeLeftMilliseconds! / 1000)}',
                    ),
                ],
              ),
            ),
            Chip(
              avatar: const Icon(Icons.memory, size: 16),
              label: Text('Coach local: ${modelMap['state'] ?? 'offline'}'),
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
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedEnemy,
                    decoration: const InputDecoration(
                      labelText: 'Enemigo para el informe',
                      border: OutlineInputBorder(),
                    ),
                    items: enemies
                        .map(
                          (enemy) => DropdownMenuItem(
                            value: enemy,
                            child: Text(enemy),
                          ),
                        )
                        .toList(),
                    onChanged: enemies.isEmpty
                        ? null
                        : (value) => setState(() => _selectedEnemy = value),
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      selectedEnemy == null || backend.operationInProgress
                      ? null
                      : () => ref
                            .read(companionControllerProvider.notifier)
                            .generateLobbyBrief(selectedEnemy),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generar informe'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      nativeSetupReady &&
                          nativeLeague.lcuConnected &&
                          !nativeLeague.operationInProgress
                      ? () => ref
                            .read(nativeLeagueProvider.notifier)
                            .importCurrentRecommendations()
                      : null,
                  icon: const Icon(Icons.download),
                  label: const Text('Importar configuración Riot'),
                ),
                if (enemies.isEmpty)
                  const Text('Esperando un enemigo bloqueado o visible.'),
                if (backend.coachingStatus['matchup_refresh_in_progress'] ==
                    true)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Generando análisis…'),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _CoachPanel(
              title: 'Coach de voz local',
              icon: Icons.mic_none,
              child: voiceCoach.processing
                  ? const LinearProgressIndicator()
                  : voiceCoach.advice == null
                  ? const Text(
                      'Mantén pulsada la tecla configurada y formula una pregunta.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('“${voiceCoach.question}”'),
                        const SizedBox(height: 8),
                        Text(voiceCoach.advice!.ttsText),
                        const SizedBox(height: 8),
                        Text(
                          voiceCoach.advice!.evidence
                              .map((item) => item.source.name)
                              .toSet()
                              .join(' · '),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
            ),
            _CoachPanel(
              title: 'Amenazas de Gank',
              icon: Icons.warning_amber,
              child: Text(
                latestGank == null
                    ? 'Esperando a que empiece la partida…'
                    : '${latestGank.title}\n${latestGank.message}',
              ),
            ),
            _CoachPanel(
              title: 'Información del Enfrentamiento',
              icon: Icons.sports_martial_arts,
              child: matchupMap.isEmpty
                  ? Text(analysisWaiting)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(matchupMap['win_condition']?.toString() ?? ''),
                        ..._stringValues(matchupMap['trading_patterns'])
                            .map((item) => Text('• $item')),
                        ..._stringValues(matchupMap['avoid'])
                            .map((item) => Text('Evita: $item')),
                      ],
                    ),
            ),
            _CoachPanel(
              title: 'Builds Recomendadas',
              icon: Icons.build_outlined,
              child: builds == null
                  ? Text(analysisWaiting)
                  : _BuildsView(builds: builds),
            ),
            _CoachPanel(
              title: 'Runas del cliente de League',
              icon: Icons.auto_fix_high_outlined,
              child: nativeLeague.runeRecommendationsLoading
                  ? const LinearProgressIndicator()
                  : nativeLeague.runeRecommendations == null
                  ? Text(
                      nativeLeague.runeRecommendationsError ??
                          'Selecciona un campeón y una posición para cargar '
                              'las recomendaciones actuales.',
                    )
                  : _RuneRecommendationsView(
                      bundle: nativeLeague.runeRecommendations!,
                      importing: nativeLeague.operationInProgress,
                      onImport: (variant) => ref
                          .read(nativeLeagueProvider.notifier)
                          .importRuneRecommendation(variant),
                    ),
            ),
            _CoachPanel(
              title: 'Objetos recomendados por Riot',
              icon: Icons.inventory_2_outlined,
              child: nativeLeague.itemRecommendationsLoading
                  ? const LinearProgressIndicator()
                  : nativeLeague.itemRecommendations == null
                  ? Text(
                      nativeLeague.itemRecommendationsError ??
                          'Selecciona un campeón y una posición para cargar '
                              'su build actual.',
                    )
                  : _ItemRecommendationsView(
                      bundle: nativeLeague.itemRecommendations!,
                      importing: nativeLeague.operationInProgress,
                      onImport: () => ref
                          .read(nativeLeagueProvider.notifier)
                          .importItemRecommendations(),
                    ),
            ),
            _CoachPanel(
              title: 'Ruta de jungla de Riot',
              icon: Icons.route_outlined,
              child: nativeLeague.jungleRecommendationsLoading
                  ? const LinearProgressIndicator()
                  : nativeLeague.jungleRecommendations == null
                  ? Text(
                      nativeLeague.jungleRecommendationsError ??
                          'Esperando la versión instalada de League.',
                    )
                  : _JungleRecommendationsView(
                      bundle: nativeLeague.jungleRecommendations!,
                    ),
            ),
            _CoachPanel(
              title: 'Tu Enfrentamiento',
              icon: Icons.compare_arrows,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      _championLabel(localChampion),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const Text('VS'),
                  Expanded(
                    child: Text(
                      selectedEnemy ?? '???',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            _CoachPanel(
              title: 'Draft',
              icon: Icons.groups,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lobby?.allLocked == true
                        ? 'Todas las elecciones están bloqueadas'
                        : 'Esperando a que se bloqueen todas las elecciones '
                              '(${lobby?.lockedEnemyCount ?? 0}/5 enemigos bloqueados)',
                  ),
                  const SizedBox(height: 12),
                  const Text('Tu Equipo'),
                  _DraftRoster(players: lobby?.myTeam ?? const []),
                  const SizedBox(height: 8),
                  const Text('Equipo Enemigo'),
                  _DraftRoster(players: lobby?.enemyTeam ?? const []),
                ],
              ),
            ),
            _CoachPanel(
              title: 'Consejos de Pick',
              icon: Icons.recommend_outlined,
              child: lobby == null || lobby.pickAdvice.isEmpty
                  ? const Text('Esperando recomendaciones del draft…')
                  : _PickAdviceView(advice: lobby.pickAdvice),
            ),
            _CoachPanel(
              title: 'Diferencia de Oro',
              icon: Icons.monetization_on_outlined,
              child: Text(
                game == null
                    ? 'Esperando a que empiece la partida…'
                    : '${goldDifference ?? 0}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            _CoachPanel(
              title: 'Directivas',
              icon: Icons.record_voice_over_outlined,
              child: backend.directives.isEmpty
                  ? Text(
                      game?.raw['directives_pacing'] is Map &&
                              (game!.raw['directives_pacing']
                                      as Map)['capped'] ==
                                  true
                          ? 'Límite de directivas · siguiente espacio en '
                                '${_formatDuration(((game.raw['directives_pacing'] as Map)['next_slot_s'] as num?)?.toDouble() ?? 0)}'
                          : analysisWaiting,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: backend.directives
                          .map(
                            (directive) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(directive.title),
                              subtitle: Text(
                                directive.hints.isEmpty
                                    ? directive.rationale
                                    : directive.hints.join(' · '),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            _CoachPanel(
              title: 'Comparación de Equipos',
              icon: Icons.balance,
              child: lobby?.compAnalysis == null
                  ? const Text('Esperando datos de exploración...')
                  : _CompositionComparison(analysis: lobby!.compAnalysis!),
            ),
            _CoachPanel(
              title: 'Composición de Equipo',
              icon: Icons.hub_outlined,
              child: teamCompMap.isEmpty
                  ? Text(analysisWaiting)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teamCompMap['identity']?.toString() ?? '',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        ..._stringValues(teamCompMap['guidelines'])
                            .map((item) => Text('• $item')),
                        Text(
                          teamCompMap['teamfight_positioning']?.toString() ??
                              '',
                        ),
                      ],
                    ),
            ),
          ],
        ),
        if (backend.lastError != null) ...[
          const SizedBox(height: 16),
          Text(
            backend.lastError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (backend.lastOperationResult.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_operationResultDescription(backend.lastOperationResult)),
        ],
        if (nativeLeague.lastOperationResult.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_operationResultDescription(nativeLeague.lastOperationResult)),
        ],
      ],
    );
  }
}

String _buildDescription(Map<String, dynamic> builds) {
  final names = <String>[];

  void collect(Object? value) {
    if (value is Map) {
      final name = value['name'];
      if (name is String && name.isNotEmpty) names.add(name);
      for (final child in value.values) {
        collect(child);
      }
    } else if (value is List) {
      for (final child in value) {
        collect(child);
      }
    }
  }

  collect(builds);
  if (names.isNotEmpty) return names.toSet().take(12).join(' · ');
  return builds.keys.join(' · ');
}

class _CoachPanel extends StatelessWidget {
  const _CoachPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 380,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftRoster extends StatelessWidget {
  const _DraftRoster({required this.players});

  final List<Map<String, dynamic>> players;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const Text('Eligiendo…');
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: players.map((player) {
        final championId = (player['champion_id'] as num?)?.toInt() ?? 0;
        final locked = player['locked'] == true;
        final name = player['champion_name']?.toString();
        return Chip(
          avatar: locked && championId > 0
              ? _NetworkPortrait(
                  url:
                      'https://cdn.communitydragon.org/latest/champion/$championId/square',
                  size: 28,
                )
              : const Icon(Icons.hourglass_empty, size: 18),
          label: Text(
            '${name == null || name.isEmpty ? 'Eligiendo…' : name}'
            '${player['position']?.toString().isEmpty == false ? ' · ${player['position']}' : ''}',
          ),
        );
      }).toList(),
    );
  }
}

class _BuildsView extends StatelessWidget {
  const _BuildsView({required this.builds});

  final Map<String, dynamic> builds;

  @override
  Widget build(BuildContext context) {
    final variants = [
      'popular',
      'matchup',
      'alternative',
    ].where((key) => builds[key] is Map).toList();
    if (variants.isEmpty) return Text(_buildDescription(builds));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: variants.map((key) {
        final build = Map<String, dynamic>.from(builds[key] as Map);
        final groups = _asMapList(build['items']);
        return ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('${key.toUpperCase()} · ${build['build_type'] ?? ''}'),
          subtitle: Text(
            'Parche ${build['patch'] ?? '?'} · ${build['match_count'] ?? 0} partidas',
          ),
          children: [
            if (build['reasoning'] != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(build['reasoning'].toString()),
              ),
            for (final group in groups)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(group['category']?.toString() ?? 'Objetos'),
                subtitle: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _asMapList(group['items'])
                      .map(
                        (item) => Tooltip(
                          message:
                              '${item['name'] ?? 'Objeto'}\n${item['situational_hint'] ?? ''}',
                          child: _NetworkPortrait(
                            url: item['icon_url']?.toString(),
                            size: 38,
                            fallback: Icons.inventory_2_outlined,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        );
      }).toList(),
    );
  }
}

class _RuneRecommendationsView extends StatelessWidget {
  const _RuneRecommendationsView({
    required this.bundle,
    required this.importing,
    required this.onImport,
  });

  final RuneRecommendationBundle bundle;
  final bool importing;
  final ValueChanged<RuneRecommendationVariant> onImport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${bundle.position.lcuValue} · mapa ${bundle.mapId}'
          '${bundle.patch == null ? '' : ' · parche ${bundle.patch!.value}'}',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < bundle.variants.length; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Opción ${index + 1} · Keystone '
              '${bundle.variants[index].keystoneId}',
            ),
            subtitle: Text(
              [
                _recommendationAttribute(
                  bundle.variants[index].primaryAttribute,
                ),
                _recommendationAttribute(
                  bundle.variants[index].secondaryAttribute,
                ),
                'Hechizos ${bundle.variants[index].summonerSpellIds.join(' + ')}',
              ].where((value) => value.isNotEmpty).join(' · '),
            ),
            trailing: IconButton(
              tooltip: 'Importar esta página de runas',
              onPressed: importing
                  ? null
                  : () => onImport(bundle.variants[index]),
              icon: const Icon(Icons.download_outlined),
            ),
          ),
      ],
    );
  }
}

String _recommendationAttribute(String value) => switch (value) {
  'kCooldown' => 'Enfriamiento',
  'kMana' => 'Maná',
  'kHealing' => 'Curación',
  'kDamage' => 'Daño',
  _ => value,
};

class _ItemRecommendationsView extends StatelessWidget {
  const _ItemRecommendationsView({
    required this.bundle,
    required this.importing,
    required this.onImport,
  });

  final ItemRecommendationBundle bundle;
  final bool importing;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${bundle.position.lcuValue} · ${bundle.mode} · mapa ${bundle.mapId} '
          '· parche ${bundle.patch.value}',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < bundle.startingBundles.length; index++)
          _ItemRecommendationRow(
            title: 'Inicio ${index + 1}',
            items: bundle.startingBundles[index].items,
          ),
        for (var index = 0; index < bundle.purchaseRanges.length; index++)
          _ItemRecommendationRow(
            title:
                'Compra ${index + 1}'
                '${bundle.purchaseRanges[index].maxCompletedItems == null ? '' : ' · hasta ${bundle.purchaseRanges[index].maxCompletedItems} completos'}',
            items: bundle.purchaseRanges[index].items,
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.icon(
              onPressed: importing ? null : onImport,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Importar set'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Tooltip(
                message: bundle.sourceUri.toString(),
                child: Text(
                  bundle.positionSpecific
                      ? 'Fuente Riot · variante específica de posición'
                      : 'Fuente Riot · variante general del campeón',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ItemRecommendationRow extends StatelessWidget {
  const _ItemRecommendationRow({required this.title, required this.items});

  final String title;
  final List<RecommendedItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map(
                  (item) => Tooltip(
                    message: 'ID ${item.id}',
                    child: Chip(
                      avatar: const Icon(Icons.shield_outlined, size: 16),
                      label: Text(item.name),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _JungleRecommendationsView extends StatelessWidget {
  const _JungleRecommendationsView({required this.bundle});

  final JungleRecommendationBundle bundle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Map11 · parche ${bundle.patch.value}',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        _JungleRouteRow(route: bundle.order),
        const SizedBox(height: 12),
        _JungleRouteRow(route: bundle.chaos),
        const SizedBox(height: 8),
        Tooltip(
          message: bundle.sourceUri.toString(),
          child: Text(
            'Fuente: Map11.bin extraído del cliente de League',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class _JungleRouteRow extends StatelessWidget {
  const _JungleRouteRow({required this.route});

  final JungleRoute route;

  @override
  Widget build(BuildContext context) {
    final side = route.side == JungleSide.order ? 'ORDER' : 'CHAOS';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(side, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(route.camps.map((camp) => camp.name.split(' ').last).join(' → ')),
      ],
    );
  }
}

class _PickAdviceView extends StatelessWidget {
  const _PickAdviceView({required this.advice});

  final List<Map<String, dynamic>> advice;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: advice.map((suggestion) {
        final reasons = _asMapList(suggestion['reasons']);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(suggestion['champion']?.toString() ?? 'Campeón'),
          subtitle: Text(
            reasons
                .map(
                  (reason) => [
                    reason['kind'],
                    reason['enemy'],
                    reason['play'],
                    reason['trait'],
                    reason['tier'],
                  ].where((value) => value != null).join(' · '),
                )
                .join('\n'),
          ),
          trailing: suggestion['score'] == null
              ? null
              : Text('${suggestion['score']}'),
        );
      }).toList(),
    );
  }
}

class _CompositionComparison extends StatelessWidget {
  const _CompositionComparison({required this.analysis});

  final Map<String, dynamic> analysis;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ['ally', 'enemy'].map((side) {
        final profile = analysis[side] is Map
            ? Map<String, dynamic>.from(analysis[side] as Map)
            : const <String, dynamic>{};
        final axes = profile['axes'] is Map
            ? Map<String, dynamic>.from(profile['axes'] as Map)
            : const <String, dynamic>{};
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '${side == 'ally' ? 'Aliado' : 'Enemigo'} · ${profile['archetype'] ?? 'sin datos'}',
          ),
          subtitle: Wrap(
            spacing: 6,
            children: axes.entries
                .map(
                  (entry) => Chip(label: Text('${entry.key}: ${entry.value}')),
                )
                .toList(),
          ),
          trailing: Text('${profile['known'] ?? 0}/5'),
        );
      }).toList(),
    );
  }
}
