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
    final companion = ref.watch(companionControllerProvider);
    final nativeVision = ref.watch(nativeVisionProvider);
    final nativeSpeech = ref.watch(nativeSpeechProvider);
    final nativeVoiceCoach = ref.watch(nativeVoiceCoachProvider);
    final calibration = ref.watch(nativeCalibrationProvider).calibration;
    final game = ref.watch(effectiveGameProvider);
    final goldDifference = (game?.raw['team_gold_diff'] as num?)?.toInt();
    final sighting = companion.alerts
        .where((alert) => alert.kind == CompanionAlertKind.junglerSighting)
        .where((alert) => _now.difference(alert.receivedAt).inSeconds < 180)
        .firstOrNull;
    final gank = companion.alerts
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
    final voice = companion.alerts
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
    final visibilityEvent = companion.alerts
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
    final hiddenPanels = companion.settings?.overlayHiddenPanels ?? const [];
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
              child: _GankAlertHUD(nativeGank: nativeGank, gank: gank),
            ),
          if (!hiddenPanels.contains('jungler'))
            _EditableOverlayPanel(
              id: 'jungler',
              title: 'Jungla enemigo',
              child: _ThreatRadarHUD(
                jungler: jungler,
                threats: threats,
                nativeSighting: nativeSighting,
                sighting: sighting,
                nativeVision: nativeVision,
                now: _now,
              ),
            ),
          if ((nativeVoiceVisible || voice != null || layout.editing) &&
              !hiddenPanels.contains('voice_ask'))
            _EditableOverlayPanel(
              id: 'voice_ask',
              title: 'Coach de voz',
              child: _VoiceCapsuleHUD(
                isListening: nativeSpeech.pushToTalkPressed,
                transcript: nativeSpeech.transcript,
                isProcessing: nativeVoiceCoach.processing,
                adviceText: nativeVoiceCoach.advice?.ttsText,
                voiceAlert: voice,
              ),
            ),
          if (!hiddenPanels.contains('matchup_info'))
            _EditableOverlayPanel(
              id: 'matchup_info',
              title: 'Enfrentamiento',
              child: _MatchupInfoHUD(
                matchupData: companion.coaching['matchup'],
              ),
            ),
          if (!hiddenPanels.contains('builds'))
            _EditableOverlayPanel(
              id: 'builds',
              title: 'Build recomendada',
              child: _LinearBuildsHUD(
                coachGroups: ref
                    .watch(coachControllerProvider)
                    .itemRecommendationGroups,
                rawBuilds: companion.coaching['builds'] is Map
                    ? Map<String, dynamic>.from(
                        companion.coaching['builds'] as Map,
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
          if (!hiddenPanels.contains('directives'))
            _EditableOverlayPanel(
              id: 'directives',
              title: 'Directivas',
              child: _PriorityDirectivesHUD(directives: companion.directives),
            ),
          if (!hiddenPanels.contains('team_comp'))
            _EditableOverlayPanel(
              id: 'team_comp',
              title: 'Composición',
              child: _EsportsCompositionHUD(
                game: game,
                aiTeamComp: companion.coaching['team_comp'] is Map
                    ? Map<String, dynamic>.from(
                        companion.coaching['team_comp'] as Map,
                      )
                    : null,
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
              child: _MiniGoldBadgeHUD(goldDifference: goldDifference),
            ),
        ],
      ),
    );
  }
}
