import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';

void main() {
  late GodSenseDatabase database;

  setUp(() => database = GodSenseDatabase.inMemory());
  tearDown(() => database.close());

  test(
    'opens schema v1 with foreign keys and required identity indexes',
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

      expect(userVersion.read<int>('user_version'), 1);
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
}
