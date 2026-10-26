import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  testWidgets(
    'Scout details recover from failure and reuse the hydrated cache',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugNetworkImageHttpClientProvider = _NoNetworkClient.new;
      addTearDown(() => debugNetworkImageHttpClientProvider = null);
      var response = Completer<LocalMatchRecord>();
      var calls = 0;
      var cached = _record(full: false);
      final scout = LocalScoutController(
        loadMatches: (_, {limit = 20}) async => [cached],
        loadRanked: (_) async => null,
        loadMatchDetails: (_) async {
          calls++;
          return cached = await response.future;
        },
        initialState: LocalScoutState(
          subjectAccount: LeagueAccountProfile(
            puuid: Puuid('synthetic-details'),
            platformId: PlatformId('LA1'),
            firstSeenAt: DateTime.utc(2026),
            lastSeenAt: DateTime.utc(2026),
            riotId: const RiotId(gameName: 'Hide on bush', tagLine: 'KR1'),
          ),
          typedMatches: const [
            ScoutMatchSummary(
              matchId: 17,
              queueId: 420,
              queueLabel: 'Ranked Solo/Duo',
              durationMinutes: 30,
              isWin: true,
              championId: 103,
              championName: 'Ahri',
              role: ScoutRole.mid,
              kills: 5,
              deaths: 1,
              assists: 9,
              kdaRatio: 14,
              cs: 220,
              csm: 7.3,
              items: [],
              hasFullDetails: false,
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localScoutProvider.overrideWith((_) => scout),
            nativeLeagueProvider.overrideWith((_) => NativeLeagueController()),
          ],
          child: MaterialApp(
            theme: godsenseTheme(),
            home: const Scaffold(body: ScoutPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Abrir detalle de partida'));
      await tester.tap(find.byTooltip('Abrir detalle de partida'));
      await tester.pump();
      expect(find.text('Cargando detalles de esta partida…'), findsOneWidget);
      expect(calls, 1);
      await tester.tap(find.byTooltip('Ocultar equipos'));
      await tester.pump();
      await tester.tap(find.byTooltip('Abrir detalle de partida'));
      await tester.pump();
      expect(
        calls,
        1,
        reason: 'Expanding again must not duplicate a pending request.',
      );
      response.completeError(StateError('League sintético no disponible'));
      await tester.pumpAndSettle();
      expect(find.text('League sintético no disponible'), findsOneWidget);
      expect(find.text('Reintentar detalles'), findsOneWidget);
      response = Completer<LocalMatchRecord>();
      await tester.tap(find.text('Reintentar detalles'));
      await tester.pump();
      expect(calls, 2);
      expect(find.text('Cargando detalles de esta partida…'), findsOneWidget);
      response.complete(_record(full: true));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar detalles'), findsNothing);
      expect(find.text('Cargando detalles de esta partida…'), findsNothing);
      expect(find.text('Fixture rival#TEST'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Ocultar equipos'));
      await tester.tap(find.byTooltip('Ocultar equipos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Abrir detalle de partida'));
      await tester.pumpAndSettle();
      expect(calls, 2, reason: 'Hydrated details should reopen from cache.');
      expect(find.text('Fixture rival#TEST'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      debugNetworkImageHttpClientProvider = null;
    },
  );
}

LocalMatchRecord _record({required bool full}) {
  final details = {
    'gameId': 17,
    'gameDuration': 1800,
    'participants': [
      for (final id in [1, 2])
        {
          'participantId': id,
          'teamId': id == 1 ? 100 : 200,
          'championId': id == 1 ? 103 : 99,
          'championName': id == 1 ? 'Ahri' : 'Lux',
          'stats': {
            'kills': 5,
            'deaths': 1,
            'assists': 9,
            'win': id == 1,
            'totalMinionsKilled': 220,
          },
        },
    ],
    'participantIdentities': [
      {
        'participantId': 1,
        'player': {
          'puuid': 'synthetic-details',
          'gameName': 'Hide on bush',
          'tagLine': 'KR1',
        },
      },
      {
        'participantId': 2,
        'player': {
          'puuid': 'synthetic-enemy',
          'gameName': 'Fixture rival',
          'tagLine': 'TEST',
        },
      },
    ],
  };
  return LocalMatchRecord(
    match: MatchKey(platformId: PlatformId('LA1'), gameId: 17),
    puuid: Puuid('synthetic-details'),
    summaryJson: jsonEncode(details),
    detailsJson: full ? jsonEncode(details) : null,
    timelineJson: full ? '{"frames":[]}' : null,
    syncedAt: DateTime.utc(2026),
  );
}

// Return a deterministic image error so the real image fallback is exercised,
// including in native Windows tests; no request leaves the test process.
class _NoNetworkClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _ImageRequest();
  @override
  set autoUncompress(bool value) {}
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageRequest implements HttpClientRequest {
  @override
  HttpHeaders get headers => _ImageHeaders();
  @override
  Future<HttpClientResponse> close() async => _ImageResponse();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 404;
  @override
  int get contentLength => 0;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => const Stream<List<int>>.empty().listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
