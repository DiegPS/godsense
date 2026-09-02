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
    final nativeCalibration = ref.watch(nativeCalibrationProvider);
    final calibration = nativeCalibration.calibration;
    final settings = backend.settings;
    final meta = settings?.meta ?? const <String, dynamic>{};
    final locks = meta['locks'] is Map ? meta['locks'] as Map : const {};
    const panels = {
      'matchup_info': 'Enfrentamiento',
      'builds': 'Builds',
      'directives': 'Directivas',
      'team_comp': 'Composición',
      'gold_chart': 'Diferencia de oro',
      'gank': 'Amenazas',
      'jungler': 'Jungla enemigo',
      'voice_ask': 'Voz',
    };
    final healthComponents =
        <String, ({bool alive, String? latency, String? error})>{
          for (final name in const ['tick', 'gank', 'cv', 'tts', 'publisher'])
            name: (
              alive: backend.health?.components[name]?.alive ?? false,
              latency: backend.health?.components[name]?.alive == true
                  ? 'ACTIVO'
                  : null,
              error: backend.health?.components[name]?.error,
            ),
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
                    'Preferencias del sistema, integración de overlay y diagnóstico.',
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
          title: 'General y Overlay',
          icon: Icons.tune_rounded,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              GsToggleSwitch(
                title: 'Activar Overlay In-Game',
                subtitle:
                    'Superposición HUD transparente acelerada por hardware.',
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
                      label: 'IDIOMA DE LA APP',
                      width: 140,
                      value: settings?.language ?? 'auto',
                      items: const {
                        'auto': 'AUTO',
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
                      label: 'CADENCIA DE VOZ',
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
                            'Calibración del Minimapa',
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
                      label: 'Manual',
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
                      label: 'Detectar',
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
          title: 'Paneles del Overlay',
          subtitle:
              'Activa o desactiva módulos visuales en la superposición HUD.',
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

        // 4. System Health Diagnostic Matrix
        GsCard(
          title: 'Diagnóstico de Componentes',
          subtitle: 'Estado de servicios en proceso y canal de eventos.',
          icon: Icons.health_and_safety_outlined,
          child: GsHealthMatrix(components: healthComponents),
        ),
        const SizedBox(height: 16),

        // 5. Support & Debugging
        GsCard(
          title: 'Soporte y Diagnóstico Local',
          subtitle: 'Generación de paquete de depuración para resolución de incidencias.',
          icon: Icons.contact_support_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _supportController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Nota del reporte de soporte',
                  hintText: 'Describe el problema o adjunta contexto…',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  GsButton(
                    label: 'Crear bundle',
                    icon: Icons.folder_zip_outlined,
                    variant: GsButtonVariant.secondary,
                    loading: backend.operationInProgress,
                    onPressed: backend.operationInProgress
                        ? null
                        : () => ref
                              .read(companionControllerProvider.notifier)
                              .createSupportBundle(),
                  ),
                  const SizedBox(width: 10),
                  GsButton(
                    label: 'Guardar reporte',
                    icon: Icons.save_outlined,
                    loading: backend.operationInProgress,
                    onPressed: backend.operationInProgress
                        ? null
                        : () => ref
                              .read(companionControllerProvider.notifier)
                              .reportSupport(_supportController.text),
                  ),
                ],
              ),
              if (backend.supportResult.isNotEmpty) ...[
                const SizedBox(height: 10),
                SelectableText(
                  _mapDescription(backend.supportResult),
                  style: const TextStyle(
                    fontSize: 11,
                    color: GsColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
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
