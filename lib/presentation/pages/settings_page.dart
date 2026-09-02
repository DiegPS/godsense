part of '../../app/godsense_app.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _supportController = TextEditingController();

  @override
  void dispose() {
    _supportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overlayEnabled = ref.watch(overlayEnabledProvider);
    final backend = ref.watch(companionControllerProvider);
    final league = ref.watch(nativeLeagueProvider);
    final speech = ref.watch(nativeSpeechProvider);
    final nativeCalibration = ref.watch(nativeCalibrationProvider);
    final calibration = nativeCalibration.calibration;
    final settings = backend.settings;
    final meta = settings?.meta ?? const <String, dynamic>{};
    final locks = meta['locks'] is Map ? meta['locks'] as Map : const {};
    const panels = {
      'matchup_info': 'Enfrentamiento',
      'builds': 'Objetos recomendados',
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
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ajustes',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text(
                    'Personaliza cómo GodSense te acompaña dentro y fuera de partida.',
                    style: TextStyle(
                      fontSize: 13,
                      color: GsColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 1. General Settings Card
        GsCard(
          title: 'Juego y overlay',
          icon: Icons.tune_rounded,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              GsToggleSwitch(
                title: 'Mostrar el overlay durante la partida',
                subtitle: 'Presenta alertas y consejos encima del juego.',
                icon: Icons.layers_outlined,
                value: overlayEnabled,
                onChanged: (value) {
                  ref.read(overlayEnabledProvider.notifier).state = value;
                },
              ),
              const Divider(height: 1, color: Color(0x14FFFFFF)),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GsSelect<String>(
                      label: 'IDIOMA',
                      width: 140,
                      value: settings?.language ?? 'auto',
                      items: const {
                        'auto': 'Automático',
                        'en': 'ENGLISH',
                        'es': 'ESPAÑOL',
                      },
                      onChanged:
                          locks.containsKey('language') ||
                              backend.operationInProgress
                          ? null
                          : (value) => ref
                                .read(companionControllerProvider.notifier)
                                .updateSettings({'language': value}),
                    ),
                    GsSelect<String>(
                      label: 'FRECUENCIA DE CONSEJOS',
                      width: 140,
                      value: settings?.cadence ?? 'normal',
                      items: const {
                        'quiet': 'Silencioso',
                        'normal': 'Normal',
                        'chatty': 'Frecuente',
                      },
                      onChanged:
                          meta['cadence_editable'] != true ||
                              backend.operationInProgress
                          ? null
                          : (value) => ref
                                .read(companionControllerProvider.notifier)
                                .updateSettings({'cadence': value}),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0x14FFFFFF)),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.crop_free_rounded,
                      size: 18,
                      color: GsColors.cyan,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Área del minimapa',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: GsColors.textPrimary,
                            ),
                          ),
                          Text(
                            _calibrationDescription(calibration),
                            style: const TextStyle(
                              fontSize: 11,
                              color: GsColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (calibration != null)
                      GsButton(
                        label: 'Borrar',
                        variant: GsButtonVariant.ghost,
                        compact: true,
                        onPressed: nativeCalibration.saving
                            ? null
                            : () => ref
                                  .read(nativeCalibrationProvider.notifier)
                                  .clear(),
                      ),
                    const SizedBox(width: 6),
                    GsButton(
                      label: 'Ajustar',
                      variant: GsButtonVariant.secondary,
                      compact: true,
                      onPressed: nativeCalibration.saving
                          ? null
                          : () => _showManualCalibrationDialog(
                              context,
                              ref,
                              calibration,
                            ),
                    ),
                    const SizedBox(width: 6),
                    GsButton(
                      label: 'Detectar automáticamente',
                      compact: true,
                      onPressed: nativeCalibration.saving
                          ? null
                          : () => ref
                                .read(nativeVisionProvider.notifier)
                                .detectCalibration(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Sherpa Speech Settings
        const NativeSpeechSettingsCard(),
        const SizedBox(height: 16),

        // 3. Overlay Panels Config
        GsCard(
          title: 'Contenido del overlay',
          subtitle: 'Elige qué información quieres ver mientras juegas.',
          icon: Icons.dashboard_customize_outlined,
          padding: EdgeInsets.zero,
          child: Column(
            children: panels.entries.map((entry) {
              final hidden =
                  settings?.overlayHiddenPanels.contains(entry.key) ?? false;
              return GsToggleSwitch(
                title: entry.value,
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

        // 4. Player-facing readiness
        GsCard(
          title: '¿Está todo listo?',
          subtitle:
              'GodSense comprueba automáticamente lo necesario para jugar.',
          icon: Icons.health_and_safety_outlined,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ReadinessRow(
                title: 'Cliente de League',
                detail: league.lcuConnected
                    ? 'Cuenta y selección de campeón disponibles.'
                    : 'Abre League e inicia sesión para conectar tu cuenta.',
                ready: league.lcuConnected,
              ),
              const Divider(height: 1, color: Color(0x14FFFFFF)),
              _ReadinessRow(
                title: 'Overlay de partida',
                detail: overlayEnabled
                    ? 'Se mostrará automáticamente cuando lo necesites.'
                    : 'Está desactivado y no aparecerá durante la partida.',
                ready: overlayEnabled,
                actionLabel: overlayEnabled ? null : 'Activar',
                onAction: overlayEnabled
                    ? null
                    : () => ref.read(overlayEnabledProvider.notifier).state =
                          true,
              ),
              const Divider(height: 1, color: Color(0x14FFFFFF)),
              _ReadinessRow(
                title: 'Detección del minimapa',
                detail: calibration == null
                    ? 'Necesita una calibración antes de detectar amenazas.'
                    : 'El área del minimapa está configurada.',
                ready: calibration != null,
                actionLabel: calibration == null ? 'Calibrar' : null,
                onAction: calibration == null
                    ? () => ref
                          .read(nativeVisionProvider.notifier)
                          .detectCalibration()
                    : null,
              ),
              const Divider(height: 1, color: Color(0x14FFFFFF)),
              _ReadinessRow(
                title: 'Preguntas por voz',
                detail: speech.settings.pushToTalkEnabled
                    ? 'Mantén ${speech.settings.pushToTalkKey.toUpperCase()} para hablar con el coach.'
                    : 'La función está desactivada.',
                ready: speech.settings.pushToTalkEnabled,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 5. Help and export
        GsCard(
          title: 'Ayuda y solución de problemas',
          subtitle: 'Exporta información técnica únicamente cuando soporte te la solicite.',
          icon: Icons.contact_support_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _supportController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '¿Qué problema encontraste? (opcional)',
                  hintText: 'Describe qué intentabas hacer y qué ocurrió.',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'El archivo incluye estados de configuración y funcionamiento. '
                'No incluye audio, capturas de pantalla ni credenciales de League.',
                style: TextStyle(fontSize: 12, color: GsColors.textSecondary),
              ),
              const SizedBox(height: 12),
              GsButton(
                label: 'Exportar información para soporte',
                icon: Icons.save_alt_rounded,
                loading: backend.operationInProgress,
                onPressed: backend.operationInProgress
                    ? null
                    : () => _exportSupportInformation(
                        context,
                        ref,
                        _supportController.text,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _exportSupportInformation(
  BuildContext context,
  WidgetRef ref,
  String note,
) async {
  const type = XTypeGroup(label: 'Archivo ZIP', extensions: ['zip']);
  final destination = await getSaveLocation(
    suggestedName: 'godsense-soporte.zip',
    acceptedTypeGroups: const [type],
  );
  if (destination == null || !context.mounted) return;

  final result = await ref
      .read(companionControllerProvider.notifier)
      .reportSupport(note);
  final sourcePath = result?['path']?.toString();
  if (sourcePath == null || !context.mounted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo preparar la información de soporte.'),
        ),
      );
    }
    return;
  }
  try {
    final temporary = File(sourcePath);
    await temporary.copy(destination.path);
    if (await temporary.exists()) await temporary.delete();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Información guardada en ${destination.path}')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo guardar el archivo: $error')),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.title,
    required this.detail,
    required this.ready,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String detail;
  final bool ready;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Icon(
          ready ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          color: ready ? GsColors.emerald : GsColors.amber,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: GsColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 12,
                  color: GsColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: 12),
          GsButton(
            label: actionLabel!,
            compact: true,
            variant: GsButtonVariant.secondary,
            onPressed: onAction,
          ),
        ],
      ],
    ),
  );
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
    await ref.read(nativeCalibrationProvider.notifier).save(result);
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
