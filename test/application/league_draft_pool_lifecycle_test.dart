import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/account_context_coordinator.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/application/native_league_foundation.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/account_context.dart';
import 'package:godsense/domain/league/local_scout.dart';
import 'package:godsense/infrastructure/league/lcu_event_stream.dart';
import 'package:godsense/infrastructure/league/league_clients.dart';

void main() {
  late _League league;
  late _Foundation foundation;
  late _Events events;
  late NativeLeagueController controller;
  var closed = false;
  setUp(() {
    closed = false;
    league = _League();
    foundation = _Foundation();
    events = _Events();
    controller = NativeLeagueController(
      lcu: league,
      live: _Live(),
      lcuEvents: events,
      foundation: foundation,
    );
  });
  tearDown(() {
    if (!closed) controller.dispose();
  });
  void close() {
    closed = true;
    controller.dispose();
  }

  Future<void> until(bool Function() ready) async {
    final watch = Stopwatch()..start();
    while (!ready() && watch.elapsed < const Duration(seconds: 5)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(ready(), isTrue, reason: 'Synthetic draft state did not finish.');
  }

  test('draft advice combines local history and mastery while excluding bans, allies and opponents', () async {
    controller.start();
    await until(
      () =>
          (controller.state.lobby['pick_advice'] as List?)?.isNotEmpty == true,
    );
    final advice = controller.state.lobby['pick_advice'] as List;
    expect(advice.map((entry) => (entry as Map)['champion_id']), [103]);
    expect((advice.single as Map)['source'], 'lcu_champion_mastery');
    expect((advice.single as Map)['champion'], 'Ahri');
    final snapshot = controller.state.lobby['snapshot'] as Map;
    final allies = snapshot['my_team'] as List;
    expect(allies.map((entry) => (entry as Map)['selection_state']), [
      'picking',
      'locked',
      'hovering',
      'unavailable',
    ]);
    expect((allies.first as Map)['is_local'], isTrue);
    expect(snapshot['timer_phase'], 'BAN_PICK');
    expect(snapshot['time_left_ms'], 12000);
    expect(controller.state.lobby['candidate'], 'Ahri');
    expect(
      league.profileIds,
      isNot(contains(91)),
      reason: 'Unpickable mastery entries must not trigger profile lookups.',
    );
    expect(foundation.historyReads, 1);
  });

  test('closing while mastery is pending does not chain more client or history requests', () async {
    final pending = Completer<Object?>();
    league.masteryGate = pending.future;
    controller.start();
    await league.masteryStarted.future;
    close();
    pending.complete(_mastery);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(league.afterClose, isEmpty);
    expect(foundation.historyReads, 0);
  });

  test('closing while local history is pending does not start more profile requests', () async {
    final pending = Completer<List<LocalMatchRecord>>();
    foundation.historyGate = pending.future;
    controller.start();
    await foundation.historyStarted.future;
    close();
    pending.complete(_matches());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(league.afterClose, isEmpty);
  });

  test(
    'a new draft loads without waiting for an obsolete mastery request',
    () async {
      final old = Completer<Object?>();
      addTearDown(() {
        if (!old.isCompleted) old.complete([]);
      });
      league.masteryGate = old.future;
      controller.start();
      await league.masteryStarted.future;
      league.phase = 'None';
      events.changed();
      await until(() => controller.state.gameflowPhase == 'None');
      league.masteryGate = null;
      league.phase = 'ChampSelect';
      events.changed();
      await until(
        () =>
            (controller.state.lobby['pick_advice'] as List?)?.isNotEmpty ==
            true,
      );
      final reads = foundation.historyReads;
      old.complete([]);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(foundation.historyReads, reads);
      events.changed();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        (controller.state.lobby['pick_advice'] as List).single['champion_id'],
        103,
      );
    },
  );

  test(
    'switching account loads its pool without waiting for the previous account',
    () async {
      final old = Completer<Object?>();
      addTearDown(() {
        if (!old.isCompleted) old.complete([]);
      });
      league.masteryGate = old.future;
      controller.start();
      await league.masteryStarted.future;
      foundation.puuid = 'second-fixture-player';
      league.masteryGate = null;
      events.changed();
      await until(
        () => foundation.historyAccounts.contains('second-fixture-player'),
      );
      await until(
        () =>
            (controller.state.lobby['pick_advice'] as List?)?.isNotEmpty ==
            true,
      );
      final reads = foundation.historyReads;
      old.complete([]);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(foundation.historyReads, reads);
      expect(foundation.historyAccounts, ['second-fixture-player']);
    },
  );

  test(
    'missing mastery never invents picks and a new draft can recover',
    () async {
      league.failMastery = true;
      controller.start();
      await until(() => controller.state.lobby.isNotEmpty);
      expect(controller.state.lobby['pick_advice'], isEmpty);
      expect(foundation.historyReads, 0);
      league.phase = 'None';
      events.changed();
      await until(() => controller.state.gameflowPhase == 'None');
      league.failMastery = false;
      league.phase = 'ChampSelect';
      events.changed();
      await until(
        () =>
            (controller.state.lobby['pick_advice'] as List?)?.isNotEmpty ==
            true,
      );
      expect(
        (controller.state.lobby['pick_advice'] as List).single['champion_id'],
        103,
      );
    },
  );
}

