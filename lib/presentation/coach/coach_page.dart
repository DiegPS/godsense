import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/coach_controller.dart';
import '../../application/dependencies.dart';
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

class CoachPage extends ConsumerWidget {
  const CoachPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(coachControllerProvider);
    final controller = ref.read(coachControllerProvider.notifier);
    final importing =
        state.importFeedback.status == CoachImportStatus.importing;
    return ColoredBox(
      color: CoachColors.canvas,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          CoachSectionHeader(
            phase: state.phase,
            automaticPhase: state.automaticPhase,
            onPhaseSelected: controller.showPhase,
          ),
          const SizedBox(height: 18),
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
                const AiCoachChatCard(),
              ],
            ),
          ] else if (state.phase == CoachPhase.inGame) ...[
            _AdaptiveGrid(
              children: [
                LiveDirectivesCard(directives: state.directives),
                ThreatAndSightingsCard(threats: state.threats),
                ItemBundlesView(
                  groups: state.itemRecommendationGroups,
                  importing: importing,
                  onImport: controller.importItemSet,
                ),
                GoldTimelineCard(
                  differential: state.goldDifferential,
                  points: state.goldTimeline,
                ),
                VoiceCoachCard(
                  processing: state.voiceProcessing,
                  history: state.voiceHistory,
                ),
                const AiCoachChatCard(),
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
            const AiCoachChatCard(),
          ] else ...[
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
            const AiCoachChatCard(),
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

class _AdaptiveGrid extends StatelessWidget {
  const _AdaptiveGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050 ? 2 : 1;
        if (columns == 1) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                const SizedBox(height: 16),
              ],
            ],
          );
        }
        final left = <Widget>[];
        final right = <Widget>[];
        for (var index = 0; index < children.length; index++) {
          (index.isEven ? left : right).add(children[index]);
        }
        Widget column(List<Widget> values) => Column(
          children: [
            for (final child in values) ...[child, const SizedBox(height: 16)],
          ],
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: column(left)),
            const SizedBox(width: 16),
            Expanded(child: column(right)),
          ],
        );
      },
    );
  }
}
