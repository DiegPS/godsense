import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/domain/league/rune_recommendation.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/jungle/jungle_recommendation.dart';
import 'package:godsense/infrastructure/jungle/jungle_recommendation_source.dart';
import 'package:godsense/infrastructure/jungle/jungle_map_transport.dart';
import 'package:godsense/infrastructure/league/league_clients.dart';
import 'package:godsense/infrastructure/league/lcu_probe_transport.dart';
import 'package:godsense/infrastructure/league/lcu_event_stream.dart';

void main() {
  late _LcuFixture client;
  late NativeLeagueController controller;

  setUp(() {
    client = _LcuFixture();
    controller = NativeLeagueController(lcu: client);
  });
  tearDown(() => controller.dispose());

  const build = {
    'runes': {
      'primary_tree_id': 8000,
      'secondary_tree_id': 8100,
      'perk_ids': [8005, 9111, 9104, 8014, 8139, 8135, 5005, 5008, 5002],
    },
  };

  test(
    'updates an existing GodSense rune page without deleting it first',
    () async {
      client.pages = [
        {'id': 7, 'name': 'My personal page', 'isDeletable': true},
        {'id': 8, 'name': 'GodSense', 'isDeletable': true},
      ];
      await controller.importRecommendedSetup(build);
      expect(client.writes.map((entry) => entry.$1), [
        'PUT /lol-perks/v1/pages/8',
      ]);
      expect(controller.state.lastOperationResult['runes'], isNotNull);
      expect(controller.state.operationInProgress, false);
    },
  );

  test(
    'failed rune update preserves the previous page and reports failure',
    () async {
      client.pages = [
        {'id': 8, 'name': 'GodSense', 'isDeletable': true},
      ];
      client.failWrite = true;
      await controller.importRecommendedSetup(build);
      expect(client.deleted, isEmpty);
      expect(controller.state.lastOperationResult['runes_error'], isNotNull);
      expect(controller.state.operationInProgress, false);
    },
  );

  test(
    'creates a new page while preserving personal and protected pages',
    () async {
      client.pages = [
        {'id': 7, 'name': 'Personal', 'isDeletable': true},
        {'id': 8, 'name': 'GodSense', 'isDeletable': false},
      ];
      await controller.importRecommendedSetup({'popular': build});
      expect(client.writes.map((entry) => entry.$1), [
        'POST /lol-perks/v1/pages',
      ]);
      final payload = client.writes.single.$2 as Map;
      expect(payload['selectedPerkIds'], hasLength(9));
      expect(payload['current'], true);
      expect(client.deleted, isEmpty);
    },
  );

  test(
    'late rune recommendations cannot overwrite a newer champion selection',
    () async {
      final firstResponse = Completer<Object?>();
      client.runeResponses[103] = firstResponse.future;
      client.runeResponses[86] = [_runeVariant(86)];
      final first = controller.loadRuneRecommendations(
        championId: 103,
        position: LeaguePosition.middle,
      );
      await controller.loadRuneRecommendations(
        championId: 86,
        position: LeaguePosition.middle,
      );
      firstResponse.complete([_runeVariant(103)]);
      await first;
      expect(controller.state.runeRecommendations?.championId, 86);
      expect(controller.state.runeRecommendationsLoading, false);
    },
  );

  test('rune recommendation failure after disposal is ignored', () async {
    final response = Completer<Object?>();
    client.runeResponses[103] = response.future;
    final closingController = NativeLeagueController(lcu: client);
    final operation = closingController.loadRuneRecommendations(
      championId: 103,
      position: LeaguePosition.middle,
    );
    closingController.dispose();
    response.completeError(StateError('Synthetic delayed failure'));
    await expectLater(operation, completes);
  });

  test('empty recommendations perform no writes', () async {
    await controller.importRecommendedSetup({});
    await controller.importCurrentRecommendations();
    await controller.importItemRecommendations();
    expect(client.writes, isEmpty);
    expect(client.deleted, isEmpty);
    expect(controller.state.operationInProgress, false);
  });

  test(
    'a late rune response after closing does not update disposed state',
    () async {
      final response = Completer<Object?>();
      client.writeResponse = response.future;
      final closingController = NativeLeagueController(lcu: client);
      final operation = closingController.importRecommendedSetup(build);
      await Future<void>.delayed(Duration.zero);
      expect(client.writes, hasLength(1));
      closingController.dispose();
      response.complete({'id': 8});
      await expectLater(operation, completes);
    },
  );

  test('repeated imports cannot create concurrent rune writes', () async {
    final response = Completer<Object?>();
    client.writeResponse = response.future;
    final first = controller.importRecommendedSetup(build);
    final repeated = controller.importRecommendedSetup(build);
    await Future<void>.delayed(Duration.zero);
    response.complete({'id': 8});
    await Future.wait([first, repeated]);
    expect(client.writes, hasLength(1));
  });

  test(
    'closing while a League request is in flight ignores its late result',
    () async {
      final response = Completer<Object?>();
      client.phaseResponse = response.future;
      final events = LcuEventStream(credentialsProvider: () => null);
      final closingController = NativeLeagueController(
        lcu: client,
        lcuEvents: events,
      );
      closingController.start();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(client.phaseReads, 1);
      closingController.dispose();
      response.complete('None');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(
        closingController.foundation,
        isNull,
        reason: 'A disposed controller must not open a new database',
      );
    },
  );

  test(
    'champion names reject invalid entries and return an immutable map',
    () async {
      client.champions = [
        {'id': 103, 'name': 'Ahri', 'alias': 'Ahri'},
        {'id': 0, 'name': 'Placeholder'},
        {'id': -1, 'name': 'Invalid'},
        {'id': 7, 'name': '  '},
        'invalid',
      ];
      final names = await controller.loadChampionNames();
      expect(names, {103: 'Ahri'});
      expect(() => names[1] = 'Modified', throwsUnsupportedError);
    },
  );

  test(
    'changing champion clears the previous rune bundle while loading',
    () async {
      client.runeResponses[103] = [_runeVariant(103)];
      await controller.loadRuneRecommendations(
        championId: 103,
        position: LeaguePosition.middle,
      );
      final response = Completer<Object?>();
      client.runeResponses[86] = response.future;
      final loading = controller.loadRuneRecommendations(
        championId: 86,
        position: LeaguePosition.top,
      );
      expect(controller.state.runeRecommendations, isNull);
      expect(controller.state.runeRecommendationsLoading, true);
      response.completeError(
        StateError('Synthetic unavailable recommendation'),
      );
      await loading;
      expect(controller.state.runeRecommendationsLoading, false);
      expect(
        controller.state.runeRecommendationsError,
        contains('Synthetic unavailable'),
      );
      client.runeResponses[86] = [_runeVariant(86)];
      await controller.loadRuneRecommendations(
        championId: 86,
        position: LeaguePosition.middle,
      );
      expect(controller.state.runeRecommendationsError, isNull);
      expect(controller.state.runeRecommendations?.championId, 86);
    },
  );

  test(
    'missing patch reports an actionable item error without writes',
    () async {
      await controller.loadItemRecommendations(
        championId: 103,
        championAlias: 'Ahri',
        position: LeaguePosition.middle,
      );
      expect(controller.state.itemRecommendationsLoading, false);
      expect(controller.state.itemRecommendations, isNull);
      expect(controller.state.itemRecommendationsError, contains('patch'));
      expect(client.writes, isEmpty);
    },
  );

  for (final staleFails in [false, true]) {
    test(
      'new jungle patch survives a stale ${staleFails ? 'failure' : 'success'}',
      () async {
        final source = _JungleSource();
        final subject = NativeLeagueController(
          lcu: client,
          jungleRecommendationSource: source,
        );
        addTearDown(subject.dispose);
        final first = subject.loadJungleRecommendations(PatchKey('26.20'));
        final second = subject.loadJungleRecommendations(PatchKey('26.21'));
        source.pending['26.21']!.complete(_jungleBundle('26.21'));
        await second;
        if (staleFails) {
          source.pending['26.20']!.completeError(
            StateError('Old patch failed'),
          );
        } else {
          source.pending['26.20']!.complete(_jungleBundle('26.20'));
        }
        await first;
        expect(subject.state.jungleRecommendations?.patch.value, '26.21');
        expect(subject.state.jungleRecommendationsLoading, false);
        expect(subject.state.jungleRecommendationsError, isNull);
      },
    );
  }

  test('jungle download failure is recoverable on retry', () async {
    final source = _JungleSource();
    final subject = NativeLeagueController(
      lcu: client,
      jungleRecommendationSource: source,
    );
    addTearDown(subject.dispose);
    final first = subject.loadJungleRecommendations(PatchKey('26.21'));
    source.pending['26.21']!.completeError(StateError('Synthetic offline'));
    await first;
    expect(subject.state.jungleRecommendationsError, contains('offline'));
    expect(subject.state.jungleRecommendationsLoading, false);
    final retry = subject.loadJungleRecommendations(PatchKey('26.21'));
    expect(subject.state.jungleRecommendationsError, isNull);
    source.pending['26.21']!.complete(_jungleBundle('26.21'));
    await retry;
    expect(subject.state.jungleRecommendations?.patch.value, '26.21');
    expect(subject.state.jungleRecommendationsError, isNull);
  });

  for (final fails in [false, true]) {
    test(
      'jungle ${fails ? 'failure' : 'success'} after disposal is ignored',
      () async {
        final source = _JungleSource();
        final subject = NativeLeagueController(
          lcu: client,
          jungleRecommendationSource: source,
        );
        final loading = subject.loadJungleRecommendations(PatchKey('26.21'));
        subject.dispose();
        if (fails) {
          source.pending['26.21']!.completeError(StateError('Late failure'));
        } else {
          source.pending['26.21']!.complete(_jungleBundle('26.21'));
        }
        await expectLater(loading, completes);
      },
    );
  }
}

