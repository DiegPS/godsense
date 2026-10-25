part of '../../app/godsense_app.dart';

class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref
        .watch(companionControllerProvider.select((state) => state.alerts))
        .where((alert) => alert.isVisibleAlert)
        .take(5);
    final lastError = ref.watch(
      companionControllerProvider.select((state) => state.lastError),
    );
    final game = ref.watch(effectiveGameProvider);
    final lobby = ref.watch(effectiveLobbyProvider);
    final calibration = ref.watch(
      nativeCalibrationProvider.select((state) => state.calibration),
    );
    final overlayEnabled = ref.watch(overlayEnabledProvider);
    final vision = ref.watch(
      nativeVisionProvider.select(
        (state) => (error: state.error, hasFrame: state.frame != null),
      ),
    );
    final speechSettings = ref.watch(
      nativeSpeechProvider.select((state) => state.settings),
    );

    final isLeagueActive = game != null || lobby?.lcuConnected == true;

    return ListView(
      padding: GsSizes.pageInsets(context),
      children: [
        // 1. Player readiness
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _OverviewServiceCard(
              title: 'Cliente de League',
              status: game != null
                  ? 'Partida en curso'
                  : lobby?.lcuConnected == true
                  ? 'Cuenta conectada'
                  : 'Abre League e inicia sesión',
              detail: game != null
                  ? _formatGameTime(game.gameTime)
                  : 'La conexión es automática',
              icon: Icons.sports_esports_outlined,
              isOnline: isLeagueActive,
            ),
            _OverviewServiceCard(
              title: 'Overlay de partida',
              status: overlayEnabled ? 'Activado' : 'Desactivado',
              detail: overlayEnabled
                  ? 'Aparecerá cuando empiece la partida'
                  : 'Puedes activarlo en Ajustes',
              icon: Icons.layers_outlined,
              isOnline: overlayEnabled,
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
            ),
            _OverviewServiceCard(
              title: 'Preguntas por voz',
              status: speechSettings.pushToTalkEnabled
                  ? 'Activadas'
                  : 'Desactivadas',
              detail: speechSettings.pushToTalkEnabled
                  ? 'Mantén ${speechSettings.pushToTalkKey.toUpperCase()} para hablar'
                  : 'Configúralas en Ajustes',
              icon: Icons.mic_none_rounded,
              isOnline: speechSettings.pushToTalkEnabled,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Current Session Card
        GsCard(
          title: 'Sesión Actual',
          icon: Icons.sports_esports_outlined,
          action: game != null
              ? GsBadge(label: game.phase, variant: GsBadgeVariant.info)
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
                        valueColor: GsColors.cyan,
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
                            ? const Color(0x33EF4444)
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
                              : GsColors.cyan,
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
              border: Border.all(color: const Color(0x4DEF4444)),
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
  });

  final String title;
  final String status;
  final String detail;
  final IconData icon;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GsColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isOnline ? GsColors.cyanGlow : GsColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOnline ? const Color(0x4D38BDF8) : GsColors.border,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 18,
                color: isOnline ? GsColors.cyan : GsColors.textMuted,
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
                          fontSize: 12,
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
                        color: isOnline ? GsColors.emerald : GsColors.textMuted,
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
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOnline ? GsColors.cyan : GsColors.textSecondary,
                  ),
                ),
                Text(
                  detail,
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
    );
  }
}
