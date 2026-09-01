import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/local_scout.dart';
import 'package:godsense/infrastructure/persistence/drift_local_scout_repository.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';

void main() {
  late GodSenseDatabase database;
  late DriftLocalScoutRepository repository;

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
  });

  tearDown(() => database.close());

  test('upserts one account match while enriching its documents', () async {
    await repository.upsertMatch(_match(summary: '{"revision":1}'));
    await repository.upsertMatch(
      _match(
        summary: '{"revision":2}',
        details: '{"players":[]}',
        timeline: '{"frames":[]}',
      ),
    );
    await repository.upsertMatch(_match(summary: '{"revision":3}'));

    final matches = await repository.loadMatches(Puuid('player'));
    expect(matches, hasLength(1));
    expect(matches.single.match.toString(), 'LA1:100');
    expect(matches.single.summaryJson, '{"revision":3}');
    expect(matches.single.detailsJson, '{"players":[]}');
    expect(matches.single.timelineJson, '{"frames":[]}');
  });

  test('suppresses only consecutive identical ranked snapshots', () async {
    expect(await repository.appendRankedSnapshot(_rank('a', 1)), isTrue);
    expect(await repository.appendRankedSnapshot(_rank('a', 2)), isFalse);
    expect(await repository.appendRankedSnapshot(_rank('b', 3)), isTrue);
    expect(await repository.appendRankedSnapshot(_rank('a', 4)), isTrue);

    expect(
      (await repository.loadLatestRanked(Puuid('player')))?.semanticHash,
      'a',
    );
    expect(await database.select(database.rankedSnapshots).get(), hasLength(3));
  });
}

LocalMatchRecord _match({
  required String summary,
  String? details,
  String? timeline,
}) => LocalMatchRecord(
  match: MatchKey(platformId: PlatformId('LA1'), gameId: 100),
  puuid: Puuid('player'),
  patch: PatchKey('16.17'),
  queueId: 420,
  startedAt: DateTime.utc(2026, 9, 1),
  summaryJson: summary,
  detailsJson: details,
  timelineJson: timeline,
  syncedAt: DateTime.utc(2026, 9, 2),
);

LocalRankedSnapshot _rank(String hash, int day) => LocalRankedSnapshot(
  puuid: Puuid('player'),
  payloadJson: '{}',
  observedAt: DateTime.utc(2026, 9, day),
  semanticHash: hash,
);
