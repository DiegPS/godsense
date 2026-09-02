import 'package:flutter/material.dart';

import '../../../application/coach_controller.dart';
import '../../shared/resilient_network_image.dart';
import '../shared/asset_portrait.dart';
import '../shared/coach_surface.dart';

class MatchupHeroCard extends StatelessWidget {
  const MatchupHeroCard({
    super.key,
    required this.state,
    required this.onEnemySelected,
    required this.onImport,
  });

  final CoachState state;
  final ValueChanged<String> onEnemySelected;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final enemies =
        state.lobby?.draft.enemies
            .where((player) => player.championName.isNotEmpty)
            .toList(growable: false) ??
        const [];
    final importing =
        state.importFeedback.status == CoachImportStatus.importing;
    final localPlayer = state.lobby?.draft.allies
        .where((player) => player.isLocal)
        .firstOrNull;
    final selectedEnemyPlayer = state.lobby?.draft.enemies
        .where((player) => player.championName == state.selectedEnemy)
        .firstOrNull;
    return CoachSurface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final duel = Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _Champion(
                  name: state.localChampion.isEmpty
                      ? 'Tu campeón'
                      : state.localChampion,
                  championId: localPlayer?.championId ?? 0,
                  accent: CoachColors.cyan,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: CoachColors.secondaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              Expanded(
                child: _Champion(
                  name: state.selectedEnemy ?? 'Rival pendiente',
                  championId: selectedEnemyPlayer?.championId ?? 0,
                  accent: CoachColors.crimson,
                ),
              ),
            ],
          );
          final actions = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (enemies.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: state.selectedEnemy,
                  decoration: const InputDecoration(
                    labelText: 'Rival de línea',
                    prefixIcon: Icon(Icons.sports_martial_arts_outlined),
                  ),
                  items: [
                    for (final enemy in enemies)
                      DropdownMenuItem(
                        value: enemy.championName,
                        child: Text(enemy.championName),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onEnemySelected(value);
                  },
                )
              else
                const Text(
                  'League todavía no ha revelado un rival.',
                  style: TextStyle(color: CoachColors.secondaryText),
                ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: importing ? null : onImport,
                icon: importing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_done_outlined),
                label: const Text('Importar setup disponible'),
              ),
              if (state.importFeedback.message != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    state.importFeedback.message!,
                    style: TextStyle(
                      color:
                          state.importFeedback.status ==
                              CoachImportStatus.failed
                          ? CoachColors.crimson
                          : CoachColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          );
          if (constraints.maxWidth < 760) {
            return Column(
              children: [duel, const SizedBox(height: 18), actions],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: duel),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _Champion extends StatelessWidget {
  const _Champion({
    required this.name,
    required this.championId,
    required this.accent,
  });

  final String name;
  final int championId;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: 2),
          ),
          child: AssetPortrait(
            semanticLabel: name,
            url: communityDragonChampionIcon(championId),
            size: 64,
            circular: true,
            fallback: Icons.person_outline,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: CoachColors.primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
