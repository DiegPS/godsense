part of '../../app/godsense_app.dart';

final localDataExportDestinationProvider =
    Provider<Future<File?> Function(String suggestedName)>((ref) {
      return (suggestedName) async {
        final location = await getSaveLocation(
          acceptedTypeGroups: const [
            XTypeGroup(label: 'JSON', extensions: ['json']),
          ],
          suggestedName: suggestedName,
        );
        return location == null ? null : File(location.path);
      };
    });

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  _SettingsSection _section = _SettingsSection.general;
  bool _dataOperationInProgress = false;
  String? _dataNotice;
  final _scrollController = ScrollController();

  void _selectSection(_SettingsSection section) {
    if (_section == section) return;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() => _section = section);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _setOverlayEnabled(bool enabled) async {
    try {
      await ref.read(overlayEnabledProvider.notifier).setEnabled(enabled);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El cambio se aplicó, pero no se pudo guardar para el próximo inicio.',
          ),
        ),
      );
    }
  }

  Future<void> _exportData() async {
    final date = DateTime.now().toIso8601String().split('T').first;
    await _runDataOperation(() async {
      final destination = await ref.read(localDataExportDestinationProvider)(
        'godsense-data-$date.json',
      );
      if (destination == null || !mounted) return null;
      await ref
          .read(nativeLeagueProvider.notifier)
          .exportLocalData(destination);
      return 'Datos exportados en ${destination.path}';
    });
  }

  Future<void> _applyRetention() async {
    await _runDataOperation(() async {
      final result = await ref
          .read(nativeLeagueProvider.notifier)
          .applyLocalDataRetention();
      return result.total == 0
          ? 'No había datos vencidos para eliminar.'
          : 'Se eliminaron ${result.total} registros vencidos.';
    });
  }

  Future<void> _deleteData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar los datos locales?'),
        content: const Text(
          'Se eliminarán cuentas, partidas, estadísticas y evidencia local. '
          'La configuración, los modelos descargados y la calibración se conservarán. '
          'Si League sigue conectado, GodSense podrá recopilar datos nuevos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: GsColors.dangerAction,
              foregroundColor: Colors.white,
            ),
            child: const Text('Borrar definitivamente'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runDataOperation(() async {
      await ref.read(nativeLeagueProvider.notifier).deleteAllLocalData();
      await ref.read(aiConversationProvider.notifier).clearConversation();
      ref.invalidate(localScoutProvider);
      ref.invalidate(savedScoutAccountsProvider);
      ref.invalidate(coachControllerProvider);
      return 'Los datos locales de League se borraron.';
    });
  }

  Future<void> _runDataOperation(Future<String?> Function() operation) async {
    if (_dataOperationInProgress) return;
    setState(() {
      _dataOperationInProgress = true;
      _dataNotice = null;
    });
    try {
      final notice = await operation();
      if (mounted) setState(() => _dataNotice = notice);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Local data operation failed.',
        category: 'privacy',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(
          () => _dataNotice =
              'No se pudo completar la operación. Revisa el registro local.',
        );
      }
    } finally {
      if (mounted) setState(() => _dataOperationInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlayEnabled = ref.watch(overlayEnabledProvider);
    final (settings, operationInProgress) = ref.watch(
      companionControllerProvider.select(
        (companion) => (companion.settings, companion.operationInProgress),
      ),
    );
    final leagueConnected = ref.watch(
      nativeLeagueProvider.select((state) => state.lcuConnected),
    );
    final voiceReadiness = speechReadiness(ref.watch(nativeSpeechProvider));
    final nativeCalibration = ref.watch(nativeCalibrationProvider);
    final calibration = nativeCalibration.calibration;
    final meta = settings?.meta ?? const <String, dynamic>{};
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
    return GsFeaturePage(
      scrollController: _scrollController,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _SettingsSectionSwitch(
            selected: _section,
            onChanged: _selectSection,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _section.description,
          style: const TextStyle(color: GsColors.textSecondary),
        ),
        const SizedBox(height: 20),

        if (_section == _SettingsSection.general) ...[
          // 1. General Settings Card
          GsCard(
            title: 'Asistencia durante la partida',
            subtitle: 'El HUD es la información de GodSense que aparece sobre League.',
            icon: Icons.tune_rounded,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                GsToggleSwitch(
                  title: 'Mostrar el overlay durante la partida',
                  subtitle: 'Se recuerda al reiniciar. Si no aparece, usa el modo Sin bordes de League.',
                  icon: Icons.layers_outlined,
                  value: overlayEnabled,
                  onChanged: _setOverlayEnabled,
                ),
                const Divider(height: 1, color: GsColors.border),
                _SettingsSelectRow(
                  icon: Icons.language_rounded,
                  title: 'Idioma de la interfaz',
                  subtitle: 'La aplicación está disponible en español. Los idiomas de audio están en Voz y micrófono.',
                  control: const Text(
                    'Español',
                    style: TextStyle(color: GsColors.textSecondary),
                  ),
                ),
                const Divider(height: 1, color: GsColors.border),
                _SettingsSelectRow(
                  icon: Icons.speed_rounded,
                  title: 'Frecuencia de consejos',
                  subtitle: meta['cadence_editable'] == true
                      ? 'Elige cuántas indicaciones tácticas recibes.'
                      : 'El motor actual administra este intervalo automáticamente; no se puede cambiar aquí.',
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
                        meta['cadence_editable'] != true || operationInProgress
                        ? null
                        : (value) => ref
                              .read(companionControllerProvider.notifier)
                              .updateSettings({'cadence': value}),
                  ),
                ),
                const Divider(height: 1, color: GsColors.border),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: GsSectionHeading(
                    title: 'Área del minimapa',
                    subtitle: _calibrationDescription(calibration),
                    icon: Icons.crop_free_rounded,
                    action: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (calibration != null) ...[
                          GsButton(
                            label: 'Restablecer área',
                            variant: GsButtonVariant.danger,
                            compact: true,
                            onPressed: nativeCalibration.saving
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title: const Text(
                                          '¿Restablecer el área del minimapa?',
                                        ),
                                        content: const Text(
                                          'Se borrará el área guardada. Tendrás que detectarla de nuevo para recuperar las alertas.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                              dialogContext,
                                              false,
                                            ),
                                            child: const Text('Cancelar'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                              dialogContext,
                                              true,
                                            ),
                                            child: const Text('Restablecer'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true && mounted) {
                                      try {
                                        await ref
                                            .read(
                                              nativeCalibrationProvider
                                                  .notifier,
                                            )
                                            .clear();
                                      } catch (_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'No se pudo restablecer el área. Vuelve a intentarlo.',
                                                  ),
                                                ),
                                              );
                                        }
                                      }
                                    }
                                  },
                          ),
                        ],
                        GsButton(
                          label: 'Ajustar coordenadas',
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Overlay Panels Config
          GsCard(
            title: 'Paneles sobre la partida',
            subtitle: overlayEnabled
                ? 'Activa los paneles que quieres ver. Su posición se cambia con Editar HUD en la barra superior.'
                : 'Activa el HUD arriba para mostrar estos paneles. Tus preferencias se conservan.',
            icon: Icons.dashboard_customize_outlined,
            padding: EdgeInsets.zero,
            child: Column(
              children: panels.entries.map((entry) {
                final hidden =
                    settings?.overlayHiddenPanels.contains(entry.key) ?? false;
                return GsToggleSwitch(
                  title: entry.value,
                  value: !hidden,
                  onChanged:
                      !overlayEnabled || settings == null || operationInProgress
                      ? null
                      : (visible) {
                          final next = [...settings.overlayHiddenPanels];
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
                  detail: leagueConnected
                      ? 'Cuenta y selección de campeón disponibles.'
                      : 'Abre League e inicia sesión para conectar tu cuenta.',
                  ready: leagueConnected,
                ),
                const Divider(height: 1, color: GsColors.border),
                _ReadinessRow(
                  title: 'Overlay de partida',
                  detail: overlayEnabled
                      ? 'Usa Sin bordes en League para mostrarlo sobre el juego.'
                      : 'Está desactivado y no aparecerá durante la partida.',
                  ready: overlayEnabled,
                  actionLabel: overlayEnabled ? null : 'Activar',
                  onAction: overlayEnabled
                      ? null
                      : () => _setOverlayEnabled(true),
                ),
                const Divider(height: 1, color: GsColors.border),
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
                const Divider(height: 1, color: GsColors.border),
                _ReadinessRow(
                  title: 'Preguntas por voz',
                  detail: voiceReadiness.detail,
                  ready: voiceReadiness.ready,
                  actionLabel: 'Configurar voz',
                  onAction: () => _selectSection(_SettingsSection.voice),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_section == _SettingsSection.voice)
          const NativeSpeechSettingsCard(),
        if (_section == _SettingsSection.privacy) ...[
          GsCard(
            title: 'Conservación de tus datos',
            subtitle: 'Los diagnósticos duran 7 días, los eventos de partida 24 horas tras terminar y el historial de Scout 180 días.',
            icon: Icons.shield_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Copia de seguridad y limpieza',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Exporta un archivo JSON o elimina únicamente registros que ya superaron los plazos indicados arriba.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GsButton(
                      label: 'Exportar mis datos',
                      icon: Icons.download_outlined,
                      variant: GsButtonVariant.secondary,
                      onPressed: _dataOperationInProgress ? null : _exportData,
                    ),
                    GsButton(
                      label: 'Limpiar registros vencidos',
                      icon: Icons.auto_delete_outlined,
                      variant: GsButtonVariant.secondary,
                      onPressed: _dataOperationInProgress
                          ? null
                          : _applyRetention,
                    ),
                  ],
                ),
                const Divider(height: 32),
                const Text(
                  'Borrado definitivo',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: GsColors.crimson,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Elimina cuentas, partidas, estadísticas y evidencia local. Conserva ajustes, modelos y calibración. Esta acción pide confirmación.',
                ),
                const SizedBox(height: 12),
                GsButton(
                  label: 'Borrar datos locales',
                  icon: Icons.delete_forever_outlined,
                  variant: GsButtonVariant.danger,
                  onPressed: _dataOperationInProgress ? null : _deleteData,
                ),
                if (_dataNotice != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _dataNotice!,
                      style: const TextStyle(color: GsColors.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (_section == _SettingsSection.coaching)
          const CoachingSettingsSection(),
        if (_section == _SettingsSection.profiles)
          const GsCard(
            title: 'Perfiles de Scout',
            subtitle: 'Las cuentas detectadas en League y los Riot ID consultados se guardan en este equipo. No se guardan contraseñas ni se inicia sesión en otra cuenta de League.',
            child: ScoutProfileSelector(),
          ),
      ],
    );
  }
}

enum _SettingsSection {
  general(
    'Juego y HUD',
    'Elige lo que ves sobre la partida y configura la detección del minimapa.',
    Icons.layers_outlined,
  ),
  voice(
    'Voz y micrófono',
    'Configura lo que tú dices y cómo escuchas las respuestas.',
    Icons.mic_none_rounded,
  ),
  coaching(
    'IA del coach',
    'Prepara la conexión de IA, elige un modelo y administra sus cuentas.',
    Icons.psychology_outlined,
  ),
  profiles(
    'Perfiles de Scout',
    'Elige qué perfil consultar y si Scout debe seguir la cuenta abierta en League.',
    Icons.manage_accounts_outlined,
  ),
  privacy(
    'Datos y privacidad',
    'Consulta qué se guarda, exporta una copia o elimina información local.',
    Icons.shield_outlined,
  );

  const _SettingsSection(this.label, this.description, this.icon);
  final String label, description;
  final IconData icon;
}

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
    } on ai_runtime.ArtifactDownloadCancelledException {
      if (mounted) {
        setState(
          () => _notice = 'Instalación cancelada. Puedes volver a intentarlo.',
        );
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Runtime settings operation failed.',
        category: 'ai',
        error: error,
        stackTrace: stackTrace,
      );
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
    final runtimeSettings = ref.watch(aiRuntimeSettingsProvider);
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
      final bytes = definition.artifact.payloads.fold<int>(
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
                    color: ready ? GsColors.accent : GsColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                if (installing || starting) ...[
                  LinearProgressIndicator(
                    value:
                        progress?.phase ==
                            ai_runtime.ArtifactInstallPhase.downloading
                        ? progress?.fraction
                        : null,
                    semanticsLabel: '$name: $status',
                  ),
                  const SizedBox(height: 8),
                  if (progress?.phase ==
                          ai_runtime.ArtifactInstallPhase.downloading &&
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
                                    await runtimeSettings.setAutoStart(false);
                                  } else {
                                    await supervisor.start(kind);
                                    await runtimeSettings.rememberStarted(kind);
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
          title: '1. Preparar el motor de IA',
          subtitle: 'El motor conecta GodSense con los modelos. Instalarlo no significa que ya esté iniciado.',
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
        UiFormGrid(
          children: [
            runtimeCard(AiRuntimeKind.kilo),
            runtimeCard(AiRuntimeKind.openCode),
          ],
        ),
        const SizedBox(height: 16),
        const GsCard(
          title: '2. Elegir modelo y respuesta',
          subtitle: 'Con un motor iniciado, elige qué modelo responderá a tus preguntas.',
          icon: Icons.tune_outlined,
          child: AiModelSelector(),
        ),
        const SizedBox(height: 16),
        const GsCard(
          title: '3. Conectar cuentas si el modelo las requiere',
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

String _installPhaseLabel(ai_runtime.ArtifactInstallPhase? phase) =>
    switch (phase) {
      ai_runtime.ArtifactInstallPhase.downloading => 'Descargando…',
      ai_runtime.ArtifactInstallPhase.verifying => 'Verificando descarga…',
      ai_runtime.ArtifactInstallPhase.extracting => 'Extrayendo archivos…',
      ai_runtime.ArtifactInstallPhase.validating => 'Comprobando instalación…',
      ai_runtime.ArtifactInstallPhase.installing => 'Finalizando instalación…',
      ai_runtime.ArtifactInstallPhase.installed => 'Instalado',
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
              const Divider(height: 17, color: GsColors.border),
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
  final controller = ref.read(nativeCalibrationProvider.notifier);
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _ManualCalibrationDialog(
      initialBounds: calibration?.bounds ?? const <String, dynamic>{},
    ),
  );
  if (result != null && context.mounted) {
    try {
      await controller.save(result);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar el área del minimapa. Vuelve a intentarlo.',
            ),
          ),
        );
      }
    }
  }
}

class _ManualCalibrationDialog extends StatefulWidget {
  const _ManualCalibrationDialog({required this.initialBounds});
  final Map<String, dynamic> initialBounds;
  @override
  State<_ManualCalibrationDialog> createState() =>
      _ManualCalibrationDialogState();
}

class _ManualCalibrationDialogState extends State<_ManualCalibrationDialog> {
  late final left = TextEditingController(
    text: '${widget.initialBounds['left'] ?? 0}',
  );
  late final top = TextEditingController(
    text: '${widget.initialBounds['top'] ?? 0}',
  );
  late final width = TextEditingController(
    text: '${widget.initialBounds['width'] ?? 300}',
  );
  late final height = TextEditingController(
    text: '${widget.initialBounds['height'] ?? 300}',
  );
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    left.dispose();
    top.dispose();
    width.dispose();
    height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Calibración manual'),
    scrollable: true,
    content: SizedBox(
      width: 420,
      child: Form(
        key: form,
        child: UiFormFields(
          children: [
            const Text(
              'Coordenadas en píxeles de pantalla, no del tamaño de esta ventana. Usa la detección automática si no conoces el área.',
            ),
            _NumberField(
              controller: left,
              label: 'Izquierda',
              helper: 'Distancia horizontal al origen de pantalla. Puede ser negativa.',
            ),
            _NumberField(
              controller: top,
              label: 'Arriba',
              helper: 'Distancia vertical al origen de pantalla. Puede ser negativa.',
            ),
            _NumberField(
              controller: width,
              label: 'Ancho',
              positive: true,
              helper: 'Ancho del minimapa en píxeles, mayor que cero.',
            ),
            _NumberField(
              controller: height,
              label: 'Alto',
              positive: true,
              helper: 'Alto del minimapa en píxeles, mayor que cero.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
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
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.helper,
    this.positive = false,
  });

  final TextEditingController controller;
  final String label;
  final String helper;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return UiControls.formInput(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      validator: (value) {
        final number = int.tryParse(value ?? '');
        if (number == null) return 'Introduce un número entero.';
        if (positive && number <= 0) return 'Debe ser mayor que cero.';
        return null;
      },
      decoration: InputDecoration(labelText: label, helperText: helper),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final section in _SettingsSection.values)
          _SectionTab(
            label: section.label,
            icon: section.icon,
            isSelected: selected == section,
            onTap: () => onChanged(section),
          ),
      ],
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
      variant: isSelected ? GsButtonVariant.primary : GsButtonVariant.secondary,
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
