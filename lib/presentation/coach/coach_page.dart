import 'package:flutter/material.dart';
import 'package:flutter_consistent_ui/flutter_consistent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/coach_controller.dart';
import '../../application/dependencies.dart';
import '../../application/native_speech_controller.dart';
import '../shared/speech_readiness.dart';
import '../../domain/league/draft_models.dart';
import 'draft/composition_breakdown_card.dart';
import 'draft/draft_matrix_card.dart';
import 'draft/pick_advice_card.dart';
import 'live/ai_coach_chat_card.dart';
import 'live/gold_timeline_card.dart';
import 'live/live_directives_card.dart';
import 'live/threat_and_sightings_card.dart';
import 'live/voice_coach_card.dart';
import 'matchup/matchup_hero_card.dart';
import 'post_game/post_game_summary.dart';
import 'setup/item_bundles_view.dart';
import 'setup/riot_jungle_route_view.dart';
import 'setup/rune_tree_view.dart';
import 'shared/coach_section_header.dart';
import 'shared/coach_surface.dart';
import '../shared/gs_feature_page.dart';
import '../shell/retained_page_stack.dart';

class CoachPage extends ConsumerWidget {
  const CoachPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ActivePageWatch(context, ref);
    final CoachState state =
        watch<CoachState?>(
          coachControllerProvider.select(
            (state) => state.phase == CoachPhase.inGame ? null : state,
          ),
        ) ??
        ref.read<CoachState>(coachControllerProvider);
    watch(
      coachControllerProvider.select(
        (state) => (state.phase, state.automaticPhase),
      ),
    );
    final controller = ref.read(coachControllerProvider.notifier);
    final importing =
        state.importFeedback.status == CoachImportStatus.importing;
    return ColoredBox(
      color: CoachColors.canvas,
      child: GsFeaturePage(
        children: [
          CoachSectionHeader(
            phase: state.phase,
            automaticPhase: state.automaticPhase,
            onPhaseSelected: controller.showPhase,
          ),
          const SizedBox(height: 18),
          const AiCoachChatCard(key: ValueKey('coach-shared-chat')),
          const SizedBox(height: 16),
          if (state.phase == CoachPhase.champSelect) ...[
            MatchupHeroCard(
              state: state,
              onEnemySelected: controller.selectEnemy,
              onImport:
                  state.runeRecommendations.isEmpty &&
                      state.itemRecommendationGroups.isEmpty
                  ? null
                  : controller.importCurrentSetup,
            ),
            const SizedBox(height: 16),
            _AdaptiveGrid(
              children: [
                DraftMatrixCard(
                  draft: state.lobby?.draft ?? DraftSnapshot.empty,
                ),
                CompositionBreakdownCard(
                  ally: state.allyComposition,
                  enemy: state.enemyComposition,
                ),
                RuneTreeView(
                  variants: state.runeRecommendations,
                  importing: importing,
                  onImport: (value) => controller.importRune(value.variant),
                ),
                ItemBundlesView(
                  groups: state.itemRecommendationGroups,
                  importing: importing,
                  onImport: controller.importItemSet,
                ),
                RiotJungleRouteView(bundle: state.jungle),
                PickAdviceCard(advice: state.pickAdvice),
              ],
            ),
          ] else if (state.phase == CoachPhase.inGame) ...[
            const _AdaptiveGrid(
              children: [
                _LiveDirectives(),
                _LiveThreats(),
                _LiveItems(),
                _LiveGold(),
                _LiveVoice(),
              ],
            ),
          ] else if (state.phase == CoachPhase.postGame) ...[
            PostGameSummary(
              session: state.lastCompletedSession,
              report: state.postGameReport,
            ),
            const SizedBox(height: 16),
            VoiceCoachCard(
              processing: state.voiceProcessing,
              history: state.voiceHistory,
            ),
            const SizedBox(height: 16),
          ] else ...[
            if (state.postGameReport != null) ...[
              PostGameSummary(
                session: state.lastCompletedSession,
                report: state.postGameReport,
              ),
              const SizedBox(height: 16),
            ],
            const CoachSurface(
              title: 'Conecta League para comenzar',
              icon: Icons.link_outlined,
              child: CoachEmptyState(
                message:
                    'GodSense activará automáticamente preparación, draft o '
                    'asistencia en partida cuando detecte el cliente.',
              ),
            ),
            const SizedBox(height: 16),
            RuneTreeView(
              variants: state.runeRecommendations,
              importing: importing,
              onImport: (value) => controller.importRune(value.variant),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdaptiveGrid extends StatefulWidget {
  const _AdaptiveGrid({required this.children});

  final List<Widget> children;

  @override
  State<_AdaptiveGrid> createState() => _AdaptiveGridState();
}

class _AdaptiveGridState extends State<_AdaptiveGrid> {
  ThemeData? _baseTheme;
  ThemeData? _gridTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!identical(_baseTheme, theme)) {
      _baseTheme = theme;
      _gridTheme = theme.copyWith(
        extensions: [
          ...theme.extensions.values.where((value) => value is! UiThemeData),
          UiThemeData.of(context).copyWith(minimumFieldWidth: 480),
        ],
      );
    }
    return Theme(
      data: _gridTheme!,
      child: UiFormGrid(children: widget.children),
    );
  }
}

// Live values rebuild only their card; a gold sample must not rebuild the chat,
// item portraits, phase controls, and all the other page sections.
class _LiveGold extends ConsumerWidget {
  const _LiveGold();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ActivePageWatch(context, ref);
    final data = watch(
      coachControllerProvider.select(
        (s) => (s.goldDifferential, s.goldTimeline),
      ),
    );
    return RepaintBoundary(
      child: GoldTimelineCard(differential: data.$1, points: data.$2),
    );
  }
}

class _LiveItems extends ConsumerWidget {
  const _LiveItems();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ActivePageWatch(context, ref);
    final data = watch(
      coachControllerProvider.select(
        (s) => (s.itemRecommendationGroups, s.importFeedback.status),
      ),
    );
    return ItemBundlesView(
      groups: data.$1,
      importing: data.$2 == CoachImportStatus.importing,
      onImport: ref.read(coachControllerProvider.notifier).importItemSet,
    );
  }
}

class _LiveDirectives extends ConsumerWidget {
  const _LiveDirectives();
  @override
  Widget build(BuildContext context, WidgetRef ref) => LiveDirectivesCard(
    directives: ActivePageWatch(context, ref)(
      coachControllerProvider.select((s) => s.directives),
    ),
  );
}

class _LiveThreats extends ConsumerWidget {
  const _LiveThreats();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ThreatAndSightingsCard(
    threats: ActivePageWatch(context, ref)(
      coachControllerProvider.select((s) => s.threats),
    ),
  );
}

class _LiveVoice extends ConsumerWidget {
  const _LiveVoice();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ActivePageWatch(context, ref);
    final data = watch(
      coachControllerProvider.select(
        (s) => (s.voiceProcessing, s.voiceHistory),
      ),
    );
    final speech = watch(nativeSpeechProvider);
    final readiness = speechReadiness(speech);
    return VoiceCoachCard(
      processing: data.$1,
      history: data.$2,
      speaking: speech.ttsBusy,
      onStopSpeaking: () =>
          ref.read(nativeSpeechProvider.notifier).stopSpeaking(),
      statusMessage: !readiness.ready
          ? readiness.detail
          : !speech.settings.ttsEnabled
          ? 'Las respuestas habladas están desactivadas. Los consejos siguen disponibles como texto.'
          : speech.modelsChecked && !speech.ttsModelInstalled
          ? 'Descarga una voz en Ajustes para escuchar las respuestas.'
          : null,
      onAdviceRequested: () => ref
          .read(nativeVoiceCoachProvider.notifier)
          .handleQuestion('¿Qué hago ahora?'),
    );
  }
}
