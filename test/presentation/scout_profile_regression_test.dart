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
  for (final width in [1280.0, 800.0]) {
    testWidgets(
      'populated Scout profile retains allies, opponents and metrics at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final account = LeagueAccountProfile(
          puuid: Puuid('synthetic-profile'),
          platformId: PlatformId('LA1'),
          firstSeenAt: DateTime.utc(2026),
          lastSeenAt: DateTime.utc(2026),
          riotId: const RiotId(gameName: 'Hide on bush', tagLine: 'KR1'),
        );
        const analytics = ScoutProfileAnalytics(
          gamesCount: 4,
          winsCount: 3,
          lossesCount: 1,
          recentForm: [true, false, true, true],
          kpis: ScoutKpis(
            sampleSize: 4,
            wins: 3,
            losses: 1,
            recentWinRate: 75,
            avgKda: 4.5,
            avgDamage: 25000,
            killParticipation: 64,
            avgObjectiveDamage: 12000,
            avgGoldPerMin: 420,
            avgCsPerMin: 7.4,
            avgVisionPerMin: 1.3,
            damagePerMinute: 850,
            objectiveDamagePerMinute: 400,
            damageShare: 32.1,
            goldShare: 28.4,
            damageEfficiency: 1.13,
          ),
          topChampions: [
            ScoutChampionStats(
              championId: 103,
              name: 'Ahri',
              games: 4,
              wins: 3,
              losses: 1,
              winrate: 75,
              kda: 4.5,
            ),
          ],
          roleDistribution: [
            ScoutRoleStats(
              role: ScoutRole.mid,
              games: 4,
              percentage: 100,
              winrate: 75,
              wins: 3,
              losses: 1,
            ),
          ],
          recentTeammates: [
            ScoutRelationshipStats(
              summonerName: 'Synthetic Ally',
              tagLine: 'LAN',
              puuid: 'ally',
              games: 3,
              wins: 2,
              losses: 1,
              winrate: 67,
            ),
          ],
          recentOpponents: [
            ScoutRelationshipStats(
              summonerName: 'Synthetic Opponent',
              tagLine: 'LAN',
              puuid: 'opponent',
              games: 2,
              wins: 0,
              losses: 2,
              winrate: 0,
            ),
          ],
          badges: [],
          gpi: [],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localScoutProvider.overrideWith(
                (_) => LocalScoutController(
                  loadMatches: (_, {limit = 20}) async => [],
                  loadRanked: (_) async => null,
                  initialState: LocalScoutState(
                    subjectAccount: account,
                    analytics: analytics,
                  ),
                ),
              ),
              nativeLeagueProvider.overrideWith(
                (_) => NativeLeagueController(),
              ),
            ],
            child: MaterialApp(
              theme: godsenseTheme(),
              home: const Scaffold(body: ScoutPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Hide on bush#KR1'), findsOneWidget);
        expect(find.text('Synthetic Ally'), findsOneWidget);
        expect(find.text('Synthetic Opponent'), findsOneWidget);
        expect(find.text('32.1%'), findsOneWidget);
        expect(find.text('28.4%'), findsOneWidget);
        expect(find.text('1.13'), findsOneWidget);
        expect(find.text('0% WR'), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        expect(find.text('Synthetic Ally'), findsOneWidget);
        expect(find.text('Synthetic Opponent'), findsOneWidget);
        expect(find.text('32.1%'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
