import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../diagnostics/app_logger.dart';
import 'godsense_database.dart';

class LocalDataRetentionPolicy {
  const LocalDataRetentionPolicy({
    this.diagnosticMaxAge = const Duration(days: 7),
    this.matchLifetimeGrace = const Duration(hours: 24),
    this.scoutHistoryMaxAge = const Duration(days: 180),
  });

  final Duration diagnosticMaxAge;
  final Duration matchLifetimeGrace;
  final Duration scoutHistoryMaxAge;

  Map<String, Object> toJson() => {
    'diagnostic_days': diagnosticMaxAge.inDays,
    'match_lifetime_grace_hours': matchLifetimeGrace.inHours,
    'scout_history_days': scoutHistoryMaxAge.inDays,
  };
}

class LocalDataRetentionResult {
  const LocalDataRetentionResult({
    required this.sourceRecords,
    required this.matchDocuments,
    required this.rankedSnapshots,
    required this.diagnosticLogFiles,
  });

  final int sourceRecords;
  final int matchDocuments;
  final int rankedSnapshots;
  final int diagnosticLogFiles;

  int get total =>
      sourceRecords + matchDocuments + rankedSnapshots + diagnosticLogFiles;
}

class LocalDataManager {
  static const _largePayloadPageSize = 10;
  LocalDataManager(
    this.database, {
    this.policy = const LocalDataRetentionPolicy(),
  });

  final GodSenseDatabase database;
  final LocalDataRetentionPolicy policy;

  Future<LocalDataRetentionResult> applyRetention({DateTime? now}) async {
    final current = (now ?? DateTime.now()).toUtc();
    final diagnosticCutoff = current.subtract(policy.diagnosticMaxAge);
    final matchCutoff = current.subtract(policy.matchLifetimeGrace);
    final scoutCutoff = current.subtract(policy.scoutHistoryMaxAge);
    final databaseResult = await database.transaction(() async {
      final sourceIds = await database
          .customSelect(
            '''
            SELECT sr.id
            FROM source_records sr
            LEFT JOIN matches m
              ON m.platform_id = sr.platform_id AND m.game_id = sr.game_id
            WHERE
              (sr.retention_class = 'diagnostic' AND sr.received_at_us < ?)
              OR (
                sr.retention_class = 'matchLifetime'
                AND (
                  (m.ended_at_us IS NOT NULL AND m.ended_at_us < ?)
                  OR (m.game_id IS NULL AND sr.received_at_us < ?)
                )
              )
            ''',
            variables: [
              Variable<int>(diagnosticCutoff.microsecondsSinceEpoch),
              Variable<int>(matchCutoff.microsecondsSinceEpoch),
              Variable<int>(matchCutoff.microsecondsSinceEpoch),
            ],
          )
          .map((row) => row.read<String>('id'))
          .get();
      await _deleteSourceRecords(sourceIds);

      final removedDocuments = await database.customUpdate(
        '''
        DELETE FROM match_documents
        WHERE EXISTS (
          SELECT 1 FROM matches m
          WHERE m.platform_id = match_documents.platform_id
            AND m.game_id = match_documents.game_id
            AND COALESCE(m.ended_at_us, m.started_at_us,
                         match_documents.synced_at_us) < ?
        )
        ''',
        variables: [Variable<int>(scoutCutoff.microsecondsSinceEpoch)],
        updates: {database.matchDocuments},
      );
      await database.customUpdate(
        '''
        DELETE FROM account_matches
        WHERE NOT EXISTS (
          SELECT 1 FROM match_documents d
          WHERE d.puuid = account_matches.puuid
            AND d.platform_id = account_matches.platform_id
            AND d.game_id = account_matches.game_id
        )
        AND NOT EXISTS (
          SELECT 1 FROM source_records sr
          WHERE sr.platform_id = account_matches.platform_id
            AND sr.game_id = account_matches.game_id
        )
        ''',
        updates: {database.accountMatches},
      );
      await database.customUpdate(
        '''
        DELETE FROM matches
        WHERE NOT EXISTS (
          SELECT 1 FROM account_matches am
          WHERE am.platform_id = matches.platform_id
            AND am.game_id = matches.game_id
        )
        AND NOT EXISTS (
          SELECT 1 FROM source_records sr
          WHERE sr.platform_id = matches.platform_id
            AND sr.game_id = matches.game_id
        )
        ''',
        updates: {database.matches},
      );
      final removedRanked = await database.customUpdate(
        '''
        DELETE FROM ranked_snapshots
        WHERE observed_at_us < ?
          AND id NOT IN (
            SELECT MAX(id) FROM ranked_snapshots GROUP BY puuid
          )
        ''',
        variables: [Variable<int>(scoutCutoff.microsecondsSinceEpoch)],
        updates: {database.rankedSnapshots},
      );
      return LocalDataRetentionResult(
        sourceRecords: sourceIds.length,
        matchDocuments: removedDocuments,
        rankedSnapshots: removedRanked,
        diagnosticLogFiles: 0,
      );
    });
    final removedLogs = await AppLogger.deleteExpired(
      policy.diagnosticMaxAge,
      now: current,
    );
    return LocalDataRetentionResult(
      sourceRecords: databaseResult.sourceRecords,
      matchDocuments: databaseResult.matchDocuments,
      rankedSnapshots: databaseResult.rankedSnapshots,
      diagnosticLogFiles: removedLogs,
    );
  }

