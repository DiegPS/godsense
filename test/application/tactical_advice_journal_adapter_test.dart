import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/tactical_advice_journal_adapter.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/game_session.dart';
import 'package:godsense/domain/tactical/tactical_models.dart';
import 'package:godsense/infrastructure/persistence/drift_journal_repository.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';

void main() {
  late GodSenseDatabase database;
  late TacticalAdviceJournalAdapter adapter;

  setUp(() {
    database = GodSenseDatabase.inMemory();
    adapter = TacticalAdviceJournalAdapter(
      repository: DriftJournalRepository(database),
      now: () => DateTime.utc(2026, 9, 1, 12),
      idPrefix: 'test-coach',
    );
  });

  tearDown(() => database.close());

  test(
    'stores a voice question separately from derived tactical advice',
    () async {
      expect(
        await adapter.ingest(
          question: '¿Dónde está el jungla?',
          advice: _advice(),
          session: _session(),
        ),
        isTrue,
      );

      final source = await database.select(database.sourceRecords).getSingle();
      final domain = await database.select(database.domainEntries).getSingle();
      final raw = jsonDecode(utf8.decode(source.rawPayload)) as Map;
      final payload = jsonDecode(domain.typedPayloadJson) as Map;

      expect(source.sourceNamespace, 'user:voice-question');
      expect(source.platformId, 'LA1');
      expect(source.gameId, 123);
      expect(source.retentionClass, 'matchLifetime');
      expect(raw['text'], '¿Dónde está el jungla?');
      expect(domain.entryKind, 'tacticalAdvice');
      expect(domain.sourceRecordId, source.id);
      expect(domain.gameTimeMs, 600000);
      expect(domain.confidence, 0.9);
      expect(payload['id'], 'voice_jungler_location');
      expect((payload['evidence'] as List), hasLength(2));
    },
  );

  test('keeps repeated questions as distinct user events', () async {
    await adapter.ingest(question: '¿Dragón?', advice: _advice());
    await adapter.ingest(question: '¿Dragón?', advice: _advice());

    expect(await database.select(database.sourceRecords).get(), hasLength(2));
    expect(await database.select(database.domainEntries).get(), hasLength(2));
  });
}

GameSession _session() => GameSession(
  sessionId: 'session-1',
  generation: const GameSessionGeneration(4),
  accountPuuid: Puuid('player'),
  phase: GameSessionPhase.inProgress,
  match: MatchKey(platformId: PlatformId('LA1'), gameId: 123),
  startedAt: DateTime.utc(2026, 9, 1, 11, 50),
  lastObservedAt: DateTime.utc(2026, 9, 1, 12),
);

TacticalAdvice _advice() => TacticalAdvice(
  id: 'voice_jungler_location',
  title: 'Jungla localizado',
  hints: const ['Juega al lado contrario.'],
  rationale: 'Vi fue observada en río.',
  ttsText: 'Vi está en río.',
  priority: 95,
  evidence: [
    TacticalEvidence(
      factType: 'voice_question',
      source: FactSource.user,
      observedAt: DateTime.utc(2026, 9, 1, 12),
      confidence: 1,
      gameTimeSeconds: 600,
    ),
    TacticalEvidence(
      factType: 'enemy_jungler_sighting',
      source: FactSource.vision,
      observedAt: DateTime.utc(2026, 9, 1, 11, 59, 55),
      confidence: 0.9,
      gameTimeSeconds: 600,
    ),
  ],
);
