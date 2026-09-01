import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/account_context_coordinator.dart';
import 'package:godsense/application/native_league_foundation.dart';
import 'package:godsense/domain/league/lcu_capabilities.dart';
import 'package:godsense/domain/league/game_session.dart';
import 'package:godsense/infrastructure/league/lcu_probe_transport.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';

void main() {
  late GodSenseDatabase database;
  late NativeLeagueFoundation foundation;
  late _FakeLeagueClient client;
  var now = DateTime.utc(2026, 9, 1);

  setUp(() {
    database = GodSenseDatabase.inMemory();
    client = _FakeLeagueClient();
    foundation = NativeLeagueFoundation(
      client: client,
      databaseFactory: () async => database,
      now: () => now,
      captureEpochId: 'test-epoch',
    );
  });

  tearDown(() => foundation.dispose());

  test('persists account and consecutive-deduplicated LCU snapshots', () async {
    final first = await foundation.observeLcu(
      connected: true,
      gameflowPhase: 'Lobby',
    );
    now = now.add(const Duration(milliseconds: 500));
    await foundation.observeLcu(connected: true, gameflowPhase: 'Lobby');

    expect(first.account.status, AccountContextStatus.ready);
    expect(first.account.context?.account.puuid.value, 'player-puuid');
    expect(
      first.capabilities[LcuCapabilityId.currentSummoner].isAvailable,
      isTrue,
    );
    expect(await database.select(database.sourceRecords).get(), hasLength(1));
    expect(
      (await database.select(database.accounts).getSingle()).puuid,
      'player-puuid',
    );
  });

  test(
    'stores A to B to A transitions and tracks transport generation',
    () async {
      await foundation.observeLcu(connected: true, gameflowPhase: 'A');
      await foundation.observeLcu(connected: true, gameflowPhase: 'B');
      await foundation.observeLcu(connected: true, gameflowPhase: 'A');
      await foundation.observeLcu(connected: false, gameflowPhase: 'NO_LCU');
      await foundation.observeLcu(connected: true, gameflowPhase: 'A');

      final records = await database.select(database.sourceRecords).get();
      expect(records.map((record) => record.transportGeneration), [1, 1, 1, 2]);
      expect(records.map((record) => record.id), [
        'test-epoch-0',
        'test-epoch-1',
        'test-epoch-2',
        'test-epoch-3',
      ]);
    },
  );

  test('keeps account available while LCU is disconnected', () async {
    await foundation.observeLcu(connected: true, gameflowPhase: 'Lobby');

    final disconnected = await foundation.observeLcu(
      connected: false,
      gameflowPhase: 'NO_LCU',
    );

    expect(disconnected.account.status, AccountContextStatus.disconnected);
    expect(disconnected.account.context?.account.puuid.value, 'player-puuid');
  });

  test('journals champ-select session separately from gameflow', () async {
    await foundation.observeLcu(
      connected: true,
      gameflowPhase: 'ChampSelect',
      champSelectSession: {
        'localPlayerCellId': 1,
        'myTeam': [
          {'cellId': 1, 'championId': 103},
        ],
      },
    );

    final records = await database.select(database.sourceRecords).get();
    expect(records, hasLength(2));
    expect(
      records.map((record) => record.sourceNamespace),
      containsAll(['lcu:gameflow', 'lcu:champ-select']),
    );
  });

  test(
    'resolves a Riot ID through LCU without switching AccountContext',
    () async {
      await foundation.observeLcu(connected: true, gameflowPhase: 'Lobby');

      final scouted = await foundation.resolveAndSyncScout(
        gameName: 'Other Player',
        tagLine: 'LAN',
      );

      expect(scouted.puuid.value, 'scouted-puuid');
      expect(scouted.riotId?.displayName, 'Other Player#LAN');
      expect(scouted.profileIconId, 907);
      expect(
        foundation.state.account.context?.account.puuid.value,
        'player-puuid',
      );
      expect(
        client.paths,
        contains(
          '/lol-summoner/v1/alias/lookup?gameName=Other+Player&tagLine=LAN',
        ),
      );
    },
  );

  test('journals Live Client data under the active account match', () async {
    await foundation.observeLcu(
      connected: true,
      gameflowPhase: 'InProgress',
      gameId: 123,
    );
    await foundation.observeLiveClient(
      gameId: 123,
      allGameData: {
        'gameData': {'gameTime': 25},
        'events': {
          'Events': [
            {'EventID': 1, 'EventName': 'GameStart', 'EventTime': 0},
          ],
        },
      },
    );

    final records = await database.select(database.sourceRecords).get();
    final liveRecords = records.where(
      (record) => record.sourceNamespace.startsWith('liveClient:'),
    );
    expect(liveRecords, hasLength(2));
    expect(liveRecords.every((record) => record.platformId == 'LA1'), isTrue);
    expect(liveRecords.every((record) => record.gameId == 123), isTrue);
    expect(await database.select(database.domainEntries).get(), hasLength(1));
  });

  test(
    'keeps one session generation from champ select through postgame',
    () async {
      var state = await foundation.observeLcu(
        connected: true,
        gameflowPhase: 'ChampSelect',
        champSelectSession: {'localPlayerCellId': 1},
      );
      final generation = state.gameSession.current!.generation.value;
      expect(state.gameSession.current?.phase, GameSessionPhase.champSelect);

      state = await foundation.observeLcu(
        connected: true,
        gameflowPhase: 'InProgress',
        gameId: 456,
      );
      await foundation.observeLiveClient(
        gameId: 456,
        allGameData: {
          'gameData': {'gameTime': 30},
          'events': {'Events': <Object?>[]},
        },
      );
      expect(state.gameSession.current?.generation.value, generation);
      expect(foundation.state.gameSession.current?.match?.gameId, 456);

      await foundation.observeLcu(
        connected: true,
        gameflowPhase: 'WaitingForStats',
        gameId: 456,
      );
      await foundation.observeLiveClient(allGameData: null, gameId: 456);

      expect(foundation.state.gameSession.current, isNull);
      expect(
        foundation.state.gameSession.lastCompleted?.generation.value,
        generation,
      );
      expect(
        foundation.state.account.context?.account.puuid.value,
        'player-puuid',
      );
      final sessionRecords =
          (await database.select(database.sourceRecords).get()).where(
            (record) => record.gameGeneration == generation,
          );
      expect(sessionRecords, isNotEmpty);
    },
  );
}