  Future<File> exportTo(File destination) async {
    await destination.parent.create(recursive: true);
    final suffix = '$pid-${DateTime.now().microsecondsSinceEpoch}';
    final temporary = File('${destination.path}.partial-$suffix');
    final sink = temporary.openWrite();
    var sinkClosed = false;
    try {
      sink.write('{');
      _writeProperty(sink, 'format', 'godsense-local-data');
      _writeProperty(sink, 'schema_version', 1, leadingComma: true);
      _writeProperty(
        sink,
        'exported_at',
        DateTime.now().toUtc().toIso8601String(),
        leadingComma: true,
      );
      _writeProperty(
        sink,
        'retention_policy',
        policy.toJson(),
        leadingComma: true,
      );
      await database.transaction(() async {
        await _writePagedTable(
          sink,
          'accounts',
          (limit, offset) => (database.select(
            database.accounts,
          )..limit(limit, offset: offset)).get(),
        );
        await _writePagedTable(
          sink,
          'account_context_states',
          (limit, offset) => (database.select(
            database.accountContextStates,
          )..limit(limit, offset: offset)).get(),
        );
        await _writePagedTable(
          sink,
          'matches',
          (limit, offset) => (database.select(
            database.matches,
          )..limit(limit, offset: offset)).get(),
        );
        await _writePagedTable(
          sink,
          'account_matches',
          (limit, offset) => (database.select(
            database.accountMatches,
          )..limit(limit, offset: offset)).get(),
        );
        await _writePagedTable(
          sink,
          'match_documents',
          (limit, offset) => (database.select(
            database.matchDocuments,
          )..limit(limit, offset: offset)).get(),
          pageSize: _largePayloadPageSize,
        );
        await _writePagedTable(
          sink,
          'ranked_snapshots',
          (limit, offset) => (database.select(
            database.rankedSnapshots,
          )..limit(limit, offset: offset)).get(),
        );
        await _writePagedTable(
          sink,
          'capture_epochs',
          (limit, offset) => (database.select(
            database.captureEpochs,
          )..limit(limit, offset: offset)).get(),
        );
        await _writePagedTable(
          sink,
          'source_records',
          (limit, offset) => (database.select(
            database.sourceRecords,
          )..limit(limit, offset: offset)).get(),
          pageSize: _largePayloadPageSize,
        );
        await _writePagedTable(
          sink,
          'domain_entries',
          (limit, offset) => (database.select(
            database.domainEntries,
          )..limit(limit, offset: offset)).get(),
          pageSize: _largePayloadPageSize,
        );
        await _writePagedTable(
          sink,
          'lineage_edges',
          (limit, offset) => (database.select(
            database.lineageEdges,
          )..limit(limit, offset: offset)).get(),
        );
        await _writePagedTable(
          sink,
          'snapshot_cursors',
          (limit, offset) => (database.select(
            database.snapshotCursors,
          )..limit(limit, offset: offset)).get(),
        );
      });
      _writeProperty(
        sink,
        'local_preferences',
        await _exportablePreferences(),
        leadingComma: true,
      );
      await _writeStreamedTable(
        sink,
        'diagnostic_logs',
        AppLogger.exportEntriesStream(),
      );
      sink.write('}');
      await sink.flush();
      await sink.close();
      sinkClosed = true;
      await _replaceDestination(temporary, destination, suffix);
      return destination;
    } catch (_) {
      if (!sinkClosed) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  Future<void> _writePagedTable<T extends DataClass>(
    IOSink sink,
    String name,
    Future<List<T>> Function(int limit, int offset) loadPage, {
    int pageSize = 100,
  }) async {
    sink.write(',${jsonEncode(name)}:[');
    var first = true;
    for (var offset = 0; ; offset += pageSize) {
      final rows = await loadPage(pageSize, offset);
      for (final row in rows) {
        if (!first) sink.write(',');
        sink.write(jsonEncode(_jsonValue(row.toJson())));
        first = false;
      }
      await sink.flush();
      if (rows.length < pageSize) break;
    }
    sink.write(']');
  }

  Future<void> _writeStreamedTable(
    IOSink sink,
    String name,
    Stream<Map<String, Object?>> entries,
  ) async {
    sink.write(',${jsonEncode(name)}:[');
    var first = true;
    await for (final entry in entries) {
      if (!first) sink.write(',');
      sink.write(jsonEncode(_jsonValue(entry)));
      first = false;
    }
    sink.write(']');
  }

  void _writeProperty(
    IOSink sink,
    String name,
    Object? value, {
    bool leadingComma = false,
  }) {
    if (leadingComma) sink.write(',');
    sink.write('${jsonEncode(name)}:${jsonEncode(_jsonValue(value))}');
  }

  Future<void> _replaceDestination(
    File temporary,
    File destination,
    String suffix,
  ) async {
    final backup = File('${destination.path}.previous-$suffix');
    if (await destination.exists()) await destination.rename(backup.path);
    try {
      await temporary.rename(destination.path);
    } catch (_) {
      if (await backup.exists()) await backup.rename(destination.path);
      rethrow;
    }
    if (await backup.exists()) await backup.delete();
  }

  Future<void> deleteAllUserData() async {
    await database.transaction(() async {
      await database.delete(database.lineageEdges).go();
      await database.delete(database.snapshotCursors).go();
      await database.delete(database.domainEntries).go();
      await database.delete(database.sourceRecords).go();
      await database.delete(database.captureEpochs).go();
      await database.delete(database.matchDocuments).go();
      await database.delete(database.rankedSnapshots).go();
      await database.delete(database.accountMatches).go();
      await database.delete(database.accountContextStates).go();
      await database.delete(database.matches).go();
      await database.delete(database.accounts).go();
    });
    final preferences = await SharedPreferences.getInstance();
    for (final key in preferences.getKeys().where(_isUserDataPreference)) {
      await preferences.remove(key);
    }
    await AppLogger.deleteAll();
  }

  Future<void> _deleteSourceRecords(List<String> ids) async {
    if (ids.isEmpty) return;
    final domainIds =
        await (database.select(database.domainEntries)
              ..where((table) => table.sourceRecordId.isIn(ids)))
            .map((row) => row.id)
            .get();
    if (domainIds.isNotEmpty) {
      await (database.delete(
        database.lineageEdges,
      )..where((table) => table.childEntryId.isIn(domainIds))).go();
    }
    await (database.delete(database.lineageEdges)..where(
          (table) =>
              table.parentKind.equals('sourceRecord') &
              table.parentId.isIn(ids),
        ))
        .go();
    await (database.delete(
      database.snapshotCursors,
    )..where((table) => table.lastSourceRecordId.isIn(ids))).go();
    await (database.delete(
      database.domainEntries,
    )..where((table) => table.sourceRecordId.isIn(ids))).go();
    await (database.delete(
      database.sourceRecords,
    )..where((table) => table.id.isIn(ids))).go();
    await database.customUpdate(
      '''
      DELETE FROM capture_epochs
      WHERE NOT EXISTS (
        SELECT 1 FROM source_records sr
        WHERE sr.capture_epoch_id = capture_epochs.id
      )
      ''',
      updates: {database.captureEpochs},
    );
  }

  Future<Map<String, Object?>> _exportablePreferences() async {
    final preferences = await SharedPreferences.getInstance();
    return {
      for (final key in preferences.getKeys().where(_isUserDataPreference))
        key: _jsonValue(preferences.get(key)),
    };
  }
}

bool _isUserDataPreference(String key) =>
    key == 'coach.conversation.history.v1' ||
    key.startsWith('coach.postgame.v1.');

Object? _jsonValue(Object? value) {
  if (value is Uint8List) {
    return {'encoding': 'base64', 'data': base64Encode(value)};
  }
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), _jsonValue(item)));
  }
  if (value is Iterable) return value.map(_jsonValue).toList(growable: false);
  return value;
}
