import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/game_session_coordinator.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/game_session.dart';

void main() {
  var now = DateTime.utc(2026, 9, 1);
  late GameSessionCoordinator coordinator;

  setUp(() {
    now = DateTime.utc(2026, 9, 1);
    coordinator = GameSessionCoordinator(now: () => now);
  });

  test('starts in champ select and adopts gameId without new generation', () {
    final provisional = coordinator
        .observeLcu(
          connected: true,
          gameflowPhase: 'ChampSelect',
          accountPuuid: Puuid('a'),
          platformId: PlatformId('LA1'),
        )
        .current!;
    now = now.add(const Duration(minutes: 2));
    final active = coordinator
        .observeLcu(
          connected: true,
          gameflowPhase: 'InProgress',
          accountPuuid: Puuid('a'),
          platformId: PlatformId('LA1'),
          gameId: 123,
        )
        .current!;

    expect(provisional.phase, GameSessionPhase.champSelect);
    expect(active.match.toString(), 'LA1:123');
    expect(active.generation.value, provisional.generation.value);
    expect(active.sessionId, provisional.sessionId);
    expect(active.startedAt, provisional.startedAt);
  });

  test('LCU disconnect does not destroy a live session', () {
    coordinator.observeLiveClient(
      available: true,
      accountPuuid: Puuid('a'),
      platformId: PlatformId('LA1'),
      gameId: 123,
      gameTimeSeconds: 30,
    );

    final disconnected = coordinator.observeLcu(
      connected: false,
      gameflowPhase: 'NO_LCU',
    );

    expect(disconnected.current?.match?.gameId, 123);
    expect(disconnected.current?.phase, GameSessionPhase.inProgress);
  });

  test('postgame completion keeps a completed session for history', () {
    coordinator.observeLiveClient(
      available: true,
      accountPuuid: Puuid('a'),
      platformId: PlatformId('LA1'),
      gameId: 123,
      gameTimeSeconds: 1200,
    );
    coordinator.observeLcu(
      connected: true,
      gameflowPhase: 'WaitingForStats',
      accountPuuid: Puuid('a'),
      platformId: PlatformId('LA1'),
      gameId: 123,
    );
    now = now.add(const Duration(seconds: 1));

    final completed = coordinator.observeLiveClient(
      available: false,
      accountPuuid: Puuid('a'),
      platformId: PlatformId('LA1'),
      gameId: 123,
    );

    expect(completed.current, isNull);
    expect(completed.lastCompleted?.phase, GameSessionPhase.completed);
    expect(completed.lastCompleted?.endReason, GameSessionEndReason.normal);
    expect(completed.lastCompleted?.endedAt, now);
  });

  test('account switch ends old session and starts a new active one', () {
    final old = coordinator
        .observeLcu(
          connected: true,
          gameflowPhase: 'InProgress',
          accountPuuid: Puuid('a'),
          platformId: PlatformId('LA1'),
          gameId: 1,
        )
        .current!;

    final switched = coordinator.observeLcu(
      connected: true,
      gameflowPhase: 'InProgress',
      accountPuuid: Puuid('b'),
      platformId: PlatformId('LA1'),
      gameId: 2,
    );

    expect(
      switched.lastCompleted?.endReason,
      GameSessionEndReason.accountSwitched,
    );
    expect(switched.current?.accountPuuid?.value, 'b');
    expect(switched.current?.generation.value, old.generation.value + 1);
  });

  test('game clock reset creates a new provisional generation', () {
    final first = coordinator
        .observeLiveClient(
          available: true,
          accountPuuid: Puuid('a'),
          platformId: PlatformId('LA1'),
          gameTimeSeconds: 900,
        )
        .current!;

    final second = coordinator.observeLiveClient(
      available: true,
      accountPuuid: Puuid('a'),
      platformId: PlatformId('LA1'),
      gameTimeSeconds: 2,
    );

    expect(
      second.lastCompleted?.endReason,
      GameSessionEndReason.replacedByAnotherMatch,
    );
    expect(second.current?.generation.value, first.generation.value + 1);
  });

  test('leaving champ select records cancellation', () {
    coordinator.observeLcu(
      connected: true,
      gameflowPhase: 'ChampSelect',
      accountPuuid: Puuid('a'),
      platformId: PlatformId('LA1'),
    );

    final cancelled = coordinator.observeLcu(
      connected: true,
      gameflowPhase: 'Lobby',
      accountPuuid: Puuid('a'),
      platformId: PlatformId('LA1'),
    );

    expect(cancelled.current, isNull);
    expect(
      cancelled.lastCompleted?.endReason,
      GameSessionEndReason.champSelectCancelled,
    );
  });
}
