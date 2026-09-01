import 'package:drift/drift.dart';

import '../../domain/journal/journal_models.dart';
import '../../domain/journal/journal_repository.dart';
import 'godsense_database.dart';

class DriftJournalRepository implements JournalRepository {
  DriftJournalRepository(this._database);

  final GodSenseDatabase _database;

  @override
  Future<AppendSourceRecordResult> append(SourceRecordDraft record) {
    return _database.transaction(() async {
      final existingById = await (_database.select(
        _database.sourceRecords,
      )..where((table) => table.id.equals(record.id.value))).getSingleOrNull();
      if (existingById != null) return AppendSourceRecordResult.duplicate;

      if (record.kind == JournalEntryKind.sourceSnapshot) {
        final result = await _appendSnapshot(record);
        if (result != null) return result;
      } else if (record.source.sourceRecordKey != null) {
        final duplicate = await _stableSourceRecordExists(record);
        if (duplicate) return AppendSourceRecordResult.duplicate;
      }

      await _insertSourceRecord(record);
      return AppendSourceRecordResult.inserted;
    });
  }

  Future<AppendSourceRecordResult?> _appendSnapshot(
    SourceRecordDraft record,
  ) async {
    final semanticKey = record.semanticKey!;
    final captureEpochId = record.captureEpochId!;
    await _ensureCaptureEpoch(captureEpochId.value, record.source.receivedAt);

    final cursor =
        await (_database.select(_database.snapshotCursors)..where(
              (table) =>
                  table.sourceNamespace.equals(record.source.namespace.value) &
                  table.semanticKey.equals(semanticKey) &
                  table.captureEpochId.equals(captureEpochId.value),
            ))
            .getSingleOrNull();
    if (cursor?.lastSemanticHash == record.semanticHash) {
      return AppendSourceRecordResult.snapshotSuppressed;
    }

    await _insertSourceRecord(record);
    await _database
        .into(_database.snapshotCursors)
        .insertOnConflictUpdate(
          SnapshotCursorsCompanion.insert(
            sourceNamespace: record.source.namespace.value,
            semanticKey: semanticKey,
            captureEpochId: captureEpochId.value,
            lastSemanticHash: record.semanticHash,
            lastSourceRecordId: record.id.value,
            updatedAtUs: _microseconds(record.source.receivedAt),
          ),
        );
    return AppendSourceRecordResult.inserted;
  }

  Future<bool> _stableSourceRecordExists(SourceRecordDraft record) async {
    final match = record.source.match;
    final query = _database.select(_database.sourceRecords)
      ..where(
        (table) =>
            table.sourceNamespace.equals(record.source.namespace.value) &
            table.sourceRecordKey.equals(record.source.sourceRecordKey!) &
            _nullableTextEquals(table.platformId, match?.platformId.value) &
            _nullableIntEquals(table.gameId, match?.gameId),
      );
    return await query.getSingleOrNull() != null;
  }

  Future<void> _ensureCaptureEpoch(String id, DateTime startedAt) async {
    await _database
        .into(_database.captureEpochs)
        .insert(
          CaptureEpochsCompanion.insert(
            id: id,
            startedAtUs: _microseconds(startedAt),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> _insertSourceRecord(SourceRecordDraft record) {
    final match = record.source.match;
    return _database
        .into(_database.sourceRecords)
        .insert(
          SourceRecordsCompanion.insert(
            id: record.id.value,
            entryKind: record.kind.name,
            sourceNamespace: record.source.namespace.value,
            sourceRecordKey: Value(record.source.sourceRecordKey),
            sourceSequence: Value(record.source.sourceSequence),
            transportGeneration: record.source.transportGeneration.value,
            gameGeneration: Value(record.source.gameGeneration?.value),
            platformId: Value(match?.platformId.value),
            gameId: Value(match?.gameId),
            semanticKey: Value(record.semanticKey),
            captureEpochId: Value(record.captureEpochId?.value),
            receivedAtUs: _microseconds(record.source.receivedAt),
            rawPayload: record.rawPayload,
            rawFormat: record.rawFormat.name,
            rawHash: record.rawHash,
            semanticHash: record.semanticHash,
            retentionClass: record.retentionClass.name,
            envelopeSchemaVersion: record.envelopeSchemaVersion,
            redacted: record.redacted,
          ),
        );
  }

  @override
  Future<bool> appendDomainEntry(DomainEntryDraft entry) {
    return _database.transaction(() async {
      if (entry.derivationKey != null) {
        final derived =
            await (_database.select(_database.domainEntries)..where(
                  (table) => table.derivationKey.equals(entry.derivationKey!),
                ))
                .getSingleOrNull();
        if (derived != null) return false;
      }
      final existing = await (_database.select(
        _database.domainEntries,
      )..where((table) => table.id.equals(entry.id.value))).getSingleOrNull();
      if (existing != null) return false;

      await _database
          .into(_database.domainEntries)
          .insert(
            DomainEntriesCompanion.insert(
              id: entry.id.value,
              sourceRecordId: Value(entry.sourceRecordId?.value),
              entryKind: entry.kind.name,
              producer: entry.producer,
              producerVersion: entry.producerVersion,
              producedAtUs: _microseconds(entry.producedAt),
              decoderId: Value(entry.decoderId),
              decoderVersion: Value(entry.decoderVersion),
              payloadSchemaVersion: entry.payloadSchemaVersion,
              typedPayloadJson: entry.typedPayloadJson,
              gameTimeMs: Value(entry.gameTime?.milliseconds),
              derivationKey: Value(entry.derivationKey),
              confidence: Value(entry.confidence),
            ),
          );
      return true;
    });
  }
}

Expression<bool> _nullableTextEquals(TextColumn column, String? value) =>
    value == null ? column.isNull() : column.equals(value);

Expression<bool> _nullableIntEquals(IntColumn column, int? value) =>
    value == null ? column.isNull() : column.equals(value);

int _microseconds(DateTime value) => value.toUtc().microsecondsSinceEpoch;
