part of '../../app/godsense_app.dart';

class GodSenseApp extends ConsumerWidget {
  const GodSenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'GodSense',
      debugShowCheckedModeBanner: false,
      theme: godsenseTheme(),
      home: GettingStartedGate(
        onDestination: (destination) =>
            ref.read(selectedPageProvider.notifier).state = destination,
        child: const GodSenseHome(),
      ),
    );
  }
}

class GodSenseHome extends ConsumerStatefulWidget {
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
  ConsumerState<GodSenseHome> createState() => _GodSenseHomeState();
}

class _GodSenseHomeState extends ConsumerState<GodSenseHome> {
  @override
  void initState() {
    super.initState();
    ref.read(visionSessionCoordinatorProvider);
    ref.read(companionControllerProvider);
    ref.read(nativeLeagueProvider);
    ref.read(nativeCalibrationProvider);
    ref.read(nativeSpeechProvider);
    ref.read(nativeVoiceCoachProvider);
    ref.read(aiRuntimeBootstrapProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        overlayWindowManager.setVisible(
          context,
          ref.read(overlayWindowVisibleProvider),
        ),
      );
    });
  }

  void _onToggleEditing() {
    final isEditing = ref.read(overlayLayoutProvider).editing;
    if (!isEditing) {
      ref.read(overlayLayoutProvider.notifier).setEditing(true);
    } else {
      ref.read(overlayLayoutProvider.notifier).setEditing(false);
      unawaited(ref.read(overlayLayoutProvider.notifier).persist());
    }
  }

  Future<void> _resetPanels() async {
    // The editing overlay is topmost; hide it so the main-window dialog can
    // receive clicks, then restore the current desired visibility on either path.
    await overlayWindowManager.hide();
    if (!mounted) return;
    try {
      if (await confirmHudReset(context) && mounted) {
        await ref.read(overlayLayoutProvider.notifier).reset();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar la distribución del HUD. Vuelve a intentarlo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        await overlayWindowManager.setVisible(
          context,
          ref.read(overlayWindowVisibleProvider),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPage = ref.watch(selectedPageProvider);
    final session = ref.watch(shellSessionStatusProvider);
    final overlayEditing = ref.watch(
      overlayLayoutProvider.select((layout) => layout.editing),
    );
    final speaking = ref.watch(
      nativeSpeechProvider.select((state) => state.ttsBusy),
    );

    ref.listen<bool>(overlayWindowVisibleProvider, (previous, visible) {
      if (previous == visible) return;
      unawaited(overlayWindowManager.setVisible(context, visible));
    });

    ref.listen(nativeVisionProvider, (previous, next) {
      final previousKeys =
          previous?.events.map(_nativeVisionEventKey).toSet() ??
          const <String>{};
      for (final event in next.events) {
        if (previousKeys.contains(_nativeVisionEventKey(event))) continue;
        final gameTime = ref.read(effectiveGameProvider)?.gameTime;
        final identified = next.lastKnown[event.champion];
        unawaited(
          ref
              .read(nativeLeagueProvider.notifier)
              .recordVisionObservation(
                VisionObservation(
                  kind: event.kind == NativeTrackerEventKind.gank
                      ? VisionObservationKind.gankThreat
                      : VisionObservationKind.enemySighting,
                  champion: event.champion,
                  location: event.location,
                  region: event.region,
                  role: event.role,
                  observedAt: event.timestamp,
                  confidence: identified?.confidence ?? 1,
                  gameTime: gameTime == null
                      ? null
                      : GameTime(
                          Duration(milliseconds: (gameTime * 1000).round()),
                        ),
                ),
              ),
        );
      }
      final proposal = next.calibrationProposal;
      if (proposal != null && proposal != previous?.calibrationProposal) {
        unawaited(
          ref.read(nativeCalibrationProvider.notifier).saveDetected(proposal),
        );
      }
    });
    final content = RetainedPageStack(
      index: selectedPage.clamp(0, 5),
      children: const [
        OverviewPage(),
        LivePage(),
        VisionPage(),
        CoachPage(),
        ScoutPage(),
        SettingsPage(),
      ],
    );

    return Scaffold(
      backgroundColor: GsColors.canvas,
      body: Stack(
        children: [
          Column(
            children: [
              _GodSenseCustomTitleBar(
                selectedPage: selectedPage,
                onSelectPage: (page) =>
                    ref.read(selectedPageProvider.notifier).state = page,
                overlayEditing: overlayEditing,
                onToggleEditing: _onToggleEditing,
                onResetPanels: overlayEditing ? _resetPanels : null,
                onStopSpeaking: speaking
                    ? () =>
                          ref.read(nativeSpeechProvider.notifier).stopSpeaking()
                    : null,
                onHelp: () async {
                  final destination = await showGettingStartedGuide(context);
                  if (context.mounted &&
                      destination != null &&
                      destination >= 0) {
                    ref.read(selectedPageProvider.notifier).state = destination;
                  }
                },
                sessionLabel: session.label,
                isOnline: session.online,
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: GsSizes.maxPageWidth,
                    ),
                    child: SizedBox.expand(child: content),
                  ),
                ),
              ),
            ],
          ),
          const _FramelessWindowResizeBorder(),
        ],
      ),
    );
  }
}

