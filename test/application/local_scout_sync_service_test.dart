import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/local_scout_sync_service.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/lcu_capabilities.dart';
import 'package:godsense/domain/league/local_scout.dart';
import 'package:godsense/infrastructure/league/lcu_probe_transport.dart';
import 'package:godsense/infrastructure/persistence/drift_local_scout_repository.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';

void main() {
  late GodSenseDatabase database;
  late _FakeTransport transport;
  late LocalScoutSyncService service;

  setUp(() async {
    database = GodSenseDatabase.inMemory();
    transport = _FakeTransport();
    service = LocalScoutSyncService(
      transport: transport,
      repository: DriftLocalScoutRepository(database),
      now: () => DateTime.utc(2026, 9, 1),
      detailLimit: 1,
    );
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            puuid: 'player',
            platformId: 'LA1',
            firstSeenAtUs: 1,
            lastSeenAtUs: 1,
          ),
        );
  });

  tearDown(() => database.close());

  test('persists ranked, nested match list, details, and timeline', () async {
    transport.responses.addAll({
      '/lol-ranked/v1/current-ranked-stats': _ok({
        'queueMap': {
          'RANKED_SOLO_5x5': {'tier': 'GOLD', 'leaguePoints': 20},
        },
      }),
      '/lol-match-history/v1/products/lol/player/matches?begIndex=0&endIndex=30':
          _ok({
            'games': {
              'games': [
                {
                  'gameId': 100,
                  'gameVersion': '16.17.555.1',
                  'queueId': 420,
                  'gameCreation': 1788220800000,
                },
                {'gameId': 99, 'gameVersion': '16.17.444.1'},
              ],
            },
          }),
      '/lol-match-history/v1/games/100': _ok({'gameId': 100}),
      '/lol-match-history/v1/game-timelines/100': _ok({'frames': <Object?>[]}),
    });

    final result = await service.synchronize(
      puuid: Puuid('player'),
      platformId: PlatformId('LA1'),
      capabilities: _capabilities(history: true, ranked: true),
      currentAccountPuuid: Puuid('player'),
    );

    expect(result.matchesSeen, 2);
    expect(result.matchesStored, 2);
    expect(result.detailsStored, 1);
    expect(result.timelinesStored, 1);
    expect(result.rankedStored, isTrue);
    final documents = await database.select(database.matchDocuments).get();
    expect(documents, hasLength(2));
    expect(
      documents.firstWhere((row) => row.gameId == 100).detailsJson,
      isNotNull,
    );
  });

  test(
    'capability degradation keeps ranked when history is unavailable',
    () async {
      transport.responses['/lol-ranked/v1/current-ranked-stats'] = _ok({
        'tier': 'SILVER',
      });

      final result = await service.synchronize(
        puuid: Puuid('player'),
        platformId: PlatformId('LA1'),
        capabilities: _capabilities(history: false, ranked: true),
        currentAccountPuuid: Puuid('player'),
      );

      expect(result.rankedStored, isTrue);
      expect(result.matchesSeen, 0);
      expect(transport.paths, isNot(contains(contains('/lol-match-history/'))));
    },
  );

  test('repeated synchronization updates rather than duplicates matches', () async {
    transport
            .responses['/lol-match-history/v1/products/lol/player/matches?begIndex=0&endIndex=30'] =
        _ok({
          'games': [
            {'gameId': 100, 'gameVersion': '16.17.1'},
          ],
        });

    await service.synchronize(
      puuid: Puuid('player'),
      platformId: PlatformId('LA1'),
      capabilities: _capabilities(history: true),
    );
    await service.synchronize(
      puuid: Puuid('player'),
      platformId: PlatformId('LA1'),
      capabilities: _capabilities(history: true),
    );

    expect(await database.select(database.matches).get(), hasLength(1));
    expect(await database.select(database.matchDocuments).get(), hasLength(1));
  });

  test(
    'never assigns the connected account rank to a different PUUID',
    () async {
      transport.responses['/lol-ranked/v1/current-ranked-stats'] = _ok({
        'tier': 'CHALLENGER',
      });

      final result = await service.synchronize(
        puuid: Puuid('player'),
        currentAccountPuuid: Puuid('another-player'),
        platformId: PlatformId('LA1'),
        capabilities: _capabilities(ranked: true),
      );

      expect(result.rankedStored, isFalse);
      expect(
        transport.paths,
        isNot(contains('/lol-ranked/v1/current-ranked-stats')),
      );
    },
  );

  test('loads match documents concurrently to keep Scout responsive', () async {
    transport.delay = const Duration(milliseconds: 15);
    transport.responses.addAll({
      '/lol-match-history/v1/products/lol/player/matches?begIndex=0&endIndex=30':
          _ok({
            'games': [
              {'gameId': 100, 'gameVersion': '16.17.1'},
              {'gameId': 99, 'gameVersion': '16.17.1'},
            ],
          }),
      '/lol-match-history/v1/games/100': _ok({'gameId': 100}),
      '/lol-match-history/v1/game-timelines/100': _ok({'frames': <Object?>[]}),
      '/lol-match-history/v1/games/99': _ok({'gameId': 99}),
      '/lol-match-history/v1/game-timelines/99': _ok({'frames': <Object?>[]}),
    });
    final progressiveRepository = DriftLocalScoutRepository(database);
    service = LocalScoutSyncService(
      transport: transport,
      repository: progressiveRepository,
      now: () => DateTime.utc(2026, 9, 1),
      detailLimit: 2,
    );

    var summariesVisibleBeforeDocuments = false;
    final stages = <LocalScoutSyncStage>[];
    final result = await service.synchronize(
      puuid: Puuid('player'),
      platformId: PlatformId('LA1'),
      capabilities: _capabilities(history: true),
      onProgress: (progress) async {
        stages.add(progress.stage);
        if (progress.stage == LocalScoutSyncStage.matches) {
          final matches = await progressiveRepository.loadMatches(
            Puuid('player'),
          );
          summariesVisibleBeforeDocuments =
              matches.length == 2 &&
              matches.every(
                (match) =>
                    match.detailsJson == null && match.timelineJson == null,
              );
        }
      },
    );

    expect(result.detailsStored, 2);
    expect(result.timelinesStored, 2);
    expect(transport.maxInFlight, greaterThan(1));
    expect(summariesVisibleBeforeDocuments, isTrue);
    expect(stages.first, LocalScoutSyncStage.matches);
    expect(
      stages.where((stage) => stage == LocalScoutSyncStage.documents),
      hasLength(2),
    );
  });
}

