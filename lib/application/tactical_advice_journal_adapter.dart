import 'dart:convert';

import '../domain/identity/league_identity.dart';
import '../domain/journal/journal_models.dart';
import '../domain/journal/journal_repository.dart';
import '../domain/league/game_session.dart';
import '../domain/tactical/tactical_models.dart';
import '../infrastructure/persistence/journal_payload_codec.dart';

class TacticalAdviceJournalAdapter {
  TacticalAdviceJournalAdapter({
    required this.repository,
    DateTime Function()? now,
    String? idPrefix,
  }) : _now = now ?? DateTime.now,
       _idPrefix =
           idPrefix ?? 'coach-${DateTime.now().toUtc().microsecondsSinceEpoch}';

  final JournalRepository repository;
  final DateTime Function() _now;
  final String _idPrefix;
  int _counter = 0;

  Future<bool> ingest({
    required String question,
    required TacticalAdvice advice,
    GameSession? session,
  }) async {
    final observedAt = _now().toUtc();
    const codec = JournalPayloadCodec();
    final questionPayload = codec.encodeJson({
      'type': 'voiceQuestion',
      'text': question,
      'input': 'localStt',
    });
    final sourceId = EntryId(_nextId('question'));
    final sourceResult = await repository.append(
      SourceRecordDraft(
        id: sourceId,
        kind: JournalEntryKind.externalEvent,
        source: SourceEnvelope(
          namespace: const SourceNamespace(
            producer: 'user',
            channel: 'voice-question',
          ),
          transportGeneration: const TransportGeneration(0),
          gameGeneration: session?.generation,
          match: session?.match,
          receivedAt: observedAt,
        ),
        rawPayload: questionPayload.bytes,
        rawFormat: RawPayloadFormat.jsonUtf8,
        rawHash: questionPayload.rawHash,
        semanticHash: questionPayload.semanticHash,
        retentionClass: RetentionClass.matchLifetime,
      ),
    );
    if (sourceResult != AppendSourceRecordResult.inserted) return false;

    final adviceJson = advice.toJson();
    final derivation = codec.encodeJson({
      'producer': 'native-tactical-engine',
      'producerVersion': '1',
      'parents': [sourceId.value],
      'parameters': {'adviceId': advice.id},
    });
    final confidences = advice.evidence
        .where((item) => item.source != FactSource.user)
        .map((item) => item.confidence)
        .toList(growable: false);
    final confidence = confidences.isEmpty
        ? null
        : confidences.reduce((left, right) => left + right) /
              confidences.length;
    final gameTime = advice.evidence
        .map((item) => item.gameTimeSeconds)
        .whereType<double>()
        .firstOrNull;
    return repository.appendDomainEntry(
      DomainEntryDraft(
        id: EntryId(_nextId('advice')),
        sourceRecordId: sourceId,
        kind: DomainEntryKind.tacticalAdvice,
        producer: 'native-tactical-engine',
        producerVersion: '1',
        producedAt: observedAt,
        payloadSchemaVersion: 1,
        typedPayloadJson: jsonEncode(adviceJson),
        gameTime: gameTime == null
            ? null
            : GameTime(Duration(milliseconds: (gameTime * 1000).round())),
        derivationKey: derivation.semanticHash,
        confidence: confidence,
      ),
    );
  }

  String _nextId(String kind) => '$_idPrefix-$kind-${_counter++}';
}
