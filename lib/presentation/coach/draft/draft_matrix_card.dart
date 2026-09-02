import 'package:flutter/material.dart';

import '../../../domain/league/draft_models.dart';
import '../../shared/resilient_network_image.dart';
import '../shared/asset_portrait.dart';
import '../shared/coach_surface.dart';

class DraftMatrixCard extends StatelessWidget {
  const DraftMatrixCard({super.key, required this.draft});

  final DraftSnapshot draft;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      title: 'Draft 5v5 y bans',
      icon: Icons.groups_2_outlined,
      subtitle: draft.allLocked
          ? 'Todas las selecciones están bloqueadas'
          : 'Se actualiza con la selección de campeón',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ally = _Roster(
            title: 'Aliados',
            players: draft.allies,
            color: CoachColors.cyan,
          );
          final enemy = _Roster(
            title: 'Rivales',
            players: draft.enemies,
            color: CoachColors.crimson,
          );
          return Column(
            children: [
              if (constraints.maxWidth < 700)
                Column(children: [ally, const SizedBox(height: 12), enemy])
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: ally),
                    const SizedBox(width: 12),
                    Expanded(child: enemy),
                  ],
                ),
              const SizedBox(height: 14),
              _Bans(bans: draft.bans),
            ],
          );
        },
      ),
    );
  }
}

class _Roster extends StatelessWidget {
  const _Roster({
    required this.title,
    required this.players,
    required this.color,
  });

  final String title;
  final List<DraftPlayer> players;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < 5; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _DraftPlayerRow(
              player: index < players.length ? players[index] : null,
              color: color,
            ),
          ),
      ],
    );
  }
}

class _DraftPlayerRow extends StatelessWidget {
  const _DraftPlayerRow({required this.player, required this.color});

  final DraftPlayer? player;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final state = player?.selectionState ?? DraftSelectionState.unavailable;
    final label = switch (state) {
      DraftSelectionState.locked => 'CONFIRMADO',
      DraftSelectionState.hovering => 'MOSTRANDO',
      DraftSelectionState.picking => 'ELIGIENDO',
      DraftSelectionState.unavailable => 'ESPERANDO',
    };
    final name = player?.championName.isNotEmpty == true
        ? player!.championName
        : 'Sin selección';
    return Semantics(
      label:
          '$name, ${player?.position.isNotEmpty == true ? player!.position : 'rol pendiente'}, $label',
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: CoachColors.elevated,
          borderRadius: BorderRadius.circular(8),
          border: player?.isLocal == true ? Border.all(color: color) : null,
        ),
        child: Row(
          children: [
            AssetPortrait(
              semanticLabel: name,
              url: communityDragonChampionIcon(player?.championId ?? 0),
              size: 32,
              circular: true,
              fallback: Icons.person_outline,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CoachColors.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    player?.position.isNotEmpty == true
                        ? player!.position
                        : 'Rol pendiente',
                    style: const TextStyle(
                      color: CoachColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: state == DraftSelectionState.locked
                    ? CoachColors.emerald.withValues(alpha: .15)
                    : CoachColors.amber.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: state == DraftSelectionState.locked
                      ? CoachColors.emerald
                      : CoachColors.amber,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bans extends StatelessWidget {
  const _Bans({required this.bans});

  final List<DraftBan> bans;

  @override
  Widget build(BuildContext context) {
    if (bans.isEmpty) {
      return const CoachEmptyState(message: 'Sin bans revelados todavía.');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final ban in bans)
          Chip(
            avatar: AssetPortrait(
              semanticLabel: 'Campeón bloqueado ${ban.championId}',
              url: communityDragonChampionIcon(ban.championId),
              size: 22,
              circular: true,
              fallback: Icons.block,
            ),
            label: Text(
              '${ban.side == DraftSide.ally ? 'Aliado' : 'Rival'} · ${ban.championId}',
            ),
          ),
      ],
    );
  }
}
