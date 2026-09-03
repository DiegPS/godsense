part of '../../app/godsense_app.dart';

class GodSenseApp extends ConsumerWidget {
  const GodSenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'GodSense',
      debugShowCheckedModeBanner: false,
      theme: godsenseTheme(),
      builder: (context, child) =>
          ExcludeSemantics(child: child ?? const SizedBox.shrink()),
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

  @override
  Widget build(BuildContext context) {
    final selectedPage = ref.watch(selectedPageProvider);
    final backend = ref.watch(companionControllerProvider);
    final nativeLeague = ref.watch(nativeLeagueProvider);
    final overlayLayout = ref.watch(overlayLayoutProvider);
    ref.watch(nativeCalibrationProvider);
    ref.watch(nativeSpeechProvider);
    ref.watch(nativeVoiceCoachProvider);

    ref.listen<bool>(overlayWindowVisibleProvider, (previous, visible) {
      if (previous == visible) return;
      unawaited(overlayWindowManager.setVisible(context, visible));
    });

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
            calibrationStale: calibration?.recalibrationSuggested ?? false,
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
            calibrationStale: calibration?.recalibrationSuggested ?? false,
            bounds: calibration?.trackingBounds,
            iconSize: calibration?.trackingIconSize ?? 28,
          );
    });

    final content = switch (selectedPage) {
      0 => const OverviewPage(),
      1 => const LivePage(),
      2 => const VisionPage(),
      3 => const CoachPage(),
      4 => const ScoutPage(),
      _ => const SettingsPage(),
    };

    return Scaffold(
      backgroundColor: const Color(0xFF07090E),
      body: Stack(
        children: [
          Column(
            children: [
              _GodSenseCustomTitleBar(
                selectedPage: selectedPage,
                onSelectPage: (page) =>
                    ref.read(selectedPageProvider.notifier).state = page,
                overlayEditing: overlayLayout.editing,
                onToggleEditing: _onToggleEditing,
                onResetPanels: overlayLayout.editing
                    ? () => ref.read(overlayLayoutProvider.notifier).reset()
                    : null,
                onHelp: () async {
                  final destination = await showGettingStartedGuide(context);
                  if (context.mounted &&
                      destination != null &&
                      destination >= 0) {
                    ref.read(selectedPageProvider.notifier).state = destination;
                  }
                },
                sessionLabel: _sessionLabel(backend, nativeLeague),
                isOnline:
                    backend.connection == CompanionConnection.online ||
                    nativeLeague.liveGame != null,
              ),
              Expanded(child: content),
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
    required this.onHelp,
    required this.sessionLabel,
    required this.isOnline,
  });

  final int selectedPage;
  final ValueChanged<int> onSelectPage;
  final bool overlayEditing;
  final VoidCallback onToggleEditing;
  final VoidCallback? onResetPanels;
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
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: const BoxDecoration(
        color: Color(0xFF080B10),
        border: Border(bottom: BorderSide(color: Color(0x14FFFFFF), width: 1)),
      ),
      child: ClipRect(
        child: Row(
          children: [
            // 1. Clean Professional Brand (Draggable)
            DragToMoveArea(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 14),
                  const Text(
                    'GodSense',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const SizedBox(
                    height: 16,
                    child: VerticalDivider(width: 1, color: Color(0x1AFFFFFF)),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            // 2. Top Navigation Tabs Bar
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = selectedPage == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: _TopNavTabButton(
                    icon: item.icon,
                    label: item.label,
                    isSelected: isSelected,
                    onTap: () => onSelectPage(index),
                  ),
                );
              }),
            ),

            const SizedBox(width: 6),

            // 3. Center Status Capsule (Draggable)
            Expanded(
              child: DragToMoveArea(
                child: Row(
                  children: [
                    const Spacer(),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D131C),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isOnline
                                ? const Color(0x3310B981)
                                : const Color(0x1AFFFFFF),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF64748B),
                                shape: BoxShape.circle,
                                boxShadow: isOnline
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x8010B981),
                                          blurRadius: 4,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                sessionLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isOnline
                                      ? const Color(0xFFE2E8F0)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),

            // 4. Action Controls
            if (overlayEditing) ...[
              _TitleBarIconButton(
                icon: Icons.restart_alt_rounded,
                tooltip: 'Restablecer HUD',
                onPressed: onResetPanels,
              ),
              const SizedBox(width: 2),
            ],
            _TitleBarActionChip(
              icon: overlayEditing
                  ? Icons.check_rounded
                  : Icons.dashboard_customize_outlined,
              label: overlayEditing ? 'Guardar HUD' : 'Editar HUD',
              active: overlayEditing,
              onPressed: onToggleEditing,
            ),
            const SizedBox(width: 2),
            _TitleBarIconButton(
              icon: Icons.help_outline_rounded,
              tooltip: 'Guía y atajos',
              onPressed: onHelp,
            ),
            const SizedBox(width: 6),
            const SizedBox(
              height: 16,
              child: VerticalDivider(width: 1, color: Color(0x1AFFFFFF)),
            ),
            const SizedBox(width: 2),

            // 5. Clean Window Controls (Minimize, Maximize, Close)
            const _CustomWindowControlButtons(),
          ],
        ),
      ),
    );
  }
}

class _TopNavTabButton extends StatelessWidget {
  const _TopNavTabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x1F38BDF8) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0x4D38BDF8) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBarActionChip extends StatefulWidget {
  const _TitleBarActionChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  State<_TitleBarActionChip> createState() => _TitleBarActionChipState();
}

class _TitleBarActionChipState extends State<_TitleBarActionChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: widget.active
                ? const Color(0x330284C7)
                : _hovered
                ? const Color(0x1F38BDF8)
                : const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.active
                  ? const Color(0x8038BDF8)
                  : _hovered
                  ? const Color(0x4D38BDF8)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.active
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFFCBD5E1),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: widget.active
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleBarIconButton extends StatefulWidget {
  const _TitleBarIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  State<_TitleBarIconButton> createState() => _TitleBarIconButtonState();
}

class _TitleBarIconButtonState extends State<_TitleBarIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovered && enabled
                  ? const Color(0x1F38BDF8)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _hovered && enabled
                    ? const Color(0x3338BDF8)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: 16,
                color: enabled
                    ? _hovered
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF94A3B8)
                    : const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    _checkMaximized();
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
              MultiViewDesktop.closeApp();
            } catch (_) {}
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _WindowBtn extends StatefulWidget {
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
  State<_WindowBtn> createState() => _WindowBtnState();
}

class _WindowBtnState extends State<_WindowBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 44,
            height: 42,
            color: _hovered
                ? (widget.isClose
                      ? const Color(0xFFE11D48)
                      : const Color(0x1FFFFFFF))
                : Colors.transparent,
            child: Center(
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: _hovered && widget.isClose
                    ? Colors.white
                    : _hovered
                    ? Colors.white
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ),
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
