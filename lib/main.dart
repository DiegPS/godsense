import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multiview_desktop/multiview_desktop.dart';
import 'package:url_launcher/url_launcher.dart';

import 'application/dependencies.dart';
import 'application/cv_corpus_comparator.dart';
import 'application/native_vision_controller.dart';
import 'application/native_league_controller.dart';
import 'application/overlay_layout_controller.dart';
import 'application/python_vision_diagnostics_controller.dart';
import 'domain/companion_models.dart';

final selectedPageProvider = StateProvider<int>((ref) => 0);
final trackerSourceProvider = StateProvider<TrackerSource>(
  (ref) => TrackerSource.python,
);
final overlayEnabledProvider = StateProvider<bool>((ref) => true);
final voiceEnabledProvider = StateProvider<bool>((ref) => true);
final overlayOpenProvider = StateProvider<bool>((ref) => false);

final appProviderContainer = ProviderContainer();
final overlayWindowManager = OverlayWindowManager(appProviderContainer);
final forceNativeVision =
    Platform.environment['GODSENSE_NATIVE_VISION_ALWAYS'] == '1';

enum TrackerSource { python, dartCv }

final effectiveGameProvider = Provider<GameSnapshot?>((ref) {
  final native = ref.watch(nativeLeagueProvider);
  if (native.liveGame != null) return GameSnapshot.fromJson(native.liveGame!);
  return ref.watch(companionControllerProvider).activeGame;
});

final effectiveLobbyProvider = Provider<LobbyState?>((ref) {
  final native = ref.watch(nativeLeagueProvider);
  if (native.lobby.isNotEmpty) return LobbyState.fromJson(native.lobby);
  return ref.watch(companionControllerProvider).lobby;
});

void main() {
  runMultiApp(
    home: (_, _) => const GodSenseApp(),
    globalScope: (child) => UncontrolledProviderScope(
      container: appProviderContainer,
      child: child,
    ),
    config: MultiAppConfig(
      generalParams: const MultiPlatformParams(
        closeMode: CloseMode.forceSecondary,
        enableDynamicAnchor: false,
      ),
      globalWindowOptions: const WindowOptions(
        size: Size(1200, 760),
        minimumSize: Size(900, 600),
        alignment: Alignment.center,
        title: 'GodSense',
      ),
      observers: [overlayWindowManager],
    ),
  );
}

class GodSenseApp extends StatelessWidget {
  const GodSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GodSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const GodSenseHome(),
    );
  }
}

class GodSenseHome extends ConsumerWidget {
  const GodSenseHome({super.key});

