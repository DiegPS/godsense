import 'dart:typed_data';

import '../identity/league_identity.dart';

enum JournalEntryKind { externalEvent, sourceSnapshot, sensorObservation }

enum RawPayloadFormat { jsonUtf8, binary }

enum RetentionClass { permanent, matchLifetime, diagnostic, aggregateOnly }

enum DomainEntryKind {
  externalEvent,
  sourceSnapshot,
  sensorObservation,
  inference,
  tacticalAdvice,
}

enum LineageRelation {
  derivedFrom,
  supports,
  contradicts,
  supersedes,
  calibratedBy,
}

class SourceNamespace {
  const SourceNamespace({required this.producer, required this.channel});

  final String producer;
  final String channel;

  String get value => '$producer:$channel';
}

class SourceEnvelope {
  const SourceEnvelope({
    required this.namespace,
    required this.transportGeneration,
    required this.receivedAt,
    this.sourceRecordKey,
    this.sourceSequence,
    this.match,
    this.gameGeneration,
  });

  final SourceNamespace namespace;
  final String? sourceRecordKey;
  final int? sourceSequence;
  final TransportGeneration transportGeneration;
  final GameSessionGeneration? gameGeneration;
  final MatchKey? match;
  final DateTime receivedAt;
}

class SourceRecordDraft {
  const SourceRecordDraft({
    required this.id,
    required this.kind,
    required this.source,
    required this.rawPayload,
    required this.rawFormat,
    required this.rawHash,
    required this.semanticHash,
    required this.retentionClass,
    this.semanticKey,
    this.captureEpochId,
    this.envelopeSchemaVersion = 1,
    this.redacted = false,
  }) : assert(envelopeSchemaVersion > 0),
       assert(
         kind != JournalEntryKind.sourceSnapshot ||
             (semanticKey != null && captureEpochId != null),
         'Snapshots require semanticKey and captureEpochId',
       );

  final EntryId id;
  final JournalEntryKind kind;
  final SourceEnvelope source;
  final Uint8List rawPayload;
  final RawPayloadFormat rawFormat;
  final String rawHash;
  final String semanticHash;
  final String? semanticKey;
  final CaptureEpochId? captureEpochId;
  final RetentionClass retentionClass;
  final int envelopeSchemaVersion;
  final bool redacted;
}

class DomainEntryDraft {
  const DomainEntryDraft({
    required this.id,
    required this.kind,
    required this.producer,
    required this.producerVersion,
    required this.producedAt,
    required this.payloadSchemaVersion,
    required this.typedPayloadJson,
    this.sourceRecordId,
    this.decoderId,
    this.decoderVersion,
    this.gameTime,
    this.derivationKey,
    this.confidence,
  }) : assert(payloadSchemaVersion > 0),
       assert(confidence == null || (confidence >= 0 && confidence <= 1));

  final EntryId id;
  final EntryId? sourceRecordId;
  final DomainEntryKind kind;
  final String producer;
  final String producerVersion;
  final DateTime producedAt;
  final String? decoderId;
  final String? decoderVersion;
  final int payloadSchemaVersion;
  final String typedPayloadJson;
  final GameTime? gameTime;
  final String? derivationKey;
  final double? confidence;
}

enum AppendSourceRecordResult { inserted, duplicate, snapshotSuppressed }
