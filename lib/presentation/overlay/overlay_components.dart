part of '../../app/godsense_app.dart';

String _enemyLocationStatus(
  Map<String, dynamic> enemy, {
  NativeIdentifiedChampion? native,
  DateTime? now,
}) {
  if (enemy['is_dead'] == true) {
    final timer = (enemy['respawn_timer'] as num?)?.toDouble() ?? 0;
    return timer > 0
        ? 'Muerto · reaparece en ${_formatDuration(timer)}'
        : 'Muerto';
  }
  final currentTime = now ?? DateTime.now();
  if (native != null) {
    final elapsed = currentTime.difference(native.lastSeen);
    if (elapsed.inMilliseconds <= 2000) {
      return 'Visto en ${native.region} · '
          '${(native.confidence * 100).toStringAsFixed(0)}% de confianza';
    }
    return 'Visto hace ${_formatDuration(elapsed.inSeconds)} en '
        '${native.region}';
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
  return 'Aún no detectado';
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
    return 'No pude procesar la pregunta. Inténtalo de nuevo.';
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

class _OverlayGlassCard extends StatelessWidget {
  const _OverlayGlassCard({
    required this.child,
    this.padding,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      // Fondo translúcido para conservar la lectura sin ocultar el juego.
      color: const Color(0xA60B0E17),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: borderColor ?? const Color(0x4D38BDF8),
          width: 1,
        ),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
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
      child: _OverlayGlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF38BDF8),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(color: Color(0x3338BDF8), height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _NativeCompositionView extends StatelessWidget {
  const _NativeCompositionView({required this.game});

  final GameSnapshot? game;

  @override
  Widget build(BuildContext context) {
    if (game == null) return const Text('Esperando partida…');
    Widget roster(String title, List<Map<String, dynamic>> players) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: players
                .map(
                  (player) => Chip(
                    avatar: _NetworkPortrait(
                      url: player['icon_url']?.toString(),
                      fallbackUrls: _stringValues(player['icon_fallback_urls']),
                      size: 24,
                    ),
                    label: Text(
                      '${player['champion_name'] ?? '?'} · ${player['role'] ?? ''}',
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        roster('Tu equipo', game!.allies),
        const SizedBox(height: 8),
        roster('Equipo enemigo', game!.enemies),
      ],
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