  static const destinations = [
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Overview'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.monitor_heart_outlined),
      selectedIcon: Icon(Icons.monitor_heart),
      label: Text('Live'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.visibility_outlined),
      selectedIcon: Icon(Icons.visibility),
      label: Text('Vision'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.psychology_outlined),
      selectedIcon: Icon(Icons.psychology),
      label: Text('Coach'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.manage_search_outlined),
      selectedIcon: Icon(Icons.manage_search),
      label: Text('Scout'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text('Settings'),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPage = ref.watch(selectedPageProvider);
    final overlayOpen = ref.watch(overlayOpenProvider);
    final backend = ref.watch(companionControllerProvider);
    final overlayLayout = ref.watch(overlayLayoutProvider);
    final trackerSource = ref.watch(trackerSourceProvider);
    final nativeLeague = ref.watch(nativeLeagueProvider);

    ref.listen(companionControllerProvider, (previous, next) {
      final game = ref.read(effectiveGameProvider);
      final activePlayer = game?.raw['active_player'];
      unawaited(
        ref
            .read(nativeVisionProvider.notifier)
            .configureTargets(
              game?.enemies ?? const [],
              localRole: activePlayer is Map
                  ? activePlayer['role']?.toString()
                  : null,
              iconSize: next.calibration?.trackingIconSize ?? 28,
            ),
      );
      ref
          .read(nativeVisionProvider.notifier)
          .configure(
            enabled:
                forceNativeVision ||
                next.activeGame != null ||
                trackerSource == TrackerSource.dartCv,
            bounds: next.calibration?.trackingBounds,
            iconSize: next.calibration?.trackingIconSize ?? 28,
          );
      final alert = next.alerts.firstOrNull;
      if (alert != null && alert != previous?.alerts.firstOrNull) {
        ref.read(nativeVisionProvider.notifier).recordLegacy(alert);
      }
    });
    ref.listen(nativeLeagueProvider, (previous, next) {
      final game = next.liveGame == null
          ? null
          : GameSnapshot.fromJson(next.liveGame!);
      final calibration = ref.read(companionControllerProvider).calibration;
      final activePlayer = game?.raw['active_player'];
      unawaited(
        ref
            .read(nativeVisionProvider.notifier)
            .configureTargets(
              game?.enemies ?? const [],
              localRole: activePlayer is Map
                  ? activePlayer['role']?.toString()
                  : null,
              iconSize: calibration?.trackingIconSize ?? 28,
            ),
      );
      ref
          .read(nativeVisionProvider.notifier)
          .configure(
            enabled:
                forceNativeVision ||
                game != null ||
                trackerSource == TrackerSource.dartCv,
            bounds: calibration?.trackingBounds,
            iconSize: calibration?.trackingIconSize ?? 28,
          );
    });
    ref.listen(trackerSourceProvider, (previous, next) {
      ref
          .read(nativeVisionProvider.notifier)
          .configure(
            enabled:
                forceNativeVision ||
                ref.read(effectiveGameProvider) != null ||
                next == TrackerSource.dartCv,
            bounds: backend.calibration?.trackingBounds,
            iconSize: backend.calibration?.trackingIconSize ?? 28,
          );
    });
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    final content = switch (selectedPage) {
      0 => const OverviewPage(),
      1 => const LivePage(),
      2 => const VisionPage(),
      3 => const CoachPage(),
      4 => const ScoutPage(),
      _ => const SettingsPage(),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('GodSense'),
        actions: [
          IconButton(
            tooltip: overlayOpen ? 'Close overlay' : 'Open overlay',
            onPressed: () => overlayWindowManager.toggle(context),
            icon: Icon(
              overlayOpen ? Icons.layers_clear_outlined : Icons.layers_outlined,
            ),
          ),
          IconButton(
            tooltip: overlayLayout.editing
                ? 'Terminar edición del overlay'
                : 'Editar paneles del overlay',
            onPressed: overlayOpen
                ? () => ref.read(overlayLayoutProvider.notifier).toggleEditing()
                : null,
            icon: Icon(
              overlayLayout.editing ? Icons.done : Icons.dashboard_customize,
            ),
          ),
          IconButton(
            tooltip: 'Restablecer paneles',
            onPressed: overlayOpen
                ? () => ref.read(overlayLayoutProvider.notifier).reset()
                : null,
            icon: const Icon(Icons.restart_alt),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: Icon(
                Icons.circle,
                size: 12,
                color: backend.connection == CompanionConnection.online
                    ? Colors.green
                    : Colors.orange,
              ),
              label: Text(_sessionLabel(backend, nativeLeague)),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1100,
              selectedIndex: selectedPage,
              onDestinationSelected: (value) {
                ref.read(selectedPageProvider.notifier).state = value;
              },
              destinations: destinations,
            ),
          if (isDesktop) const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: selectedPage,
              onDestinationSelected: (value) {
                ref.read(selectedPageProvider.notifier).state = value;
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: 'Overview',
                ),
                NavigationDestination(
                  icon: Icon(Icons.monitor_heart_outlined),
                  label: 'Live',
                ),
                NavigationDestination(
                  icon: Icon(Icons.visibility_outlined),
                  label: 'Vision',
                ),
                NavigationDestination(
                  icon: Icon(Icons.psychology_outlined),
                  label: 'Coach',
                ),
                NavigationDestination(
                  icon: Icon(Icons.manage_search_outlined),
                  label: 'Scout',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }
}

class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(companionControllerProvider);
    final game = ref.watch(effectiveGameProvider);
    final lobby = ref.watch(effectiveLobbyProvider);
    final coach = backend.localCoachHealth['opencode'];
    final coachMap = coach is Map ? coach : const {};
    final model = coachMap['model'];
    final modelMap = model is Map ? model : const {};
    final cv = backend.health?.components['cv'];
    final alerts = backend.alerts
        .where((alert) => alert.isVisibleAlert)
        .take(5);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Overview', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatusCard(
              title: 'League client',
              value: game != null
                  ? 'In game · ${game.phase}'
                  : lobby?.lcuConnected == true
                  ? lobby!.phase
                  : 'Not connected',
              icon: Icons.sports_esports,
            ),
            _StatusCard(
              title: 'Local coach',
              value:
                  modelMap['name']?.toString() ??
                  coachMap['state']?.toString() ??
                  'Checking',
              icon: Icons.psychology,
            ),
            _StatusCard(
              title: 'Vision tracker',
              value: cv == null
                  ? 'Unavailable'
                  : cv.alive
                  ? 'Running'
                  : cv.error ?? 'Stopped',
              icon: Icons.visibility,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Current session', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(
                  game == null
                      ? 'No active game'
                      : '${game.phase} · ${_formatGameTime(game.gameTime)}',
                ),
                subtitle: Text(
                  game == null
                      ? 'GodSense will start tracking when League game data is available.'
                      : '${game.allies.length} allies · ${game.enemies.length} enemies',
                ),
              ),
              const Divider(height: 1),
              if (alerts.isEmpty)
                const ListTile(
                  leading: Icon(Icons.notifications_none),
                  title: Text('No recent alerts'),
                  subtitle: Text('Live alerts arrive through /ws/alerts.'),
                )
              else
                for (final alert in alerts)
                  ListTile(
                    leading: Icon(
                      alert.kind == CompanionAlertKind.gank
                          ? Icons.warning_amber
                          : Icons.visibility,
                    ),
                    title: Text(alert.title),
                    subtitle: Text(alert.message),
                  ),
            ],
          ),
        ),
        if (backend.lastError != null) ...[
          const SizedBox(height: 12),
          Text(
            backend.lastError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class LivePage extends ConsumerWidget {
  const LivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(companionControllerProvider);
    final game = ref.watch(effectiveGameProvider) ?? state.game;
    final isEnded = game?.gameEnded == true;
    final derived = game?.raw['derived'] is Map
        ? Map<String, dynamic>.from(game!.raw['derived'] as Map)
        : const <String, dynamic>{};
    final objectives = derived['objectives'] is Map
        ? Map<String, dynamic>.from(derived['objectives'] as Map)
        : const <String, dynamic>{};
    final goldPoints = state.timeline['gold_points'] is List
        ? state.timeline['gold_points'] as List
        : const [];
    final timelineEvents = _asMapList(state.timeline['events']);
    final clips = _asMapList(state.highlights['clips'])
      ..sort(
        (a, b) =>
            ((a['slot'] as num?) ?? 0).compareTo((b['slot'] as num?) ?? 0),
      );
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
            _LiveMatchup(
              activePlayer: activePlayer,
              opponent: opponent,
              profiles: state.players,
            ),
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
        const SizedBox(height: 20),
        Text('Highlights', style: Theme.of(context).textTheme.titleLarge),
        Card(
          child: clips.isEmpty
              ? ListTile(
                  leading: const Icon(Icons.movie_outlined),
                  title: Text(
                    state.highlights['settled'] == false
                        ? 'Procesando highlights…'
                        : 'No hay clips para esta partida',
                  ),
                )
              : Column(
                  children: clips.map((clip) {
                    final slot = (clip['slot'] as num?)?.toInt() ?? 0;
                    return ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(
                        _highlightLabel(clip['event_type']?.toString()),
                      ),
                      subtitle: Text(
                        _formatGameTime(
                          (clip['game_time'] as num?)?.toDouble() ?? 0,
                        ),
                      ),
                      trailing: FilledButton(
                        onPressed: () => launchUrl(
                          ref
                              .read(companionControllerProvider.notifier)
                              .highlightClipUri(slot),
                        ),
                        child: const Text('Reproducir'),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

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

class VisionPage extends ConsumerWidget {
  const VisionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(trackerSourceProvider);
    final backend = ref.watch(companionControllerProvider);
    final game = ref.watch(effectiveGameProvider);
    final cv = backend.health?.components['cv'];
    final calibration = backend.calibration;
    final native = ref.watch(nativeVisionProvider);
    final pythonDiagnostics = ref.watch(pythonVisionDiagnosticsProvider);
    final corpus = ref.watch(cvCorpusComparatorProvider);
    final positionedEnemies = game?.enemies
        .where((enemy) => enemy['position'] is Map)
        .length;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Vision tracker',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Use the same interface to compare the current Python tracker with the DartCV implementation.',
        ),
        const SizedBox(height: 20),
        SegmentedButton<TrackerSource>(
          segments: const [
            ButtonSegment(
              value: TrackerSource.python,
              icon: Icon(Icons.cloud_outlined),
              label: Text('Python backend'),
            ),
            ButtonSegment(
              value: TrackerSource.dartCv,
              icon: Icon(Icons.memory),
              label: Text('DartCV native'),
            ),
          ],
          selected: {source},
          onSelectionChanged: (selection) {
            ref.read(trackerSourceProvider.notifier).state = selection.first;
          },
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.circle_outlined),
            title: Text(
              source == TrackerSource.python
                  ? 'Python tracker selected'
                  : 'DartCV tracker selected',
            ),
            subtitle: Text(
              source == TrackerSource.python
                  ? 'Status: ${cv?.alive == true ? 'running' : cv?.error ?? 'idle'} · Target: 6 FPS'
                  : 'Status: ${native.running
                            ? 'running'
                            : native.processing
                            ? 'capturing'
                            : 'idle'} · '
                        '${native.fps.toStringAsFixed(1)} FPS · '
                        'CV ${native.averageCvMilliseconds.toStringAsFixed(1)} ms avg / '
                        '${native.p95CvMilliseconds.toStringAsFixed(1)} ms p95 · '
                        'GDI ${native.averageCaptureMilliseconds.toStringAsFixed(1)} ms',
            ),
            trailing: Text(
              'Legacy ${positionedEnemies ?? 0} · Native ${native.frame?.detections.length ?? 0}',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Paridad determinista',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: corpus.running
                          ? null
                          : () => ref
                                .read(cvCorpusComparatorProvider.notifier)
                                .run(),
                      icon: corpus.running
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.compare),
                      label: const Text('Comparar corpus'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (corpus.error != null)
                  Text(
                    corpus.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Frames ${corpus.frames}')),
                      Chip(
                        label: Text(
                          'Precision ${(corpus.precision * 100).toStringAsFixed(2)}%',
                        ),
                      ),
                      Chip(
                        label: Text(
                          'Recall ${(corpus.recall * 100).toStringAsFixed(2)}%',
                        ),
                      ),
                      Chip(
                        label: Text(
                          'Identidad ${(corpus.identityAgreement * 100).toStringAsFixed(2)}%',
                        ),
                      ),
                      Chip(
                        label: Text(
                          'Boxes exactos ${corpus.exactBoxes}/${corpus.matchedBoxes}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          'IoU ${corpus.averageIou.toStringAsFixed(4)}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          'Δ confidence ${corpus.averageConfidenceDelta.toStringAsFixed(4)}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          'Δ TM ${corpus.averageTemplateDelta.toStringAsFixed(4)}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          'Δ hist ${corpus.averageHistogramDelta.toStringAsFixed(4)}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          'Dart ${corpus.averageDartMilliseconds.toStringAsFixed(2)} ms/frame',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: Icon(
              pythonDiagnostics.connected
                  ? Icons.check_circle
                  : Icons.error_outline,
              color: pythonDiagnostics.connected ? Colors.green : Colors.orange,
            ),
            title: const Text('Python TrackerEngine diagnóstico'),
            subtitle: Text(
              pythonDiagnostics.connected
                  ? '${pythonDiagnostics.status} · '
                        '${pythonDiagnostics.metrics['fps'] ?? 0} FPS · '
                        '${pythonDiagnostics.detections.length} detecciones'
                  : 'API 8430 desconectada. Inicia -CvDashboard.',
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _TrackerMetricsComparison(
                  native: native,
                  python: pythonDiagnostics,
                ),
              ),
            ],
          ),
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
                Text(_calibrationDescription(calibration)),
                FilledButton.icon(
                  onPressed: native.processing
                      ? null
                      : () => ref
                            .read(nativeVisionProvider.notifier)
                            .detectCalibration(),
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('Detectar nativo'),
                ),
                if (native.calibrationProposal != null)
                  FilledButton.icon(
                    onPressed: backend.operationInProgress
                        ? null
                        : () => ref
                              .read(companionControllerProvider.notifier)
                              .saveManualCalibration(
                                native.calibrationProposal!.bounds,
                              ),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar propuesta'),
                  ),
                OutlinedButton.icon(
                  onPressed:
                      calibration?.effectiveBounds == null || native.processing
                      ? null
                      : () => ref
                            .read(nativeVisionProvider.notifier)
                            .captureOnce(calibration!.effectiveBounds!),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Capturar ahora'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _VisionPreview(
              title: 'Captura del minimapa',
              bytes: native.frame?.capturePng,
            ),
            _VisionPreview(
              title: 'Máscara HSV roja',
              bytes: native.frame?.maskPng,
            ),
            _VisionPreview(
              title: 'Candidatos detectados',
              bytes: native.frame?.annotatedPng,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Previews Python exacto',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _VisionPreview(
              title: 'Python frame',
              bytes: pythonDiagnostics.framePng,
            ),
            _VisionPreview(
              title: 'Python máscara',
              bytes: pythonDiagnostics.maskPng,
            ),
            _VisionPreview(
              title: 'Python anotado',
              bytes: pythonDiagnostics.annotatedPng,
            ),
          ],
        ),
        if (native.calibrationProposal != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calibración nativa propuesta',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${native.calibrationProposal!.bounds} · '
                    'icon ${native.calibrationProposal!.iconSize}px · '
                    'confidence ${(native.calibrationProposal!.confidence * 100).toStringAsFixed(1)}%',
                  ),
                  const SizedBox(height: 8),
                  Image.memory(
                    native.calibrationProposal!.edgesPng,
                    height: 260,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
        ],
        if (native.error != null) ...[
          const SizedBox(height: 12),
          Text(
            native.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (native.frame != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in native.frame!.stageMicroseconds.entries)
                Chip(
                  label: Text(
                    '${entry.key}: ${(entry.value / 1000).toStringAsFixed(2)} ms',
                  ),
                ),
              Chip(
                label: Text(
                  'preview: ${(native.frame!.previewMicroseconds / 1000).toStringAsFixed(2)} ms',
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Comparación cronológica',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: native.logs.isEmpty
                  ? null
                  : () => ref.read(nativeVisionProvider.notifier).clearLogs(),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Limpiar'),
            ),
          ],
        ),
        Card(
          child: native.logs.isEmpty
              ? const ListTile(
                  title: Text('Sin detecciones todavía'),
                  subtitle: Text(
                    'Los eventos se guardan en tracker-comparison.jsonl.',
                  ),
                )
              : Column(
                  children: native.logs.take(50).map((entry) {
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        entry.source == TrackerLogSource.native
                            ? Icons.memory
                            : Icons.cloud_outlined,
                      ),
                      title: Text(
                        '${entry.source.name.toUpperCase()} · ${entry.event}',
                      ),
                      subtitle: Text(entry.message),
                      trailing: Text(_formatTimestamp(entry.timestamp)),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

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
                      builds != null &&
                          !backend.operationInProgress &&
                          !nativeLeague.operationInProgress
                      ? () => nativeLeague.lcuConnected
                            ? ref
                                  .read(nativeLeagueProvider.notifier)
                                  .importRecommendedSetup(builds)
                            : ref
                                  .read(companionControllerProvider.notifier)
                                  .importLobbySetup()
                      : null,
                  icon: const Icon(Icons.download),
                  label: const Text('Importar runas + build'),
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
                      backend.game?.raw['directives_pacing'] is Map &&
                              (backend.game!.raw['directives_pacing']
                                      as Map)['capped'] ==
                                  true
                          ? 'Límite de directivas · siguiente espacio en '
                                '${_formatDuration(((backend.game!.raw['directives_pacing'] as Map)['next_slot_s'] as num?)?.toDouble() ?? 0)}'
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

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _supportController = TextEditingController();
  double? _volume;

  @override
  void dispose() {
    _supportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overlayEnabled = ref.watch(overlayEnabledProvider);
    final backend = ref.watch(companionControllerProvider);
    final settings = backend.settings;
    final voiceEnabled =
        (settings?.ttsEnabled ?? ref.watch(voiceEnabledProvider)) == true;
    final meta = settings?.meta ?? const <String, dynamic>{};
    final locks = meta['locks'] is Map ? meta['locks'] as Map : const {};
    const panels = {
      'matchup_info': 'Enfrentamiento',
      'builds': 'Builds',
      'directives': 'Directivas',
      'team_comp': 'Composición',
      'gold_chart': 'Diferencia de oro',
      'gank': 'Amenazas',
      'jungler': 'Jungla enemigo',
      'voice_ask': 'Voz',
    };

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Ajustes', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Activar overlay'),
                subtitle: const Text('Mostrar información sobre League.'),
                value: overlayEnabled,
                onChanged: (value) async {
                  ref.read(overlayEnabledProvider.notifier).state = value;
                  if (value) {
                    await overlayWindowManager.open(context);
                  } else {
                    await overlayWindowManager.close();
                  }
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Activar voz del coach'),
                subtitle: const Text('Leer directivas importantes.'),
                value: voiceEnabled,
                onChanged: (value) {
                  ref.read(voiceEnabledProvider.notifier).state = value;
                  ref.read(companionControllerProvider.notifier).updateSettings(
                    {'tts_enabled': value},
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Tecla para hablar'),
                subtitle: locks.containsKey('ptt_key')
                    ? Text('Bloqueado por ${locks['ptt_key']}')
                    : null,
                trailing: DropdownButton<String>(
                  value: settings?.pttKey ?? 'delete',
                  items:
                      const [
                            'delete',
                            'f9',
                            'mouse4',
                            'mouse5',
                            'capslock',
                            'iso102',
                            'off',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.toUpperCase()),
                            ),
                          )
                          .toList(),
                  onChanged:
                      locks.containsKey('ptt_key') ||
                          backend.operationInProgress
                      ? null
                      : (value) => ref
                            .read(companionControllerProvider.notifier)
                            .updateSettings({'ptt_key': value}),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Volumen de voz'),
                subtitle: Slider(
                  value: _volume ?? settings?.ttsVolume ?? 1,
                  onChanged: backend.operationInProgress
                      ? null
                      : (value) => setState(() => _volume = value),
                  onChangeEnd: (value) {
                    ref
                        .read(companionControllerProvider.notifier)
                        .updateSettings({'tts_volume': value});
                    setState(() => _volume = null);
                  },
                ),
                trailing: FilledButton(
                  onPressed: backend.operationInProgress
                      ? null
                      : () => ref
                            .read(companionControllerProvider.notifier)
                            .testVoice(),
                  child: const Text('Probar'),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Idioma'),
                subtitle: meta['language_restart_required'] == true
                    ? const Text('Requiere reiniciar')
                    : null,
                trailing: DropdownButton<String>(
                  value: settings?.language ?? 'auto',
                  items: const ['auto', 'en', 'es']
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged:
                      locks.containsKey('language') ||
                          backend.operationInProgress
                      ? null
                      : (value) => ref
                            .read(companionControllerProvider.notifier)
                            .updateSettings({'language': value}),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Cadencia'),
                trailing: DropdownButton<String>(
                  value: settings?.cadence ?? 'normal',
                  items: const ['quiet', 'normal', 'chatty']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged:
                      meta['cadence_editable'] != true ||
                          backend.operationInProgress
                      ? null
                      : (value) => ref
                            .read(companionControllerProvider.notifier)
                            .updateSettings({'cadence': value}),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Highlights'),
                subtitle: Text(
                  meta['highlights_ready'] == true
                      ? 'Grabación disponible'
                      : 'Grabador no disponible',
                ),
                value: settings?.highlightsEnabled ?? false,
                onChanged:
                    meta['highlights_editable'] == true &&
                        !backend.operationInProgress
                    ? (value) => ref
                          .read(companionControllerProvider.notifier)
                          .updateSettings({'highlights_enabled': value})
                    : null,
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Calibración del minimapa'),
                subtitle: Text(_calibrationDescription(backend.calibration)),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: backend.operationInProgress
                          ? null
                          : () => _showManualCalibrationDialog(
                              context,
                              ref,
                              backend.calibration,
                            ),
                      child: const Text('Manual'),
                    ),
                    FilledButton(
                      onPressed: backend.operationInProgress
                          ? null
                          : () => ref
                                .read(companionControllerProvider.notifier)
                                .autoCalibrate(),
                      child: const Text('Detectar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Paneles del overlay',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Card(
          child: Column(
            children: panels.entries.map((entry) {
              final hidden =
                  settings?.overlayHiddenPanels.contains(entry.key) ?? false;
              return SwitchListTile(
                title: Text(entry.value),
                value: !hidden,
                onChanged: backend.operationInProgress
                    ? null
                    : (visible) {
                        final next = [...?settings?.overlayHiddenPanels];
                        if (visible) {
                          next.remove(entry.key);
                        } else if (!next.contains(entry.key)) {
                          next.add(entry.key);
                        }
                        ref
                            .read(companionControllerProvider.notifier)
                            .updateSettings({'overlay_hidden_panels': next});
                      },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Text('Salud', style: Theme.of(context).textTheme.titleLarge),
        Card(
          child: Column(
            children: const ['tick', 'gank', 'cv', 'tts', 'publisher'].map((
              name,
            ) {
              final component = backend.health?.components[name];
              return ListTile(
                leading: Icon(
                  component?.alive == true
                      ? Icons.check_circle
                      : Icons.error_outline,
                  color: component?.alive == true
                      ? Colors.green
                      : Colors.orange,
                ),
                title: Text(name),
                subtitle: Text(component?.error ?? 'Sin errores'),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Text('Soporte local', style: Theme.of(context).textTheme.titleLarge),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _supportController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Nota del reporte',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: backend.operationInProgress
                          ? null
                          : () => ref
                                .read(companionControllerProvider.notifier)
                                .createSupportBundle(),
                      child: const Text('Crear bundle'),
                    ),
                    FilledButton(
                      onPressed: backend.operationInProgress
                          ? null
                          : () => ref
                                .read(companionControllerProvider.notifier)
                                .reportSupport(_supportController.text),
                      child: const Text('Enviar reporte'),
                    ),
                  ],
                ),
                if (backend.supportResult.isNotEmpty)
                  SelectableText(_mapDescription(backend.supportResult)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class GodSenseOverlay extends ConsumerStatefulWidget {
  const GodSenseOverlay({super.key});

  @override
  ConsumerState<GodSenseOverlay> createState() => _GodSenseOverlayState();
}

class _GodSenseOverlayState extends ConsumerState<GodSenseOverlay> {
  late final Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(trackerSourceProvider);
    final backend = ref.watch(companionControllerProvider);
    final nativeVision = ref.watch(nativeVisionProvider);
    final game = ref.watch(effectiveGameProvider);
    final goldDifference = (game?.raw['team_gold_diff'] as num?)?.toInt();
    final sighting = backend.alerts
        .where((alert) => alert.kind == CompanionAlertKind.junglerSighting)
        .where((alert) => _now.difference(alert.receivedAt).inSeconds < 180)
        .firstOrNull;
    final gank = backend.alerts
        .where((alert) => alert.kind == CompanionAlertKind.gank)
        .where((alert) => _now.difference(alert.receivedAt).inSeconds < 5)
        .firstOrNull;
    final voice = backend.alerts
        .where((alert) => alert.kind == CompanionAlertKind.voice)
        .where((alert) {
          final state = alert.raw['state']?.toString();
          return state == 'recording' ||
              state == 'thinking' ||
              state == 'answering' ||
              _now.difference(alert.receivedAt).inSeconds < 8;
        })
        .firstOrNull;
    final visibilityEvent = backend.alerts
        .where((alert) => alert.kind == CompanionAlertKind.overlayVisibility)
        .firstOrNull;
    final layout = ref.watch(overlayLayoutProvider);
    final visible = layout.editing || visibilityEvent?.raw['visible'] != false;
    final enemies = game?.enemies ?? const <Map<String, dynamic>>[];
    final jungler = enemies
        .where((enemy) => enemy['role']?.toString().toUpperCase() == 'JUNGLE')
        .firstOrNull;
    final threats = [...enemies]
      ..sort((a, b) {
        final aJungle = a['role']?.toString().toUpperCase() == 'JUNGLE';
        final bJungle = b['role']?.toString().toUpperCase() == 'JUNGLE';
        if (aJungle != bJungle) return aJungle ? -1 : 1;
        final aMia = a['is_mia'] == true;
        final bMia = b['is_mia'] == true;
        if (aMia != bMia) return aMia ? -1 : 1;
        return 0;
      });
    final hiddenPanels = backend.settings?.overlayHiddenPanels ?? const [];
    final nativeBounds = nativeVision.bounds;
    final nativeRegions =
        nativeVision.frame?.detections
            .where((detection) => detection.championName != null)
            .map(
              (detection) => detection.regionFor(
                (nativeBounds?['width'] as num?)?.round() ?? 1,
                (nativeBounds?['height'] as num?)?.round() ?? 1,
              ),
            )
            .toSet()
            .join(' · ') ??
        '';
    final latestNativeEvent = nativeVision.events.firstOrNull;
    ref.listen(overlayLayoutProvider.select((state) => state.editing), (
      previous,
      editing,
    ) async {
      await MultiViewDesktop.of(context).setIgnoreMouseEvents(!editing);
      if (!editing) {
        await ref.read(overlayLayoutProvider.notifier).persist();
      }
    });

    ref.listen(
      companionControllerProvider.select((state) => state.alerts.firstOrNull),
      (previous, next) {
        if (next == previous || next?.kind != CompanionAlertKind.overlayEdit) {
          return;
        }
        ref
            .read(overlayLayoutProvider.notifier)
            .setEditing(next!.raw['edit'] == true);
      },
    );

    if (!visible) return const SizedBox.expand();

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          if (layout.editing)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.open_with),
                        const SizedBox(width: 8),
                        const Text(
                          'Modo edición: arrastra, redimensiona o colapsa paneles',
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () => ref
                              .read(overlayLayoutProvider.notifier)
                              .setEditing(false),
                          child: const Text('Terminar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          _EditableOverlayPanel(
            id: 'status',
            title: 'Estado',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('GodSense overlay'),
                    Text(
                      source == TrackerSource.python
                          ? 'Tracker: Python backend'
                          : 'Tracker: DartCV native',
                    ),
                    Text(
                      'Backend: ${backend.connection.name} · WS: ${backend.webSocketConnected ? 'live' : 'reconnecting'}',
                    ),
                  ],
                ),
              ),
            ),
          ),
          _EditableOverlayPanel(
            id: 'native_vision',
            title: 'Tracker nativo',
            child: Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.memory),
                    title: Text(
                      'DartCV · ${nativeVision.frame?.detections.where((detection) => detection.championName != null).length ?? 0} identificados '
                      '/ ${nativeVision.frame?.detections.length ?? 0} anillos',
                    ),
                    subtitle: Text(
                      nativeVision.error ??
                          '${nativeVision.fps.toStringAsFixed(1)} FPS · '
                              'CV ${nativeVision.averageCvMilliseconds.toStringAsFixed(1)} ms avg / '
                              '${nativeVision.p95CvMilliseconds.toStringAsFixed(1)} p95 · '
                              'GDI ${nativeVision.averageCaptureMilliseconds.toStringAsFixed(1)} ms · '
                              '${nativeVision.frame == null ? 'Esperando captura' : _formatTimestamp(nativeVision.frame!.processedAt)}'
                              '${nativeRegions.isEmpty ? '' : '\n$nativeRegions'}',
                    ),
                  ),
                  ...nativeVision.identified.values.map(
                    (identified) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.memory),
                      title: Text(identified.name),
                      subtitle: Text(
                        '${identified.region} · ${(identified.confidence * 100).toStringAsFixed(1)}% · '
                        '${_formatTimestamp(identified.lastSeen)}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (latestNativeEvent != null || layout.editing)
            _EditableOverlayPanel(
              id: 'native_alerts',
              title: 'Alertas nativas',
              child: Card(
                child: ListTile(
                  leading: Icon(
                    latestNativeEvent?.kind == NativeTrackerEventKind.gank
                        ? Icons.warning_amber
                        : Icons.visibility,
                  ),
                  title: Text(
                    latestNativeEvent == null
                        ? 'Esperando alerta nativa…'
                        : latestNativeEvent.kind == NativeTrackerEventKind.gank
                        ? 'Gank: ${latestNativeEvent.champion}'
                        : 'Jungla: ${latestNativeEvent.champion}',
                  ),
                  subtitle: latestNativeEvent == null
                      ? null
                      : Text(
                          '${latestNativeEvent.location} · ${latestNativeEvent.region} · '
                          '${_formatTimestamp(latestNativeEvent.timestamp)}',
                        ),
                ),
              ),
            ),
          if (gank != null || layout.editing)
            _EditableOverlayPanel(
              id: 'gank',
              title: 'Alerta de gank',
              child: Card(
                child: ListTile(
                  leading: Icon(
                    Icons.warning_amber,
                    color: gank?.raw['threat_level'] == 'DANGER'
                        ? Colors.red
                        : Colors.orange,
                  ),
                  title: Text(gank?.title ?? 'Amenaza de gank'),
                  subtitle: Text(
                    gank?.message ?? 'Esperando una amenaza de gank…',
                  ),
                ),
              ),
            ),
          if ((sighting != null || layout.editing) &&
              !hiddenPanels.contains('jungler'))
            _EditableOverlayPanel(
              id: 'sighting',
              title: 'Avistamiento',
              child: Card(
                child: ListTile(
                  leading: _NetworkPortrait(
                    url: sighting == null
                        ? null
                        : _championIconForAlert(sighting, enemies),
                    size: 48,
                  ),
                  title: Text(sighting?.title ?? 'Avistamiento del jungla'),
                  subtitle: Text(
                    sighting == null
                        ? 'Esperando un avistamiento…'
                        : '${sighting.message} · hace '
                              '${_formatDuration(_now.difference(sighting.receivedAt).inSeconds)}',
                  ),
                ),
              ),
            ),
          if (!hiddenPanels.contains('jungler'))
            _EditableOverlayPanel(
              id: 'jungler',
              title: 'Jungla enemigo',
              child: Card(
                child: ListTile(
                  leading: _NetworkPortrait(
                    url: jungler?['icon_url']?.toString(),
                    size: 56,
                  ),
                  title: Text(
                    '${jungler?['champion_name'] ?? 'Jungla enemigo'} · JUNGLE',
                  ),
                  subtitle: Text(
                    jungler == null
                        ? 'Esperando identificación del jungla…'
                        : _enemyLocationStatus(jungler),
                  ),
                  trailing: jungler?['is_mia'] == true
                      ? Text(
                          _formatDuration(
                            (jungler?['mia_duration'] as num?)?.toDouble() ?? 0,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          if (!hiddenPanels.contains('gank'))
            _EditableOverlayPanel(
              id: 'threats',
              title: 'Amenazas',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amenazas · ${threats.where((enemy) => enemy['is_mia'] == true).length} MIA',
                      ),
                      const Divider(),
                      if (threats.isEmpty)
                        const Text('Esperando enemigos de la partida…'),
                      for (final enemy in threats.take(5))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: _NetworkPortrait(
                            url: enemy['icon_url']?.toString(),
                            size: 36,
                          ),
                          title: Text(
                            '${enemy['champion_name'] ?? '?'} · ${enemy['role'] ?? ''}',
                          ),
                          subtitle: Text(_enemyLocationStatus(enemy)),
                          trailing: enemy['is_mia'] == true
                              ? Text(
                                  _formatDuration(
                                    (enemy['mia_duration'] as num?)
                                            ?.toDouble() ??
                                        0,
                                  ),
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if ((voice != null || layout.editing) &&
              !hiddenPanels.contains('voice_ask'))
            _EditableOverlayPanel(
              id: 'voice_ask',
              title: 'Coach de voz',
              child: Card(
                child: ListTile(
                  leading: Icon(
                    voice?.raw['state'] == 'recording'
                        ? Icons.mic
                        : voice?.raw['state'] == 'thinking'
                        ? Icons.psychology
                        : voice?.raw['state'] == 'error'
                        ? Icons.error_outline
                        : Icons.record_voice_over,
                  ),
                  title: Text(
                    voice?.raw['question']?.toString() ??
                        voice?.title ??
                        'Coach de voz',
                  ),
                  subtitle: Text(
                    voice == null
                        ? 'Esperando una interacción de voz…'
                        : _voiceMessage(voice),
                  ),
                ),
              ),
            ),
          if (!hiddenPanels.contains('matchup_info'))
            _EditableOverlayPanel(
              id: 'matchup_info',
              title: 'Enfrentamiento',
              child: _OverlayInfoCard(
                title: 'Enfrentamiento',
                width: 360,
                child: Text(
                  backend.coaching['matchup'] is Map
                      ? (backend.coaching['matchup'] as Map)['win_condition']
                                ?.toString() ??
                            'Esperando condición de victoria…'
                      : 'Esperando análisis del enfrentamiento…',
                ),
              ),
            ),
          if (!hiddenPanels.contains('builds'))
            _EditableOverlayPanel(
              id: 'builds',
              title: 'Build recomendada',
              child: _OverlayInfoCard(
                title: 'Build recomendada',
                width: 360,
                child: Text(
                  backend.coaching['builds'] is Map
                      ? _buildDescription(
                          Map<String, dynamic>.from(
                            backend.coaching['builds'] as Map,
                          ),
                        )
                      : 'Esperando build recomendada…',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          if (!hiddenPanels.contains('directives'))
            _EditableOverlayPanel(
              id: 'directives',
              title: 'Directivas',
              child: _OverlayInfoCard(
                title: 'Directivas',
                width: 360,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: backend.directives.isEmpty
                      ? const [Text('Esperando directivas…')]
                      : backend.directives
                            .take(3)
                            .map(
                              (directive) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('• ${directive.title}'),
                              ),
                            )
                            .toList(),
                ),
              ),
            ),
          if (!hiddenPanels.contains('team_comp'))
            _EditableOverlayPanel(
              id: 'team_comp',
              title: 'Composición',
              child: _OverlayInfoCard(
                title: 'Composición',
                width: 360,
                child: Text(
                  backend.coaching['team_comp'] is Map
                      ? (backend.coaching['team_comp'] as Map)['identity']
                                ?.toString() ??
                            'Esperando identidad…'
                      : 'Esperando composición del equipo…',
                ),
              ),
            ),
          if (gank != null && backend.calibration?.bounds != null)
            _CalibrationDangerRing(
              bounds: backend.calibration!.bounds!,
              danger: gank.raw['threat_level'] == 'DANGER',
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            ),
          if (!hiddenPanels.contains('gold_chart'))
            _EditableOverlayPanel(
              id: 'gold_chart',
              title: 'Diferencia de oro',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Diferencia de oro'),
                      Text(
                        goldDifference == null
                            ? 'Esperando partida…'
                            : _signedNumber(goldDifference),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color:
                                  goldDifference == null || goldDifference == 0
                                  ? null
                                  : goldDifference > 0
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class OverlayWindowManager extends WindowObserver {
  OverlayWindowManager(this.container);

  final ProviderContainer container;
  int? _viewId;
  Future<int>? _opening;

  Future<void> toggle(BuildContext ownerContext) async {
    if (_viewId != null &&
        MultiViewDesktop.allWindowViewIds.contains(_viewId)) {
      await close();
      return;
    }
    await open(ownerContext);
  }

  Future<int> open(BuildContext ownerContext) async {
    final existing = _viewId;
    if (existing != null &&
        MultiViewDesktop.allWindowViewIds.contains(existing)) {
      await MultiViewDesktop.fromId(existing).show();
      return existing;
    }

    final pending = _opening;
    if (pending != null) return pending;

    final ownerId = MultiViewDesktop.getIdByContext(ownerContext);
    final opening = openWindow(
      (_, _) => const GodSenseOverlay(),
      options: const WindowOptions(
        fullScreen: true,
        title: 'GodSense Overlay',
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        backgroundColor: Colors.transparent,
        alwaysOnTop: true,
      ),
      parentContext: ownerContext,
    );
    _opening = opening;

    try {
      final id = await opening;
      _viewId = id;
      final window = MultiViewDesktop.fromId(id);
      await window.setHasShadow(false);
      await window.setResizable(false);
      await window.setMovable(false);
      await window.setIgnoreMouseEvents(true);
      container.read(overlayOpenProvider.notifier).state = true;

      await MultiViewDesktop.fromId(ownerId).focus();
      return id;
    } finally {
      _opening = null;
    }
  }

  Future<void> close() async {
    final id = _viewId;
    if (id == null || !MultiViewDesktop.allWindowViewIds.contains(id)) {
      _viewId = null;
      container.read(overlayOpenProvider.notifier).state = false;
      return;
    }

    await MultiViewDesktop.fromId(id).closeWindow();
  }

  @override
  void onWindowClosed(int viewId) {
    if (_viewId != viewId) return;
    _viewId = null;
    container.read(overlayOpenProvider.notifier).state = false;
  }
}

String _sessionLabel(CompanionState state, NativeLeagueState native) {
  if (native.inGame) return 'League game active · native';
  if (native.lcuConnected) return '${native.gameflowPhase} · native';
  if (state.connection != CompanionConnection.online) return 'League offline';
  if (state.activeGame != null) return 'League game active · fallback';
  if (state.lobby?.lcuConnected == true) {
    return '${state.lobby!.phase} · fallback';
  }
  return 'Waiting for League';
}

String _formatGameTime(double seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds.floor() % 60;
  return '$minutes:${remaining.toString().padLeft(2, '0')}';
}

String _formatDuration(num seconds) => _formatGameTime(seconds.toDouble());

String _formatTimestamp(DateTime timestamp) {
  final local = timestamp.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  String three(int value) => value.toString().padLeft(3, '0');
  return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}.${three(local.millisecond)}';
}

String _calibrationDescription(CalibrationState? calibration) {
  if (calibration == null) return 'Waiting for backend calibration state.';
  if (!calibration.calibrated && calibration.defaultBounds == null) {
    return 'A live game is required to calibrate.';
  }
  if (calibration.calibrated &&
      !calibration.boundsAreUsable(calibration.bounds)) {
    final bad = calibration.bounds!;
    return 'Calibración inválida ${bad['width']}x${bad['height']}. '
        'Vuelve a calibrar manualmente.';
  }
  final bounds = calibration.effectiveBounds;
  if (bounds == null) return 'Calibration is active.';
  final source = calibration.calibrated
      ? 'calibración guardada'
      : calibration.defaultTrustworthy
      ? 'estimación confiable'
      : 'estimación provisional';
  return '$source · ${bounds['width']}x${bounds['height']} at '
      '${bounds['left']}, ${bounds['top']} · icon ${calibration.iconSize?.round() ?? '-'} px';
}

String _signedNumber(int value) => value > 0 ? '+$value' : '$value';

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

int _teamKills(List<Map<String, dynamic>> players) {
  return players.fold(0, (total, player) {
    final kda = player['kda'];
    return total +
        (kda is List && kda.isNotEmpty ? (kda.first as num?)?.toInt() ?? 0 : 0);
  });
}

int _teamGold(List<Map<String, dynamic>> players) {
  return players.fold(
    0,
    (total, player) => total + ((player['gold_total'] as num?)?.toInt() ?? 0),
  );
}

String _highlightLabel(String? eventType) {
  return switch (eventType) {
    'penta' => 'Pentakill',
    'quadra' => 'Quadrakill',
    'triple' => 'Triple kill',
    'double' => 'Double kill',
    'steal' => 'Robo de objetivo',
    'solo' => 'Eliminación en solitario',
    _ => eventType ?? 'Highlight',
  };
}

String _championIconForAlert(
  CompanionAlert alert,
  List<Map<String, dynamic>> enemies,
) {
  final champion = alert.raw['champion']?.toString();
  if (champion == null) return '';
  return enemies
          .where((enemy) => enemy['champion_name']?.toString() == champion)
          .firstOrNull?['icon_url']
          ?.toString() ??
      '';
}

String _enemyLocationStatus(Map<String, dynamic> enemy) {
  if (enemy['is_dead'] == true) {
    return 'Muerto · reaparece en ${_formatDuration((enemy['respawn_timer'] as num?)?.toDouble() ?? 0)}';
  }
  final current = enemy['map_location']?.toString();
  if (current != null && current.isNotEmpty) return 'Visto en $current';
  final duration = (enemy['mia_duration'] as num?)?.floor() ?? 0;
  final last = enemy['last_known_location']?.toString();
  if (enemy['is_mia'] == true) {
    return 'MIA ${_formatDuration(duration)}${last == null || last.isEmpty ? '' : ' · última vez en $last'}';
  }
  if (duration > 0 && last != null && last.isNotEmpty) {
    return 'Visto hace ${_formatDuration(duration)} en $last';
  }
  return 'Aún no visto';
}

String _voiceMessage(CompanionAlert alert) {
  final raw = alert.raw;
  final state = raw['state']?.toString();
  if (state == 'recording') return 'Escuchando…';
  if (state == 'thinking') return 'Pensando…';
  if (state == 'answering' || state == 'answer') {
    return raw['text']?.toString() ?? 'Respondiendo…';
  }
  if (state == 'error') {
    final detail = raw['detail'] is Map ? raw['detail'] as Map : const {};
    final suffix = detail.isEmpty
        ? ''
        : ' · ${detail.entries.map((entry) => '${entry.key}: ${entry.value}').join(', ')}';
    return '${raw['reason'] ?? 'Error'}$suffix';
  }
  return alert.message;
}

class _CalibrationDangerRing extends StatelessWidget {
  const _CalibrationDangerRing({
    required this.bounds,
    required this.danger,
    required this.devicePixelRatio,
  });

  final Map<String, dynamic> bounds;
  final bool danger;
  final double devicePixelRatio;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: ((bounds['left'] as num?)?.toDouble() ?? 0) / devicePixelRatio,
      top: ((bounds['top'] as num?)?.toDouble() ?? 0) / devicePixelRatio,
      width: ((bounds['width'] as num?)?.toDouble() ?? 0) / devicePixelRatio,
      height: ((bounds['height'] as num?)?.toDouble() ?? 0) / devicePixelRatio,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: danger ? Colors.red : Colors.orange,
              width: 5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _OverlayInfoCard extends StatelessWidget {
  const _OverlayInfoCard({
    required this.title,
    required this.width,
    required this.child,
  });

  final String title;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Divider(),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableOverlayPanel extends ConsumerWidget {
  const _EditableOverlayPanel({
    required this.id,
    required this.title,
    required this.child,
  });

  final String id;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(overlayLayoutProvider);
    final layout = state.panels[id];
    if (layout == null) return const SizedBox.shrink();
    final viewport = MediaQuery.sizeOf(context);
    final left = layout.x
        .clamp(0, (viewport.width - 44).clamp(0, double.infinity))
        .toDouble();
    final top = layout.y
        .clamp(0, (viewport.height - 44).clamp(0, double.infinity))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: layout.width.clamp(240, viewport.width - left).toDouble(),
      height: layout.collapsed
          ? 48
          : layout.height.clamp(80, viewport.height - top).toDouble(),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: state.editing
                  ? BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : const BoxDecoration(),
              child: layout.collapsed
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsets.only(top: state.editing ? 40 : 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          primary: false,
                          child: child,
                        ),
                      ),
                    ),
            ),
          ),
          if (state.editing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 40,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) => ref
                    .read(overlayLayoutProvider.notifier)
                    .move(id, details.delta, viewport),
                onPanEnd: (_) =>
                    ref.read(overlayLayoutProvider.notifier).persist(),
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.primaryContainer
                      .withValues(alpha: 0.9),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      const Icon(Icons.drag_indicator, size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(title, overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          layout.collapsed
                              ? Icons.expand_more
                              : Icons.expand_less,
                        ),
                        onPressed: () => ref
                            .read(overlayLayoutProvider.notifier)
                            .toggleCollapsed(id),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (state.editing && !layout.collapsed)
            Positioned(
              right: 0,
              bottom: 0,
              width: 30,
              height: 30,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) => ref
                    .read(overlayLayoutProvider.notifier)
                    .resize(id, details.delta, viewport),
                onPanEnd: (_) =>
                    ref.read(overlayLayoutProvider.notifier).persist(),
                child: const Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(Icons.drag_handle, size: 24),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _championLabel(String? champion) {
  return champion == null || champion.isEmpty ? '—' : champion;
}

List<String> _stringValues(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}

String _mapDescription(Map<dynamic, dynamic> map) {
  if (map.isEmpty) return 'Sin datos';
  return map.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n');
}

String _operationResultDescription(Map<String, dynamic> result) {
  final parts = <String>[];
  final runes = result['runes'];
  if (runes is Map && runes['page_name'] != null) {
    parts.add('Runas importadas: ${runes['page_name']}');
  }
  if (result['runes_error'] != null) {
    parts.add('Error de runas: ${result['runes_error']}');
  }
  final build = result['build'];
  if (build is Map && build['set_title'] != null) {
    parts.add('Build importada: ${build['set_title']}');
  }
  if (result['build_error'] != null) {
    parts.add('Error de build: ${result['build_error']}');
  }
  final failed = result['failed'];
  if (failed is Map && failed.isNotEmpty) {
    parts.add('No aplicado: ${_mapDescription(failed)}');
  }
  if (parts.isEmpty && result['ok'] == true) return 'Operación completada.';
  return parts.isEmpty ? _mapDescription(result) : parts.join('\n');
}

Future<void> _showManualCalibrationDialog(
  BuildContext context,
  WidgetRef ref,
  CalibrationState? calibration,
) async {
  final bounds = calibration?.bounds ?? const <String, dynamic>{};
  final left = TextEditingController(text: '${bounds['left'] ?? 0}');
  final top = TextEditingController(text: '${bounds['top'] ?? 0}');
  final width = TextEditingController(text: '${bounds['width'] ?? 300}');
  final height = TextEditingController(text: '${bounds['height'] ?? 300}');
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Calibración manual'),
      content: SizedBox(
        width: 420,
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _NumberField(controller: left, label: 'Izquierda'),
            _NumberField(controller: top, label: 'Arriba'),
            _NumberField(controller: width, label: 'Ancho'),
            _NumberField(controller: height, label: 'Alto'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final parsed = {
              'left': int.tryParse(left.text),
              'top': int.tryParse(top.text),
              'width': int.tryParse(width.text),
              'height': int.tryParse(height.text),
            };
            if (parsed.values.any((value) => value == null) ||
                (parsed['width'] ?? 0) <= 0 ||
                (parsed['height'] ?? 0) <= 0) {
              return;
            }
            Navigator.pop(context, parsed.cast<String, dynamic>());
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  left.dispose();
  top.dispose();
  width.dispose();
  height.dispose();
  if (result != null) {
    await ref
        .read(companionControllerProvider.notifier)
        .saveManualCalibration(result);
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
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
  const _LiveMatchup({
    required this.activePlayer,
    required this.opponent,
    required this.profiles,
  });

  final Map<String, dynamic> activePlayer;
  final Map<String, dynamic> opponent;
  final Map<String, dynamic> profiles;

  @override
  Widget build(BuildContext context) {
    final profile = profiles[opponent['champion_name']] is Map
        ? Map<String, dynamic>.from(profiles[opponent['champion_name']] as Map)
        : const <String, dynamic>{};
    final rank = profile['rank'] is Map
        ? Map<String, dynamic>.from(profile['rank'] as Map)
        : const <String, dynamic>{};
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
            if (rank.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.military_tech),
                title: Text(
                  '${rank['tier'] ?? ''} ${rank['division'] ?? ''} · ${rank['lp'] ?? 0} LP',
                ),
                subtitle: Text(
                  '${rank['wins'] ?? 0}W ${rank['losses'] ?? 0}L · ${rank['winrate'] ?? 0}% WR',
                ),
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

class _NetworkPortrait extends StatelessWidget {
  const _NetworkPortrait({
    required this.url,
    required this.size,
    this.fallback = Icons.person,
  });

  final String? url;
  final double size;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return SizedBox.square(dimension: size, child: Icon(fallback));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            SizedBox.square(dimension: size, child: Icon(fallback)),
      ),
    );
  }
}

class _VisionPreview extends StatelessWidget {
  const _VisionPreview({required this.title, required this.bytes});

  final String title;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AspectRatio(
              aspectRatio: 1,
              child: ColoredBox(
                color: Colors.black,
                child: bytes == null
                    ? const Center(
                        child: Text(
                          'Esperando captura…',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : Image.memory(
                        bytes!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackerMetricsComparison extends StatelessWidget {
  const _TrackerMetricsComparison({required this.native, required this.python});

  final NativeVisionState native;
  final PythonVisionDiagnosticsState python;

  @override
  Widget build(BuildContext context) {
    final metrics = python.metrics;
    String pythonValue(String key) {
      final value = metrics[key];
      if (value is num) return '${value.toStringAsFixed(2)} ms';
      return '—';
    }

    final rows = [
      (
        'Captura',
        '${native.averageCaptureMilliseconds.toStringAsFixed(2)} ms',
        pythonValue('capture_ms'),
      ),
      (
        'Detector',
        _nativeStage(native, 'mask', 'artifact_filter', 'ring_sweep'),
        pythonValue('detect_ms'),
      ),
      (
        'Clasificación',
        _nativeStage(native, 'classification'),
        pythonValue('score_ms'),
      ),
      (
        'Total actual',
        '${(native.averageCaptureMilliseconds + native.averageCvMilliseconds).toStringAsFixed(2)} ms',
        pythonValue('total_ms'),
      ),
      (
        'Promedio CV',
        '${native.averageCvMilliseconds.toStringAsFixed(2)} ms',
        pythonValue('average_ms'),
      ),
      (
        'P95 CV',
        '${native.p95CvMilliseconds.toStringAsFixed(2)} ms',
        pythonValue('p95_ms'),
      ),
      ('FPS', native.fps.toStringAsFixed(2), '${metrics['fps'] ?? '—'}'),
      (
        'Duty (1 core)',
        '${((native.averageCaptureMilliseconds + native.averageCvMilliseconds) * native.fps / 10).toStringAsFixed(2)}%',
        metrics['duty_percent'] is num
            ? '${(metrics['duty_percent'] as num).toStringAsFixed(2)}%'
            : '—',
      ),
      (
        'CPU proceso',
        'Incluido en Flutter',
        metrics['cpu_percent'] is num
            ? '${(metrics['cpu_percent'] as num).toStringAsFixed(2)}%'
            : '—',
      ),
      (
        'Working set',
        _formatBytes(native.workingSetBytes),
        metrics['working_set_bytes'] is num
            ? _formatBytes((metrics['working_set_bytes'] as num).toInt())
            : '—',
      ),
    ];
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.4),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
      },
      children: [
        const TableRow(
          children: [
            Padding(padding: EdgeInsets.all(6), child: Text('Métrica')),
            Padding(padding: EdgeInsets.all(6), child: Text('DartCV')),
            Padding(padding: EdgeInsets.all(6), child: Text('Python exacto')),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              Padding(padding: const EdgeInsets.all(6), child: Text(row.$1)),
              Padding(padding: const EdgeInsets.all(6), child: Text(row.$2)),
              Padding(padding: const EdgeInsets.all(6), child: Text(row.$3)),
            ],
          ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '—';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }

  String _nativeStage(
    NativeVisionState state,
    String first, [
    String? second,
    String? third,
  ]) {
    final stages = state.frame?.stageMicroseconds ?? const {};
    final microseconds =
        (stages[first] ?? 0) +
        (second == null ? 0 : stages[second] ?? 0) +
        (third == null ? 0 : stages[third] ?? 0);
    return '${(microseconds / 1000).toStringAsFixed(2)} ms';
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(value),
        ),
      ),
    );
  }
}
