import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/application/local_scout_controller.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/account_context.dart';
import 'package:godsense/domain/league/local_scout.dart';

void main() {
  testWidgets('expanded card shows loading, retry and arriving participants', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final response = Completer<LocalMatchRecord>();
    var calls = 0;
    final account = LeagueAccountProfile(
      puuid: Puuid('player'),
      platformId: PlatformId('LA1'),
      firstSeenAt: DateTime.utc(2026),
      lastSeenAt: DateTime.utc(2026),
    );
    final payload = jsonEncode({
      'gameDuration': 1800,
      'participantIdentities': [
        {
          'participantId': 1,
          'player': {
            'puuid': 'player',
            'gameName': 'Nombre recibido',
            'tagLine': 'LAN',
          },
        },
      ],
      'participants': [
        {
          'participantId': 1,
          'teamId': 100,
          'championId': 22,
          'stats': {'kills': 5, 'win': true},
        },
      ],
    });
    final record = LocalMatchRecord(
      match: MatchKey(platformId: PlatformId('LA1'), gameId: 10),
      puuid: account.puuid,
      summaryJson: payload,
      syncedAt: DateTime.utc(2026),
    );
    final controller = LocalScoutController(
      loadMatches: (_, {limit = 20}) async => [record],
      loadRanked: (_) async => null,
      loadMatchDetails: (_) {
        if (++calls == 1) {
          return Future.error(StateError('League no disponible'));
        }
        return response.future;
      },
    );
    await controller.loadAccount(account);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localScoutProvider.overrideWith((ref) => controller),
          nativeLeagueProvider.overrideWith((ref) => NativeLeagueController()),
        ],
        child: MaterialApp(
          theme: godsenseTheme(),
          home: const Scaffold(body: ScoutPage()),
        ),
      ),
    );
    await tester.ensureVisible(find.byTooltip('Abrir detalle de partida'));
    await tester.tap(find.byTooltip('Abrir detalle de partida'));
    await tester.pumpAndSettle();
    expect(find.text('League no disponible'), findsOneWidget);
    await tester.tap(find.text('Reintentar detalles'));
    await tester.pump();
    expect(find.text('Cargando detalles de esta partida…'), findsOneWidget);
    response.complete(
      LocalMatchRecord(
        match: record.match,
        puuid: record.puuid,
        summaryJson: record.summaryJson,
        detailsJson: payload,
        syncedAt: record.syncedAt,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cargando detalles de esta partida…'), findsNothing);
    expect(find.text('Reintentar detalles'), findsNothing);
    expect(find.text('Nombre recibido#LAN'), findsOneWidget);
    expect(controller.state.typedMatches.single.hasFullDetails, isTrue);
    expect(tester.takeException(), isNull);
  });
}
