import 'dart:convert';

import '../domain/identity/league_identity.dart';
import '../domain/journal/journal_models.dart';
import '../domain/journal/journal_repository.dart';
import '../domain/league/game_session.dart';
import '../domain/vision/vision_observation.dart';
import '../infrastructure/persistence/journal_payload_codec.dart';

class VisionJournalAdapter {
  VisionJournalAdapter({required this.repository, String? idPrefix})
    : _idPrefix =
          idPrefix ?? 'vision-${DateTime.now().toUtc().microsecondsSinceEpoch}';

  final JournalRepository repository;
  final String _idPrefix;
  int _counter = 0;

  Future<bool> ingest(
    VisionObservation observation, {
    GameSession? session,
  }) async {
    const codec = JournalPayloadCodec();
    final payload = <String, Object?>{
      'type': observation.kind.name,
      'champion': observation.champion,
      'location': observation.location,
      'region': observation.region,
      'role': observation.role,
      'observedAt': observation.observedAt.toUtc().toIso8601String(),
      'confidence': observation.confidence,
      'gameTimeMs': observation.gameTime?.milliseconds,
    };
    final encoded = codec.encodeJson(payload);
    final stableKey = codec.encodeJson({
      'kind': observation.kind.name,
      'champion': observation.champion,
      'region': observation.region,
      'observedAtUs': observation.observedAt.toUtc().microsecondsSinceEpoch,
    }).semanticHash;
    final sourceId = EntryId(_nextId('source'));
    final result = await repository.append(
      SourceRecordDraft(
        id: sourceId,
        kind: JournalEntryKind.sensorObservation,
        source: SourceEnvelope(
          namespace: const SourceNamespace(
            producer: 'dartcv',
            channel: 'minimap',
          ),
          sourceRecordKey: stableKey,
          transportGeneration: const TransportGeneration(0),
          gameGeneration: session?.generation,
          match: session?.match,
          receivedAt: observation.observedAt,
        ),
        rawPayload: encoded.bytes,
        rawFormat: RawPayloadFormat.jsonUtf8,
        rawHash: encoded.rawHash,
        semanticHash: encoded.semanticHash,
        retentionClass: RetentionClass.matchLifetime,
      ),
    );
    if (result != AppendSourceRecordResult.inserted) return false;
    return repository.appendDomainEntry(
      DomainEntryDraft(
        id: EntryId(_nextId('observation')),
        sourceRecordId: sourceId,
        kind: DomainEntryKind.sensorObservation,
        producer: 'dartcv-minimap-decoder',
        producerVersion: '1',
        producedAt: observation.observedAt,
        decoderId: 'native-minimap-event',
        decoderVersion: '1',
        payloadSchemaVersion: 1,
        typedPayloadJson: jsonEncode(payload),
        gameTime: observation.gameTime,
        confidence: observation.confidence.clamp(0, 1),
      ),
    );
  }

  String _nextId(String kind) => '$_idPrefix-$kind-${_counter++}';
}
