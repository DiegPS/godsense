part of '../../app/godsense_app.dart';

class GodSenseApp extends StatelessWidget {
  const GodSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GodSense',
      debugShowCheckedModeBanner: false,
      theme: godsenseTheme(),
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
    final nativeLeague = ref.watch(nativeLeagueProvider);
    final overlayLayout = ref.watch(overlayLayoutProvider);
    ref.watch(nativeCalibrationProvider);
    ref.watch(nativeSpeechProvider);
    ref.watch(nativeVoiceCoachProvider);

    ref.listen(companionControllerProvider, (previous, next) {
      final alert = next.alerts.firstOrNull;
      if (alert != null && alert != previous?.alerts.firstOrNull) {
        ref.read(nativeVisionProvider.notifier).recordLegacy(alert);
      }
      overlayParityLogger.record(
        next,
        ref.read(nativeVisionProvider),
        ref.read(effectiveGameProvider),
      );
    });
    ref.listen(nativeVisionProvider, (previous, next) {
      final proposal = next.calibrationProposal;
      if (proposal != null && proposal != previous?.calibrationProposal) {
        unawaited(
          ref.read(nativeCalibrationProvider.notifier).saveDetected(proposal),
        );
      }
      overlayParityLogger.record(
        ref.read(companionControllerProvider),
        next,
        ref.read(effectiveGameProvider),
      );
    });
    ref.listen(nativeLeagueProvider, (previous, next) {
      overlayParityLogger.record(
        ref.read(companionControllerProvider),
        ref.read(nativeVisionProvider),
        ref.read(effectiveGameProvider),
      );
    });
    ref.listen(nativeLeagueProvider, (previous, next) {
      final game = next.liveGame == null
          ? null
          : GameSnapshot.fromJson(next.liveGame!);
      final calibration = ref.read(nativeCalibrationProvider).calibration;
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
            enabled: forceNativeVision || (game != null && !game.gameEnded),
            bounds: calibration?.trackingBounds,
            iconSize: calibration?.trackingIconSize ?? 28,
          );
    });
    ref.listen(nativeCalibrationProvider, (previous, next) {
      final calibration = next.calibration;
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
              iconSize: calibration?.trackingIconSize ?? 28,
            ),
      );
      ref
          .read(nativeVisionProvider.notifier)
          .configure(
            enabled: forceNativeVision || (game != null && !game.gameEnded),
            bounds: calibration?.trackingBounds,
            iconSize: calibration?.trackingIconSize ?? 28,
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
