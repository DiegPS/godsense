import '../domain/identity/league_identity.dart';
import '../domain/league/game_session.dart';

class GameSessionCoordinator {
  GameSessionCoordinator({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  GameSessionState _state = const GameSessionState();
  int _generation = 0;
  int _provisionalCounter = 0;
  String _lastLcuPhase = 'NO_LCU';

  GameSessionState get state => _state;

  GameSessionState observeLcu({
    required bool connected,
    required String gameflowPhase,
    Puuid? accountPuuid,
    PlatformId? platformId,
    int? gameId,
  }) {
    if (!connected) return _state;
    _lastLcuPhase = gameflowPhase;
    final now = _now().toUtc();
    final match = gameId == null || platformId == null
        ? null
        : MatchKey(platformId: platformId, gameId: gameId);
    _handleAccountSwitch(accountPuuid, now);
    _handleMatchReplacement(match, accountPuuid, now);

    final targetPhase = _phaseForLcu(gameflowPhase);
    if (targetPhase != null) {
      final current = _state.current;
      if (current == null) {
        _start(
          phase: targetPhase,
          accountPuuid: accountPuuid,
          match: match,
          now: now,
        );
      } else {
        _state = GameSessionState(
          current: current.copyWith(
            accountPuuid: accountPuuid,
            phase: targetPhase,
            match: match,
            lastObservedAt: now,
          ),
          lastCompleted: _state.lastCompleted,
        );
      }
      return _state;
    }

    final current = _state.current;
    if (current != null && _isOutsideSession(gameflowPhase)) {
      final reason = current.phase == GameSessionPhase.champSelect
          ? GameSessionEndReason.champSelectCancelled
          : GameSessionEndReason.normal;
      _complete(reason, now);
    }
    return _state;
  }

  GameSessionState observeLiveClient({
    required bool available,
    Puuid? accountPuuid,
    PlatformId? platformId,
    int? gameId,
    double? gameTimeSeconds,
  }) {
    final now = _now().toUtc();
    final match = gameId == null || platformId == null
        ? null
        : MatchKey(platformId: platformId, gameId: gameId);
    _handleAccountSwitch(accountPuuid, now);
    _handleMatchReplacement(match, accountPuuid, now);
    if (available) {
      final gameTime = gameTimeSeconds == null || gameTimeSeconds < 0
          ? null
          : GameTime(Duration(milliseconds: (gameTimeSeconds * 1000).round()));
      var current = _state.current;
      if (current?.lastGameTime != null &&
          gameTime != null &&
          gameTime.milliseconds + 5000 < current!.lastGameTime!.milliseconds) {
        _complete(GameSessionEndReason.replacedByAnotherMatch, now);
        current = null;
      }
      if (current == null) {
        _start(
          phase: GameSessionPhase.inProgress,
          accountPuuid: accountPuuid,
          match: match,
          gameTime: gameTime,
          now: now,
        );
      } else {
        _state = GameSessionState(
          current: current.copyWith(
            accountPuuid: accountPuuid,
            phase: GameSessionPhase.inProgress,
            match: match,
            lastGameTime: gameTime,
            lastObservedAt: now,
          ),
          lastCompleted: _state.lastCompleted,
        );
      }
    } else if (_state.current?.phase == GameSessionPhase.postGame ||
        _isOutsideSession(_lastLcuPhase)) {
      _complete(GameSessionEndReason.normal, now);
    }
    return _state;
  }

  void _handleAccountSwitch(Puuid? accountPuuid, DateTime now) {
    final currentAccount = _state.current?.accountPuuid;
    if (currentAccount != null &&
        accountPuuid != null &&
        currentAccount != accountPuuid) {
      _complete(GameSessionEndReason.accountSwitched, now);
    }
  }

  void _handleMatchReplacement(
    MatchKey? match,
    Puuid? accountPuuid,
    DateTime now,
  ) {
    final currentMatch = _state.current?.match;
    if (currentMatch != null && match != null && currentMatch != match) {
      _complete(GameSessionEndReason.replacedByAnotherMatch, now);
      _start(
        phase: GameSessionPhase.inProgress,
        accountPuuid: accountPuuid,
        match: match,
        now: now,
      );
    }
  }

  void _start({
    required GameSessionPhase phase,
    required Puuid? accountPuuid,
    required MatchKey? match,
    required DateTime now,
    GameTime? gameTime,
  }) {
    _generation++;
    _provisionalCounter++;
    _state = GameSessionState(
      current: GameSession(
        sessionId: match?.toString() ?? 'provisional-$_provisionalCounter',
        generation: GameSessionGeneration(_generation),
        accountPuuid: accountPuuid,
        phase: phase,
        match: match,
        startedAt: now,
        lastObservedAt: now,
        lastGameTime: gameTime,
      ),
      lastCompleted: _state.lastCompleted,
    );
  }

  void _complete(GameSessionEndReason reason, DateTime now) {
    final current = _state.current;
    if (current == null) return;
    _state = GameSessionState(
      lastCompleted: current.copyWith(
        phase: GameSessionPhase.completed,
        lastObservedAt: now,
        endedAt: now,
        endReason: reason,
      ),
    );
  }
}

GameSessionPhase? _phaseForLcu(String phase) => switch (phase) {
  'ChampSelect' => GameSessionPhase.champSelect,
  'GameStart' => GameSessionPhase.starting,
  'InProgress' => GameSessionPhase.inProgress,
  'PreEndOfGame' ||
  'WaitingForStats' ||
  'EndOfGame' => GameSessionPhase.postGame,
  _ => null,
};

bool _isOutsideSession(String phase) => switch (phase) {
  'None' || 'Lobby' || 'Matchmaking' || 'ReadyCheck' => true,
  _ => false,
};
