import '../identity/league_identity.dart';

enum GameSessionPhase { champSelect, starting, inProgress, postGame, completed }

enum GameSessionEndReason {
  normal,
  champSelectCancelled,
  accountSwitched,
  replacedByAnotherMatch,
}

class GameSession {
  const GameSession({
    required this.sessionId,
    required this.generation,
    required this.accountPuuid,
    required this.phase,
    required this.startedAt,
    required this.lastObservedAt,
    this.match,
    this.lastGameTime,
    this.endedAt,
    this.endReason,
  });

  final String sessionId;
  final GameSessionGeneration generation;
  final Puuid? accountPuuid;
  final GameSessionPhase phase;
  final MatchKey? match;
  final DateTime startedAt;
  final DateTime lastObservedAt;
  final GameTime? lastGameTime;
  final DateTime? endedAt;
  final GameSessionEndReason? endReason;

  bool get isActive => phase != GameSessionPhase.completed;

  GameSession copyWith({
    Puuid? accountPuuid,
    GameSessionPhase? phase,
    MatchKey? match,
    DateTime? lastObservedAt,
    GameTime? lastGameTime,
    DateTime? endedAt,
    GameSessionEndReason? endReason,
  }) => GameSession(
    sessionId: sessionId,
    generation: generation,
    accountPuuid: accountPuuid ?? this.accountPuuid,
    phase: phase ?? this.phase,
    match: match ?? this.match,
    startedAt: startedAt,
    lastObservedAt: lastObservedAt ?? this.lastObservedAt,
    lastGameTime: lastGameTime ?? this.lastGameTime,
    endedAt: endedAt ?? this.endedAt,
    endReason: endReason ?? this.endReason,
  );
}

class GameSessionState {
  const GameSessionState({this.current, this.lastCompleted});

  final GameSession? current;
  final GameSession? lastCompleted;
}