LcuCapabilities _capabilities({bool history = false, bool ranked = false}) {
  final now = DateTime.utc(2026);
  return LcuCapabilities([
    for (final id in LcuCapabilityId.values)
      LcuCapability(
        id: id,
        status:
            (id == LcuCapabilityId.matchHistoryList && history) ||
                (id == LcuCapabilityId.rankedCurrent && ranked)
            ? LcuCapabilityStatus.available
            : LcuCapabilityStatus.unknown,
        reason:
            (id == LcuCapabilityId.matchHistoryList && history) ||
                (id == LcuCapabilityId.rankedCurrent && ranked)
            ? LcuCapabilityReason.verified
            : LcuCapabilityReason.requiresContext,
        checkedAt: now,
      ),
  ]);
}

LcuProbeResponse _ok(Object body) =>
    LcuProbeResponse.success(statusCode: 200, body: body);

class _FakeTransport implements LcuReadTransport {
  final Map<String, LcuProbeResponse> responses = {};
  final List<String> paths = [];
  Duration delay = Duration.zero;
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<Object?> get(String path) async => (await getDetailed(path)).body;

  @override
  Future<LcuProbeResponse> getDetailed(String path) async {
    paths.add(path);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      return responses[path] ??
          const LcuProbeResponse.failure(
            failureKind: LcuProbeFailureKind.clientError,
            statusCode: 404,
          );
    } finally {
      inFlight--;
    }
  }
}
