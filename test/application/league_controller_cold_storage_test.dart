import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/tactical/tactical_models.dart';
import 'package:godsense/domain/vision/vision_observation.dart';
import 'package:godsense/infrastructure/league/lcu_probe_transport.dart';
import 'package:godsense/infrastructure/league/league_clients.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late NativeLeagueController controller;
  late _FixtureLcu client;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('godsense-cold-storage-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
    SharedPreferences.setMockInitialValues({});
    // Check the production factory's actual directory before allowing any write.
    expect((await getApplicationSupportDirectory()).path, root.path);
    client = _FixtureLcu();
    controller = NativeLeagueController(lcu: client);
    expect(controller.foundation, isNull);
  });
  tearDown(() async {
    final foundation = controller.foundation;
    controller.foundation = null;
    controller.dispose();
    await foundation?.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });
  Future<Map<String, dynamic>> export() async {
    final file = await controller.exportLocalData(
      File('${root.path}/export.json'),
    );
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  test('export before connecting to League creates only the isolated empty database', () async {
    final data = await export();
    expect(data['accounts'], isEmpty);
    expect(data['matches'], isEmpty);
    expect(data['source_records'], isEmpty);
    expect(
      await File('${root.path}/database/godsense.sqlite').exists(),
      isTrue,
    );
    expect(client.paths, isEmpty);
  });
  test(
    'opening match history before connecting safely returns an empty library',
    () async {
      expect(await controller.loadLocalMatches(Puuid('synthetic')), isEmpty);
      expect((await export())['matches'], isEmpty);
      expect(client.paths, isEmpty);
    },
  );
  test(
    'opening ranked history before connecting safely returns no snapshot',
    () async {
      expect(await controller.loadLocalRanked(Puuid('synthetic')), isNull);
      expect((await export())['ranked_snapshots'], isEmpty);
      expect(client.paths, isEmpty);
    },
  );
  test(
    'retention and confirmed deletion work before any account is loaded',
    () async {
      await controller.applyLocalDataRetention();
      await controller.deleteAllLocalData();
      final data = await export();
      expect(data['accounts'], isEmpty);
      expect(data['source_records'], isEmpty);
      expect(controller.state.accountContext, isNull);
    },
  );
  test(
    'a local voice answer is journaled through the controller cold-start path',
    () async {
      expect(
        await controller.recordTacticalAdvice(
          question: '¿Qué hago?',
          advice: const TacticalAdvice(
            id: 'synthetic-advice',
            title: 'Oleada',
            hints: ['Congela'],
            rationale: 'Posición segura',
            ttsText: 'Congela la oleada',
            priority: 1,
            evidence: [],
          ),
        ),
        isTrue,
      );
      final data = await export();
      expect(data['source_records'], hasLength(1));
      expect(data['domain_entries'], hasLength(1));
      expect(
        (data['domain_entries'] as List).single['sourceRecordId'],
        (data['source_records'] as List).single['id'],
      );
    },
  );
  test('a vision observation is stored once through the controller cold-start path', () async {
    final observation = VisionObservation(
      kind: VisionObservationKind.enemySighting,
      champion: 'Lee Sin',
      location: 'Río',
      region: 'Bot',
      observedAt: DateTime.now(),
      confidence: .9,
    );
    expect(await controller.recordVisionObservation(observation), isTrue);
    expect(await controller.recordVisionObservation(observation), isFalse);
    final data = await export();
    expect(data['source_records'], hasLength(1));
  });
  test(
    'resolving a Scout Riot ID cold persists the requested account',
    () async {
      final account = await controller.resolveScoutAccount(
        gameName: ' Fixture ',
        tagLine: ' TEST ',
      );
      expect(account.puuid.value, 'scouted-synthetic');
      expect(account.riotId?.displayName, 'Fixture#TEST');
      expect((await export())['accounts'], hasLength(1));
      expect(client.paths.first, contains('gameName=Fixture'));
    },
  );
  test('search and sync cold preserve account identity when match capabilities are unavailable', () async {
    final account = await controller.scoutByRiotId(
      gameName: 'Fixture',
      tagLine: 'TEST',
    );
    expect(account.puuid.value, 'scouted-synthetic');
    final result = await controller.synchronizeScoutAccount(account);
    expect(result.matchesStored, 0);
    expect(result.rankedStored, isFalse);
    expect(await controller.loadLocalMatches(account.puuid), isEmpty);
    expect((await export())['accounts'], hasLength(1));
  });
}

class _FixtureLcu extends LcuClient {
  final paths = <String>[];
  @override
  Future<LcuProbeResponse> getDetailed(String path) async {
    paths.add(path);
    if (path.startsWith('/lol-summoner/v1/alias/lookup?')) {
      return const LcuProbeResponse.success(
        statusCode: 200,
        body: {'puuid': 'scouted-synthetic'},
      );
    }
    if (path.startsWith('/lol-summoner/v1/summoners?')) {
      return const LcuProbeResponse.success(
        statusCode: 200,
        body: {
          'puuid': 'scouted-synthetic',
          'summonerId': 10,
          'summonerLevel': 30,
        },
      );
    }
    throw StateError('Unexpected LCU access: $path');
  }
}
