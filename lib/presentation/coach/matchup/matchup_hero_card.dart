import 'package:flutter/material.dart';
import 'package:godsense/presentation/shared/gs_tokens.dart';

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
          final duel = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: GsColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: GsColors.border, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _Champion(
                    name: state.localChampion.isEmpty
                        ? 'Tu campeón'
                        : state.localChampion,
                    championId: localPlayer?.championId ?? 0,
                    role: localPlayer?.position.isNotEmpty == true
                        ? localPlayer!.position
                        : 'ALIADO',
                    accent: CoachColors.accent,
                    isLocal: true,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: GsColors.surfaceHover,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: GsColors.borderInteractive,
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'VS',
                    style: TextStyle(
                      color: GsColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  child: _Champion(
                    name: state.selectedEnemy ?? 'Rival pendiente',
                    championId: selectedEnemyPlayer?.championId ?? 0,
                    role: selectedEnemyPlayer?.position.isNotEmpty == true
                        ? selectedEnemyPlayer!.position
                        : 'RIVAL',
                    accent: GsColors.crimson,
                    isLocal: false,
                  ),
                ),
              ],
            ),
          );

          final actions = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (enemies.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.sports_martial_arts_outlined,
                      size: 15,
                      color: GsColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Selecciona tu rival de línea:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: GsColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final enemy in enemies) ...[
                      _EnemyPickerChip(
                        name: enemy.championName,
                        championId: enemy.championId,
                        isSelected: enemy.championName == state.selectedEnemy,
                        onTap: () => onEnemySelected(enemy.championName),
                      ),
                    ],
                  ],
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GsColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GsColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: GsColors.textMuted,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'League todavía no ha revelado un rival.',
                          style: TextStyle(
                            color: GsColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (state.matchup case final matchup?) ...[
                const SizedBox(height: 12),
                _MatchupSummary(matchup: matchup),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: importing ? null : onImport,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                  backgroundColor: GsColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                icon: importing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.download_done_outlined, size: 18),
                label: const Text(
                  'Importar setup disponible',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              if (state.importFeedback.message != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          state.importFeedback.status ==
                              CoachImportStatus.failed
                          ? GsColors.crimsonGlow
                          : GsColors.emeraldGlow,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            state.importFeedback.status ==
                                CoachImportStatus.failed
                            ? GsColors.crimson
                            : GsColors.emeraldGlow,
                      ),
                    ),
                    child: Text(
                      state.importFeedback.message!,
                      style: TextStyle(
                        color:
                            state.importFeedback.status ==
                                CoachImportStatus.failed
                            ? GsColors.crimson
                            : GsColors.emerald,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );

          if (constraints.maxWidth < 760) {
            return Column(
              children: [duel, const SizedBox(height: 16), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 3, child: duel),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _MatchupSummary extends StatelessWidget {
  const _MatchupSummary({required this.matchup});

  final CoachMatchupViewData matchup;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GsColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GsColors.accentTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (matchup.winCondition.isNotEmpty) ...[
            const Text(
              'CONDICIÓN DE LÍNEA',
              style: TextStyle(
                color: GsColors.accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              matchup.winCondition,
              style: const TextStyle(
                color: GsColors.textPrimary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
          for (final pattern in matchup.tradingPatterns.take(2)) ...[
            const SizedBox(height: 6),
            Text(
              '• $pattern',
              style: const TextStyle(
                color: GsColors.textSecondary,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
          if (matchup.powerSpikes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '⚡ ${matchup.powerSpikes.first}',
              style: const TextStyle(
                color: GsColors.amber,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EnemyPickerChip extends StatelessWidget {
  const _EnemyPickerChip({
    required this.name,
    required this.championId,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final int championId;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Seleccionar $name como rival de línea',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? GsColors.crimsonGlow
                  : GsColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? GsColors.crimson
                    : GsColors.borderInteractive,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? GsColors.crimson : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: AssetPortrait(
                    semanticLabel: name,
                    url: communityDragonChampionIcon(championId),
                    size: 24,
                    circular: true,
                    fallback: Icons.person_outline,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? GsColors.crimson : GsColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Champion extends StatelessWidget {
  const _Champion({
    required this.name,
    required this.championId,
    required this.role,
    required this.accent,
    required this.isLocal,
  });

  final String name;
  final int championId;
  final String role;
  final Color accent;
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            role.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: accent,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: 2),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: .25), blurRadius: 8),
            ],
          ),
          child: AssetPortrait(
            semanticLabel: name,
            url: communityDragonChampionIcon(championId),
            size: 58,
            circular: true,
            fallback: Icons.person_outline,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: CoachColors.primaryText,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
