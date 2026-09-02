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
  testWidgets('explains the offline state when no account is available', (
    tester,
  ) async {
    await tester.pumpWidget(_scoutApp(const LocalScoutState()));

    expect(find.text('Scout'), findsOneWidget);
    expect(find.text('Conecta una cuenta de League'), findsOneWidget);
    expect(find.byTooltip('Actualizar historial local'), findsOneWidget);
    expect(find.text('Nombre de Riot'), findsOneWidget);
    expect(find.text('Buscar'), findsOneWidget);
  });

  testWidgets('renders cached rank and match data with modern esports card', (
    tester,
  ) async {
    const match = ScoutMatchSummary(
      matchId: 123,
      queueId: 420,
      queueLabel: 'Clasificatoria Solo/Dúo',
      durationMinutes: 28.5,
      isWin: true,
      championId: 22,
      championName: 'Ashe',
      role: ScoutRole.bottom,
      kills: 8,
      deaths: 2,
      assists: 11,
      kdaRatio: 9.5,
      cs: 230,
      csm: 8.1,
      damage: 26500,
      gold: 14200,
      visionScore: 28,
      killParticipation: 65.5,
      items: [3031, 3072, 3006, 0, 0, 0, 3340],
      hasFullDetails: true,
    );

    const analytics = ScoutProfileAnalytics(
      gamesCount: 1,
      winsCount: 1,
      lossesCount: 0,
      recentForm: [true],
      kpis: ScoutKpis(
        sampleSize: 1,
        wins: 1,
        losses: 0,
        recentWinRate: 100.0,
        avgKda: 9.5,
        avgDamage: 26500,
        killParticipation: 65.5,
        avgCsPerMin: 8.1,
      ),
      topChampions: [
        ScoutChampionStats(
          championId: 22,
          name: 'Ashe',
          games: 1,
          wins: 1,
          losses: 0,
          winrate: 100.0,
          kda: 9.5,
        ),
      ],
      roleDistribution: [
        ScoutRoleStats(
          role: ScoutRole.bottom,
          games: 1,
          percentage: 100.0,
          winrate: 100.0,
          wins: 1,
          losses: 0,
        ),
      ],
      recentTeammates: [],
      recentOpponents: [],
      badges: [],
      gpi: [],
    );

    final subjectAccount = LeagueAccountProfile(
      puuid: Puuid('player'),
      platformId: PlatformId('LA1'),
      firstSeenAt: DateTime.utc(2026),
      lastSeenAt: DateTime.utc(2026),
      riotId: const RiotId(gameName: 'Diego', tagLine: 'LAN'),
      summonerId: 1,
    );

    await tester.pumpWidget(
      _scoutApp(
        LocalScoutState(
          subjectAccount: subjectAccount,
          analytics: analytics,
          typedMatches: const [match],
          profile: const {
            'game_name': 'Diego',
            'tag_line': 'LAN',
            'rank': {'tier': 'GOLD', 'division': 'II', 'lp': 64, 'winrate': 60},
          },
        ),
      ),
    );

    expect(find.text('Diego#LAN'), findsOneWidget);
    expect(find.textContaining('GOLD II'), findsOneWidget);
    expect(find.text('VICTORIA'), findsOneWidget);
    expect(find.text('Resumen de Rendimiento'), findsOneWidget);
    expect(find.text('RECENT WIN RATE'), findsOneWidget);
  });

  testWidgets('toggles expanded match details', (tester) async {
    const match = ScoutMatchSummary(
      matchId: 999,
      queueId: 420,
      queueLabel: 'Clasificatoria Solo/Dúo',
      durationMinutes: 25.0,
      isWin: true,
      championId: 22,
      championName: 'Ashe',
      role: ScoutRole.bottom,
      kills: 5,
      deaths: 1,
      assists: 7,
      kdaRatio: 12.0,
      cs: 200,
      csm: 8.0,
      items: [0, 0, 0, 0, 0, 0, 0],
      hasFullDetails: true,
      participants: [
        ScoutMatchParticipant(
          participantId: 1,
          puuid: 'player',
          name: 'Diego',
          tag: 'LAN',
          championId: 22,
          championName: 'Ashe',
          role: ScoutRole.bottom,
          kills: 5,
          deaths: 1,
          assists: 7,
          cs: 200,
          damage: 20000,
          gold: 11000,
          visionScore: 20,
          items: [0, 0, 0, 0, 0, 0, 0],
          isSubject: true,
          isAlly: true,
        ),
      ],
    );

    await tester.pumpWidget(
      _scoutApp(
        LocalScoutState(
          subjectAccount: LeagueAccountProfile(
            puuid: Puuid('player'),
            platformId: PlatformId('LA1'),
            firstSeenAt: DateTime.utc(2026),
            lastSeenAt: DateTime.utc(2026),
            riotId: const RiotId(gameName: 'Diego', tagLine: 'LAN'),
            summonerId: 1,
          ),
          typedMatches: const [match],
        ),
      ),
    );

    // Initial state: collapsed
    expect(find.text('Tu Equipo · VICTORIA'), findsNothing);

    // Tap to expand
    await tester.tap(find.text('VICTORIA'));
    await tester.pumpAndSettle();

    expect(find.text('Tu Equipo · VICTORIA'), findsOneWidget);
  });

  testWidgets('renders properly across wide (1280) and compact (800) widths', (
    tester,
  ) async {
    final state = LocalScoutState(
      subjectAccount: LeagueAccountProfile(
        puuid: Puuid('player'),
        platformId: PlatformId('LA1'),
        firstSeenAt: DateTime.utc(2026),
        lastSeenAt: DateTime.utc(2026),
        riotId: const RiotId(gameName: 'Diego', tagLine: 'LAN'),
        summonerId: 1,
      ),
      analytics: const ScoutProfileAnalytics(
        gamesCount: 2,
        winsCount: 2,
        lossesCount: 0,
        recentForm: [true, true],
        kpis: ScoutKpis(
          sampleSize: 2,
          wins: 2,
          losses: 0,
          recentWinRate: 100.0,
          avgKda: 10.0,
        ),
        topChampions: [],
        roleDistribution: [],
        recentTeammates: [],
        recentOpponents: [],
        badges: [],
        gpi: [],
      ),
    );

    // 1. Wide view (1280x800)
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_scoutApp(state));
    await tester.pumpAndSettle();
    expect(find.text('Scout'), findsOneWidget);
    expect(find.text('Diego#LAN'), findsOneWidget);

    // 2. Compact view (800x600)
    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpWidget(_scoutApp(state));
    await tester.pumpAndSettle();
    expect(find.text('Scout'), findsOneWidget);
    expect(find.text('Diego#LAN'), findsOneWidget);
  });
}

Widget _scoutApp(LocalScoutState state) {
  return ProviderScope(
    overrides: [
      localScoutProvider.overrideWith(
        (_) => LocalScoutController(
          loadMatches: (_, {limit = 20}) async => const [],
          loadRanked: (_) async => null,
          initialState: state,
        ),
      ),
      nativeLeagueProvider.overrideWith((_) => NativeLeagueController()),
    ],
    child: const MaterialApp(home: Scaffold(body: ScoutPage())),
  );
}
