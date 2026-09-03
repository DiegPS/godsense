part of '../../app/godsense_app.dart';

class GodSenseOverlay extends ConsumerStatefulWidget {
  const GodSenseOverlay({super.key});

  @override
  ConsumerState<GodSenseOverlay> createState() => _GodSenseOverlayState();
}

class _GodSenseOverlayState extends ConsumerState<GodSenseOverlay> {
  late final Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backend = ref.watch(companionControllerProvider);
    final nativeVision = ref.watch(nativeVisionProvider);
    final nativeSpeech = ref.watch(nativeSpeechProvider);
    final nativeVoiceCoach = ref.watch(nativeVoiceCoachProvider);
    final calibration = ref.watch(nativeCalibrationProvider).calibration;
    final game = ref.watch(effectiveGameProvider);
    final goldDifference = (game?.raw['team_gold_diff'] as num?)?.toInt();
    final sighting = backend.alerts
        .where((alert) => alert.kind == CompanionAlertKind.junglerSighting)
        .where((alert) => _now.difference(alert.receivedAt).inSeconds < 180)
        .firstOrNull;
    final gank = backend.alerts
        .where((alert) => alert.kind == CompanionAlertKind.gank)
        .where((alert) => _now.difference(alert.receivedAt).inSeconds < 5)
        .firstOrNull;
    final nativeGank = nativeVision.events
        .where((event) => event.kind == NativeTrackerEventKind.gank)
        .where((event) => _now.difference(event.timestamp).inSeconds < 5)
        .firstOrNull;
    final nativeSighting = nativeVision.events
        .where((event) => event.kind == NativeTrackerEventKind.junglerSighting)
        .where((event) => _now.difference(event.timestamp).inSeconds < 180)
        .firstOrNull;
    final voice = backend.alerts
        .where((alert) => alert.kind == CompanionAlertKind.voice)
        .where((alert) {
          final state = alert.raw['state']?.toString();
          return state == 'recording' ||
              state == 'thinking' ||
              state == 'answering' ||
              _now.difference(alert.receivedAt).inSeconds < 8;
        })
        .firstOrNull;
    final nativeVoiceVisible =
        nativeSpeech.pushToTalkPressed ||
        (nativeSpeech.lastTranscriptAt != null &&
            _now.difference(nativeSpeech.lastTranscriptAt!).inSeconds < 8);
    final visibilityEvent = backend.alerts
        .where((alert) => alert.kind == CompanionAlertKind.overlayVisibility)
        .firstOrNull;
    final layout = ref.watch(overlayLayoutProvider);
    final inGame = game != null && !game.gameEnded;
    final inGameVisible = inGame && visibilityEvent?.raw['visible'] != false;
    final visible = layout.editing || inGameVisible;
    final enemies = game?.enemies ?? const <Map<String, dynamic>>[];
    final jungler = enemies
        .where((enemy) => enemy['role']?.toString().toUpperCase() == 'JUNGLE')
        .firstOrNull;
    final threats = [...enemies]
      ..sort((a, b) {
        final aJungle = a['role']?.toString().toUpperCase() == 'JUNGLE';
        final bJungle = b['role']?.toString().toUpperCase() == 'JUNGLE';
        if (aJungle != bJungle) return aJungle ? -1 : 1;
        final aMia = a['is_mia'] == true;
        final bMia = b['is_mia'] == true;
        if (aMia != bMia) return aMia ? -1 : 1;
        return 0;
      });
    final hiddenPanels = backend.settings?.overlayHiddenPanels ?? const [];
    ref.listen(overlayLayoutProvider.select((state) => state.editing), (
      previous,
      editing,
    ) async {
      await MultiViewDesktop.of(context).setIgnoreMouseEvents(!editing);
      if (!editing) {
        await ref.read(overlayLayoutProvider.notifier).persist();
      }
    });

    ref.listen(
      companionControllerProvider.select((state) => state.alerts.firstOrNull),
      (previous, next) {
        if (next == previous || next?.kind != CompanionAlertKind.overlayEdit) {
          return;
        }
        ref
            .read(overlayLayoutProvider.notifier)
            .setEditing(next!.raw['edit'] == true);
      },
    );