class _GodSenseCustomTitleBar extends StatelessWidget {
  const _GodSenseCustomTitleBar({
    required this.selectedPage,
    required this.onSelectPage,
    required this.overlayEditing,
    required this.onToggleEditing,
    required this.onResetPanels,
    this.onStopSpeaking,
    required this.onHelp,
    required this.sessionLabel,
    required this.isOnline,
  });
  final int selectedPage;
  final ValueChanged<int> onSelectPage;
  final bool overlayEditing;
  final VoidCallback onToggleEditing;
  final VoidCallback? onResetPanels;
  final VoidCallback? onStopSpeaking;
  final VoidCallback onHelp;
  final String sessionLabel;
  final bool isOnline;
  static const _navItems = [
    (icon: Icons.grid_view_rounded, label: 'Inicio'),
    (icon: Icons.sensors_rounded, label: 'En vivo'),
    (icon: Icons.visibility_outlined, label: 'Mapa'),
    (icon: Icons.psychology_outlined, label: 'Coach'),
    (icon: Icons.manage_search_rounded, label: 'Scout'),
    (icon: Icons.tune_rounded, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final showLabels =
          constraints.maxWidth >= 1100 &&
          MediaQuery.textScalerOf(context).scale(14) <= 20;
      return Material(
        color: GsColors.canvas,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: GsColors.border)),
          ),
          child: SizedBox(
            height: GsSizes.control(context) + 12,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (_) {
                      try {
                        MultiViewDesktop.of(context).startDragging();
                      } catch (_) {}
                    },
                    child: Row(
                      children: [
                        const DragToMoveArea(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.radar_rounded,
                                  color: GsColors.cyan,
                                  size: 24,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'GodSense',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        for (var index = 0; index < _navItems.length; index++)
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Semantics(
                              selected: selectedPage == index,
                              child: Tooltip(
                                message: _navItems[index].label,
                                child: TextButton(
                                  onPressed: () => onSelectPage(index),
                                  style:
                                      gsButtonStyle(
                                        context,
                                        variant: GsButtonVariant.ghost,
                                        compact: true,
                                      ).copyWith(
                                        textStyle: WidgetStatePropertyAll(
                                          Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        padding: const WidgetStatePropertyAll(
                                          EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 8,
                                          ),
                                        ),
                                        backgroundColor:
                                            WidgetStateProperty.resolveWith(
                                              (states) =>
                                                  states.contains(
                                                        WidgetState.hovered,
                                                      ) ||
                                                      states.contains(
                                                        WidgetState.pressed,
                                                      )
                                                  ? GsColors.cyanGlow
                                                  : Colors.transparent,
                                            ),
                                        foregroundColor: WidgetStatePropertyAll(
                                          selectedPage == index
                                              ? GsColors.cyan
                                              : GsColors.textSecondary,
                                        ),
                                        side: WidgetStateProperty.resolveWith(
                                          (states) => BorderSide(
                                            color:
                                                states.contains(
                                                  WidgetState.focused,
                                                )
                                                ? GsColors.cyanLight
                                                : Colors.transparent,
                                          ),
                                        ),
                                      ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_navItems[index].icon, size: 18),
                                          if (showLabels) ...[
                                            const SizedBox(width: 6),
                                            Text(_navItems[index].label),
                                          ],
                                        ],
                                      ),
                                      if (selectedPage == index)
                                        const Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: -9,
                                          child: SizedBox(
                                            height: 2,
                                            child: ColoredBox(
                                              color: GsColors.cyan,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: DragToMoveArea(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Tooltip(
                                message: sessionLabel,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: isOnline
                                          ? GsColors.emerald
                                          : GsColors.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        sessionLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isOnline
                                              ? GsColors.emerald
                                              : GsColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (onStopSpeaking != null)
                  GsIconButton(
                    icon: Icons.stop_circle_outlined,
                    tooltip: 'Detener voz',
                    onPressed: onStopSpeaking,
                    variant: GsButtonVariant.ghost,
                  ),
                if (overlayEditing)
                  GsIconButton(
                    icon: Icons.restart_alt_rounded,
                    tooltip: 'Restablecer HUD',
                    onPressed: onResetPanels,
                    variant: GsButtonVariant.ghost,
                  ),
                GsButton(
                  label: overlayEditing ? 'Guardar HUD' : 'Editar HUD',
                  icon: overlayEditing
                      ? Icons.check_rounded
                      : Icons.dashboard_customize_outlined,
                  variant: overlayEditing
                      ? GsButtonVariant.primary
                      : GsButtonVariant.secondary,
                  onPressed: onToggleEditing,
                  compact: true,
                ),
                const SizedBox(width: 4),
                GsIconButton(
                  icon: Icons.help_outline_rounded,
                  tooltip: 'Guía y atajos',
                  onPressed: onHelp,
                  variant: GsButtonVariant.ghost,
                ),
                const SizedBox(width: 4),
                const _CustomWindowControlButtons(),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _CustomWindowControlButtons extends StatefulWidget {
  const _CustomWindowControlButtons();

  @override
  State<_CustomWindowControlButtons> createState() =>
      _CustomWindowControlButtonsState();
}

class _CustomWindowControlButtonsState
    extends State<_CustomWindowControlButtons> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkMaximized());
  }

  MultiViewDesktop? _currentWindow() {
    try {
      return MultiViewDesktop.of(context);
    } catch (_) {
      return null;
    }
  }

  void _checkMaximized() {
    final win = _currentWindow();
    if (win == null) return;
    win.isMaximized().then((value) {
      if (mounted && value != _isMaximized) {
        setState(() => _isMaximized = value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowBtn(
          icon: Icons.remove,
          tooltip: 'Minimizar',
          onTap: () => _currentWindow()?.minimize(),
        ),
        _WindowBtn(
          icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
          iconSize: _isMaximized ? 11 : 13,
          tooltip: _isMaximized ? 'Restaurar' : 'Maximizar',
          onTap: () async {
            final win = _currentWindow();
            if (win != null) {
              if (await win.isMaximized()) {
                await win.unmaximize();
              } else {
                await win.maximize();
              }
              _checkMaximized();
            }
          },
        ),
        _WindowBtn(
          icon: Icons.close,
          tooltip: 'Cerrar',
          isClose: true,
          onTap: () {
            try {
              MultiViewDesktop.closeApp(closeMode: CloseMode.destroy);
            } catch (_) {}
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _WindowBtn extends StatelessWidget {
  const _WindowBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconSize = 14,
    this.isClose = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double iconSize;
  final bool isClose;
  @override
  Widget build(BuildContext context) {
    if (!isClose) {
      return GsIconButton(
        icon: icon,
        tooltip: tooltip,
        iconSize: iconSize,
        onPressed: onTap,
        variant: GsButtonVariant.ghost,
      );
    }
    return IconButton(
      icon: Icon(icon, size: iconSize),
      tooltip: tooltip,
      onPressed: onTap,
      style:
          gsButtonStyle(
            context,
            variant: GsButtonVariant.ghost,
            compact: true,
          ).copyWith(
            minimumSize: WidgetStatePropertyAll(
              Size.square(GsSizes.control(context)),
            ),
            padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.pressed)) {
                return Colors.white;
              }
              return GsColors.textSecondary;
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.pressed)) {
                return GsColors.crimson;
              }
              return Colors.transparent;
            }),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
    );
  }
}

class _FramelessWindowResizeBorder extends StatelessWidget {
  const _FramelessWindowResizeBorder();

  @override
  Widget build(BuildContext context) {
    const edgeSize = 4.0;
    const cornerSize = 8.0;

    return Stack(
      children: const [
        // Top edge
        Positioned(
          top: 0,
          left: cornerSize,
          right: cornerSize,
          height: edgeSize,
          child: DragToResizeArea(
            resizeEdge: ResizeEdge.top,
            child: SizedBox.expand(),
          ),
        ),
        // Bottom edge
        Positioned(
          bottom: 0,
          left: cornerSize,
          right: cornerSize,
          height: edgeSize,
          child: DragToResizeArea(
            resizeEdge: ResizeEdge.bottom,
            child: SizedBox.expand(),
          ),
        ),
        // Left edge
        Positioned(
          top: cornerSize,
          bottom: cornerSize,
          left: 0,
          width: edgeSize,
          child: DragToResizeArea(
            resizeEdge: ResizeEdge.left,
            child: SizedBox.expand(),
          ),
        ),
        // Right edge
        Positioned(
          top: cornerSize,
          bottom: cornerSize,
          right: 0,
          width: edgeSize,
          child: DragToResizeArea(
            resizeEdge: ResizeEdge.right,
            child: SizedBox.expand(),
          ),
        ),
        // Top Left Corner
        Positioned(
          top: 0,
          left: 0,
          width: cornerSize,
          height: cornerSize,
          child: DragToResizeArea(
            resizeEdge: ResizeEdge.topLeft,
            child: SizedBox.expand(),
          ),
        ),
        // Top Right Corner
        Positioned(
          top: 0,
          right: 0,
          width: cornerSize,
          height: cornerSize,
          child: DragToResizeArea(
            resizeEdge: ResizeEdge.topRight,
            child: SizedBox.expand(),
          ),
        ),
        // Bottom Left Corner
        Positioned(
          bottom: 0,
          left: 0,
          width: cornerSize,
          height: cornerSize,
          child: DragToResizeArea(
            resizeEdge: ResizeEdge.bottomLeft,
            child: SizedBox.expand(),
          ),
        ),
        // Bottom Right Corner
        Positioned(
          bottom: 0,
          right: 0,
          width: cornerSize,
          height: cornerSize,
          child: DragToResizeArea(
            resizeEdge: ResizeEdge.bottomRight,
            child: SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

String _nativeVisionEventKey(NativeTrackerEvent event) =>
    '${event.kind.name}:${event.champion}:${event.region}:'
    '${event.timestamp.toUtc().microsecondsSinceEpoch}';
