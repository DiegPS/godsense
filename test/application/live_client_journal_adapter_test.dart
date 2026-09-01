import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/live_client_journal_adapter.dart';
import 'package:godsense/application/live_game_processor.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/infrastructure/persistence/drift_journal_repository.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';

void main() {
  late GodSenseDatabase database;
  late LiveClientJournalAdapter adapter;
  var now = DateTime.utc(2026, 9, 1);

  setUp(() {
    database = GodSenseDatabase.inMemory();
    adapter = LiveClientJournalAdapter(
      repository: DriftJournalRepository(database),
      now: () => now,
      idPrefix: 'test-live',
    );
  });

  tearDown(() => database.close());

  test('journals cumulative events once and preserves logical time', () async {
    final payload = _snapshot([
      {'EventID': 7, 'EventName': 'ChampionKill', 'EventTime': 12.345},
    ]);

    await adapter.ingest(allGameData: payload, match: _match(1));
    now = now.add(const Duration(milliseconds: 200));
    await adapter.ingest(allGameData: payload, match: _match(1));

    final sources = await database.select(database.sourceRecords).get();
    final domains = await database.select(database.domainEntries).get();
    expect(
      sources.where((record) => record.entryKind == 'externalEvent'),
      hasLength(1),
    );
    expect(domains, hasLength(1));
    expect(domains.single.gameTimeMs, 12345);
    expect(jsonDecode(domains.single.typedPayloadJson)['EventID'], 7);
  });

  test('does not collapse distinct EventIDs with identical payloads', () async {
    await adapter.ingest(
      allGameData: _snapshot([
        {'EventID': 1, 'EventName': 'Ace', 'EventTime': 10},
        {'EventID': 2, 'EventName': 'Ace', 'EventTime': 10},
      ]),
      match: _match(1),
    );

    expect(await database.select(database.domainEntries).get(), hasLength(2));
  });

  test('samples state at one hertz while retaining every event', () async {
    await adapter.ingest(allGameData: _snapshot(const []), match: _match(1));
    now = now.add(const Duration(milliseconds: 999));
    await adapter.ingest(allGameData: _snapshot(const []), match: _match(1));
    now = now.add(const Duration(milliseconds: 1));
    final changed = _snapshot(const []);
    (changed['gameData'] as Map<String, dynamic>)['gameTime'] = 21;
    await adapter.ingest(allGameData: changed, match: _match(1));

    final snapshots = (await database.select(database.sourceRecords).get())
        .where((record) => record.entryKind == 'sourceSnapshot');
    expect(snapshots, hasLength(2));
  });

  test('avoids duplication when an unknown match becomes known', () async {
    final payload = _snapshot([
      {'EventID': 9, 'EventName': 'GameStart', 'EventTime': 0},
    ]);

    await adapter.ingest(allGameData: payload);
    now = now.add(const Duration(milliseconds: 100));
    await adapter.ingest(allGameData: payload, match: _match(1));

    expect(await database.select(database.domainEntries).get(), hasLength(1));
  });

  test('same EventID is independent between known matches', () async {
    final payload = _snapshot([
      {'EventID': 1, 'EventName': 'GameStart', 'EventTime': 0},
    ]);

    await adapter.ingest(allGameData: payload, match: _match(1));
    await adapter.ingest(allGameData: payload, match: _match(2));

    expect(await database.select(database.domainEntries).get(), hasLength(2));
  });

  test('journaling leaves the existing live projection unchanged', () async {
    final payload = _processorSnapshot();
    final observedAt = DateTime.utc(2026, 9, 1, 12);
    final before = LiveGameProcessor().process(
      payload,
      itemCatalog: const {},
      gameId: '1',
      observedAt: observedAt,
    );

    await adapter.ingest(allGameData: payload, match: _match(1));

    final after = LiveGameProcessor().process(
      payload,
      itemCatalog: const {},
      gameId: '1',
      observedAt: observedAt,
    );
    expect(after.snapshot, before.snapshot);
    expect(after.timeline, before.timeline);
  });
}

MatchKey _match(int gameId) =>
    MatchKey(platformId: PlatformId('LA1'), gameId: gameId);

Map<String, dynamic> _snapshot(List<Map<String, dynamic>> events) => {
  'gameData': {'gameTime': 20},
  'events': {'Events': events},
};

Map<String, dynamic> _processorSnapshot() => {
  'gameData': {
    'gameTime': 20.0,
    'gameMode': 'CLASSIC',
    'mapName': 'Map11',
    'mapNumber': 11,
  },
  'activePlayer': {
    'summonerName': 'Local#LAN',
    'currentGold': 500,
    'abilities': const <String, Object?>{},
    'championStats': const <String, Object?>{},
  },
  'allPlayers': const <Map<String, Object?>>[],
  'events': {
    'Events': [
      {'EventID': 1, 'EventName': 'GameStart', 'EventTime': 0},
    ],
  },
};
