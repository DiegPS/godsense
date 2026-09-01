import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/journal/journal_models.dart';
import 'package:godsense/infrastructure/persistence/drift_journal_repository.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';
import 'package:godsense/infrastructure/persistence/journal_payload_codec.dart';

void main() {
  group('DriftJournalRepository', () {
    late GodSenseDatabase database;
    late DriftJournalRepository repository;

    setUp(() {
      database = GodSenseDatabase.inMemory();
      repository = DriftJournalRepository(database);
    });

    tearDown(() => database.close());

    test('deduplicates a stable event across transport reconnects', () async {
      final first = _event(
        id: 'record-1',
        sourceRecordKey: 'event-7',
        transportGeneration: 1,
      );
      final repeatedAfterReconnect = _event(
        id: 'record-2',
        sourceRecordKey: 'event-7',
        transportGeneration: 2,
      );

      expect(await repository.append(first), AppendSourceRecordResult.inserted);
      expect(
        await repository.append(repeatedAfterReconnect),
        AppendSourceRecordResult.duplicate,
      );
      expect(await database.select(database.sourceRecords).get(), hasLength(1));
    });

    test('scopes stable source event identity to the match', () async {
      final first = _event(
        id: 'record-1',
        sourceRecordKey: 'event-7',
        gameId: 99,
      );
      final sameSourceIdInAnotherMatch = _event(
        id: 'record-2',
        sourceRecordKey: 'event-7',
        gameId: 100,
      );

      expect(await repository.append(first), AppendSourceRecordResult.inserted);
      expect(
        await repository.append(sameSourceIdInAnotherMatch),
        AppendSourceRecordResult.inserted,
      );
      expect(await database.select(database.sourceRecords).get(), hasLength(2));
    });

    test('does not equate independent events that share a payload', () async {
      final first = _event(id: 'record-1');
      final second = _event(id: 'record-2');

      expect(await repository.append(first), AppendSourceRecordResult.inserted);
      expect(
        await repository.append(second),
        AppendSourceRecordResult.inserted,
      );
      expect(await database.select(database.sourceRecords).get(), hasLength(2));
    });

    test('suppresses only consecutive equal snapshots in one epoch', () async {
      expect(
        await repository.append(_snapshot(id: 'a1', state: 'A')),
        AppendSourceRecordResult.inserted,
      );
      expect(
        await repository.append(_snapshot(id: 'a2', state: 'A')),
        AppendSourceRecordResult.snapshotSuppressed,
      );
      expect(
        await repository.append(_snapshot(id: 'b1', state: 'B')),
        AppendSourceRecordResult.inserted,
      );
      expect(
        await repository.append(_snapshot(id: 'a3', state: 'A')),
        AppendSourceRecordResult.inserted,
      );

      final records = await database.select(database.sourceRecords).get();
      expect(records.map((record) => record.id), ['a1', 'b1', 'a3']);
    });

    test('records a new baseline when the capture epoch changes', () async {
      expect(
        await repository.append(_snapshot(id: 'a1', state: 'A')),
        AppendSourceRecordResult.inserted,
      );
      expect(
        await repository.append(
          _snapshot(id: 'a2', state: 'A', epoch: 'epoch-2'),
        ),
        AppendSourceRecordResult.inserted,
      );

      expect(await database.select(database.sourceRecords).get(), hasLength(2));
      expect(await database.select(database.captureEpochs).get(), hasLength(2));
    });

    test('uses deterministic derivation keys for idempotent outputs', () async {
      final first = _domainEntry(
        id: 'inference-1',
        derivationKey: 'sha256:key',
      );
      final retry = _domainEntry(
        id: 'inference-2',
        derivationKey: 'sha256:key',
      );

      expect(await repository.appendDomainEntry(first), isTrue);
      expect(await repository.appendDomainEntry(retry), isFalse);
      expect(await database.select(database.domainEntries).get(), hasLength(1));
    });

    test(
      'keeps raw source bytes separate from decoded domain payloads',
      () async {
        final source = _event(id: 'source-1', sourceRecordKey: 'event-1');
        await repository.append(source);
        await repository.appendDomainEntry(
          _domainEntry(id: 'decoded-1', sourceRecordId: source.id),
        );

        final storedSource = await database
            .select(database.sourceRecords)
            .getSingle();
        final storedDomain = await database
            .select(database.domainEntries)
            .getSingle();
        expect(utf8.decode(storedSource.rawPayload), '{"EventID":7}');
        expect(storedDomain.typedPayloadJson, '{"type":"objectiveKilled"}');
        expect(storedDomain.sourceRecordId, 'source-1');
      },
    );
  });
}

SourceRecordDraft _event({
  required String id,
  String? sourceRecordKey,
  int transportGeneration = 1,
  int gameId = 99,
}) {
  const codec = JournalPayloadCodec();
  final payload = codec.encodeJson({'EventID': 7});
  return SourceRecordDraft(
    id: EntryId(id),
    kind: JournalEntryKind.externalEvent,
    source: SourceEnvelope(
      namespace: const SourceNamespace(
        producer: 'liveClient',
        channel: 'eventdata',
      ),
      sourceRecordKey: sourceRecordKey,
      transportGeneration: TransportGeneration(transportGeneration),
      match: MatchKey(platformId: PlatformId('LA1'), gameId: gameId),
      receivedAt: DateTime.utc(2026, 9, 1),
    ),
    rawPayload: payload.bytes,
    rawFormat: RawPayloadFormat.jsonUtf8,
    rawHash: payload.rawHash,
    semanticHash: payload.semanticHash,
    retentionClass: RetentionClass.permanent,
  );
}

SourceRecordDraft _snapshot({
  required String id,
  required String state,
  String epoch = 'epoch-1',
}) {
  const codec = JournalPayloadCodec();
  final payload = codec.encodeJson({'gameflow': state});
  return SourceRecordDraft(
    id: EntryId(id),
    kind: JournalEntryKind.sourceSnapshot,
    source: SourceEnvelope(
      namespace: const SourceNamespace(producer: 'lcu', channel: 'gameflow'),
      transportGeneration: const TransportGeneration(1),
      receivedAt: DateTime.utc(2026, 9, 1),
    ),
    rawPayload: payload.bytes,
    rawFormat: RawPayloadFormat.jsonUtf8,
    rawHash: payload.rawHash,
    semanticHash: payload.semanticHash,
    semanticKey: 'current-phase',
    captureEpochId: CaptureEpochId(epoch),
    retentionClass: RetentionClass.matchLifetime,
  );
}

DomainEntryDraft _domainEntry({
  required String id,
  String? derivationKey,
  EntryId? sourceRecordId,
}) {
  return DomainEntryDraft(
    id: EntryId(id),
    sourceRecordId: sourceRecordId,
    kind: DomainEntryKind.inference,
    producer: 'fact-reconciler',
    producerVersion: '1',
    producedAt: DateTime.utc(2026, 9, 1),
    payloadSchemaVersion: 1,
    typedPayloadJson: '{"type":"objectiveKilled"}',
    derivationKey: derivationKey,
  );
}
