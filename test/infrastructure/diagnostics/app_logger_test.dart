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

  test('writes JSON lines and rotates bounded local files', () {
    for (var index = 0; index < 20; index++) {
      AppLogger.error(
        'Failure $index token=secret-$index ${'x' * 80}',
        category: 'test',
      );
    }

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
    AppLogger.warning('token=private-value', category: 'test');
    final file = File(AppLogger.logFilePath!);
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
}
