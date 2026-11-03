part of '../../app/godsense_app.dart';

class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ActivePageWatch(context, ref);
    final alerts = watch(
      companionControllerProvider.select((state) => state.alerts),
    ).where((alert) => alert.isVisibleAlert).take(5);
    final lastError = watch(
      companionControllerProvider.select((state) => state.lastError),
    );
    final game = watch(effectiveGameProvider);
    final lobby = watch(effectiveLobbyProvider);
    final calibration = watch(
      nativeCalibrationProvider.select((state) => state.calibration),
    );
    final overlayEnabled = watch(overlayEnabledProvider);
    final vision = watch(
      nativeVisionProvider.select(
        (state) => (error: state.error, hasFrame: state.frame != null),
      ),
    );
    final voice = speechReadiness(watch(nativeSpeechProvider));

    final gameEnded = game?.gameEnded == true;
    final hasActiveGame = game != null && !gameEnded;
    final isLeagueActive = hasActiveGame || lobby?.lcuConnected == true;

    return GsFeaturePage(
      children: [
        // 1. Player readiness
        UiMetricGrid(
          minimumItemWidth: 240,
          children: [
            _OverviewServiceCard(
              title: 'Cliente de League',
              status: hasActiveGame
                  ? 'Partida en curso'
                  : lobby?.lcuConnected == true
                  ? 'Cuenta conectada'
                  : 'Abre League e inicia sesión',
              detail: hasActiveGame
                  ? _formatGameTime(game.gameTime)
                  : 'La conexión es automática',
              icon: Icons.sports_esports_outlined,
              isOnline: isLeagueActive,
              onTap: () => ref.read(selectedPageProvider.notifier).state = 1,
            ),
            _OverviewServiceCard(
              title: 'Overlay de partida',
              status: overlayEnabled ? 'Activado' : 'Desactivado',
              detail: overlayEnabled
                  ? 'Aparecerá cuando empiece la partida'
                  : 'Puedes activarlo en Ajustes',
              icon: Icons.layers_outlined,
              isOnline: overlayEnabled,
              onTap: () => ref.read(selectedPageProvider.notifier).state = 5,
            ),
            _OverviewServiceCard(
              title: 'Alertas del minimapa',
              status: calibration == null
                  ? 'Necesitan calibración'
                  : calibration.recalibrationSuggested
                  ? 'Necesitan recalibración'
                  : vision.error != null
                  ? 'Captura no disponible'
                  : vision.hasFrame
                  ? 'Activas'
                  : 'Iniciando captura',
              detail: calibration == null
                  ? 'Configura el área del minimapa'
                  : vision.error != null
                  ? 'Revisa la pantalla configurada en Mapa'
                  : 'GodSense vigilará las amenazas',
              icon: Icons.radar_rounded,
              isOnline:
                  calibration != null &&
                  !calibration.recalibrationSuggested &&
                  vision.error == null &&
                  vision.hasFrame,
              onTap: () => ref.read(selectedPageProvider.notifier).state = 2,
            ),
            _OverviewServiceCard(
              title: 'Preguntas por voz',
              status: voice.status,
              detail: voice.detail,
              icon: Icons.mic_none_rounded,
              isOnline: voice.ready,
              onTap: () => ref.read(selectedPageProvider.notifier).state = 5,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Current Session Card
        GsCard(
          title: gameEnded ? 'Última sesión' : 'Sesión Actual',
          icon: Icons.sports_esports_outlined,
          action: game != null
              ? GsBadge(
                  label: gameEnded ? 'FINALIZADA' : _gamePhaseLabel(game.phase),
                  variant: gameEnded
                      ? GsBadgeVariant.neutral
                      : GsBadgeVariant.info,
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (game == null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: GsColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.hourglass_empty_rounded,
                          size: 28,
                          color: GsColors.textMuted,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No hay una partida activa de League of Legends en curso.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: GsColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'GodSense iniciará el rastreo automáticamente en cuanto empiece el juego.',
                          style: TextStyle(
                            fontSize: 12,
                            color: GsColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                if (gameEnded) ...[
                  const Text(
                    'Datos conservados de la última partida; ya no se actualizan en vivo.',
                    style: TextStyle(
                      color: GsColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: GsMetricStat(
                        label: 'Tiempo',
                        value: _formatGameTime(game.gameTime),
                        icon: Icons.timer_outlined,
                      ),
                    ),
                    Expanded(
                      child: GsMetricStat(
                        label: 'Aliados',
                        value: '${game.allies.length} campeones',
                        icon: Icons.shield_outlined,
                        valueColor: GsColors.accent,
                      ),
                    ),
                    Expanded(
                      child: GsMetricStat(
                        label: 'Enemigos',
                        value: '${game.enemies.length} campeones',
                        icon: Icons.warning_amber_rounded,
                        valueColor: GsColors.crimson,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'ÚLTIMAS ALERTAS DE PARTIDA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: GsColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              if (alerts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GsColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: GsColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 16,
                        color: GsColors.textMuted,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sin alertas recientes. Las alertas de gank y visión aparecerán aquí en vivo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: GsColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...alerts.map(
                  (alert) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: GsColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: alert.kind == CompanionAlertKind.gank
                            ? GsColors.crimsonGlow
                            : GsColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          alert.kind == CompanionAlertKind.gank
                              ? Icons.warning_amber_rounded
                              : Icons.visibility_outlined,
                          size: 18,
                          color: alert.kind == CompanionAlertKind.gank
                              ? GsColors.crimson
                              : GsColors.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: GsColors.textPrimary,
                                ),
                              ),
                              Text(
                                alert.message,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: GsColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (lastError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GsColors.crimsonGlow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: GsColors.crimson),
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
                    'GodSense no pudo actualizar parte de la información. '
                    'Volverá a intentarlo automáticamente.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: GsColors.crimson,
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
}

class _OverviewServiceCard extends StatelessWidget {
  const _OverviewServiceCard({
    required this.title,
    required this.status,
    required this.detail,
    required this.icon,
    required this.isOnline,
    required this.onTap,
  });

  final String title;
  final String status;
  final String detail;
  final IconData icon;
  final bool isOnline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GsColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GsSizes.cardRadius),
        side: const BorderSide(color: GsColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isOnline
                      ? GsColors.accentTint
                      : GsColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOnline ? GsColors.borderActive : GsColors.border,
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 18,
                    color: isOnline ? GsColors.accent : GsColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: GsColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline
                                ? GsColors.emerald
                                : GsColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isOnline
                            ? GsColors.accent
                            : GsColors.textSecondary,
                      ),
                    ),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 12,
                        color: GsColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: GsColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
