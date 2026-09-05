part of '../../app/godsense_app.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  _SettingsSection _section = _SettingsSection.general;

  @override
  Widget build(BuildContext context) {
    final overlayEnabled = ref.watch(overlayEnabledProvider);
    final companion = ref.watch(companionControllerProvider);
    final league = ref.watch(nativeLeagueProvider);
    final speech = ref.watch(nativeSpeechProvider);
    final nativeCalibration = ref.watch(nativeCalibrationProvider);
    final calibration = nativeCalibration.calibration;
    final settings = companion.settings;
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
      padding: GsSizes.pageInsets(context),
      children: [
        GsSectionHeading(
          page: true,
          title: 'Ajustes',
          subtitle: 'Personaliza cómo GodSense te acompaña dentro y fuera de partida.',
          action: null,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: _SettingsSectionSwitch(
            selected: _section,
            onChanged: (section) => setState(() => _section = section),
          ),
        ),
        const SizedBox(height: 20),

        if (_section == _SettingsSection.general) ...[
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
                _SettingsSelectRow(
                  icon: Icons.language_rounded,
                  title: 'Idioma del asistente',
                  subtitle: 'Idioma de los textos, alertas y recomendaciones.',
                  control: GsSelect<String>(
                    compact: true,
                    width: 150,
                    value: settings?.language ?? 'auto',
                    items: const {
                      'auto': 'Automático',
                      'en': 'Inglés',
                      'es': 'Español',
                    },
                    onChanged:
                        locks.containsKey('language') ||
                            companion.operationInProgress
                        ? null
                        : (value) => ref
                              .read(companionControllerProvider.notifier)
                              .updateSettings({'language': value}),
                  ),
                ),
                const Divider(height: 1, color: Color(0x14FFFFFF)),
                _SettingsSelectRow(
                  icon: Icons.speed_rounded,
                  title: 'Frecuencia de consejos',
                  subtitle: 'Intervalo con el que el coach emite directivas tácticas.',
                  control: GsSelect<String>(
                    compact: true,
                    width: 150,
                    value: settings?.cadence ?? 'normal',
                    items: const {
                      'quiet': 'Silencioso',
                      'normal': 'Normal',
                      'chatty': 'Frecuente',
                    },
                    onChanged:
                        meta['cadence_editable'] != true ||
                            companion.operationInProgress
                        ? null
                        : (value) => ref
                              .read(companionControllerProvider.notifier)
                              .updateSettings({'cadence': value}),
                  ),
                ),
                const Divider(height: 1, color: Color(0x14FFFFFF)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.crop_free_rounded,
                        size: 18,
                        color: GsColors.cyan,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Área del minimapa',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: GsColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _calibrationDescription(calibration),
                              style: const TextStyle(
                                fontSize: 12,
                                color: GsColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (calibration != null) ...[
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
                      ],
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
                  onChanged: companion.operationInProgress
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
        ] else ...[
          const CoachingSettingsSection(),
        ],
      ],
    );
  }
}

enum _SettingsSection { general, coaching }

class CoachingSettingsSection extends ConsumerStatefulWidget {
  const CoachingSettingsSection({super.key});

  @override
  ConsumerState<CoachingSettingsSection> createState() =>
      _CoachingSettingsSectionState();
}

