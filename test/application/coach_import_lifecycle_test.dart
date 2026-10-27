import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/coach_controller.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/game_session.dart';
import 'package:godsense/domain/league/item_recommendation.dart';
import 'package:godsense/domain/league/rune_recommendation.dart';

void main() {
  test('equivalent rebuilt recommendations do not cancel an import', () async {
    final gate = Completer<void>();
    var items = 0;
    final controller = CoachController(
      importRunes: (_) => gate.future,
      importItems: () async {
        items++;
      },
    );
    addTearDown(controller.dispose);
    controller.synchronize(_input());
    final importing = controller.importCurrentSetup();
    controller.synchronize(_input());
    expect(controller.state.importFeedback.status, CoachImportStatus.importing);
    gate.complete();
    await importing;
    expect(items, 1);
    expect(controller.state.importFeedback.status, CoachImportStatus.succeeded);
  });

  test(
    'combined import stops cleanly when closed during the rune step',
    () async {
      final gate = Completer<void>();
      var items = 0;
      final controller = CoachController(
        importRunes: (_) => gate.future,
        importItems: () async {
          items++;
        },
      );
      controller.synchronize(_input());
      final importing = controller.importCurrentSetup();
      controller.dispose();
      gate.complete();
      await expectLater(importing, completes);
      expect(items, 0);
    },
  );

  test(
    'a failed old import cannot mark a different account as failed',
    () async {
      final gate = Completer<void>();
      final controller = CoachController(
        importRunes: (_) => gate.future,
        importItems: () async {},
      );
      addTearDown(controller.dispose);
      controller.synchronize(_input());
      final importing = controller.importCurrentSetup();
      controller.synchronize(_input(account: 'synthetic-B'));
      gate.completeError(StateError('synthetic old account failure'));
      await importing;
      expect(controller.state.importFeedback.status, CoachImportStatus.idle);
    },
  );

  test(
    'pending combined setup excludes both separate import controls',
    () async {
      final gate = Completer<void>();
      var runes = 0;
      var items = 0;
      final controller = CoachController(
        importRunes: (_) {
          runes++;
          return gate.future;
        },
        importItems: () async {
          items++;
        },
      );
      addTearDown(controller.dispose);
      controller.synchronize(_input());
      final importing = controller.importCurrentSetup();
      await controller.importRune(
        controller.state.runeRecommendations.single.variant,
      );
      await controller.importItemSet();
      await controller.importCurrentSetup();
      expect(runes, 1);
      expect(items, 0);
      gate.complete();
      await importing;
      expect(items, 1);
    },
  );

  test(
    'a successful import completing after close does not update disposed state',
    () async {
      final gate = Completer<void>();
      final controller = CoachController(
        importRunes: (_) async {},
        importItems: () => gate.future,
      );
      final importing = controller.importItemSet();
      controller.dispose();
      gate.complete();
      await expectLater(importing, completes);
    },
  );

  test('a failed import completing after close is handled without disposed state access', () async {
    final gate = Completer<void>();
    final controller = CoachController(
      importRunes: (_) async {},
      importItems: () => gate.future,
    );
    final importing = controller.importItemSet();
    controller.dispose();
    gate.completeError(StateError('synthetic disconnected client'));
    await expectLater(importing, completes);
  });

  test(
    'repeated imports do not launch overlapping client operations',
    () async {
      final gate = Completer<void>();
      var calls = 0;
      final controller = CoachController(
        importRunes: (_) async {},
        importItems: () {
          calls++;
          return gate.future;
        },
      );
      addTearDown(controller.dispose);
      final first = controller.importItemSet();
      final second = controller.importItemSet();
      expect(calls, 1);
      expect(
        controller.state.importFeedback.status,
        CoachImportStatus.importing,
      );
      gate.complete();
      await Future.wait([first, second]);
      expect(
        controller.state.importFeedback.status,
        CoachImportStatus.succeeded,
      );
    },
  );

  test('combined import preserves order and stops if runes fail', () async {
    final calls = <String>[];
    final controller = CoachController(
      importRunes: (_) async {
        calls.add('runes');
        throw StateError('synthetic rune rejection');
      },
      importItems: () async {
        calls.add('items');
      },
    );
    addTearDown(controller.dispose);
    controller.synchronize(_input());
    await controller.importCurrentSetup();
    expect(calls, ['runes']);
    expect(controller.state.importFeedback.status, CoachImportStatus.failed);
  });

  test('combined import cannot send items for a different account after rune completion', () async {
    final gate = Completer<void>();
    var items = 0;
    final controller = CoachController(
      importRunes: (_) => gate.future,
      importItems: () async {
        items++;
      },
    );
    addTearDown(controller.dispose);
    controller.synchronize(_input(account: 'synthetic-A'));
    final importing = controller.importCurrentSetup();
    controller.synchronize(_input(account: 'synthetic-B'));
    gate.complete();
    await importing;
    expect(
      items,
      0,
      reason:
          'A request belonging to account A must not continue on account B.',
    );
    expect(controller.state.importFeedback.status, CoachImportStatus.idle);
  });

  test('combined import stops if recommendation context changes while runes are pending', () async {
    final gate = Completer<void>();
    var items = 0;
    final controller = CoachController(
      importRunes: (_) => gate.future,
      importItems: () async {
        items++;
      },
    );
    addTearDown(controller.dispose);
    controller.synchronize(_input());
    final importing = controller.importCurrentSetup();
    controller.synchronize(_input(championId: 86));
    gate.complete();
    await importing;
    expect(
      items,
      0,
      reason: 'Do not combine runes for Ahri with items for a different pick.',
    );
  });

  test(
    'combined setup imports runes before items and accepts a later retry',
    () async {
      final calls = <String>[];
      final controller = CoachController(
        importRunes: (_) async {
          calls.add('runes');
        },
        importItems: () async {
          calls.add('items');
        },
      );
      addTearDown(controller.dispose);
      controller.synchronize(_input());
      await controller.importCurrentSetup();
      await controller.importCurrentSetup();
      expect(calls, ['runes', 'items', 'runes', 'items']);
      expect(
        controller.state.importFeedback.status,
        CoachImportStatus.succeeded,
      );
    },
  );
}