const _mastery = [
  {'championId': 91, 'championPoints': 900000, 'championLevel': 7},
  {'championId': 99, 'championPoints': 200000, 'championLevel': 7},
  {'championId': 711, 'championPoints': 100000, 'championLevel': 6},
  {'championId': 103, 'championPoints': 80000, 'championLevel': 6},
  {'championId': 86, 'championPoints': 50000, 'championLevel': 5},
];

List<LocalMatchRecord> _matches({String puuid = 'fixture-player'}) {
  LocalMatchRecord match(int id, String json) => _match(id, json, puuid: puuid);
  return [
    match(1, '{malformed'),
    match(
      2,
      jsonEncode({
        'participants': [
          {'puuid': 'unrelated', 'championId': 91},
        ],
      }),
    ),
    match(
      3,
      jsonEncode({
        'participantIdentities': [
          {
            'participantId': 1,
            'player': {'puuid': puuid},
          },
        ],
        'participants': [
          {
            'participantId': 1,
            'championId': 103,
            'timeline': {'lane': 'MIDDLE', 'role': 'SOLO'},
          },
        ],
      }),
    ),
    match(
      4,
      jsonEncode({
        'participants': [
          {
            'puuid': puuid,
            'championId': 86,
            'timeline': {'lane': 'MIDDLE', 'role': 'SOLO'},
          },
        ],
      }),
    ),
    match(
      5,
      jsonEncode({
        'participants': [
          {
            'puuid': puuid,
            'championId': 99,
            'timeline': {'lane': 'BOTTOM', 'role': 'DUO_SUPPORT'},
          },
        ],
      }),
    ),
  ];
}

LocalMatchRecord _match(int id, String json, {required String puuid}) =>
    LocalMatchRecord(
      match: MatchKey(platformId: PlatformId('LA1'), gameId: id),
      puuid: Puuid(puuid),
      summaryJson: json,
      syncedAt: DateTime.utc(2026),
    );

