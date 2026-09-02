import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/local_scout_controller.dart';
import 'package:godsense/application/local_scout_sync_service.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/account_context.dart';
import 'package:godsense/domain/league/local_scout.dart';
import 'package:godsense/infrastructure/league/lcu_probe_transport.dart';

final _account = LeagueAccountProfile(
  puuid: Puuid('player'),
  platformId: PlatformId('LA1'),
  firstSeenAt: DateTime.utc(2026),
  lastSeenAt: DateTime.utc(2026),
);

Map<String, Object?> _details(int id) => {
  'gameId': id,
  'participants': [
    {
      'participantId': 1,
      'teamId': 100,
      'championId': 22,
      'stats': {'kills': 5},
    },
    {
      'participantId': 2,
      'teamId': 200,
      'championId': 99,
      'stats': {'kills': 2},
    },
  ],
  'participantIdentities': [
    {
      'participantId': 1,
      'player': {'puuid': 'player', 'gameName': 'Aliado'},
    },
    {
      'participantId': 2,
      'player': {'puuid': 'enemy', 'gameName': 'Rival'},
    },
  ],
};

LocalMatchRecord _record(int id, {bool full = false}) => LocalMatchRecord(
  match: MatchKey(platformId: PlatformId('LA1'), gameId: id),
  puuid: Puuid('player'),
  patch: PatchKey('16.17'),
  queueId: 420,
  startedAt: DateTime.utc(2026, 8, 1),
  syncedAt: DateTime.utc(2026),
  summaryJson: jsonEncode({
    'gameId': id,
    'gameDuration': 1800,
    ..._details(id),
  }),
  detailsJson: full ? jsonEncode(_details(id)) : null,
  timelineJson: '{"frames":[]}',
);

void main() {
  test(
    'loads older match on demand, updates its card and reuses cache',
    () async {
      var record = _record(10);
      var calls = 0;
      final started = Completer<void>();
      final response = Completer<LocalMatchRecord>();
      final controller = LocalScoutController(
        loadMatches: (_, {limit = 20}) async => [record],
        loadRanked: (_) async => null,
        loadMatchDetails: (cached) async {
          calls++;
          started.complete();
          return record = await response.future;
        },
      );
      addTearDown(controller.dispose);
      await controller.loadAccount(_account);
      final load = controller.selectMatch(10);
      await started.future;
      await controller.refresh();
      await controller.selectMatch(10);
      expect(calls, 1);
      expect(controller.state.loadingMatchIds, contains(10));
      expect(controller.state.loading, isFalse);
      response.complete(_record(10, full: true));
      await load;
      expect(controller.state.typedMatches.single.hasFullDetails, isTrue);
      expect(
        controller.state.typedMatches.single.participants.last.name,
        'Rival',
      );
      expect(controller.state.loadingMatchIds, isEmpty);
      await controller.selectMatch(10);
      expect(calls, 1);
    },
  );

  test('failed details stay scoped to the card and can be retried', () async {
    var calls = 0;
    final controller = LocalScoutController(
      loadMatches: (_, {limit = 20}) async => [_record(10), _record(20)],
      loadRanked: (_) async => null,
      loadMatchDetails: (cached) async {
        if (++calls == 1) throw StateError('League no disponible');
        return _record(cached.match.gameId, full: true);
      },
    );
    addTearDown(controller.dispose);
    await controller.loadAccount(_account);
    await controller.selectMatch(10);
    expect(controller.state.matchDetailErrors[10], 'League no disponible');
    expect(controller.state.lastError, isNull);
    expect(controller.state.loadingMatchIds, isEmpty);
    await controller.selectMatch(10);
    expect(controller.state.matchDetailErrors, isEmpty);
    expect(controller.state.typedMatches.first.hasFullDetails, isTrue);
    expect(controller.state.typedMatches.last.hasFullDetails, isFalse);
  });

  test('late details do not restore a disconnected account', () async {
    final started = Completer<void>();
    final response = Completer<LocalMatchRecord>();
    final controller = LocalScoutController(
      loadMatches: (_, {limit = 20}) async => [_record(10)],
      loadRanked: (_) async => null,
      loadMatchDetails: (_) {
        started.complete();
        return response.future;
      },
    );
    addTearDown(controller.dispose);
    await controller.loadAccount(_account);
    final load = controller.selectMatch(10);
    await started.future;
    await controller.loadAccount(null);
    response.complete(_record(10, full: true));
    await load;
    expect(controller.state.subjectAccount, isNull);
    expect(controller.state.typedMatches, isEmpty);
  });

  test(
    'fetches exactly the requested document and preserves cached metadata',
    () async {
      final repository = _Repository();
      final transport = _Transport(
        LcuProbeResponse.success(body: _details(10), statusCode: 200),
      );
      final service = LocalScoutSyncService(
        transport: transport,
        repository: repository,
        detailLimit: 0,
      );
      final cached = _record(10);
      final result = await service.loadMatchDetails(cached);
      expect(transport.paths, ['/lol-match-history/v1/games/10']);
      expect(result.detailsJson, isNotNull);
      expect(result.summaryJson, cached.summaryJson);
      expect(result.timelineJson, cached.timelineJson);
      expect(result.startedAt, cached.startedAt);
      expect(repository.saved, same(result));
    },
  );

  for (final response in [
    const LcuProbeResponse.failure(
      failureKind: LcuProbeFailureKind.clientError,
      statusCode: 404,
    ),
    const LcuProbeResponse.success(body: {}, statusCode: 200),
    LcuProbeResponse.success(body: _details(99), statusCode: 200),
  ]) {
    test(
      'does not cache unavailable or invalid details: ${response.body}',
      () async {
        final repository = _Repository();
        final service = LocalScoutSyncService(
          transport: _Transport(response),
          repository: repository,
        );
        await expectLater(
          service.loadMatchDetails(_record(10)),
          throwsStateError,
        );
        expect(repository.saved, isNull);
      },
    );
  }
}

class _Transport implements LcuReadTransport {
  _Transport(this.response);
  final LcuProbeResponse response;
  final paths = <String>[];
  @override
  Future<LcuProbeResponse> getDetailed(String path) async {
    paths.add(path);
    return response;
  }

  @override
  Future<Object?> get(String path) async => (await getDetailed(path)).body;
}

class _Repository implements LocalScoutRepository {
  LocalMatchRecord? saved;
  @override
  Future<void> upsertMatch(LocalMatchRecord match) async {
    saved = match;
  }

  @override
  Future<bool> appendRankedSnapshot(LocalRankedSnapshot snapshot) async =>
      false;
  @override
  Future<List<LocalMatchRecord>> loadMatches(
    Puuid puuid, {
    int limit = 20,
  }) async => [];
  @override
  Future<LocalRankedSnapshot?> loadLatestRanked(Puuid puuid) async => null;
}
