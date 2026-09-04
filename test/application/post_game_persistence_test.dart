import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:godsense/application/coach_controller.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/game_session.dart';
import 'package:godsense/infrastructure/persistence/shared_preferences_post_game_report_store.dart';

void main() {
  test('report survives restart and is isolated by account', () async {
    SharedPreferences.setMockInitialValues({});
    CoachController create() => CoachController(
      importRunes: (_) async {},
      importItems: () async {},
      reportStore: const SharedPreferencesPostGameReportStore(),
    );
    final first = create();
    first.synchronize(_inputs('A', ended: true));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(first.state.postGameReport?.champion, 'Ahri');
    first.dispose();
    final restored = create();
    addTearDown(restored.dispose);
    restored.synchronize(_inputs('A'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(restored.state.postGameReport?.champion, 'Ahri');
    expect(restored.state.postGameReport?.matchLabel, 'LA1:123');
    restored.synchronize(_inputs('B'));
    expect(restored.state.postGameReport, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(restored.state.postGameReport, isNull);
  });
}

CoachInputs _inputs(String account, {bool ended = false}) => CoachInputs(
  accountKey: account,
  gameflowPhase: ended ? 'EndOfGame' : 'None',
  session: GameSessionState(
    lastCompleted: ended
        ? GameSession(
            sessionId: 'test-session',
            generation: const GameSessionGeneration(1),
            accountPuuid: Puuid(account),
            phase: GameSessionPhase.completed,
            startedAt: DateTime.utc(2026),
            lastObservedAt: DateTime.utc(2026),
            match: MatchKey(platformId: PlatformId('LA1'), gameId: 123),
          )
        : null,
  ),
  liveGame: ended
      ? {
          '_game_ended': true,
          'game_time': 1200,
          'active_player': {
            'champion_name': 'Ahri',
            'kda': [3, 2, 7],
            'cs': 120,
          },
        }
      : null,
  lobby: null,
  runes: null,
  items: null,
  jungle: null,
  directives: const [],
  threats: const [],
  voiceProcessing: false,
  voiceQuestion: '',
  voiceAdvice: null,
  voiceAnsweredAt: null,
);
