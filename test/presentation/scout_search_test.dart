import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/application/local_scout_controller.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/account_context.dart';

void main() {
  testWidgets(
    'Scout search validates input, recovers from failure and refreshes a profile',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final account = LeagueAccountProfile(
        puuid: Puuid('synthetic-scout'),
        platformId: PlatformId('LA1'),
        firstSeenAt: DateTime.utc(2026),
        lastSeenAt: DateTime.utc(2026),
        riotId: const RiotId(gameName: 'Hide on bush', tagLine: 'KR1'),
      );
      var resolutions = 0;
      var historyReads = 0;
      Completer<LeagueAccountProfile>? response;
      final scout = LocalScoutController(
        loadMatches: (_, {limit = 20}) async {
          historyReads++;
          return [];
        },
        loadRanked: (_) async => null,
        resolveAccount: ({required gameName, required tagLine}) async {
          resolutions++;
          expect(gameName, 'Hide on bush');
          expect(tagLine, 'KR1');
          return response!.future;
        },
      );
      final container = ProviderContainer(
        overrides: [
          localScoutProvider.overrideWith((_) => scout),
          nativeLeagueProvider.overrideWith((_) => NativeLeagueController()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: godsenseTheme(),
            home: const Scaffold(body: ScoutPage()),
          ),
        ),
      );
      await tester.tap(find.text('Buscar'));
      await tester.pump();
      expect(
        resolutions,
        0,
        reason: 'Empty input must not reach the transport',
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '  Hide on bush  ');
      await tester.enterText(fields.at(1), ' #KR1 ');
      response = Completer<LeagueAccountProfile>();
      await tester.tap(find.text('Buscar'));
      await tester.pump();
      expect(scout.state.loading, true);
      expect(find.textContaining('Buscando invocador'), findsOneWidget);
      response.completeError(StateError('Synthetic offline'));
      await tester.pump();
      await tester.pump();
      expect(scout.state.loading, false);
      expect(
        find.textContaining('No pudimos actualizar este perfil'),
        findsOneWidget,
      );
      response = Completer<LeagueAccountProfile>();
      await tester.tap(find.text('Buscar'));
      await tester.pump();
      response.complete(account);
      await _settleScout(tester, scout);
      expect(resolutions, 2);
      expect(historyReads, 1);
      expect(scout.state.lastError, isNull);
      expect(find.text('Hide on bush#KR1'), findsOneWidget);
      expect(
        find.textContaining('No pudimos actualizar este perfil'),
        findsNothing,
      );
      await tester.tap(find.byTooltip('Actualizar historial local'));
      await _settleScout(tester, scout);
      expect(historyReads, 2);
      expect(find.text('Hide on bush#KR1'), findsOneWidget);
      await tester.tap(find.text('Mi Cuenta'));
      await tester.pump();
      expect(scout.state.lastError, contains('No hay cuenta conectada'));
      expect(find.text('Hide on bush#KR1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<void> _settleScout(
  WidgetTester tester,
  LocalScoutController scout,
) async {
  for (var attempt = 0; attempt < 250; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (!scout.state.loading && !scout.state.refreshing) return;
  }
  fail('Scout did not finish its background projection');
}
