import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/league/draft_models.dart';

void main() {
  test('normalizes draft players, selection states, and bans', () {
    final draft = DraftSnapshot.fromMap({
      'my_team': [
        {
          'cell_id': 1,
          'champion_id': 22,
          'champion_name': 'Ashe',
          'position': 'BOTTOM',
          'selection_state': 'locked',
          'is_local': true,
        },
      ],
      'their_team': [
        {
          'cell_id': 6,
          'champion_id': 103,
          'champion_name': 'Ahri',
          'selection_state': 'hovering',
        },
      ],
      'bans': {
        'my_team_bans': [11, 0],
        'their_team_bans': [64],
      },
      'all_locked': false,
    });

    expect(draft.allies.single.selectionState, DraftSelectionState.locked);
    expect(draft.allies.single.isLocal, isTrue);
    expect(draft.enemies.single.selectionState, DraftSelectionState.hovering);
    expect(draft.bans.map((ban) => ban.championId), [11, 64]);
    expect(draft.bans.last.side, DraftSide.enemy);
  });
}
