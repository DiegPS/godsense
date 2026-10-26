import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/diagnostics/app_logger.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';
import 'package:godsense/infrastructure/persistence/local_data_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late GodSenseDatabase database;
  late LocalDataManager manager;
  late Directory diagnosticDirectory;
  final now = DateTime.utc(2026, 9, 13);

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'coach.conversation.history.v1': 'private conversation',
      'coach.postgame.v1.player': 'private report',
      'speech.settings.v1': 'preserved configuration',
    });
    database = GodSenseDatabase.inMemory();
    manager = LocalDataManager(database);
    diagnosticDirectory = await Directory.systemTemp.createTemp(
      'godsense-data-manager-logs-',
    );
    await AppLogger.initialize(directory: diagnosticDirectory);
    AppLogger.warning('token=private-diagnostic', category: 'test');
    await _insertFixture(database, now);
  });

  tearDown(() async {
    await database.close();
    if (diagnosticDirectory.existsSync()) {
      await diagnosticDirectory.delete(recursive: true);
    }
  });

  test('enforces diagnostic, match and scout retention', () async {
    final result = await manager.applyRetention(now: now);

    expect(result.sourceRecords, 2);
    expect(result.matchDocuments, 1);
    expect(result.rankedSnapshots, 1);
    expect(await database.select(database.sourceRecords).get(), isEmpty);
    expect(await database.select(database.domainEntries).get(), isEmpty);
    expect(await database.select(database.snapshotCursors).get(), isEmpty);
    expect(await database.select(database.matchDocuments).get(), isEmpty);
    expect(await database.select(database.rankedSnapshots).get(), hasLength(1));
  });

  test(
    'retention preserves an active journal match before Scout has a document',
    () async {
      final recent = now
          .subtract(const Duration(minutes: 5))
          .microsecondsSinceEpoch;
      await database.customStatement(
        'UPDATE matches SET started_at_us = ?, ended_at_us = NULL',
        [recent],
      );
      await database.customStatement(
        'UPDATE source_records SET received_at_us = ?',
        [recent],
      );
      await database.customStatement('DELETE FROM match_documents');
      await manager.applyRetention(now: now);
      await manager.applyRetention(now: now);
      expect(
        (await database.select(database.matches).get()).map(
          (match) => match.gameId,
        ),
        [10],
      );
      expect(
        await database.select(database.accountMatches).get(),
        hasLength(1),
      );
      expect(await database.select(database.sourceRecords).get(), hasLength(2));
    },
  );

  test('exports every local table with binary payloads encoded', () async {
    final directory = await Directory.systemTemp.createTemp(
      'godsense-export-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final destination = File('${directory.path}\\export.json');
    await destination.writeAsString('previous export');
    for (var index = 0; index < 205; index++) {
      final seen = now.microsecondsSinceEpoch + index;
      await database.customStatement('''
        INSERT INTO accounts (
          puuid, platform_id, first_seen_at_us, last_seen_at_us,
          record_schema_version
        ) VALUES ('player-$index', 'LA1', $seen, $seen, 1)
      ''');
    }

    await manager.exportTo(destination);
    final decoded = jsonDecode(await destination.readAsString()) as Map;

    expect(decoded['format'], 'godsense-local-data');
    expect(decoded['accounts'], hasLength(206));
    expect(decoded['source_records'], hasLength(2));
    expect(
      decoded['local_preferences']['coach.conversation.history.v1'],
      'private conversation',
    );
    expect(decoded['source_records'][0]['rawPayload']['encoding'], 'base64');
    expect(decoded['diagnostic_logs'], isNotEmpty);
    expect(
      decoded['diagnostic_logs'].toString(),
      isNot(contains('private-diagnostic')),
    );
    expect(
      directory
          .listSync()
          .whereType<File>()
          .map((file) => file.path)
          .where(
            (path) => path.contains('.partial-') || path.contains('.previous-'),
          ),
      isEmpty,
    );
  });

  test('deletes all account, match and journal data transactionally', () async {
    await manager.deleteAllUserData();

    final counts = await database.customSelect('''
      SELECT
        (SELECT COUNT(*) FROM accounts) +
        (SELECT COUNT(*) FROM matches) +
        (SELECT COUNT(*) FROM source_records) +
        (SELECT COUNT(*) FROM domain_entries) +
        (SELECT COUNT(*) FROM match_documents) +
        (SELECT COUNT(*) FROM ranked_snapshots) AS total
    ''').getSingle();
    expect(counts.read<int>('total'), 0);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('coach.conversation.history.v1'), isFalse);
    expect(preferences.containsKey('coach.postgame.v1.player'), isFalse);
    expect(
      preferences.getString('speech.settings.v1'),
      'preserved configuration',
    );
    expect(File(AppLogger.logFilePath!).existsSync(), isFalse);
  });

  test('failed database export preserves the previous file and removes partial output', () async {
    final directory = await Directory.systemTemp.createTemp(
      'godsense-failed-export-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final destination = File('${directory.path}/export.json');
    await destination.writeAsString('previous complete export');
    // Fail near the end of the snapshot, after other tables have been written.
    await database.customStatement('DROP TABLE snapshot_cursors');
    await expectLater(manager.exportTo(destination), throwsA(anything));
    expect(await destination.readAsString(), 'previous complete export');
    final remaining = directory.listSync().whereType<File>().toList();
    expect(remaining, hasLength(1));
    expect(
      await FileSystemEntity.identical(remaining.single.path, destination.path),
      true,
    );
  });

  test('an occupied directory cannot be overwritten by an export', () async {
    final directory = await Directory.systemTemp.createTemp(
      'godsense-export-destination-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final occupied = await Directory('${directory.path}/occupied').create();
    final protected = File('${occupied.path}/keep.txt');
    await protected.writeAsString('keep');
    await expectLater(
      manager.exportTo(File(occupied.path)),
      throwsA(isA<FileSystemException>()),
    );
    expect(await protected.readAsString(), 'keep');
    expect(directory.listSync().whereType<File>(), isEmpty);
  });
}

Future<void> _insertFixture(GodSenseDatabase database, DateTime now) async {
  final old = now.subtract(const Duration(days: 200)).microsecondsSinceEpoch;
  final recent = now.subtract(const Duration(days: 1)).microsecondsSinceEpoch;
  await database.customStatement('''
    INSERT INTO accounts (
      puuid, platform_id, first_seen_at_us, last_seen_at_us,
      record_schema_version
    ) VALUES ('player', 'LA1', $old, $recent, 1)
  ''');
  await database.customStatement('''
    INSERT INTO matches (
      platform_id, game_id, started_at_us, ended_at_us,
      record_schema_version
    ) VALUES ('LA1', 10, $old, $old, 1)
  ''');
  await database.customStatement(
    "INSERT INTO account_matches (puuid, platform_id, game_id) "
    "VALUES ('player', 'LA1', 10)",
  );
  await database.customStatement('''
    INSERT INTO match_documents (
      platform_id, game_id, puuid, summary_json, synced_at_us
    ) VALUES ('LA1', 10, 'player', '{}', $old)
  ''');
  await database.customStatement('''
    INSERT INTO ranked_snapshots (
      puuid, observed_at_us, payload_json, semantic_hash
    ) VALUES
      ('player', $old, '{}', 'old'),
      ('player', $recent, '{}', 'recent')
  ''');
  await database.customStatement(
    "INSERT INTO capture_epochs (id, started_at_us) VALUES ('epoch', $old)",
  );
  for (final entry in const [
    ('diagnostic-source', 'diagnostic'),
    ('match-source', 'matchLifetime'),
  ]) {
    await database.customStatement('''
      INSERT INTO source_records (
        id, entry_kind, source_namespace, transport_generation,
        platform_id, game_id, capture_epoch_id, received_at_us, raw_payload,
        raw_format, raw_hash, semantic_hash, retention_class,
        envelope_schema_version, redacted
      ) VALUES (
        '${entry.$1}', 'sourceEvent', 'test', 1,
        'LA1', 10, 'epoch', $old, X'0102',
        'jsonUtf8', 'raw', '${entry.$1}', '${entry.$2}', 1, 1
      )
    ''');
  }
  await database.customStatement('''
    INSERT INTO domain_entries (
      id, source_record_id, entry_kind, producer, producer_version,
      produced_at_us, payload_schema_version, typed_payload_json
    ) VALUES (
      'domain', 'diagnostic-source', 'decodedObservation', 'test', '1',
      $old, 1, '{}'
    )
  ''');
  await database.customStatement('''
    INSERT INTO snapshot_cursors (
      source_namespace, semantic_key, capture_epoch_id, last_semantic_hash,
      last_source_record_id, updated_at_us
    ) VALUES ('test', 'key', 'epoch', 'hash', 'diagnostic-source', $old)
  ''');
}