class _FakeLeagueClient implements LcuReadTransport {
  final paths = <String>[];

  @override
  Future<LcuProbeResponse> getDetailed(String path) async {
    paths.add(path);
    if (path == '/lol-summoner/v1/current-summoner') {
      return const LcuProbeResponse.success(
        statusCode: 200,
        body: {
          'puuid': 'player-puuid',
          'gameName': 'Diego',
          'tagLine': 'LAN',
          'summonerId': 42,
        },
      );
    }
    if (path.startsWith('/lol-summoner/v1/alias/lookup?')) {
      return const LcuProbeResponse.success(
        statusCode: 200,
        body: {
          'puuid': 'scouted-puuid',
          'alias': {'gameName': 'Other Player', 'tagLine': 'LAN'},
        },
      );
    }
    if (path.startsWith('/lol-summoner/v1/summoners?')) {
      return const LcuProbeResponse.success(
        statusCode: 200,
        body: {
          'puuid': 'scouted-puuid',
          'summonerId': 99,
          'summonerLevel': 38,
          'profileIconId': 907,
        },
      );
    }
    return const LcuProbeResponse.success(
      statusCode: 200,
      body: <String, Object?>{},
    );
  }

  @override
  Future<Object?> get(String path) async {
    return switch (path) {
      '/riotclient/region-locale' => {'region': 'LA1', 'locale': 'es_MX'},
      '/lol-patch/v1/game-version' => '16.17.123.1',
      _ => null,
    };
  }
}
