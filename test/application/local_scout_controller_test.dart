import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/local_scout_controller.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/account_context.dart';
import 'package:godsense/domain/league/local_scout.dart';
import 'package:godsense/infrastructure/persistence/drift_local_scout_repository.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';

void main() {
  late GodSenseDatabase database;
  late DriftLocalScoutRepository repository;
  late LocalScoutController controller;

  setUp(() async {
    database = GodSenseDatabase.inMemory();
    repository = DriftLocalScoutRepository(database);
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
    await repository.upsertMatch(
      LocalMatchRecord(
        match: MatchKey(platformId: PlatformId('LA1'), gameId: 123),
        puuid: Puuid('player'),
        patch: PatchKey('16.17'),
        queueId: 420,
        startedAt: DateTime.utc(2026, 9, 1),
        summaryJson: '''
          {"participants":[{"puuid":"player","championName":"Ashe",
          "win":true,"kills":8,"deaths":2,"assists":11,
          "teamPosition":"BOTTOM"}]}
        ''',
        detailsJson: '''
          {"teams":[{"side":"Azul","win":true}],
          "participants":[{"puuid":"player","championName":"Ashe"}]}
        ''',
        timelineJson: '{"frames":[]}',
        syncedAt: DateTime.utc(2026, 9, 2),
      ),
    );
    await repository.appendRankedSnapshot(
      LocalRankedSnapshot(
        puuid: Puuid('player'),
        payloadJson: '''
          {"queueMap":{"RANKED_SOLO_5x5":{"tier":"GOLD",
          "division":"II","leaguePoints":64,"wins":30,"losses":20}}}
        ''',
        observedAt: DateTime.utc(2026, 9, 2),
        semanticHash: 'gold-2-64',
      ),
    );
    controller = LocalScoutController(databaseFactory: () async => database);
  });

  tearDown(() async {
    controller.dispose();
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'loads the connected account profile and cached matches offline',
    () async {
      await controller.loadAccount(_account());

      expect(controller.state.lastError, isNull);
      expect(controller.state.loading, isFalse);
      expect(controller.state.profile['game_name'], 'Diego');
      expect(controller.state.profile['rank'], containsPair('tier', 'GOLD'));
      expect(controller.state.profile['rank'], containsPair('winrate', 60));
      expect(controller.state.matches, hasLength(1));
      expect(controller.state.matches.single['result'], 'Victoria');
      expect(
        controller.state.matches.single['champion'],
        containsPair('name', 'Ashe'),
      );
    },
  );

  test('loads cached match detail and reports timeline availability', () async {
    await controller.loadAccount(_account());
    await controller.selectMatch(123);

    expect(controller.state.lastError, isNull);
    expect(controller.state.selectedMatch['match_id'], 123);
    expect(controller.state.selectedMatch['timeline_available'], isTrue);
    expect(controller.state.selectedMatch['teams'], hasLength(1));
    expect(controller.state.selectedMatch['players'], hasLength(1));
  });

  test('clears account-scoped data when no account is active', () async {
    await controller.loadAccount(_account());
    await controller.loadAccount(null);

    expect(controller.state.profile, isEmpty);
    expect(controller.state.matches, isEmpty);
    expect(controller.state.selectedMatch, isEmpty);
  });
}

LeagueAccountProfile _account() => LeagueAccountProfile(
  puuid: Puuid('player'),
  platformId: PlatformId('LA1'),
  riotId: const RiotId(gameName: 'Diego', tagLine: 'LAN'),
  firstSeenAt: DateTime.utc(2026, 9, 1),
  lastSeenAt: DateTime.utc(2026, 9, 2),
);