class _CoachingSettingsSectionState
    extends ConsumerState<CoachingSettingsSection> {
  late Map<AiRuntimeKind, Future<bool>> _installed;
  AiRuntimeKind? _operating;
  AiRuntimeKind? _noticeKind;
  String? _notice;
  bool _failed = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _refreshInstalled();
  }

  void _refreshInstalled() {
    final supervisor = ref.read(aiRuntimeSupervisorProvider);
    _installed = {
      for (final kind in AiRuntimeKind.values)
        kind: supervisor.isInstalled(kind),
    };
  }

  Future<void> _run(
    AiRuntimeKind kind,
    Future<void> Function() action,
    String success,
  ) async {
    if (_operating != null) return;
    setState(() {
      _operating = kind;
      _noticeKind = kind;
      _notice = null;
      _failed = false;
      _cancelling = false;
    });
    try {
      await action();
      if (mounted) setState(() => _notice = success);
    } on ArtifactDownloadCancelledException {
      if (mounted) {
        setState(
          () => _notice = 'Instalación cancelada. Puedes volver a intentarlo.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _notice = 'No se pudo completar la operación. $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _operating = null;
          _cancelling = false;
          _refreshInstalled();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final supervisor = ref.watch(aiRuntimeSupervisorProvider);
    final state =
        ref.watch(aiRuntimeSupervisorStateProvider).value ?? supervisor.state;
    final chatting = ref.watch(
      aiConversationProvider.select((value) => value.isBusy),
    );
    final blocked = _operating != null || state.isBusy || chatting;
    ref.listen(aiRuntimeSupervisorStateProvider, (previous, next) {
      if (previous?.value?.lifecycle != next.value?.lifecycle && mounted) {
        setState(_refreshInstalled);
      }
    });

    Widget runtimeCard(AiRuntimeKind kind) {
      final definition = supervisor.definition(kind);
      final name = kind == AiRuntimeKind.kilo ? 'Kilo Code' : 'OpenCode';
      final active = state.kind == kind;
      final ready = active && state.isReady;
      final installing =
          active && state.lifecycle == AiRuntimeLifecycle.installing;
      final starting = active && state.lifecycle == AiRuntimeLifecycle.starting;
      final progress = installing ? state.installProgress : null;
      final bytes = definition.package.payloads.fold<int>(
        0,
        (sum, file) => sum + file.bytes,
      );
      return FutureBuilder<bool>(
        future: _installed[kind],
        builder: (context, snapshot) {
          final installed = snapshot.data == true;
          final checked =
              snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError;
          final status = installing
              ? _installPhaseLabel(progress?.phase)
              : starting
              ? 'Iniciando…'
              : ready
              ? 'Listo · versión ${state.version ?? definition.version}'
              : snapshot.hasError
              ? 'No se pudo comprobar la instalación'
              : !checked
              ? 'Comprobando instalación…'
              : installed
              ? 'Instalado'
              : 'Sin instalar';
          return GsCard(
            title: name,
            subtitle:
                'Versión ${definition.version} · ${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB de descarga',
            icon: kind == AiRuntimeKind.kilo
                ? Icons.route_outlined
                : Icons.code_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    color: ready ? GsColors.cyan : GsColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                if (installing || starting) ...[
                  LinearProgressIndicator(
                    value: progress?.phase == ArtifactInstallPhase.downloading
                        ? progress?.fraction
                        : null,
                    semanticsLabel: '$name: $status',
                  ),
                  const SizedBox(height: 8),
                  if (progress?.phase == ArtifactInstallPhase.downloading &&
                      progress!.totalBytes > 0)
                    Text(
                      '${(progress.receivedBytes / (1024 * 1024)).toStringAsFixed(1)} / '
                      '${(progress.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                    ),
                  const SizedBox(height: 8),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (installing)
                      OutlinedButton(
                        onPressed: _cancelling
                            ? null
                            : () {
                                setState(() => _cancelling = true);
                                supervisor.cancelInstallation();
                              },
                        child: Text(
                          _cancelling ? 'Cancelando…' : 'Cancelar instalación',
                        ),
                      )
                    else if (!installed)
                      FilledButton.icon(
                        onPressed: blocked || !checked
                            ? null
                            : () => _run(kind, () async {
                                await supervisor.install(kind);
                              }, '$name instalado. Ya puedes iniciarlo.'),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Descargar e instalar'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: blocked
                            ? null
                            : () => _run(
                                kind,
                                () async {
                                  if (ready) {
                                    await supervisor.stop();
                                    await ref
                                        .read(aiRuntimeSettingsProvider)
                                        .setAutoStart(false);
                                  } else {
                                    await supervisor.start(kind);
                                    await ref
                                        .read(aiRuntimeSettingsProvider)
                                        .rememberStarted(kind);
                                  }
                                },
                                ready
                                    ? '$name detenido.'
                                    : '$name iniciado y disponible.',
                              ),
                        icon: Icon(
                          ready ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          size: 18,
                        ),
                        label: Text(ready ? 'Detener $name' : 'Iniciar $name'),
                      ),
                    if (snapshot.hasError)
                      TextButton(
                        onPressed: blocked
                            ? null
                            : () => setState(_refreshInstalled),
                        child: const Text('Volver a comprobar'),
                      ),
                  ],
                ),
                if (_noticeKind == kind && _notice != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _notice!,
                    style: TextStyle(
                      color: _failed
                          ? GsColors.crimson
                          : GsColors.textSecondary,
                    ),
                  ),
                ] else if (active && state.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.error!,
                    style: const TextStyle(color: GsColors.crimson),
                  ),
                ],
              ],
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GsCard(
          title: 'Proveedor del coach',
          subtitle: 'Descarga una copia independiente para GodSense.',
          icon: Icons.hub_outlined,
          child: Text(
            chatting
                ? 'Termina o cancela la respuesta del coach antes de cambiar de motor.'
                : 'Puedes instalar ambos. Solo uno estará encendido a la vez. '
                      'Instalar o iniciar otro detiene el anterior. '
                      'La instalación no descarga modelos de IA: las respuestas necesitan Internet.',
            style: const TextStyle(color: GsColors.textSecondary, height: 1.45),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              return Column(
                children: [
                  runtimeCard(AiRuntimeKind.kilo),
                  const SizedBox(height: 16),
                  runtimeCard(AiRuntimeKind.openCode),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: runtimeCard(AiRuntimeKind.kilo)),
                const SizedBox(width: 16),
                Expanded(child: runtimeCard(AiRuntimeKind.openCode)),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const GsCard(
          title: 'Modelo y respuestas',
          icon: Icons.tune_outlined,
          child: AiModelSelector(),
        ),
        const SizedBox(height: 16),
        const GsCard(
          title: 'Cuentas de modelos',
          subtitle: 'Conecta únicamente los proveedores que quieras utilizar.',
          icon: Icons.account_circle_outlined,
          child: AiProviderConnections(),
        ),
        const SizedBox(height: 16),
        const _SettingsPlanCard(
          title: 'Contexto y privacidad',
          icon: Icons.shield_outlined,
          items: [
            'Las instalaciones y la configuración de GodSense están separadas de tus otras aplicaciones.',
            'No se importan las claves ni las cuentas de tus instalaciones personales.',
            'Cuando preguntas al coach con IA, tu pregunta y el contexto necesario de la partida se envían al proveedor del modelo elegido.',
          ],
        ),
      ],
    );
  }
}

String _installPhaseLabel(ArtifactInstallPhase? phase) => switch (phase) {
  ArtifactInstallPhase.downloading => 'Descargando…',
  ArtifactInstallPhase.verifying => 'Verificando descarga…',
  ArtifactInstallPhase.extracting => 'Extrayendo archivos…',
  ArtifactInstallPhase.validating => 'Comprobando instalación…',
  ArtifactInstallPhase.activating => 'Finalizando instalación…',
  ArtifactInstallPhase.installed => 'Instalado',
  _ => 'Preparando instalación…',
};

class _SettingsPlanCard extends StatelessWidget {
  const _SettingsPlanCard({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return GsCard(
      title: title,
      icon: icon,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _PlanRow(label: items[index]),
            if (index != items.length - 1)
              const Divider(height: 17, color: Color(0x14FFFFFF)),
          ],
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.radio_button_unchecked_rounded,
          color: GsColors.textMuted,
          size: 16,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: GsColors.textSecondary, fontSize: 14),
          ),
        ),
      ],
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

class _SettingsSectionSwitch extends StatelessWidget {
  const _SettingsSectionSwitch({
    required this.selected,
    required this.onChanged,
  });

  final _SettingsSection selected;
  final ValueChanged<_SettingsSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: GsSizes.control(context) + 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1017),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1FFFFFFF), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SectionTab(
            label: 'General',
            icon: Icons.tune_rounded,
            isSelected: selected == _SettingsSection.general,
            onTap: () => onChanged(_SettingsSection.general),
          ),
          const SizedBox(width: 4),
          _SectionTab(
            label: 'Coaching',
            icon: Icons.psychology_outlined,
            isSelected: selected == _SettingsSection.coaching,
            onTap: () => onChanged(_SettingsSection.coaching),
          ),
        ],
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: isSelected,
    child: GsButton(
      label: label,
      icon: icon,
      onPressed: onTap,
      variant: isSelected ? GsButtonVariant.secondary : GsButtonVariant.ghost,
    ),
  );
}

class _SettingsSelectRow extends StatelessWidget {
  const _SettingsSelectRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.control,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget control;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: GsSectionHeading(
      title: title,
      subtitle: subtitle,
      icon: icon,
      action: control,
    ),
  );
}
