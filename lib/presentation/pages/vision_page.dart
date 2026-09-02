part of '../../app/godsense_app.dart';

class VisionPage extends ConsumerWidget {
  const VisionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(effectiveGameProvider);
    final calibrationState = ref.watch(nativeCalibrationProvider);
    final calibration = calibrationState.calibration;
    final native = ref.watch(nativeVisionProvider);
    final positionedEnemies =
        game?.enemies.where((enemy) => enemy['position'] is Map).length ?? 0;

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
                    'Mapa y alertas',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text(
                    'Comprueba el minimapa y revisa los últimos avistamientos enemigos.',
                    style: TextStyle(
                      fontSize: 13,
                      color: GsColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            GsBadge(
              label: native.recognitionStatus,
              variant: native.recognitionReady
                  ? GsBadgeVariant.success
                  : GsBadgeVariant.neutral,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 1. Player-facing status
        GsCard(
          title: 'Estado de las alertas',
          icon: Icons.radar_rounded,
          child: Wrap(
            spacing: 28,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              GsMetricStat(
                label: 'Minimapa',
                value: calibration == null
                    ? 'Sin configurar'
                    : calibration.recalibrationSuggested
                    ? 'Recalibrar'
                    : 'Configurado',
                subtitle: calibration == null
                    ? 'Calibra para comenzar'
                    : calibration.recalibrationSuggested
                    ? 'Cambió la configuración de League'
                    : 'Área guardada',
                icon: Icons.map_outlined,
                valueColor:
                    calibration == null || calibration.recalibrationSuggested
                    ? GsColors.amber
                    : GsColors.emerald,
              ),
              GsMetricStat(
                label: 'Enemigos identificados',
                value: '${native.identified.length}',
                subtitle: '$positionedEnemies con posición conocida',
                icon: Icons.person_search_rounded,
                valueColor: (native.frame?.detections.length ?? 0) > 0
                    ? GsColors.emerald
                    : GsColors.textMuted,
              ),
              GsMetricStat(
                label: 'Reconocimiento',
                value:
                    '${native.loadedTargets}/${native.expectedTargets} retratos',
                subtitle: native.recognitionStatus,
                icon: Icons.radar_rounded,
                valueColor: native.recognitionReady
                    ? GsColors.emerald
                    : GsColors.amber,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Calibration action
        GsCard(
          child: Row(
            children: [
              const Icon(
                Icons.center_focus_strong_rounded,
                color: GsColors.cyan,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _calibrationDescription(calibration),
                  style: const TextStyle(
                    fontSize: 12,
                    color: GsColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GsButton(
                label: 'Calibrar automáticamente',
                icon: Icons.auto_fix_high_rounded,
                compact: true,
                loading: native.processing,
                onPressed: native.processing
                    ? null
                    : () => ref
                          .read(nativeVisionProvider.notifier)
                          .detectCalibration(),
              ),
              const SizedBox(width: 8),
              GsButton(
                label: 'Comprobar ahora',
                icon: Icons.camera_alt_outlined,
                variant: GsButtonVariant.secondary,
                compact: true,
                onPressed:
                    calibration?.effectiveBounds == null || native.processing
                    ? null
                    : () => ref
                          .read(nativeVisionProvider.notifier)
                          .captureOnce(calibration!.effectiveBounds!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Useful previews
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _VisionPreview(
              title: 'Minimapa observado',
              bytes: native.frame?.capturePng,
            ),
            _VisionPreview(
              title: 'Detecciones actuales',
              bytes: native.frame?.annotatedPng,
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
                    'Área del minimapa encontrada',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'GodSense detectó esta región. Comprueba visualmente que corresponde al minimapa.',
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
                    'No pudimos revisar el minimapa. Comprueba la calibración '
                    'e inténtalo de nuevo.',
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
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'ÚLTIMOS AVISTAMIENTOS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: GsColors.textMuted,
                ),
              ),
            ),
            GsButton(
              label: 'Limpiar',
              icon: Icons.delete_outline_rounded,
              variant: GsButtonVariant.ghost,
              compact: true,
              onPressed: native.logs.isEmpty
                  ? null
                  : () => ref.read(nativeVisionProvider.notifier).clearLogs(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GsCard(
          padding: const EdgeInsets.all(8),
          child: native.logs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Todavía no hay avistamientos. Aparecerán aquí durante la partida.',
                      style: TextStyle(
                        color: GsColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: native.logs.take(50).map((entry) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: GsColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.visibility_outlined,
                            size: 16,
                            color: GsColors.cyan,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.message,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: GsColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatTimestamp(entry.timestamp),
                            style: const TextStyle(
                              fontSize: 10,
                              color: GsColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
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
      width: 320,
      child: GsCard(
        title: title,
        padding: EdgeInsets.zero,
        child: AspectRatio(
          aspectRatio: 1,
          child: ColoredBox(
            color: Colors.black,
            child: bytes == null
                ? const Center(
                    child: Text(
                      'Esperando captura…',
                      style: TextStyle(color: GsColors.textMuted, fontSize: 12),
                    ),
                  )
                : Image.memory(
                    bytes!,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
          ),
        ),
      ),
    );
  }
}
