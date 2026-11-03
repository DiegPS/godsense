import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/application/local_scout_controller.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/account_context.dart';
import 'package:godsense/presentation/scout/scout_profile_selector.dart';

void main() {
  for (final width in [360.0, 1200.0]) {
    testWidgets('saved profiles can be chosen without League at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final profiles = [
        for (final region in ['LA1', 'NA1'])
          LeagueAccountProfile(
            puuid: Puuid('player-$region'),
            platformId: PlatformId(region),
            riotId: const RiotId(gameName: 'Pedro', tagLine: 'TAG'),
            firstSeenAt: DateTime.utc(2026),
            lastSeenAt: DateTime.utc(2026),
          ),
      ];
      final scout = LocalScoutController(
        loadMatches: (_, {limit = 20}) async => [],
        loadRanked: (_) async => null,
      );
      final container = ProviderContainer(
        overrides: [
          localScoutProvider.overrideWith((_) => scout),
          savedScoutAccountsProvider.overrideWith((_) async => profiles),
          nativeLeagueProvider.overrideWith((_) => NativeLeagueController()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: godsenseTheme(),
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: ScoutProfileSelector(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byType(DropdownButtonFormField<({String puuid, String platform})>),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pedro#TAG · LA1'), findsOneWidget);
      expect(find.text('Pedro#TAG · NA1'), findsOneWidget);
      await tester.tap(find.text('Pedro#TAG · NA1'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 100 && scout.state.loading; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(scout.state.subjectAccount?.platformId.value, 'NA1');
      expect(scout.followsConnectedAccount, false);
      expect(find.textContaining('permanece seleccionado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byType(DropdownButtonFormField<({String puuid, String platform})>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seguir la cuenta de League').last);
      await tester.pumpAndSettle();
      expect(scout.followsConnectedAccount, true);
      expect(scout.state.subjectAccount, isNull);
      expect(scout.state.lastError, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'profile catalog errors provide a retry rather than an empty-success state',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localScoutProvider.overrideWith(
              (_) => LocalScoutController(
                loadMatches: (_, {limit = 20}) async => [],
                loadRanked: (_) async => null,
              ),
            ),
            savedScoutAccountsProvider.overrideWith((_) async {
              if (++attempts == 1) throw StateError('disk read');
              return [];
            }),
            nativeLeagueProvider.overrideWith((_) => NativeLeagueController()),
          ],
          child: MaterialApp(
            theme: godsenseTheme(),
            home: const Scaffold(body: ScoutProfileSelector()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('No se pudieron leer'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.textContaining('No se pudieron leer'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