class _JungleSource extends JungleRecommendationSource {
  _JungleSource() : super(transport: _UnusedJungleTransport());
  final pending = <String, Completer<JungleRecommendationBundle>>{};

  @override
  Future<JungleRecommendationBundle> load(PatchKey patch) =>
      (pending[patch.value] = Completer<JungleRecommendationBundle>()).future;
}

class _UnusedJungleTransport implements JungleMapTransport {
  @override
  Future<Map<String, dynamic>> loadMap11(PatchKey patch) =>
      throw StateError('Unexpected network transport access');
  @override
  Uri sourceUri(PatchKey patch) => Uri.parse('https://example.invalid/map');
}

JungleRecommendationBundle _jungleBundle(String patch) =>
    JungleRecommendationBundle(
      patch: PatchKey(patch),
      mapId: 11,
      order: const JungleRoute(side: JungleSide.order, camps: []),
      chaos: const JungleRoute(side: JungleSide.chaos, camps: []),
      fetchedAt: DateTime.utc(2026, 10, 25),
      sourceUri: Uri.parse('https://example.invalid/map'),
    );

class _LcuFixture extends LcuClient {
  List<Object?> pages = [];
  List<Object?> champions = [];
  final writes = <(String, Object?)>[];
  final deleted = <String>[];
  final runeResponses = <int, Object?>{};
  bool failWrite = false;
  Future<Object?>? writeResponse;
  Future<Object?>? phaseResponse;
  int phaseReads = 0;

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
        failureKind: LcuProbeFailureKind.disconnected,
      );

  @override
  Future<Object?> get(String path) async {
    if (path.startsWith('/lol-perks/v1/recommended-pages/champion/')) {
      final id = int.parse(path.split('/')[5]);
      return runeResponses[id];
    }
    if (path == '/lol-gameflow/v1/gameflow-phase') {
      phaseReads++;
      return phaseResponse ?? 'None';
    }
    return switch (path) {
      '/lol-perks/v1/pages' => pages,
      '/lol-game-data/assets/v1/champion-summary.json' => champions,
      _ => null,
    };
  }

  @override
  Future<Object?> delete(String path) async {
    deleted.add(path);
    return null;
  }

  @override
  Future<Object?> post(String path, Object? body) async =>
      _write('POST $path', body);
  @override
  Future<Object?> put(String path, Object? body) async =>
      _write('PUT $path', body);

  Object? _write(String path, Object? body) {
    writes.add((path, body));
    if (failWrite) throw StateError('Synthetic write failure');
    return writeResponse ?? {'id': 8};
  }
}

Map<String, dynamic> _runeVariant(int champion) => {
  'recommendationId': 'synthetic-$champion',
  'recommendationChampionId': champion,
  'position': 'MIDDLE',
  'perks': [
    for (final id in [8112, 8139, 8140, 8106, 8226, 8210, 5005, 5008, 5001])
      {'id': id},
  ],
  'keystone': {'id': 8112},
  'primaryPerkStyleId': 8100,
  'secondaryPerkStyleId': 8200,
  'summonerSpellIds': [4, 12],
};
