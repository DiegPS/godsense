import '../identity/league_identity.dart';

class LocalMatchRecord {
  const LocalMatchRecord({
    required this.match,
    required this.puuid,
    required this.summaryJson,
    required this.syncedAt,
    this.patch,
    this.queueId,
    this.startedAt,
    this.endedAt,
    this.detailsJson,
    this.timelineJson,
  });

  final MatchKey match;
  final Puuid puuid;
  final PatchKey? patch;
  final int? queueId;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String summaryJson;
  final String? detailsJson;
  final String? timelineJson;
  final DateTime syncedAt;
}

class LocalRankedSnapshot {
  const LocalRankedSnapshot({
    required this.puuid,
    required this.payloadJson,
    required this.observedAt,
    required this.semanticHash,
  });

  final Puuid puuid;
  final String payloadJson;
  final DateTime observedAt;
  final String semanticHash;
}

abstract interface class LocalScoutRepository {
  Future<void> upsertMatch(LocalMatchRecord match);

  Future<bool> appendRankedSnapshot(LocalRankedSnapshot snapshot);

  Future<List<LocalMatchRecord>> loadMatches(Puuid puuid, {int limit = 20});

  Future<LocalRankedSnapshot?> loadLatestRanked(Puuid puuid);
}

class LocalScoutSyncResult {
  const LocalScoutSyncResult({
    required this.matchesSeen,
    required this.matchesStored,
    required this.detailsStored,
    required this.timelinesStored,
    required this.rankedStored,
    this.error,
  });

  final int matchesSeen;
  final int matchesStored;
  final int detailsStored;
  final int timelinesStored;
  final bool rankedStored;
  final String? error;
}

enum LocalScoutSyncStage { ranked, matches, documents }

class LocalScoutSyncProgress {
  const LocalScoutSyncProgress({
    required this.stage,
    required this.completed,
    required this.total,
  });

  final LocalScoutSyncStage stage;
  final int completed;
  final int total;
}