class _Foundation implements NativeLeagueFoundation {
  String puuid = 'fixture-player';
  final historyAccounts = <String>[];
  int historyReads = 0;
  Future<List<LocalMatchRecord>>? historyGate;
  final historyStarted = Completer<void>();
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
            puuid: Puuid(puuid),
            platformId: PlatformId('LA1'),
            summonerId: 7,
            clientVersion: '16.18.123.1',
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
  Future<List<LocalMatchRecord>> loadLocalMatches(
    Puuid puuid, {
    int limit = 20,
  }) async {
    historyReads++;
    historyAccounts.add(puuid.value);
    if (!historyStarted.isCompleted) historyStarted.complete();
    return await (historyGate ?? Future.value(_matches(puuid: puuid.value)));
  }

  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _League extends LcuClient {
  String phase = 'ChampSelect';
  bool closed = false;
  bool failMastery = false;
  Future<Object?>? masteryGate;
  final masteryStarted = Completer<void>();
  final profileIds = <int>[];
  final afterClose = <String>[];
  final names = const {
    103: 'Ahri',
    86: 'Garen',
    99: 'Lux',
    711: 'Vex',
    9: 'Fiddlesticks',
    91: 'Talon',
  };
  @override
  Future<LcuCredentials?> discover() async => const LcuCredentials(
    port: 1,
    password: 'synthetic',
    protocol: 'https',
    lockfilePath: 'fixture',
  );
  @override
  Future<Object?> get(String path) async {
    if (closed) {
      afterClose.add(path);
      return null;
    }
    if (path == '/lol-champion-mastery/v1/local-player/champion-mastery') {
      if (!masteryStarted.isCompleted) masteryStarted.complete();
      if (failMastery) throw StateError('Synthetic unavailable mastery');
      return await (masteryGate ?? Future.value(_mastery));
    }
    final profile = RegExp(r'^/lol-game-data/assets/v1/champions/(\d+)\.json$')
        .firstMatch(path);
    if (profile != null) {
      final id = int.parse(profile.group(1)!);
      profileIds.add(id);
      return {
        'name': names[id],
        'alias': names[id],
        'roles': ['mage'],
        'stats': {'attackRange': 550},
        'spells': [
          {
            'name': 'Fixture Q',
            'cooldownCoefficients': [8, 7, 6],
          },
          {'slot': 'P', 'name': 'Fixture passive'},
          'invalid',
          {'spellKey': 'R', 'name': 'Fixture R', 'cooldownBurn': '100/80/60'},
          {'slot': 'INVALID'},
        ],
      };
    }
    return switch (path) {
      '/lol-gameflow/v1/gameflow-phase' => phase,
      '/lol-summoner/v1/current-summoner' => {
        'puuid': 'fixture-player',
        'summonerId': 7,
      },
      '/lol-champ-select/v1/pickable-champion-ids' => [103, 86, 99, 711],
      '/lol-game-data/assets/v1/champion-summary.json' => [
        for (final entry in names.entries)
          {'id': entry.key, 'name': entry.value, 'alias': entry.value},
      ],
      '/lol-champ-select/v1/session' => {
        'localPlayerCellId': 0,
        'myTeam': [
          {'cellId': 0, 'championId': 103, 'assignedPosition': 'MIDDLE'},
          {'cellId': 1, 'championId': 99},
          {'cellId': 2, 'championId': 9},
          {'cellId': 3, 'championId': 0},
        ],
        'theirTeam': [
          {'cellId': 5, 'championId': 711},
        ],
        'bans': {
          'myTeamBans': [86],
          'theirTeamBans': [],
        },
        'timer': {'phase': 'BAN_PICK', 'adjustedTimeLeftInPhase': 12000},
        'actions': [
          [
            {'actorCellId': 0, 'type': 'pick', 'championId': 9},
            {
              'actorCellId': 0,
              'type': 'pick',
              'championId': 103,
              'isInProgress': true,
            },
            {
              'actorCellId': 1,
              'type': 'pick',
              'championId': 99,
              'completed': true,
            },
            {
              'actorCellId': 5,
              'type': 'pick',
              'championId': 711,
              'completed': true,
            },
          ],
        ],
      },
      _ => null,
    };
  }

  @override
  void dispose() {
    closed = true;
    super.dispose();
  }
}

class _Live extends LiveClientApi {
  @override
  Future<Map<String, dynamic>?> allGameData() async => null;
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
