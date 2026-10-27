import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/coach_controller.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/game_session.dart';

void main() {
  late _Store store;
  late CoachController controller;
  setUp(() {
    store = _Store();
    controller = CoachController(
      importRunes: (_) async {},
      importItems: () async {},
      reportStore: store,
    );
  });
  tearDown(() => controller.dispose());
  Future<void> flush() =>
      Future<void>.delayed(const Duration(milliseconds: 10));

  test('late account A report cannot replace account B report', () async {
    final gate = Completer<Map<String, dynamic>?>();
    store.reads['A'] = gate.future;
    store.reads['B'] = Future.value(_report('B champion'));
    controller.synchronize(_inputs('A'));
    await store.started.future;
    controller.synchronize(_inputs('B'));
    await flush();
    gate.complete(_report('A champion'));
    await flush();
    expect(controller.state.postGameReport?.champion, 'B champion');
  });

  test('saved report without optional telemetry remains readable', () async {
    store.reads['A'] = Future.value({'_game_ended': true});
    controller.synchronize(_inputs('A'));
    await flush();
    final report = controller.state.postGameReport!;
    expect(report.champion, 'Campeón');
    expect(report.kda, 0);
    expect(report.teamState, 'UNKNOWN');
    expect(report.keyEvents, isEmpty);
    expect(report.review, hasLength(1));
      expect(report.review.single, startsWith('Revisa los eventos clave'));
  });

  test(
    'an unreadable report does not prevent starting a new session',
    () async {
      final gate = Completer<Map<String, dynamic>?>();
      store.reads['A'] = gate.future;
      controller.synchronize(_inputs('A'));
      await store.started.future;
      gate.completeError(
        const FormatException('synthetic corrupt saved report'),
      );
      await flush();
      expect(controller.state.postGameReport, isNull);
      controller.synchronize(_inputs('A', ended: true));
      await flush();
      expect(controller.state.postGameReport?.champion, 'New champion');
      expect(store.writes, hasLength(1));
    },
  );

  test(
    'completed snapshot from a different account is not persisted',
    () async {
      controller.synchronize(_inputs('B', ended: true, sessionAccount: 'A'));
      await flush();
      expect(controller.state.postGameReport, isNull);
      expect(store.writes, isEmpty);
    },
  );

  test(
    'persisted report omits unrelated raw player data and duplicate snapshots',
    () async {
      controller.synchronize(_inputs('A', ended: true));
      controller.synchronize(_inputs('A', ended: true));
      await flush();
      expect(store.writes, hasLength(1));
      final snapshot = store.writes.single.$2;
      expect(snapshot['active_player'], {
        'champion_name': 'New champion',
        'kda': [2, 0, 8],
        'cs': 180,
      });
      expect(
        (snapshot['active_player'] as Map).containsKey('summoner_name'),
        isFalse,
      );
      expect(snapshot.containsKey('raw_private_fixture'), isFalse);
      expect(controller.state.postGameReport?.kda, 10);
    },
  );

  test('a failed report write can be retried on the next update', () async {
    store.failNextSave = true;
    controller.synchronize(_inputs('A', ended: true));
    await flush();
    controller.synchronize(_inputs('A', ended: true));
    await flush();
    expect(store.writes, hasLength(2));
    expect(controller.state.postGameReport?.champion, 'New champion');
  });
}

Map<String, dynamic> _report(String champion) => {
  '_game_ended': true,
  'active_player': {
    'champion_name': champion,
    'kda': [2, 1, 4],
    'cs': 200,
  },
  'game_time': 1800,
};

CoachInputs _inputs(
  String account, {
  bool ended = false,
  String? sessionAccount,
}) => CoachInputs(
  accountKey: account,
  gameflowPhase: ended ? 'EndOfGame' : 'None',
  session: GameSessionState(
    lastCompleted: ended
        ? GameSession(
            sessionId: 'synthetic-session',
            generation: const GameSessionGeneration(1),
            accountPuuid: Puuid(sessionAccount ?? account),
            phase: GameSessionPhase.completed,
            startedAt: DateTime.utc(2026),
            lastObservedAt: DateTime.utc(2026),
          )
        : null,
  ),
  liveGame: ended
      ? {
          '_game_ended': true,
          'game_time': 1800,
          'raw_private_fixture': 'not exportable',
          'active_player': {
            'champion_name': 'New champion',
            'kda': [2, 0, 8],
            'cs': 180,
            'summoner_name': 'Not part of the report',
          },
        }
      : null,
  lobby: null,
  runes: null,
  items: null,
  jungle: null,
  directives: const [],
  threats: const [],
  voiceProcessing: false,
  voiceQuestion: '',
  voiceAdvice: null,
  voiceAnsweredAt: null,
);

class _Store implements PostGameReportStore {
  final reads = <String, Future<Map<String, dynamic>?>>{};
  final writes = <(String, Map<String, dynamic>)>[];
  final started = Completer<void>();
  bool failNextSave = false;
  @override
  Future<Map<String, dynamic>?> load(String accountKey) async {
    if (!started.isCompleted) started.complete();
    return await reads[accountKey];
  }

  @override
  Future<void> save(String accountKey, Map<String, dynamic> snapshot) async {
    writes.add((accountKey, snapshot));
    if (failNextSave) {
      failNextSave = false;
      throw StateError('synthetic preferences failure');
    }
  }
}
