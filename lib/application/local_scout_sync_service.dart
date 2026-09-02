import 'dart:convert';

import '../domain/identity/league_identity.dart';
import '../domain/league/lcu_capabilities.dart';
import '../domain/league/local_scout.dart';
import '../infrastructure/league/lcu_probe_transport.dart';
import '../infrastructure/persistence/journal_payload_codec.dart';

class LocalScoutSyncService {
  LocalScoutSyncService({
    required this.transport,
    required this.repository,
    DateTime Function()? now,
    this.historyLimit = 20,
    this.detailLimit = 10,
    this.detailConcurrency = 4,
  }) : assert(detailConcurrency > 0),
       _now = now ?? DateTime.now;

  final LcuReadTransport transport;
  final LocalScoutRepository repository;
  final DateTime Function() _now;
  final int historyLimit;
  final int detailLimit;
  final int detailConcurrency;

  Future<LocalScoutSyncResult> synchronize({
    required Puuid puuid,
    required PlatformId platformId,
    required LcuCapabilities capabilities,
    Puuid? currentAccountPuuid,
    bool includeHistory = true,
  }) async {
    var rankedStored = false;
    var matchesStored = 0;
    var detailsStored = 0;
    var timelinesStored = 0;
    final errors = <String>[];

    if (capabilities.canLoadRanked) {
      final ranked = await _firstSuccess([
        if (capabilities[LcuCapabilityId.rankedByPuuid].isAvailable)
          '/lol-ranked/v1/ranked-stats/${puuid.value}',
        if (puuid == currentAccountPuuid &&
            capabilities[LcuCapabilityId.rankedCurrent].isAvailable)
          '/lol-ranked/v1/current-ranked-stats',
      ]);
      if (ranked != null) {
        const codec = JournalPayloadCodec();
        final encoded = codec.encodeJson(ranked);
        rankedStored = await repository.appendRankedSnapshot(
          LocalRankedSnapshot(
            puuid: puuid,
            payloadJson: utf8.decode(encoded.bytes),
            observedAt: _now().toUtc(),
            semanticHash: encoded.semanticHash,
          ),
        );
      }
    }

    if (!includeHistory ||
        !capabilities[LcuCapabilityId.matchHistoryList].isAvailable) {
      return LocalScoutSyncResult(
        matchesSeen: 0,
        matchesStored: 0,
        detailsStored: 0,
        timelinesStored: 0,
        rankedStored: rankedStored,
      );
    }

    final response = await transport.getDetailed(
      '/lol-match-history/v1/products/lol/${puuid.value}/matches'
      '?begIndex=0&endIndex=$historyLimit',
    );
    if (!response.isSuccess) {
      return LocalScoutSyncResult(
        matchesSeen: 0,
        matchesStored: 0,
        detailsStored: 0,
        timelinesStored: 0,
        rankedStored: rankedStored,
        error: 'Match history HTTP ${response.statusCode ?? 'transport'}',
      );
    }
    final games = _extractGames(response.body);
    var nextIndex = 0;

    Future<void> processGames() async {
      while (nextIndex < games.length) {
        final index = nextIndex++;
        final summary = games[index];
        final gameId = _int(summary['gameId'] ?? summary['game_id']);
        if (gameId == null) continue;
        Object? details;
        Object? timeline;
        if (index < detailLimit &&
            capabilities[LcuCapabilityId.matchDetails].status !=
                LcuCapabilityStatus.unavailable) {
          final loadTimeline =
              capabilities[LcuCapabilityId.matchTimeline].status !=
              LcuCapabilityStatus.unavailable;
          final documents = await Future.wait([
            transport.getDetailed('/lol-match-history/v1/games/$gameId'),
            if (loadTimeline)
              transport.getDetailed(
                '/lol-match-history/v1/game-timelines/$gameId',
              ),
          ]);
          final detailResponse = documents.first;
          if (detailResponse.isSuccess) {
            details = detailResponse.body;
            detailsStored++;
          }
          if (loadTimeline) {
            final timelineResponse = documents[1];
            if (timelineResponse.isSuccess) {
              timeline = timelineResponse.body;
              timelinesStored++;
            }
          }
        }
        try {
          await repository.upsertMatch(
            LocalMatchRecord(
              match: MatchKey(platformId: platformId, gameId: gameId),
              puuid: puuid,
              patch: _patch(summary['gameVersion'] ?? summary['game_version']),
              queueId: _int(summary['queueId'] ?? summary['queue_id']),
              startedAt: _timestamp(
                summary['gameCreation'] ??
                    summary['gameStartTimestamp'] ??
                    summary['gameBeginDate'],
              ),
              endedAt: _timestamp(summary['gameEndTimestamp']),
              summaryJson: _canonicalJson(summary),
              detailsJson: details == null ? null : _canonicalJson(details),
              timelineJson: timeline == null ? null : _canonicalJson(timeline),
              syncedAt: _now().toUtc(),
            ),
          );
          matchesStored++;
        } catch (error) {
          errors.add('$gameId: $error');
        }
      }
    }

    final workerCount = games.length < detailConcurrency
        ? games.length
        : detailConcurrency;
    await Future.wait(List.generate(workerCount, (_) => processGames()));
    return LocalScoutSyncResult(
      matchesSeen: games.length,
      matchesStored: matchesStored,
      detailsStored: detailsStored,
      timelinesStored: timelinesStored,
      rankedStored: rankedStored,
      error: errors.isEmpty ? null : errors.join('; '),
    );
  }

  Future<Object?> _firstSuccess(List<String> paths) async {
    for (final path in paths) {
      final response = await transport.getDetailed(path);
      if (response.isSuccess) return response.body;
    }
    return null;
  }
}

List<Map<String, Object?>> _extractGames(Object? body) {
  Object? candidate = body;
  if (candidate is Map) candidate = candidate['games'];
  if (candidate is Map) candidate = candidate['games'];
  if (candidate is! List) return const [];
  return candidate
      .whereType<Map>()
      .map((game) => game.map((key, value) => MapEntry(key.toString(), value)))
      .toList(growable: false);
}

String _canonicalJson(Object? value) =>
    utf8.decode(const JournalPayloadCodec().encodeJson(value).bytes);

int? _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

DateTime? _timestamp(Object? value) {
  final raw = _int(value);
  if (raw == null || raw <= 0) return null;
  final milliseconds = raw > 100000000000000 ? raw ~/ 1000 : raw;
  return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}

PatchKey? _patch(Object? value) {
  final pieces = value?.toString().split('.') ?? const [];
  if (pieces.length < 2) return null;
  try {
    return PatchKey('${pieces[0]}.${pieces[1]}');
  } on FormatException {
    return null;
  }
}
