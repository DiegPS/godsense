import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/account_context_coordinator.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/application/native_league_foundation.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/account_context.dart';
import 'package:godsense/infrastructure/data_dragon/data_dragon_catalog_service.dart';
import 'package:godsense/infrastructure/jungle/jungle_recommendation_source.dart';
import 'package:godsense/infrastructure/league/lcu_event_stream.dart';
import 'package:godsense/infrastructure/league/league_clients.dart';

void main() {
  late _Foundation foundation;
  late _Catalog catalog;
  late _Events events;
  late NativeLeagueController controller;
  var disposed = false;
  setUp(() {
    disposed = false;
    foundation = _Foundation();
    catalog = _Catalog();
    events = _Events();
    controller = NativeLeagueController(
      lcu: _League(),
      live: _Live(),
      lcuEvents: events,
      foundation: foundation,
      dataDragonCatalog: catalog,
      jungleRecommendationSource: _NoJungleNetwork(),
    );
  });
  tearDown(() {
    if (!disposed) controller.dispose();
  });

  Future<void> until(bool Function() ready) async {
    final watch = Stopwatch()..start();
    while (!ready() && watch.elapsed < const Duration(seconds: 5)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(
      ready(),
      isTrue,
      reason: 'Synthetic live enrichment did not finish.',
    );
  }

  Future<void> pulse() async {
    final previous = controller.state.lastLiveUpdate;
    events.changed();
    await until(() => controller.state.lastLiveUpdate != previous);
  }

  Map enemy() => (controller.state.liveGame!['enemies'] as List).single as Map;

  test('optional catalogs enrich live players without blocking telemetry and reuse successful data', () async {
    controller.start();
    await until(() => controller.state.inGame && catalog.abilitiesCalls > 0);
    await pulse();
    expect(enemy()['vision_icon_url'], 'https://example.invalid/16.18/Vex.png');
    expect(
      (enemy()['abilities'] as List).single['name'],
      'Fixture ability 16.18',
    );
    expect(catalog.itemCalls, 1);
    expect(catalog.portraitCalls, 1);
    expect(catalog.abilitiesCalls, 1);
    await pulse();
    expect(catalog.itemCalls, 1);
    expect(catalog.portraitCalls, 1);
    expect(catalog.abilitiesCalls, 1);
  });

  test(
    'late old-patch portraits and abilities do not replace the current patch',
    () async {
      catalog.pendingPortraits = Completer<Map<String, String>>();
      catalog.pendingAbilities =
          Completer<Map<String, List<Map<String, dynamic>>>>();
      controller.start();
      await until(() => controller.state.inGame && catalog.abilitiesCalls == 1);
      foundation.patch = '16.19';
      await pulse();
      catalog.pendingPortraits!.complete({
        'vex': 'https://example.invalid/obsolete.png',
      });
      catalog.pendingAbilities!.complete({
        'vex': [
          {'name': 'Obsolete spell', 'slot': 'Q'},
        ],
      });
      await Future<void>.delayed(Duration.zero);
      catalog.pendingPortraits = null;
      catalog.pendingAbilities = null;
      await pulse();
      await until(
        () => catalog.abilitiesCalls >= 2 && catalog.portraitCalls >= 2,
      );
      await pulse();
      expect(
        enemy()['vision_icon_url'],
        'https://example.invalid/16.19/Vex.png',
      );
      expect(
        (enemy()['abilities'] as List).single['name'],
        'Fixture ability 16.19',
      );
    },
  );

  test(
    'closing while optional catalogs are pending ignores their late errors',
    () async {
      catalog.pendingPortraits = Completer<Map<String, String>>();
      catalog.pendingAbilities =
          Completer<Map<String, List<Map<String, dynamic>>>>();
      controller.start();
      await until(() => controller.state.inGame && catalog.abilitiesCalls == 1);
      controller.dispose();
      disposed = true;
      catalog.pendingPortraits!.completeError(
        StateError('synthetic closed portrait source'),
      );
      catalog.pendingAbilities!.completeError(
        StateError('synthetic closed ability source'),
      );
      await Future<void>.delayed(Duration.zero);
    },
  );
}

class _Foundation implements NativeLeagueFoundation {
  String patch = '16.18';
  @override
  NativeLeagueFoundationState get state {
    final now = DateTime.utc(2026);
    final initial = NativeLeagueFoundationState.initial(now);
    return NativeLeagueFoundationState(
      account: AccountContextState(
        status: AccountContextStatus.ready,
        syncRevision: 1,
        context: AccountContext(
          account: LeagueAccountProfile(
            puuid: Puuid('fixture'),
            platformId: PlatformId('LA1'),
            patchKey: PatchKey(patch),
            clientVersion: '$patch.123.1',
            firstSeenAt: now,
            lastSeenAt: now,
          ),
          accountGeneration: 1,
          syncRevision: 1,
          activatedAt: now,
        ),
      ),
      capabilities: initial.capabilities,
      gameSession: initial.gameSession,
    );
  }

  @override
  Future<NativeLeagueFoundationState> observeLcu({
    required bool connected,
    required String gameflowPhase,
    Object? champSelectSession,
    int? gameId,
    bool forceAccountSync = false,
    bool forceCapabilityProbe = false,
  }) async => state;
  @override
  Future<void> observeLiveClient({
    required Map<String, dynamic>? allGameData,
    int? gameId,
  }) async {}
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Catalog implements DataDragonCatalogService {
  int itemCalls = 0;
  int portraitCalls = 0;
  int abilitiesCalls = 0;
  Completer<Map<String, String>>? pendingPortraits;
  Completer<Map<String, List<Map<String, dynamic>>>>? pendingAbilities;
  @override
  Future<Map<int, Map<String, dynamic>>> loadItems({
    required PatchKey patch,
    required PlatformId platformId,
    ClientVersion? clientVersion,
    LeagueLocale? locale,
  }) async {
    itemCalls++;
    return {
      1001: {
        'name': 'Fixture boots',
        'gold': {'total': 300},
      },
    };
  }

  @override
  Future<Map<String, String>> loadChampionPortraits({
    required PatchKey patch,
    required PlatformId platformId,
    ClientVersion? clientVersion,
  }) async {
    portraitCalls++;
    return await (pendingPortraits?.future ??
        Future.value({
          'vex': 'https://example.invalid/${patch.value}/Vex.png',
        }));
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> loadChampionAbilities({
    required Iterable<String> championNames,
    required PatchKey patch,
    required PlatformId platformId,
    ClientVersion? clientVersion,
    LeagueLocale? locale,
  }) async {
    abilitiesCalls++;
    return await (pendingAbilities?.future ??
        Future.value({
          'vex': [
            {
              'slot': 'Q',
              'name': 'Fixture ability ${patch.value}',
              'cooldown': '8',
            },
          ],
        }));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _League extends LcuClient {
  @override
  Future<LcuCredentials?> discover() async => null;
}

class _Live extends LiveClientApi {
  @override
  Future<Map<String, dynamic>?> allGameData() async => {
    'gameData': {'gameTime': 600, 'gameMode': 'CLASSIC', 'mapNumber': 11},
    'activePlayer': {
      'summonerName': 'Hide on bush#DEMO',
      'currentGold': 800,
      'championStats': {'currentHealth': 900, 'maxHealth': 1000},
    },
    'allPlayers': [
      for (final team in ['ORDER', 'CHAOS'])
        {
          'summonerName': team == 'ORDER'
              ? 'Hide on bush#DEMO'
              : 'Fixture#DEMO',
          'championName': team == 'ORDER' ? 'Ahri' : 'Vex',
          'team': team,
          'position': 'MIDDLE',
          'level': 8,
          'scores': {'kills': 1, 'deaths': 1, 'assists': 1, 'creepScore': 80},
          'items': <Object?>[],
        },
    ],
    'events': {'Events': <Object?>[]},
  };
}

class _Events extends LcuEventStream {
  _Events() : super(credentialsProvider: () => null);
  final changes = StreamController<LcuApiEvent>.broadcast();
  @override
  Stream<LcuApiEvent> get events => changes.stream;
  @override
  void start() {}
  void changed() => changes.add(
    const LcuApiEvent(
      uri: '/lol-gameflow/v1/gameflow-phase',
      eventType: 'Update',
      data: null,
    ),
  );
  @override
  Future<void> dispose() async {
    await changes.close();
    await super.dispose();
  }
}

class _NoJungleNetwork implements JungleRecommendationSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Optional jungle source is unavailable in this test.');
}
