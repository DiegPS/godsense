import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/coach_controller.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/game_session.dart';

void main() {
  const resolver = CoachPhaseResolver();

  test('prioritizes an active Live Client game', () {
    expect(
      resolver.resolve(
        session: const GameSessionState(),
        liveGameActive: true,
        gameflowPhase: 'ChampSelect',
      ),
      CoachPhase.inGame,
    );
  });

  test('normalizes champ select and post-game phases', () {
    expect(
      resolver.resolve(
        session: const GameSessionState(),
        liveGameActive: false,
        gameflowPhase: 'IN_SELECT',
      ),
      CoachPhase.champSelect,
    );
    expect(
      resolver.resolve(
        session: const GameSessionState(),
        liveGameActive: false,
        gameflowPhase: 'EndOfGame',
      ),
      CoachPhase.postGame,
    );
  });

  test('uses the typed game session when gameflow is unavailable', () {
    expect(
      resolver.resolve(
        session: GameSessionState(
          current: _session(GameSessionPhase.champSelect),
        ),
        liveGameActive: false,
        gameflowPhase: 'NO_LCU',
      ),
      CoachPhase.champSelect,
    );
  });
}

GameSession _session(GameSessionPhase phase) => GameSession(
  sessionId: 'session',
  generation: GameSessionGeneration(1),
  accountPuuid: Puuid('player'),
  phase: phase,
  startedAt: DateTime.utc(2026),
  lastObservedAt: DateTime.utc(2026),
);
