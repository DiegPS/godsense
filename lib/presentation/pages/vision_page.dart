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
        Text(
          'Vision tracker',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Captura Win32 y visión DartCV ejecutadas íntegramente en proceso.',
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.circle_outlined),
            title: const Text('DartCV tracker nativo'),
            subtitle: Text(
              'Status: ${native.running
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
              'Live ${positionedEnemies ?? 0} · CV ${native.frame?.detections.length ?? 0}',
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
