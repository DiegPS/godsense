enum DraftSide { ally, enemy }

enum DraftSelectionState { locked, hovering, picking, unavailable }

class DraftBan {
  const DraftBan({required this.championId, required this.side});

  final int championId;
  final DraftSide side;
}

class DraftPlayer {
  const DraftPlayer({
    required this.cellId,
    required this.championId,
    required this.championName,
    required this.position,
    required this.side,
    required this.selectionState,
    required this.isLocal,
  });

  final int? cellId;
  final int championId;
  final String championName;
  final String position;
  final DraftSide side;
  final DraftSelectionState selectionState;
  final bool isLocal;
}

class DraftSnapshot {
  const DraftSnapshot({
    required this.allies,
    required this.enemies,
    required this.bans,
    required this.allLocked,
  });

  static const empty = DraftSnapshot(
    allies: [],
    enemies: [],
    bans: [],
    allLocked: false,
  );

  final List<DraftPlayer> allies;
  final List<DraftPlayer> enemies;
  final List<DraftBan> bans;
  final bool allLocked;

  factory DraftSnapshot.fromMap(Map<String, dynamic> snapshot) {
    List<DraftPlayer> players(Object? value, DraftSide side) => value is List
        ? value
              .whereType<Map>()
              .map((raw) {
                final player = raw.map(
                  (key, value) => MapEntry(key.toString(), value),
                );
                final championId =
                    (player['champion_id'] as num?)?.toInt() ?? 0;
                final explicit = player['selection_state']?.toString();
                final selectionState = switch (explicit) {
                  'locked' => DraftSelectionState.locked,
                  'picking' => DraftSelectionState.picking,
                  'hovering' => DraftSelectionState.hovering,
                  _ when player['locked'] == true => DraftSelectionState.locked,
                  _ when championId > 0 => DraftSelectionState.hovering,
                  _ => DraftSelectionState.unavailable,
                };
                return DraftPlayer(
                  cellId: (player['cell_id'] as num?)?.toInt(),
                  championId: championId,
                  championName: player['champion_name']?.toString() ?? '',
                  position: player['position']?.toString() ?? '',
                  side: side,
                  selectionState: selectionState,
                  isLocal: player['is_local'] == true,
                );
              })
              .toList(growable: false)
        : const [];

    final bansMap = snapshot['bans'] is Map
        ? (snapshot['bans'] as Map).map(
            (key, value) => MapEntry(key.toString(), value),
          )
        : const <String, dynamic>{};
    List<DraftBan> bans(Object? value, DraftSide side) => value is List
        ? value
              .whereType<num>()
              .map((id) => DraftBan(championId: id.toInt(), side: side))
              .where((ban) => ban.championId > 0)
              .toList(growable: false)
        : const [];
    return DraftSnapshot(
      allies: players(snapshot['my_team'], DraftSide.ally),
      enemies: players(snapshot['their_team'], DraftSide.enemy),
      bans: [
        ...bans(bansMap['my_team_bans'], DraftSide.ally),
        ...bans(bansMap['their_team_bans'], DraftSide.enemy),
      ],
      allLocked: snapshot['all_locked'] == true,
    );
  }
}
