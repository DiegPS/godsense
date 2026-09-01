import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'godsense_database.g.dart';

class Accounts extends Table {
  TextColumn get puuid => text()();
  TextColumn get platformId => text()();
  TextColumn get gameName => text().nullable()();
  TextColumn get tagLine => text().nullable()();
  IntColumn get summonerId => integer().nullable()();
  IntColumn get summonerLevel => integer().nullable()();
  IntColumn get profileIconId => integer().nullable()();
  TextColumn get lastClientVersion => text().nullable()();
  TextColumn get lastPatchKey => text().nullable()();
  IntColumn get firstSeenAtUs => integer()();
  IntColumn get lastSeenAtUs => integer()();
  IntColumn get recordSchemaVersion =>
      integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {puuid};
}

class AccountContextStates extends Table {
  IntColumn get singletonId => integer().withDefault(const Constant(1))();
  TextColumn get currentPuuid =>
      text().nullable().references(Accounts, #puuid)();
  IntColumn get accountGeneration => integer()();
  IntColumn get syncRevision => integer()();
  IntColumn get updatedAtUs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {singletonId};

  @override
  List<String> get customConstraints => ['CHECK (singleton_id = 1)'];
}

class Matches extends Table {
  TextColumn get platformId => text()();
  IntColumn get gameId => integer()();
  TextColumn get patchKey => text().nullable()();
  IntColumn get queueId => integer().nullable()();
  IntColumn get startedAtUs => integer().nullable()();
  IntColumn get endedAtUs => integer().nullable()();
  IntColumn get recordSchemaVersion =>
      integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {platformId, gameId};
}

class AccountMatches extends Table {
  TextColumn get puuid => text().references(Accounts, #puuid)();
  TextColumn get platformId => text()();
  IntColumn get gameId => integer()();
  TextColumn get participantRole => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {puuid, platformId, gameId};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (platform_id, game_id) '
        'REFERENCES matches(platform_id, game_id)',
  ];
}

class MatchDocuments extends Table {
  TextColumn get platformId => text()();
  IntColumn get gameId => integer()();
  TextColumn get puuid => text().references(Accounts, #puuid)();
  TextColumn get summaryJson => text()();
  TextColumn get detailsJson => text().nullable()();
  TextColumn get timelineJson => text().nullable()();
  IntColumn get syncedAtUs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {platformId, gameId, puuid};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (platform_id, game_id) '
        'REFERENCES matches(platform_id, game_id)',
  ];
}

class RankedSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get puuid => text().references(Accounts, #puuid)();
  IntColumn get observedAtUs => integer()();
  TextColumn get payloadJson => text()();
  TextColumn get semanticHash => text()();
}

class CaptureEpochs extends Table {
  TextColumn get id => text()();
  IntColumn get startedAtUs => integer()();
  IntColumn get endedAtUs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SourceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get entryKind => text()();
  TextColumn get sourceNamespace => text()();
  TextColumn get sourceRecordKey => text().nullable()();
  IntColumn get sourceSequence => integer().nullable()();
  IntColumn get transportGeneration => integer()();
  IntColumn get gameGeneration => integer().nullable()();
  TextColumn get platformId => text().nullable()();
  IntColumn get gameId => integer().nullable()();
  TextColumn get semanticKey => text().nullable()();
  TextColumn get captureEpochId =>
      text().nullable().references(CaptureEpochs, #id)();
  IntColumn get receivedAtUs => integer()();
  BlobColumn get rawPayload => blob()();
  TextColumn get rawFormat => text()();
  TextColumn get rawHash => text()();
  TextColumn get semanticHash => text()();
  TextColumn get retentionClass => text()();
  IntColumn get envelopeSchemaVersion => integer()();
  BoolColumn get redacted => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DomainEntries extends Table {
  TextColumn get id => text()();
  TextColumn get sourceRecordId =>
      text().nullable().references(SourceRecords, #id)();
  TextColumn get entryKind => text()();
  TextColumn get producer => text()();
  TextColumn get producerVersion => text()();
  IntColumn get producedAtUs => integer()();
  TextColumn get decoderId => text().nullable()();
  TextColumn get decoderVersion => text().nullable()();
  IntColumn get payloadSchemaVersion => integer()();
  TextColumn get typedPayloadJson => text()();
  IntColumn get gameTimeMs => integer().nullable()();
  TextColumn get derivationKey => text().nullable()();
  RealColumn get confidence => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LineageEdges extends Table {
  TextColumn get childEntryId => text().references(DomainEntries, #id)();
  TextColumn get parentKind => text()();
  TextColumn get parentId => text()();
  TextColumn get relation => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    childEntryId,
    parentKind,
    parentId,
    relation,
  };
}

class SnapshotCursors extends Table {
  TextColumn get sourceNamespace => text()();
  TextColumn get semanticKey => text()();
  TextColumn get captureEpochId => text().references(CaptureEpochs, #id)();
  TextColumn get lastSemanticHash => text()();
  TextColumn get lastSourceRecordId => text().references(SourceRecords, #id)();
  IntColumn get updatedAtUs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    sourceNamespace,
    semanticKey,
    captureEpochId,
  };
}

@DriftDatabase(
  tables: [
    Accounts,
    AccountContextStates,
    Matches,
    AccountMatches,
    MatchDocuments,
    RankedSnapshots,
    CaptureEpochs,
    SourceRecords,
    DomainEntries,
    LineageEdges,
    SnapshotCursors,
  ],
)
class GodSenseDatabase extends _$GodSenseDatabase {
  GodSenseDatabase(super.executor);

  GodSenseDatabase.inMemory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement('''
        CREATE UNIQUE INDEX source_records_stable_identity
        ON source_records(
          source_namespace,
          COALESCE(platform_id, ''),
          COALESCE(game_id, -1),
          source_record_key
        )
        WHERE source_record_key IS NOT NULL
      ''');
      await customStatement('''
        CREATE UNIQUE INDEX domain_entries_derivation_identity
        ON domain_entries(derivation_key)
        WHERE derivation_key IS NOT NULL
      ''');
      await customStatement('''
        CREATE INDEX source_records_match_time
        ON source_records(platform_id, game_id, received_at_us)
      ''');
      await customStatement('''
        CREATE INDEX domain_entries_source_record
        ON domain_entries(source_record_id)
      ''');
      await _createScoutIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(accounts, accounts.summonerId);
        await migrator.addColumn(accounts, accounts.summonerLevel);
        await migrator.addColumn(accounts, accounts.profileIconId);
        await migrator.addColumn(accounts, accounts.lastClientVersion);
        await migrator.addColumn(accounts, accounts.lastPatchKey);
        await migrator.createTable(accountContextStates);
      }
      if (from < 3) {
        await migrator.createTable(matchDocuments);
        await migrator.createTable(rankedSnapshots);
        await _createScoutIndexes();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA busy_timeout = 5000');
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = NORMAL');
    },
  );

  Future<void> _createScoutIndexes() async {
    await customStatement('''
      CREATE INDEX IF NOT EXISTS match_documents_account_time
      ON match_documents(puuid, synced_at_us DESC)
    ''');
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS ranked_snapshots_consecutive_identity
      ON ranked_snapshots(puuid, observed_at_us, semantic_hash)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS ranked_snapshots_account_time
      ON ranked_snapshots(puuid, observed_at_us DESC)
    ''');
  }
}

Future<GodSenseDatabase> openGodSenseDatabase() async {
  final supportDirectory = await getApplicationSupportDirectory();
  final databaseDirectory = Directory(
    p.join(supportDirectory.path, 'database'),
  );
  await databaseDirectory.create(recursive: true);
  final file = File(p.join(databaseDirectory.path, 'godsense.sqlite'));
  return GodSenseDatabase(NativeDatabase.createInBackground(file));
}
