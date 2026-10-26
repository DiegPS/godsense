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
  test(
    'large export stays bounded, responsive and includes every row',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'godsense-export-stress-',
      );
      final database = GodSenseDatabase(
        NativeDatabase.createInBackground(
          File('${directory.path}/fixture.sqlite'),
        ),
      );
      Timer? monitor;
      try {
        const count = 8000;
        final payload = 'x' * (24 * 1024);
        await database.transaction(() async {
          for (var index = 0; index < count; index++) {
            await database.customStatement(
              'INSERT INTO accounts (puuid, platform_id, game_name, first_seen_at_us, last_seen_at_us, record_schema_version) VALUES (?, ?, ?, ?, ?, ?)',
              ['synthetic-$index', 'LA1', payload, 1, 1, 1],
            );
          }
        });
        final baseline = ProcessInfo.currentRss;
        var peak = baseline;
        final clock = Stopwatch()..start();
        var previous = 0;
        var largestGap = 0;
        void sample() {
          peak = max(peak, ProcessInfo.currentRss);
          final now = clock.elapsedMicroseconds;
          largestGap = max(largestGap, now - previous);
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
        final length = await destination.length();
        final report = {
          'rows': count,
          'export_bytes': length,
          'rss_growth_bytes': peak - baseline,
          'maximum_caller_gap_ms': largestGap / 1000,
        };
        await Directory('build/testing').create(recursive: true);
        await File('build/testing/large-export-memory.json')
            .writeAsString(jsonEncode(report));
        expect(length, greaterThan(count * payload.length));
        expect(
          peak - baseline,
          lessThan(96 * 1024 * 1024),
          reason: 'Export must not retain a whole large table in memory',
        );
        expect(
          largestGap,
          lessThan(250000),
          reason: 'Export must keep the caller event loop responsive',
        );
        final ids = <int>{};
        final pattern = RegExp(r'"puuid":"synthetic-(\d+)"');
        var carry = '';
        await for (final chunk in utf8.decoder.bind(destination.openRead())) {
          final text = carry + chunk;
          for (final match in pattern.allMatches(text)) {
            ids.add(int.parse(match[1]!));
          }
          carry = text.substring(max(0, text.length - 80));
        }
        expect(ids, hasLength(count));
        expect(ids.reduce(min), 0);
        expect(ids.reduce(max), count - 1);
        expect((await destination.openRead(length - 1).single).single, 125);
      } finally {
        monitor?.cancel();
        await database.close();
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
