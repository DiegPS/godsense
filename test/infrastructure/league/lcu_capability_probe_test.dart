import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/league/lcu_capabilities.dart';
import 'package:godsense/infrastructure/league/lcu_capability_probe.dart';
import 'package:godsense/infrastructure/league/lcu_probe_transport.dart';

void main() {
  group('LcuCapabilityProbe', () {
    test(
      'probes only operations whose required context is available',
      () async {
        final transport = _FakeTransport.allSuccessful();
        final probe = LcuCapabilityProbe(
          transport: transport,
          now: () => DateTime.utc(2026, 9, 1),
        );

        final capabilities = await probe.probe();

        expect(
          capabilities[LcuCapabilityId.currentSummoner].isAvailable,
          isTrue,
        );
        expect(capabilities[LcuCapabilityId.gameflow].isAvailable, isTrue);
        expect(capabilities[LcuCapabilityId.patchVersion].isAvailable, isTrue);
        expect(capabilities[LcuCapabilityId.rankedCurrent].isAvailable, isTrue);
        expect(
          capabilities[LcuCapabilityId.runeRecommendationsRead].isAvailable,
          isTrue,
        );
        expect(
          capabilities[LcuCapabilityId.champSelect].reason,
          LcuCapabilityReason.requiresContext,
        );
        expect(
          capabilities[LcuCapabilityId.matchHistoryList].reason,
          LcuCapabilityReason.requiresContext,
        );
        expect(
          transport.paths,
          containsAll([
            '/lol-summoner/v1/current-summoner',
            '/lol-gameflow/v1/gameflow-phase',
            '/lol-patch/v1/game-version',
            '/lol-ranked/v1/current-ranked-stats',
            '/lol-perks/v1/recommended-pages/champion/103/'
                'position/MIDDLE/map/11',
          ]),
        );
        expect(transport.paths, hasLength(5));
      },
    );

    test(
      'probes account, match, and champ-select families granularly',
      () async {
        final transport = _FakeTransport.allSuccessful();
        final probe = LcuCapabilityProbe(transport: transport);

        final capabilities = await probe.probe(
          const LcuProbeContext(
            puuid: 'player-puuid',
            gameId: 123,
            gameflowPhase: 'ChampSelect',
            clientVersion: '16.17.123.1',
          ),
        );

        for (final id in [
          LcuCapabilityId.champSelect,
          LcuCapabilityId.matchHistoryList,
          LcuCapabilityId.matchDetails,
          LcuCapabilityId.matchTimeline,
          LcuCapabilityId.rankedByPuuid,
        ]) {
          expect(capabilities[id].isAvailable, isTrue, reason: id.name);
          expect(capabilities[id].clientVersion, '16.17.123.1');
        }
        expect(
          capabilities[LcuCapabilityId.runeWriting].reason,
          LcuCapabilityReason.requiresUserOperation,
        );
        expect(
          capabilities[LcuCapabilityId.itemSetWriting].reason,
          LcuCapabilityReason.requiresUserOperation,
        );
      },
    );

    test(
      'keeps an ambiguous 404 unknown instead of disabling a feature',
      () async {
        final transport = _FakeTransport.allSuccessful()
          ..responses['/lol-ranked/v1/current-ranked-stats'] =
              const LcuProbeResponse.failure(
                failureKind: LcuProbeFailureKind.clientError,
                statusCode: 404,
                error: 'Not found',
              );
        final capabilities = await LcuCapabilityProbe(transport: transport)
            .probe();

        final ranked = capabilities[LcuCapabilityId.rankedCurrent];
        expect(ranked.status, LcuCapabilityStatus.unknown);
        expect(ranked.reason, LcuCapabilityReason.ambiguousNotFound);
        expect(capabilities.canLoadAccount, isTrue);
        expect(capabilities.canRunLiveCoach, isTrue);
      },
    );

    test('classifies connection failures as temporary per operation', () async {
      final transport = _FakeTransport.allSuccessful()
        ..responses['/lol-patch/v1/game-version'] =
            const LcuProbeResponse.failure(
              failureKind: LcuProbeFailureKind.disconnected,
              error: 'Client restarted',
            );
      final capabilities = await LcuCapabilityProbe(transport: transport)
          .probe();

      expect(
        capabilities[LcuCapabilityId.patchVersion].status,
        LcuCapabilityStatus.temporarilyUnavailable,
      );
      expect(
        capabilities[LcuCapabilityId.patchVersion].reason,
        LcuCapabilityReason.disconnected,
      );
      expect(capabilities[LcuCapabilityId.currentSummoner].isAvailable, isTrue);
    });

    test('derives feature availability without disabling unrelated areas', () {
      final now = DateTime.utc(2026, 9, 1);
      final capabilities = LcuCapabilities([
        _capability(LcuCapabilityId.currentSummoner, now, available: true),
        _capability(LcuCapabilityId.gameflow, now, available: true),
        _capability(LcuCapabilityId.matchHistoryList, now, available: false),
        _capability(LcuCapabilityId.matchDetails, now, available: false),
        _capability(LcuCapabilityId.rankedCurrent, now, available: true),
      ]);

      expect(capabilities.canLoadAccount, isTrue);
      expect(capabilities.canRunLiveCoach, isTrue);
      expect(capabilities.canLoadRanked, isTrue);
      expect(capabilities.canSyncNewMatches, isFalse);
    });
  });
}

LcuCapability _capability(
  LcuCapabilityId id,
  DateTime checkedAt, {
  required bool available,
}) {
  return LcuCapability(
    id: id,
    status: available
        ? LcuCapabilityStatus.available
        : LcuCapabilityStatus.unavailable,
    reason: available
        ? LcuCapabilityReason.verified
        : LcuCapabilityReason.unsupported,
    checkedAt: checkedAt,
  );
}

class _FakeTransport implements LcuProbeTransport {
  _FakeTransport.allSuccessful();

  final Map<String, LcuProbeResponse> responses = {};
  final List<String> paths = [];

  @override
  Future<LcuProbeResponse> getDetailed(String path) async {
    paths.add(path);
    if (path.contains('/recommended-pages/champion/103/')) {
      return const LcuProbeResponse.success(
        body: [
          {
            'recommendationChampionId': 103,
            'position': 'MIDDLE',
            'perks': [1, 2, 3, 4, 5, 6, 7, 8, 9],
          },
        ],
        statusCode: 200,
      );
    }
    return responses[path] ??
        const LcuProbeResponse.success(
          body: <String, Object?>{},
          statusCode: 200,
        );
  }
}
