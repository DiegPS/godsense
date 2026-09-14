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
    final payload = await database.transaction(() async {
      return <String, Object?>{
        'format': 'godsense-local-data',
        'schema_version': 1,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'retention_policy': policy.toJson(),
        'accounts': _jsonRows(await database.select(database.accounts).get()),
        'account_context_states': _jsonRows(
          await database.select(database.accountContextStates).get(),
        ),
        'matches': _jsonRows(await database.select(database.matches).get()),
        'account_matches': _jsonRows(
          await database.select(database.accountMatches).get(),
        ),
        'match_documents': _jsonRows(
          await database.select(database.matchDocuments).get(),
        ),
        'ranked_snapshots': _jsonRows(
          await database.select(database.rankedSnapshots).get(),
        ),
        'capture_epochs': _jsonRows(
          await database.select(database.captureEpochs).get(),
        ),
        'source_records': _jsonRows(
          await database.select(database.sourceRecords).get(),
        ),
        'domain_entries': _jsonRows(
          await database.select(database.domainEntries).get(),
        ),
        'lineage_edges': _jsonRows(
          await database.select(database.lineageEdges).get(),
        ),
        'snapshot_cursors': _jsonRows(
          await database.select(database.snapshotCursors).get(),
        ),
        'local_preferences': await _exportablePreferences(),
      };
    });
    payload['diagnostic_logs'] = await AppLogger.exportEntries();
    await destination.parent.create(recursive: true);
    await destination.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    return destination;
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

List<Map<String, Object?>> _jsonRows(List<DataClass> rows) => rows
    .map((row) => _jsonValue(row.toJson()) as Map<String, Object?>)
    .toList(growable: false);

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