    if (!visible) return const SizedBox.expand();

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          if (layout.editing)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: _OverlayGlassCard(
                  borderColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.open_with, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 8),
                      const Text(
                        'Modo edición: arrastra, redimensiona o colapsa paneles',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonal(
                        onPressed: () => ref
                            .read(overlayLayoutProvider.notifier)
                            .setEditing(false),
                        child: const Text('Terminar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (nativeGank != null || gank != null || layout.editing)
            _EditableOverlayPanel(
              id: 'gank',
              title: 'Alerta de gank',
              child: _OverlayGlassCard(
                borderColor:
                    nativeGank != null || gank?.raw['threat_level'] == 'DANGER'
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFF59E0B),
                child: ListTile(
                  leading: Icon(
                    Icons.warning_amber,
                    color:
                        nativeGank != null ||
                            gank?.raw['threat_level'] == 'DANGER'
                        ? Colors.redAccent
                        : Colors.orangeAccent,
                    size: 32,
                  ),
                  title: Text(
                    nativeGank != null
                        ? 'DANGER: ${nativeGank.champion}'
                        : gank?.title ?? 'Amenaza de gank',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    nativeGank != null
                        ? '${nativeGank.location} · ${nativeGank.role}'
                        : gank?.message ?? 'Esperando una amenaza de gank…',
                    style: const TextStyle(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
            ),
          if (!hiddenPanels.contains('jungler'))
            _EditableOverlayPanel(
              id: 'jungler',
              title: 'Jungla enemigo',
              child: _OverlayGlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: _NetworkPortrait(
                        url: jungler?['icon_url']?.toString(),
                        fallbackUrls: _stringValues(
                          jungler?['icon_fallback_urls'],
                        ),
                        size: 56,
                      ),
                      title: Text(
                        '${jungler?['champion_name'] ?? 'Jungla enemigo'} · JUNGLE',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                      subtitle: Text(
                        jungler == null
                            ? 'Esperando identificación del jungla…'
                            : _enemyLocationStatus(
                                jungler,
                                native: _nativeForEnemy(
                                  nativeVision.lastKnown,
                                  jungler,
                                ),
                                now: _now,
                              ),
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (nativeSighting != null || sighting != null)
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.visibility,
                          color: Color(0xFF38BDF8),
                        ),
                        title: Text(
                          nativeSighting != null
                              ? '${nativeSighting.champion} visto en ${nativeSighting.location}'
                              : sighting!.title,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          nativeSighting != null
                              ? '${nativeSighting.region} · hace ${_formatDuration(_now.difference(nativeSighting.timestamp).inSeconds)}'
                              : '${sighting!.message} · hace ${_formatDuration(_now.difference(sighting.receivedAt).inSeconds)}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    const Divider(color: Color(0x3338BDF8), height: 1),
                    if (!nativeVision.recognitionReady)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          nativeVision.recognitionStatus,
                          style: const TextStyle(color: Color(0xFFFBBF24)),
                        ),
                      ),
                    for (final enemy in threats.take(5))
                      ListTile(
                        dense: true,
                        leading: _NetworkPortrait(
                          url: enemy['icon_url']?.toString(),
                          fallbackUrls: _stringValues(
                            enemy['icon_fallback_urls'],
                          ),
                          size: 32,
                        ),
                        title: Text(
                          '${enemy['champion_name'] ?? '?'} · ${enemy['role'] ?? ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          _enemyLocationStatus(
                            enemy,
                            native: _nativeForEnemy(
                              nativeVision.lastKnown,
                              enemy,
                            ),
                            now: _now,
                          ),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if ((nativeVoiceVisible || voice != null || layout.editing) &&
              !hiddenPanels.contains('voice_ask'))
            _EditableOverlayPanel(
              id: 'voice_ask',
              title: 'Coach de voz',
              child: _OverlayGlassCard(
                borderColor: const Color(0xFF818CF8),
                child: ListTile(
                  leading: Icon(
                    nativeSpeech.pushToTalkPressed
                        ? Icons.mic
                        : voice?.raw['state'] == 'recording'
                        ? Icons.mic
                        : voice?.raw['state'] == 'thinking'
                        ? Icons.psychology
                        : voice?.raw['state'] == 'error'
                        ? Icons.error_outline
                        : Icons.record_voice_over,
                    color: const Color(0xFF818CF8),
                  ),
                  title: Text(
                    nativeSpeech.pushToTalkPressed
                        ? 'Escuchando…'
                        : nativeSpeech.transcript.isNotEmpty
                        ? nativeSpeech.transcript
                        : voice?.raw['question']?.toString() ??
                              voice?.title ??
                              'Coach de voz',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    nativeSpeech.pushToTalkPressed
                        ? 'Suelta la tecla para enviar'
                        : nativeVoiceCoach.processing
                        ? 'Preparando respuesta…'
                        : nativeVoiceCoach.advice != null
                        ? nativeVoiceCoach.advice!.ttsText
                        : nativeSpeech.transcript.isNotEmpty
                        ? 'Pregunta entendida'
                        : voice == null
                        ? 'Esperando una interacción de voz…'
                        : _voiceMessage(voice),
                    style: const TextStyle(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
            ),
          if (!hiddenPanels.contains('matchup_info'))
            _EditableOverlayPanel(
              id: 'matchup_info',
              title: 'Enfrentamiento',
              child: _OverlayInfoCard(
                title: 'Enfrentamiento',
                width: 360,
                child: Text(
                  backend.coaching['matchup'] is Map
                      ? (backend.coaching['matchup'] as Map)['win_condition']
                                ?.toString() ??
                            'Esperando condición de victoria…'
                      : 'Esperando análisis del enfrentamiento…',
                ),
              ),
            ),
          if (!hiddenPanels.contains('builds'))
            _EditableOverlayPanel(
              id: 'builds',
              title: 'Build recomendada',
              child: _OverlayInfoCard(
                title: 'Build recomendada',
                width: 360,
                child: _OverlayBuildsView(
                  coachGroups: ref
                      .watch(coachControllerProvider)
                      .itemRecommendationGroups,
                  rawBuilds: backend.coaching['builds'] is Map
                      ? Map<String, dynamic>.from(
                          backend.coaching['builds'] as Map,
                        )
                      : (ref.watch(nativeLeagueProvider).liveGame?['builds']
                                is Map
                            ? Map<String, dynamic>.from(
                                ref
                                        .watch(nativeLeagueProvider)
                                        .liveGame!['builds']
                                    as Map,
                              )
                            : null),
                ),
              ),
            ),
          if (!hiddenPanels.contains('directives'))
            _EditableOverlayPanel(
              id: 'directives',
              title: 'Directivas',
              child: _OverlayInfoCard(
                title: 'Directivas',
                width: 360,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: backend.directives.isEmpty
                      ? const [Text('Esperando directivas…')]
                      : backend.directives
                            .take(3)
                            .map(
                              (directive) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('• ${directive.title}'),
                              ),
                            )
                            .toList(),
                ),
              ),
            ),
          if (!hiddenPanels.contains('team_comp'))
            _EditableOverlayPanel(
              id: 'team_comp',
              title: 'Composición',
              child: _OverlayInfoCard(
                title: 'Composición',
                width: 360,
                child: backend.coaching['team_comp'] is Map
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (backend.coaching['team_comp'] as Map)['identity']
                                    ?.toString() ??
                                'Composición detectada',
                          ),
                          ..._stringValues(
                            (backend.coaching['team_comp']
                                as Map)['guidelines'],
                          ).map((value) => Text('• $value')),
                        ],
                      )
                    : _NativeCompositionView(game: game),
              ),
            ),
          if (gank != null && calibration?.bounds != null)
            _CalibrationDangerRing(
              bounds: calibration!.bounds!,
              danger: gank.raw['threat_level'] == 'DANGER',
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            ),
          if (!hiddenPanels.contains('gold_chart'))
            _EditableOverlayPanel(
              id: 'gold_chart',
              title: 'Diferencia de oro',
              child: _OverlayGlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Diferencia de oro',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      goldDifference == null
                          ? 'Esperando partida…'
                          : _signedNumber(goldDifference),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: goldDifference == null || goldDifference == 0
                                ? const Color(0xFFE2E8F0)
                                : goldDifference > 0
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFF87171),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
