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

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Ajustes', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Activar overlay'),
                subtitle: const Text('Mostrar información sobre League.'),
                value: overlayEnabled,
                onChanged: (value) async {
                  ref.read(overlayEnabledProvider.notifier).state = value;
                  if (value) {
                    await overlayWindowManager.open(context);
                  } else {
                    await overlayWindowManager.close();
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Idioma'),
                subtitle: meta['language_restart_required'] == true
                    ? const Text('Requiere reiniciar')
                    : null,
                trailing: DropdownButton<String>(
                  value: settings?.language ?? 'auto',
                  items: const ['auto', 'en', 'es']
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged:
                      locks.containsKey('language') ||
                          backend.operationInProgress
                      ? null
                      : (value) => ref
                            .read(companionControllerProvider.notifier)
                            .updateSettings({'language': value}),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Cadencia'),
                trailing: DropdownButton<String>(
                  value: settings?.cadence ?? 'normal',
                  items: const ['quiet', 'normal', 'chatty']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged:
                      meta['cadence_editable'] != true ||
                          backend.operationInProgress
                      ? null
                      : (value) => ref
                            .read(companionControllerProvider.notifier)
                            .updateSettings({'cadence': value}),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Highlights'),
                subtitle: Text(
                  meta['highlights_ready'] == true
                      ? 'Grabación disponible'
                      : 'Grabador no disponible',
                ),
                value: settings?.highlightsEnabled ?? false,
                onChanged:
                    meta['highlights_editable'] == true &&
                        !backend.operationInProgress
                    ? (value) => ref
                          .read(companionControllerProvider.notifier)
                          .updateSettings({'highlights_enabled': value})
                    : null,
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Calibración del minimapa'),
                subtitle: Text(_calibrationDescription(calibration)),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    if (calibration != null)
                      OutlinedButton(
                        onPressed: nativeCalibration.saving
                            ? null
                            : () => ref
                                  .read(nativeCalibrationProvider.notifier)
                                  .clear(),
                        child: const Text('Borrar'),
                      ),
                    OutlinedButton(
                      onPressed: nativeCalibration.saving
                          ? null
                          : () => _showManualCalibrationDialog(
                              context,
                              ref,
                              calibration,
                            ),
                      child: const Text('Manual'),
                    ),
                    FilledButton(
                      onPressed: nativeCalibration.saving
                          ? null
                          : () => ref
                                .read(nativeVisionProvider.notifier)
                                .detectCalibration(),
                      child: const Text('Detectar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const NativeSpeechSettingsCard(),
        const SizedBox(height: 16),
        Text(
          'Paneles del overlay',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Card(
          child: Column(
            children: panels.entries.map((entry) {
              final hidden =
                  settings?.overlayHiddenPanels.contains(entry.key) ?? false;
              return SwitchListTile(
                title: Text(entry.value),
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
        Text('Salud', style: Theme.of(context).textTheme.titleLarge),
        Card(
          child: Column(
            children: const ['tick', 'gank', 'cv', 'tts', 'publisher'].map((
              name,
            ) {
              final component = backend.health?.components[name];
              return ListTile(
                leading: Icon(
                  component?.alive == true
                      ? Icons.check_circle
                      : Icons.error_outline,
                  color: component?.alive == true
                      ? Colors.green
                      : Colors.orange,
                ),
                title: Text(name),
                subtitle: Text(component?.error ?? 'Sin errores'),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Text('Soporte local', style: Theme.of(context).textTheme.titleLarge),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _supportController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Nota del reporte',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: backend.operationInProgress
                          ? null
                          : () => ref
                                .read(companionControllerProvider.notifier)
                                .createSupportBundle(),
                      child: const Text('Crear bundle'),
                    ),
                    FilledButton(
                      onPressed: backend.operationInProgress
                          ? null
                          : () => ref
                                .read(companionControllerProvider.notifier)
                                .reportSupport(_supportController.text),
                      child: const Text('Guardar reporte'),
                    ),
                  ],
                ),
                if (backend.supportResult.isNotEmpty)
                  SelectableText(_mapDescription(backend.supportResult)),
              ],
            ),
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
