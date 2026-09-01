import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';

void main() {
  late GodSenseDatabase database;

  setUp(() => database = GodSenseDatabase.inMemory());
  tearDown(() => database.close());

  test(
    'opens schema v3 with foreign keys and required identity indexes',
    () async {
      final userVersion = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      final foreignKeys = await database
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      final indexes = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'source_records_%'",
          )
          .get();

      expect(userVersion.read<int>('user_version'), 3);
      expect(foreignKeys.read<int>('foreign_keys'), 1);
      expect(
        indexes.map((row) => row.read<String>('name')),
        containsAll([
          'source_records_stable_identity',
          'source_records_match_time',
        ]),
      );
    },
  );

  test('enforces the account-to-match composite foreign key', () async {
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            puuid: 'puuid-1',
            platformId: 'LA1',
            firstSeenAtUs: 1,
            lastSeenAtUs: 1,
          ),
        );

    expect(
      () => database
          .into(database.accountMatches)
          .insert(
            AccountMatchesCompanion.insert(
              puuid: 'puuid-1',
              platformId: 'LA1',
              gameId: 99,
            ),
          ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('FOREIGN KEY constraint failed'),
        ),
      ),
    );
  });

  test(
    'migrates the phase 2A schema from v1 through v3 without data loss',
    () async {
      await database.close();
      database = GodSenseDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw
              ..execute('''
              CREATE TABLE accounts (
                puuid TEXT NOT NULL PRIMARY KEY,
                platform_id TEXT NOT NULL,
                game_name TEXT,
                tag_line TEXT,
                first_seen_at_us INTEGER NOT NULL,
                last_seen_at_us INTEGER NOT NULL,
                record_schema_version INTEGER NOT NULL DEFAULT 1
              )
            ''')
              ..execute('''
              INSERT INTO accounts (
                puuid, platform_id, first_seen_at_us, last_seen_at_us
              ) VALUES ('existing-puuid', 'LA1', 1, 2)
            ''')
              ..execute('PRAGMA user_version = 1');
          },
        ),
      );

      final account = await database.select(database.accounts).getSingle();
      final contextTable = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'account_context_states'",
          )
          .getSingle();

      expect(account.puuid, 'existing-puuid');
      expect(account.summonerId, isNull);
      expect(contextTable.read<String>('name'), 'account_context_states');
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        3,
      );
      final scoutTables = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name IN ('match_documents', 'ranked_snapshots')",
          )
          .get();
      expect(scoutTables, hasLength(2));
    },
  );
}
