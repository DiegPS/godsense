part of '../../app/godsense_app.dart';

class VisionPage extends ConsumerWidget {
  const VisionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(effectiveGameProvider);
    final calibrationState = ref.watch(nativeCalibrationProvider);
    final calibration = calibrationState.calibration;
    final native = ref.watch(nativeVisionProvider);
    final corpus = ref.watch(cvCorpusComparatorProvider);
    final positionedEnemies = game?.enemies
        .where((enemy) => enemy['position'] is Map)
        .length;

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
                    'Vision Tracker',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text(
                    'Captura Win32 GDI y visión computacional DartCV ejecutadas 100% en proceso.',
                    style: TextStyle(
                      fontSize: 13,
                      color: GsColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            GsBadge(
              label: native.running ? 'TRACKER ACTIVO' : 'TRACKER IDLE',
              variant: native.running
                  ? GsBadgeVariant.success
                  : GsBadgeVariant.neutral,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 1. Performance Overview
        GsCard(
          title: 'DartCV tracker nativo',
          icon: Icons.memory_rounded,
          child: Wrap(
            spacing: 28,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              GsMetricStat(
                label: 'Frecuencia',
                value: '${native.fps.toStringAsFixed(1)} FPS',
                icon: Icons.speed_rounded,
                valueColor: GsColors.cyan,
              ),
              GsMetricStat(
                label: 'Latencia DartCV',
                value: '${native.averageCvMilliseconds.toStringAsFixed(1)} ms',
                subtitle:
                    'p95: ${native.p95CvMilliseconds.toStringAsFixed(1)} ms',
                icon: Icons.memory_rounded,
              ),
              GsMetricStat(
                label: 'Captura GDI',
                value:
                    '${native.averageCaptureMilliseconds.toStringAsFixed(1)} ms',
                icon: Icons.screenshot_monitor_rounded,
              ),
              GsMetricStat(
                label: 'Enemigos Detectados',
                value: '${native.frame?.detections.length ?? 0}',
                subtitle: 'Live API: ${positionedEnemies ?? 0}',
                icon: Icons.person_search_rounded,
                valueColor: (native.frame?.detections.length ?? 0) > 0
                    ? GsColors.emerald
                    : GsColors.textMuted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Paridad Determinista
        GsCard(
          title: 'Paridad Determinista',
          icon: Icons.compare_arrows_rounded,
          action: GsButton(
            label: 'Comparar corpus',
            icon: Icons.compare_rounded,
            compact: true,
            loading: corpus.running,
            onPressed: corpus.running
                ? null
                : () => ref.read(cvCorpusComparatorProvider.notifier).run(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (corpus.error != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: GsColors.crimsonGlow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    corpus.error!,
                    style: const TextStyle(
                      color: GsColors.crimson,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ParityMetric(label: 'Frames', value: '${corpus.frames}'),
                    _ParityMetric(
                      label: 'Precision',
                      value: '${(corpus.precision * 100).toStringAsFixed(1)}%',
                      isSuccess: corpus.precision >= 0.95,
                    ),
                    _ParityMetric(
                      label: 'Recall',
                      value: '${(corpus.recall * 100).toStringAsFixed(1)}%',
                      isSuccess: corpus.recall >= 0.95,
                    ),
                    _ParityMetric(
                      label: 'Identidad',
                      value:
                          '${(corpus.identityAgreement * 100).toStringAsFixed(1)}%',
                      isSuccess: corpus.identityAgreement >= 0.95,
                    ),
                    _ParityMetric(
                      label: 'Boxes Exactos',
                      value: '${corpus.exactBoxes}/${corpus.matchedBoxes}',
                    ),
                    _ParityMetric(
                      label: 'IoU Promedio',
                      value: corpus.averageIou.toStringAsFixed(3),
                    ),
                    _ParityMetric(
                      label: 'Tiempo Dart',
                      value:
                          '${corpus.averageDartMilliseconds.toStringAsFixed(1)} ms',
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Calibration Action
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
                label: 'Detectar nativo',
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
                label: 'Capturar ahora',
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

        // 4. Vision Previews
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
                    native.error!,
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
                'REGISTRO CRONOLÓGICO DE VISIÓN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: GsColors.textMuted,
                ),
              ),
            ),
            GsButton(
              label: 'Limpiar registro',
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
                      'Sin detecciones todavía. Los eventos de detección de campeones se guardan en tiempo real.',
                      style: TextStyle(
                        color: GsColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: native.logs.take(50).map((entry) {
                    final isNative = entry.source == TrackerLogSource.native;
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
                          Icon(
                            isNative
                                ? Icons.memory_rounded
                                : Icons.cloud_outlined,
                            size: 16,
                            color: isNative ? GsColors.cyan : GsColors.amber,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.source.name.toUpperCase()} · ${entry.event}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: GsColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  entry.message,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: GsColors.textSecondary,
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

class _ParityMetric extends StatelessWidget {
  const _ParityMetric({
    required this.label,
    required this.value,
    this.isSuccess,
  });

  final String label;
  final String value;
  final bool? isSuccess;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: GsColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: isSuccess == true
            ? Border.all(color: const Color(0x3310B981))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: GsColors.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSuccess == true
                  ? GsColors.emerald
                  : GsColors.textPrimary,
            ),
          ),
        ],
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