CoachInputs _input({String account = 'synthetic-A', int championId = 103}) =>
    CoachInputs(
      accountKey: account,
      gameflowPhase: 'ChampSelect',
      session: const GameSessionState(),
      liveGame: null,
      lobby: null,
      runes: RuneRecommendationBundle(
        championId: championId,
        position: LeaguePosition.middle,
        mapId: 11,
        variants: [
          RuneRecommendationVariant(
            recommendationId: 'fixture-$championId',
            championId: championId,
            position: LeaguePosition.middle,
            perkIds: const [
              8005,
              9111,
              9104,
              8014,
              8139,
              8135,
              5005,
              5008,
              5002,
            ],
            primaryStyleId: 8000,
            secondaryStyleId: 8100,
            summonerSpellIds: const [4, 14],
            keystoneId: 8005,
            primaryAttribute: '',
            secondaryAttribute: '',
            isDefaultPosition: true,
            isOverride: false,
          ),
        ],
        fetchedAt: DateTime.utc(2026),
      ),
      items: ItemRecommendationBundle(
        championId: championId,
        championAlias: championId == 103 ? 'Ahri' : 'Garen',
        position: LeaguePosition.middle,
        patch: PatchKey('16.18'),
        mapId: 11,
        mode: 'CLASSIC',
        startingBundles: const [
          RecommendedItemBundle(
            items: [RecommendedItem(id: 1001, name: 'Synthetic boots')],
          ),
        ],
        purchaseRanges: const [],
        positionSpecific: true,
        fetchedAt: DateTime.utc(2026),
        sourceUri: Uri.parse('https://example.invalid/fixture'),
      ),
      jungle: null,
      directives: const [],
      threats: const [],
      voiceProcessing: false,
      voiceQuestion: '',
      voiceAdvice: null,
      voiceAnsweredAt: null,
    );
