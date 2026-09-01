import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/vision_journal_adapter.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/game_session.dart';
import 'package:godsense/domain/vision/vision_observation.dart';
import 'package:godsense/infrastructure/persistence/drift_journal_repository.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';

void main() {
  late GodSenseDatabase database;
  late VisionJournalAdapter adapter;

  setUp(() {
    database = GodSenseDatabase.inMemory();
    adapter = VisionJournalAdapter(
      repository: DriftJournalRepository(database),
      idPrefix: 'test-vision',
    );
  });

  tearDown(() => database.close());

  test('stores immutable DartCV evidence under the active match', () async {
    final observation = _observation();

    expect(await adapter.ingest(observation, session: _session()), isTrue);

    final source = await database.select(database.sourceRecords).getSingle();
    final domain = await database.select(database.domainEntries).getSingle();
    final payload = jsonDecode(domain.typedPayloadJson) as Map;
    expect(source.entryKind, 'sensorObservation');
    expect(source.sourceNamespace, 'dartcv:minimap');
    expect(source.platformId, 'LA1');
    expect(source.gameId, 123);
    expect(source.gameGeneration, 7);
    expect(domain.entryKind, 'sensorObservation');
    expect(domain.sourceRecordId, source.id);
    expect(domain.gameTimeMs, 605000);
    expect(domain.confidence, 0.94);
    expect(payload['champion'], 'Vi');
    expect(payload['region'], 'TOP_RIVER');
  });

  test('deduplicates a replay of the same physical observation', () async {
    expect(await adapter.ingest(_observation()), isTrue);
    expect(await adapter.ingest(_observation()), isFalse);

    expect(await database.select(database.sourceRecords).get(), hasLength(1));
    expect(await database.select(database.domainEntries).get(), hasLength(1));
  });
}

VisionObservation _observation() => VisionObservation(
  kind: VisionObservationKind.enemySighting,
  champion: 'Vi',
  location: 'Río superior',
  region: 'TOP_RIVER',
  role: 'JUNGLE',
  observedAt: DateTime.utc(2026, 9, 1, 12),
  confidence: 0.94,
  gameTime: GameTime(const Duration(seconds: 605)),
);

GameSession _session() => GameSession(
  sessionId: 'session-1',
  generation: const GameSessionGeneration(7),
  accountPuuid: Puuid('player'),
  phase: GameSessionPhase.inProgress,
  match: MatchKey(platformId: PlatformId('LA1'), gameId: 123),
  startedAt: DateTime.utc(2026, 9, 1, 11, 50),
  lastObservedAt: DateTime.utc(2026, 9, 1, 12),
);
