import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/diagnostics/app_logger.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'godsense-logger-test-',
    );
    await AppLogger.initialize(
      directory: temporaryDirectory,
      maxBytes: 512,
      backupCount: 2,
    );
  });

  tearDown(() async {
    await AppLogger.flush();
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('redacts credentials, identity, prompts and user paths', () {
    final redacted = AppLogger.redact(
      'Authorization: Bearer abc.def password=hunter2 '
      'puuid="player-secret" question:where C:\\Users\\diego\\file '
      'mail diego@example.com',
    );

    expect(redacted, isNot(contains('abc.def')));
    expect(redacted, isNot(contains('hunter2')));
    expect(redacted, isNot(contains('player-secret')));
    expect(redacted, isNot(contains('where')));
    expect(redacted, isNot(contains('diego@example.com')));
    expect(redacted, isNot(contains(r'C:\Users\diego')));
  });

  test('redacts identity in LCU paths and query parameters', () {
    final redacted = AppLogger.redact(
      '/lol-ranked/v1/ranked-stats/private-puuid?gameName=Diego&tagLine=LAN '
      '/lol-summoner/v1/summoners/another-private-id',
    );

    expect(redacted, isNot(contains('private-puuid')));
    expect(redacted, isNot(contains('Diego')));
    expect(redacted, isNot(contains('LAN')));
    expect(redacted, isNot(contains('another-private-id')));
  });

  test(
    'initialization fails open when the log directory is unavailable',
    () async {
      final blocker = File('${temporaryDirectory.path}\\not-a-directory');
      await blocker.writeAsString('occupied');

      final initialized = await AppLogger.initialize(
        directory: Directory(blocker.path),
      );

      expect(initialized, isFalse);
      expect(AppLogger.logFilePath, isNull);
      expect(
        () => AppLogger.error('The application must keep running.'),
        returnsNormally,
      );
    },
  );

  test('writes JSON lines and rotates bounded local files', () async {
    for (var index = 0; index < 20; index++) {
      AppLogger.error(
        'Failure $index token=secret-$index ${'x' * 80}',
        category: 'test',
      );
    }

    await AppLogger.flush();
    final file = File(AppLogger.logFilePath!);
    expect(file.existsSync(), isTrue);
    expect(File('${file.path}.1').existsSync(), isTrue);
    final contents = [file, File('${file.path}.1')]
        .where((candidate) => candidate.existsSync())
        .map((candidate) => candidate.readAsStringSync())
        .join();
    expect(contents, isNot(contains('secret-19')));
    expect(contents, contains('[REDACTED]'));
  });

  test('exports entries and deletes expired diagnostic files', () async {
    final file = File(AppLogger.logFilePath!);
    await file.writeAsString(
      '${_entry(DateTime.utc(2026, 1, 1), 'token=[REDACTED]')}\n',
      flush: true,
    );
    await file.setLastModified(DateTime.utc(2026, 1, 1));

    final entries = await AppLogger.exportEntries();
    expect(entries, isNotEmpty);
    expect(entries.toString(), isNot(contains('private-value')));
    expect(
      await AppLogger.deleteExpired(
        const Duration(days: 7),
        now: DateTime.utc(2026, 2, 1),
      ),
      1,
    );
    expect(file.existsSync(), isFalse);
  });

  test(
    'queued writes are ordered and deletion cannot resurrect old logs',
    () async {
      AppLogger.info('before-delete');
      await AppLogger.deleteAll();
      AppLogger.info('after-delete');
      final entries = await AppLogger.exportEntries();
      expect(entries.map((entry) => entry['message']), ['after-delete']);
    },
  );

  test('removes expired entries without deleting recent entries', () async {
    final file = File(AppLogger.logFilePath!);
    await file.writeAsString(
      '${_entry(DateTime.utc(2026, 1, 1), 'expired')}\n'
      '${_entry(DateTime.utc(2026, 2, 27), 'recent')}\n',
      flush: true,
    );

    await AppLogger.deleteExpired(
      const Duration(days: 7),
      now: DateTime.utc(2026, 3, 1),
    );

    final entries = await AppLogger.exportEntries();
    expect(entries.map((entry) => entry['message']), ['recent']);
  });
}

String _entry(DateTime timestamp, String message) =>
    '{"timestamp":"${timestamp.toIso8601String()}","message":"$message"}';
