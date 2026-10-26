import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/account_context_coordinator.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/application/native_league_foundation.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/account_context.dart';
import 'package:godsense/domain/league/game_session.dart';
import 'package:godsense/domain/league/lcu_capabilities.dart';
import 'package:godsense/infrastructure/jungle/jungle_map_transport.dart';
import 'package:godsense/infrastructure/jungle/jungle_recommendation_source.dart';
import 'package:godsense/infrastructure/league/lcu_event_stream.dart';
import 'package:godsense/infrastructure/league/league_clients.dart';

Future<void> _until(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(ready(), true);
}

void main() {
  test(
    'jungle routes recover after local data reset without a patch change',
    () async {
      final client = _Client();
      final source = _Maps();
      final controller = NativeLeagueController(
        lcu: client,
        live: _Live(),
        lcuEvents: LcuEventStream(credentialsProvider: () => null),
        foundation: _Foundation(client: client),
        jungleRecommendationSource: JungleRecommendationSource(
          transport: source,
        ),
      );
      try {
        controller.start();
        await _until(() => controller.state.jungleRecommendations != null);
        expect(source.loads, 1);
        expect(
          controller.state.jungleRecommendations!.order.camps,
          hasLength(6),
        );
        await controller.deleteAllLocalData();
        expect(controller.state.jungleRecommendations, isNull);
        await _until(() => controller.state.jungleRecommendations != null);
        expect(source.loads, 2);
        expect(controller.state.jungleRecommendations!.patch.value, '16.17');
      } finally {
        controller.dispose();
      }
    },
  );
}

class _Client extends LcuClient {
  @override
  Future<LcuCredentials?> discover() async => const LcuCredentials(
    port: 1,
    password: 'synthetic',
    protocol: 'https',
    lockfilePath: 'synthetic',
  );
  @override
  Future<Object?> get(String path) async => switch (path) {
    '/lol-gameflow/v1/gameflow-phase' => 'InProgress',
    '/lol-gameflow/v1/session' => {
      'gameData': {'gameId': 42},
    },
    _ => null,
  };
}

class _Live extends LiveClientApi {
  @override
  Future<Map<String, dynamic>?> allGameData() async => null;
}

class _Foundation extends NativeLeagueFoundation {
  _Foundation({required super.client});
  late final snapshot = NativeLeagueFoundationState(
    account: AccountContextState(
      status: AccountContextStatus.ready,
      syncRevision: 1,
      context: AccountContext(
        account: LeagueAccountProfile(
          puuid: Puuid('synthetic'),
          platformId: PlatformId('LA1'),
          patchKey: PatchKey('16.17'),
          firstSeenAt: DateTime.utc(2026),
          lastSeenAt: DateTime.utc(2026),
        ),
        accountGeneration: 1,
        syncRevision: 1,
        activatedAt: DateTime.utc(2026),
      ),
    ),
    capabilities: LcuCapabilities([]),
    gameSession: const GameSessionState(),
  );
  @override
  NativeLeagueFoundationState get state => snapshot;
  @override
  Future<NativeLeagueFoundationState> observeLcu({
    required bool connected,
    required String gameflowPhase,
    Object? champSelectSession,
    int? gameId,
    bool forceAccountSync = false,
    bool forceCapabilityProbe = false,
  }) async => snapshot;
  @override
  Future<void> observeLiveClient({
    required Map<String, dynamic>? allGameData,
    int? gameId,
  }) async {}
  @override
  Future<void> deleteAllLocalData() async {}
}

class _Maps implements JungleMapTransport {
  int loads = 0;
  @override
  Uri sourceUri(PatchKey patch) => Uri.parse('https://example.invalid/map');
  @override
  Future<Map<String, dynamic>> loadMap11(PatchKey patch) async {
    loads++;
    return {
      'locations': {
        '__type': 'JungleRecommendationMapInformation',
        'JungleLocationInformation': [
          for (var id = 1; id <= 6; id++)
            {
              'Location': id,
              'name': 'Camp $id',
              'Position': [id * 100, 0, id * 100],
            },
        ],
      },
      'paths': {
        '__type': 'JunglePathRecommendation',
        'OrderJunglePath': [
          for (var id = 1; id <= 6; id++) {'__type': 'TakeCamp', 'Camp': id},
        ],
        'ChaosJunglePath': [
          for (var id = 6; id >= 1; id--) {'__type': 'TakeCamp', 'Camp': id},
        ],
      },
    };
  }
}
