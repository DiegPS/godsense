import 'dart:convert';

import '../domain/identity/league_identity.dart';
import '../domain/journal/journal_models.dart';
import '../domain/journal/journal_repository.dart';
import '../infrastructure/persistence/journal_payload_codec.dart';

class LiveClientJournalAdapter {
  LiveClientJournalAdapter({
    required this.repository,
    DateTime Function()? now,
    String? idPrefix,
  }) : _now = now ?? DateTime.now,
       _idPrefix =
           idPrefix ?? 'live-${DateTime.now().toUtc().microsecondsSinceEpoch}';

  final JournalRepository repository;
  final DateTime Function() _now;
  final String _idPrefix;

  int _recordCounter = 0;
  int _transportGeneration = 0;
  bool _connected = false;
  MatchKey? _lastMatch;
  DateTime? _lastSnapshotAt;
  final Set<String> _seenEventKeys = {};

  Future<void> ingest({
    required Map<String, dynamic>? allGameData,
    MatchKey? match,
    GameSessionGeneration? gameGeneration,
  }) async {
    if (allGameData == null) {
      _connected = false;
      _lastSnapshotAt = null;
      return;
    }
    if (!_connected) {
      _transportGeneration++;
      _connected = true;
      _seenEventKeys.clear();
      _lastSnapshotAt = null;
    }
    if (_lastMatch != null && match != null && match != _lastMatch) {
      _seenEventKeys.clear();
    }
    if (match != null) _lastMatch = match;

    final observedAt = _now().toUtc();
    await _ingestEvents(
      allGameData['events'],
      match: match,
      gameGeneration: gameGeneration,
      observedAt: observedAt,
    );
    if (_lastSnapshotAt == null ||
        observedAt.difference(_lastSnapshotAt!) >= const Duration(seconds: 1)) {
      await _appendSnapshot(
        allGameData,
        match: match,
        gameGeneration: gameGeneration,
        observedAt: observedAt,
      );
      _lastSnapshotAt = observedAt;
    }
  }

  Future<void> _ingestEvents(
    Object? rawEvents, {
    required MatchKey? match,
    required GameSessionGeneration? gameGeneration,
    required DateTime observedAt,
  }) async {
    final envelope = _stringMap(rawEvents);
    final events = envelope['Events'];
    if (events is! List) return;
    for (final rawEvent in events.whereType<Map>()) {
      final event = _stringMap(rawEvent);
      const codec = JournalPayloadCodec();
      final encoded = codec.encodeJson(event);
      final eventId = (event['EventID'] as num?)?.toInt();
      final sourceKey = eventId?.toString() ?? encoded.semanticHash;
      if (!_seenEventKeys.add(sourceKey)) continue;

      final sourceId = EntryId(_nextId('source-event'));
      final result = await repository.append(
        SourceRecordDraft(
          id: sourceId,
          kind: JournalEntryKind.externalEvent,
          source: SourceEnvelope(
            namespace: SourceNamespace(
              producer: 'liveClient',
              channel: match == null
                  ? 'eventdata:transport-$_transportGeneration'
                  : 'eventdata',
            ),
            sourceRecordKey: sourceKey,
            sourceSequence: eventId,
            transportGeneration: TransportGeneration(_transportGeneration),
            gameGeneration: gameGeneration,
            match: match,
            receivedAt: observedAt,
          ),
          rawPayload: encoded.bytes,
          rawFormat: RawPayloadFormat.jsonUtf8,
          rawHash: encoded.rawHash,
          semanticHash: encoded.semanticHash,
          retentionClass: RetentionClass.permanent,
        ),
      );
      if (result != AppendSourceRecordResult.inserted) continue;

      await repository.appendDomainEntry(
        DomainEntryDraft(
          id: EntryId(_nextId('decoded-event')),
          sourceRecordId: sourceId,
          kind: DomainEntryKind.externalEvent,
          producer: 'live-client-event-decoder',
          producerVersion: '1',
          producedAt: observedAt,
          decoderId: 'live-client-event',
          decoderVersion: '1',
          payloadSchemaVersion: 1,
          typedPayloadJson: utf8.decode(encoded.bytes),
          gameTime: _gameTime(event['EventTime']),
        ),
      );
    }
  }

  Future<void> _appendSnapshot(
    Map<String, dynamic> allGameData, {
    required MatchKey? match,
    required GameSessionGeneration? gameGeneration,
    required DateTime observedAt,
  }) async {
    const codec = JournalPayloadCodec();
    final encoded = codec.encodeJson(allGameData);
    await repository.append(
      SourceRecordDraft(
        id: EntryId(_nextId('source-snapshot')),
        kind: JournalEntryKind.sourceSnapshot,
        source: SourceEnvelope(
          namespace: const SourceNamespace(
            producer: 'liveClient',
            channel: 'allgamedata',
          ),
          transportGeneration: TransportGeneration(_transportGeneration),
          gameGeneration: gameGeneration,
          match: match,
          receivedAt: observedAt,
        ),
        rawPayload: encoded.bytes,
        rawFormat: RawPayloadFormat.jsonUtf8,
        rawHash: encoded.rawHash,
        semanticHash: encoded.semanticHash,
        semanticKey: 'current-game-state',
        captureEpochId: CaptureEpochId(
          '$_idPrefix-transport-$_transportGeneration',
        ),
        retentionClass: RetentionClass.matchLifetime,
      ),
    );
  }

  String _nextId(String kind) => '$_idPrefix-$kind-${_recordCounter++}';
}

GameTime? _gameTime(Object? value) {
  if (value is! num || value < 0) return null;
  return GameTime(Duration(milliseconds: (value * 1000).round()));
}

Map<String, Object?> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}
