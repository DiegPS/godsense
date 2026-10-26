import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/application/native_league_foundation.dart';
import 'package:godsense/infrastructure/league/lcu_event_stream.dart';
import 'package:godsense/infrastructure/league/lcu_probe_transport.dart';
import 'package:godsense/infrastructure/league/league_clients.dart';
import 'package:godsense/infrastructure/persistence/godsense_database.dart';

Future<void> _until(bool Function() completed) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!completed() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(completed(), true);
}

void main() {
  test('closing during item-set lookup prevents any later import write', () async {
    final client = _Client();
    final database = GodSenseDatabase.inMemory();
    final foundation = NativeLeagueFoundation(
      client: client,
      databaseFactory: () async => database,
    );
    final controller = NativeLeagueController(
      lcu: client,
      lcuEvents: LcuEventStream(credentialsProvider: () => null),
      live: _Live(),
      foundation: foundation,
    );
    var disposed = false;
    try {
      controller.start();
      await _until(() => controller.localSummonerId == 7);
      final importing = controller.importRecommendedSetup({
        'items': [
          {
            'category': 'Start',
            'items': [
              {'item_id': 2003},
            ],
          },
        ],
      });
      await _until(() => client.itemReads > 0);
      controller.foundation = null;
      controller.dispose();
      disposed = true;
      client.itemSets.complete({'accountId': 7, 'itemSets': []});
      await importing;
      expect(
        client.writes,
        isEmpty,
        reason:
            'A closed controller must not mutate League after an awaited read',
      );
    } finally {
      if (!disposed) {
        controller.foundation = null;
        controller.dispose();
      }
      await foundation.dispose();
    }
  });
}

class _Client extends LcuClient {
  final itemSets = Completer<Object?>();
  int itemReads = 0;
  final writes = <String>[];
  @override
  Future<LcuCredentials?> discover() async => const LcuCredentials(
    port: 1,
    password: 'synthetic',
    protocol: 'https',
    lockfilePath: 'synthetic',
  );
  @override
  Future<LcuProbeResponse> getDetailed(String path) async =>
      const LcuProbeResponse.failure(
        failureKind: LcuProbeFailureKind.clientError,
        statusCode: 404,
      );
  @override
  Future<Object?> get(String path) async {
    if (path == '/lol-item-sets/v1/item-sets/7/sets') {
      itemReads++;
      return itemSets.future;
    }
    return switch (path) {
      '/lol-gameflow/v1/gameflow-phase' => 'ChampSelect',
      '/lol-summoner/v1/current-summoner' => {
        'summonerId': 7,
        'puuid': 'synthetic',
      },
      '/lol-champ-select/v1/session' => {'myTeam': [], 'theirTeam': []},
      _ => null,
    };
  }

  @override
  Future<Object?> put(String path, Object? body) async {
    writes.add(path);
    return body;
  }
}

class _Live extends LiveClientApi {
  @override
  Future<Map<String, dynamic>?> allGameData() async => null;
}
