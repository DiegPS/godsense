import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';
import 'package:godsense/infrastructure/persistence/local_data_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export of large match timelines bounds memory and event-loop pauses', () async {
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp(
      'godsense-heavy-matches-',
    );
    final database = GodSenseDatabase(
      NativeDatabase.createInBackground(
        File('${directory.path}/fixture.sqlite'),
      ),
    );
    Timer? monitor;
    try {
      final timeline = jsonEncode({
        'frames': [
          {'synthetic': 'x' * (768 * 1024)},
        ],
      });
      await database.transaction(() async {
        await database.customStatement(
          "INSERT INTO accounts (puuid, platform_id, first_seen_at_us, last_seen_at_us, record_schema_version) VALUES ('synthetic', 'LA1', 1, 1, 1)",
        );
        for (var index = 0; index < 200; index++) {
          await database.customStatement(
            "INSERT INTO matches (platform_id, game_id, record_schema_version) VALUES ('LA1', ?, 1)",
            [index],
          );
          await database.customStatement(
            "INSERT INTO match_documents (platform_id, game_id, puuid, summary_json, timeline_json, synced_at_us) VALUES ('LA1', ?, 'synthetic', '{}', ?, 1)",
            [index, timeline],
          );
        }
      });
      final baseline = ProcessInfo.currentRss;
      var peak = baseline;
      final clock = Stopwatch()..start();
      var previous = 0;
      var maximumGap = 0;
      void sample() {
        peak = max(peak, ProcessInfo.currentRss);
        final now = clock.elapsedMicroseconds;
        maximumGap = max(maximumGap, now - previous);
        previous = now;
      }

      monitor = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => sample(),
      );
      final destination = File('${directory.path}/export.json');
      await LocalDataManager(database).exportTo(destination);
      sample();
      monitor.cancel();
      await Directory('build/testing').create(recursive: true);
      await File('build/testing/large-match-export-memory.json').writeAsString(
        jsonEncode({
          'matches': 200,
          'timeline_bytes_each': timeline.length,
          'export_bytes': await destination.length(),
          'rss_growth_bytes': peak - baseline,
          'maximum_caller_gap_ms': maximumGap / 1000,
        }),
      );
      expect(await destination.length(), greaterThan(200 * timeline.length));
      expect(
        peak - baseline,
        lessThan(96 * 1024 * 1024),
        reason: 'Large timeline pages must not accumulate the entire export in memory',
      );
      expect(
        maximumGap,
        lessThan(250000),
        reason:
            'Large timelines must not freeze the caller while encoding a page',
      );
    } finally {
      monitor?.cancel();
      await database.close();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 90)));
}
