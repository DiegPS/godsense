import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/application/local_scout_controller.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/account_context.dart';
import 'package:godsense/domain/league/local_scout.dart';

void main() {
  for (final close in [false, true]) {
    test(
      'late optional timeline failure cannot apply old details after ${close ? 'dispose' : 'account change'}',
      () async {
        final gate = Completer<LocalMatchRecord>();
        final started = Completer<void>();
        final controller = LocalScoutController(
          loadMatches: (puuid, {limit = 20}) async => [_match(puuid)],
          loadRanked: (_) async => null,
          loadMatchDetails: (record) {
            started.complete();
            return gate.future;
          },
        );
        var disposed = false;
        addTearDown(() {
          if (!disposed) controller.dispose();
        });
        await controller.loadAccount(_account('first'));
        final selecting = controller.selectMatch(123);
        await started.future;
        if (close) {
          disposed = true;
          controller.dispose();
        } else {
          await controller.loadAccount(_account('second'));
        }
        gate.completeError(StateError('Synthetic unavailable timeline'));
        await selecting;
        if (!close) {
          expect(controller.state.subjectAccount!.puuid.value, 'second');
          expect(controller.state.typedSelectedMatch, isNull);
          expect(controller.state.loadingMatchIds, isEmpty);
          expect(controller.state.matchDetailErrors, isEmpty);
        }
      },
    );

    test(
      'pending ranked lookup cannot chain old match reads after ${close ? 'dispose' : 'account change'}',
      () async {
        final gate = Completer<LocalRankedSnapshot?>();
        final started = Completer<void>();
        final reads = <String>[];
        final controller = LocalScoutController(
          loadMatches: (puuid, {limit = 20}) async {
            reads.add(puuid.value);
            return [];
          },
          loadRanked: (puuid) async {
            if (puuid.value == 'first') {
              if (!started.isCompleted) started.complete();
              return await gate.future;
            }
            return null;
          },
        );
        var disposed = false;
        addTearDown(() {
          if (!disposed) controller.dispose();
        });
        final loading = controller.loadAccount(_account('first'));
        await started.future;
        if (close) {
          disposed = true;
          controller.dispose();
        } else {
          await controller.loadAccount(_account('second'));
        }
        gate.complete(null);
        await loading;
        expect(reads, isNot(contains('first')));
      },
    );
  }

  test(
    'an obsolete ranked refresh after synchronization cannot read old matches',
    () async {
      final pending = Completer<LocalRankedSnapshot?>();
      final started = Completer<void>();
      final reads = <String>[];
      var firstRanks = 0;
      final controller = LocalScoutController(
        loadMatches: (puuid, {limit = 20}) async {
          reads.add(puuid.value);
          return [];
        },
        loadRanked: (puuid) async {
          if (puuid.value == 'first' && ++firstRanks == 2) {
            started.complete();
            return await pending.future;
          }
          return null;
        },
        synchronizeAccount: (account, {onProgress}) async =>
            const LocalScoutSyncResult(
              matchesSeen: 0,
              matchesStored: 0,
              detailsStored: 0,
              timelinesStored: 0,
              rankedStored: false,
            ),
      );
      addTearDown(controller.dispose);
      final previous = controller.loadAccount(_account('first'));
      await started.future;
      await controller.loadAccount(_account('second'));
      pending.complete(null);
      await previous;
      expect(reads.where((id) => id == 'first'), hasLength(1));
      expect(controller.state.subjectAccount!.puuid.value, 'second');
    },
  );

  test(
    'current optional timeline failure still allows the cached scoreboard',
    () async {
      final controller = LocalScoutController(
        loadMatches: (puuid, {limit = 20}) async => [_match(puuid)],
        loadRanked: (_) async => null,
        loadMatchDetails: (_) async =>
            throw StateError('Synthetic unavailable timeline'),
      );
      addTearDown(controller.dispose);
      await controller.loadAccount(_account('first'));
      await controller.selectMatch(123);
      expect(controller.state.typedSelectedMatch?.matchId, 123);
      expect(controller.state.matchDetailErrors, isEmpty);
    },
  );
}

LeagueAccountProfile _account(String id) => LeagueAccountProfile(
  puuid: Puuid(id),
  platformId: PlatformId('LA1'),
  firstSeenAt: DateTime.utc(2026),
  lastSeenAt: DateTime.utc(2026),
);

LocalMatchRecord _match(Puuid puuid) {
  final payload = jsonEncode({
    'gameDuration': 1800,
    'participantIdentities': [
      {
        'participantId': 1,
        'player': {'puuid': puuid.value},
      },
    ],
    'participants': [
      {
        'participantId': 1,
        'championId': 22,
        'teamId': 100,
        'stats': {'kills': 1, 'deaths': 1, 'assists': 2, 'win': true},
        'timeline': {'lane': 'BOTTOM', 'role': 'DUO_CARRY'},
      },
    ],
    'teams': [
      {'teamId': 100, 'win': 'Win'},
    ],
  });
  return LocalMatchRecord(
    match: MatchKey(platformId: PlatformId('LA1'), gameId: 123),
    puuid: puuid,
    summaryJson: payload,
    detailsJson: payload,
    syncedAt: DateTime.utc(2026),
  );
}
