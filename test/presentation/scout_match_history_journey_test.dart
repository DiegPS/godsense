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
  for (final width in [1600.0, 1280.0, 800.0, 640.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Scout history pagination and teams at $width / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 2600);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        late _FixtureScout scout;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localScoutProvider.overrideWith(
                (_) => scout = _FixtureScout(
                  LocalScoutState(
                    subjectAccount: LeagueAccountProfile(
                      puuid: Puuid('synthetic-history'),
                      platformId: PlatformId('LA1'),
                      firstSeenAt: DateTime.utc(2026),
                      lastSeenAt: DateTime.utc(2026),
                      riotId: const RiotId(
                        gameName: 'Hide on bush',
                        tagLine: 'KR1',
                      ),
                    ),
                    typedMatches: List.generate(7, _match),
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
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Abrir detalle de partida'), findsNWidgets(3));
        await tester.ensureVisible(find.text('Mostrar 3 partidas más'));
        await tester.tap(find.text('Mostrar 3 partidas más'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Abrir detalle de partida'), findsNWidgets(6));
        await tester.ensureVisible(find.text('Mostrar 1 partida más'));
        await tester.tap(find.text('Mostrar 1 partida más'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Abrir detalle de partida'), findsNWidgets(7));
        await tester.ensureVisible(
          find.byTooltip('Abrir detalle de partida').first,
        );
        await tester.tap(find.byTooltip('Abrir detalle de partida').first);
        await tester.pumpAndSettle();
        expect(find.text('Fixture player 10#TEST'), findsOneWidget);
        expect(find.text('DESARROLLO DE LA PARTIDA'), findsOneWidget);
        expect(find.text('5:00 · Dragón aliado'), findsOneWidget);
        expect(find.text('20:01 · Barón rival'), findsOneWidget);
        expect(find.textContaining('Ward sintético'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byTooltip('Ocultar equipos'));
        await tester.tap(find.byTooltip('Ocultar equipos'));
        await tester.pumpAndSettle();
        expect(find.text('Fixture player 10#TEST'), findsNothing);
        expect(find.text('DESARROLLO DE LA PARTIDA'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Abrir detalle de partida').first);
        await tester.pumpAndSettle();
        scout.switchAccount();
        await tester.pumpAndSettle();
        expect(find.byTooltip('Abrir detalle de partida'), findsNWidgets(3));
        expect(find.byTooltip('Ocultar equipos'), findsNothing);
        expect(find.text('Fixture player 10#TEST'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

class _FixtureScout extends LocalScoutController {
  _FixtureScout(LocalScoutState initial)
    : super(
        loadMatches: (_, {limit = 20}) async => [],
        loadRanked: (_) async => null,
        initialState: initial,
      );

  void switchAccount() {
    state = LocalScoutState(
      subjectAccount: LeagueAccountProfile(
        puuid: Puuid('another-synthetic-history'),
        platformId: PlatformId('LA1'),
        firstSeenAt: DateTime.utc(2026),
        lastSeenAt: DateTime.utc(2026),
      ),
      typedMatches: state.typedMatches,
    );
  }
}

ScoutMatchSummary _match(int index) => ScoutMatchSummary(
  matchId: 100 + index,
  queueId: 420,
  queueLabel: 'Ranked Solo/Duo',
  durationMinutes: 35,
  isWin: index.isEven,
  championId: 103,
  championName: 'Ahri',
  championLevel: 18,
  role: ScoutRole.mid,
  kills: 15,
  deaths: 3,
  assists: 12,
  kdaRatio: 9,
  cs: 250,
  csm: 7.14,
  damage: 35000,
  killParticipation: 72,
  items: const [3020, 3089, 3135, 3157, 4645, 6655, 3363],
  performanceScore: ScoutPerformanceScore(
    value: index.isEven ? 85 : 45,
    version: 2,
    breakdown: const {},
  ),
  hasFullDetails: true,
  participants: List.generate(
    10,
    (i) => ScoutMatchParticipant(
      participantId: i + 1,
      puuid: 'fixture-$i',
      name: 'Fixture player ${i + 1}',
      tag: 'TEST',
      championId: 103,
      championName: 'Ahri',
      role: ScoutRole.mid,
      kills: 15,
      deaths: 3,
      assists: 12,
      cs: 250,
      damage: 35000,
      gold: 18000,
      visionScore: 40,
      items: const [],
      isSubject: i == 0,
      isAlly: i < 5,
    ),
  ),
  timelineEvents: const [
    ScoutTimelineEvent(
      timestampMilliseconds: 300000,
      type: 'ELITE_MONSTER_KILL',
      label: 'Dragón aliado',
      isAlly: true,
    ),
    ScoutTimelineEvent(
      timestampMilliseconds: 1201000,
      type: 'ELITE_MONSTER_KILL',
      label: 'Barón rival',
      isAlly: false,
    ),
    ScoutTimelineEvent(
      timestampMilliseconds: 10000,
      type: 'WARD_PLACED',
      label: 'Ward sintético',
    ),
  ],
  goldTimeline: const [
    ScoutGoldTimelinePoint(timestampMilliseconds: 0, difference: 0),
    ScoutGoldTimelinePoint(timestampMilliseconds: 300000, difference: 1500),
    ScoutGoldTimelinePoint(timestampMilliseconds: 600000, difference: 2200),
    ScoutGoldTimelinePoint(timestampMilliseconds: 900000, difference: -2000),
    ScoutGoldTimelinePoint(timestampMilliseconds: 1200000, difference: -1000),
  ],
);
