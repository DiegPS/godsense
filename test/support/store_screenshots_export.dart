// Artifact renderer: flutter test test/support/store_screenshots_export.dart
// Uses production widgets, in-memory preferences and synthetic demo data only.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dart_ai_runtime/dart_ai_runtime.dart' as runtime;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/app/godsense_app.dart';
import 'package:godsense/application/coach_controller.dart';
import 'package:godsense/application/companion_controller.dart';
import 'package:godsense/application/dependencies.dart';
import 'package:godsense/application/local_scout_controller.dart';
import 'package:godsense/application/native_league_controller.dart';
import 'package:godsense/application/native_calibration_controller.dart';
import 'package:godsense/application/native_vision_controller.dart';
import 'package:godsense/application/native_speech_controller.dart';
import 'package:godsense/domain/companion_gateway.dart';
import 'package:godsense/domain/companion_models.dart';
import 'package:godsense/domain/identity/league_identity.dart';
import 'package:godsense/domain/league/account_context.dart';
import 'package:godsense/domain/league/game_session.dart';
import 'package:godsense/domain/native_speech_settings.dart';
import 'package:godsense/domain/tactical/tactical_models.dart';
import 'package:godsense/infrastructure/speech/shared_preferences_speech_settings_repository.dart';
import 'package:godsense/infrastructure/native_vision/shared_preferences_calibration_repository.dart';
import 'package:godsense/infrastructure/native_vision/dartcv_minimap_tracker.dart';
import 'package:godsense/presentation/coach/coach_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _output = 'design/store/screenshots';
const _boundary = Key('store-capture');
const _now = '2026-10-25T12:00:00Z';
const _art = 'https://ddragon.leagueoflegends.com/cdn/16.21.1/img/champion';

void main() {
  testWidgets('export private-data-free Store screenshots', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('InterVariable')
      ..addFont(rootBundle.load('assets/fonts/inter/InterVariable.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await font.load();
    await icons.load();
    final temporary = await tester.runAsync(
      () => Directory.systemTemp.createTemp('godsense-store-demo-'),
    );
    final pictures = <String, List<int>>{};
    for (final file in Directory(
      'build/store-art-assets',
    ).listSync().whereType<File>()) {
      if (file.path.endsWith('.png')) {
        pictures[file.uri.pathSegments.last] = file.readAsBytesSync();
      }
    }
    for (final entry in {
      103: 'Ahri',
      268: 'Azir',
      61: 'Orianna',
      22: 'Ashe',
      64: 'LeeSin',
      86: 'Garen',
      222: 'Jinx',
      89: 'Leona',
      412: 'Thresh',
      127: 'Lissandra',
      122: 'Darius',
      254: 'Vi',
      11: 'MasterYi',
      238: 'Zed',
      157: 'Yasuo',
      55: 'Katarina',
    }.entries) {
      pictures['${entry.key}.png'] = pictures['${entry.value}.png']!;
    }
    final previousHttp = HttpOverrides.current;
    HttpOverrides.global = _OfflineImages(pictures);
    addTearDown(() => HttpOverrides.global = previousHttp);
    debugNetworkImageHttpClientProvider = () => _ImageClient(pictures);
    addTearDown(() => debugNetworkImageHttpClientProvider = null);
    Directory(_output).createSync(recursive: true);
    debugPrint('STORE_ART fonts and offline fixtures ready');

    Future<void> capture(
      String name,
      int page,
      Widget child,
      CoachInputs inputs, {
      double scroll = 0,
    }) async {
      final coach = CoachController(
        importRunes: (_) async {},
        importItems: () async {},
      );
      coach.synchronize(inputs);
      if (inputs.lobby != null) coach.selectEnemy('Lissandra');
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(name),
          overrides: [
            localScoutProvider.overrideWith(
              (_) => LocalScoutController(
                loadMatches: (_, {limit = 20}) async => const [],
                loadRanked: (_) async => null,
                initialState: _scout(),
              ),
            ),
            nativeLeagueProvider.overrideWith((_) => NativeLeagueController()),
            nativeCalibrationProvider.overrideWith((_) => _DemoCalibration()),
            nativeVisionProvider.overrideWith((_) => _DemoVision()),
            nativeSpeechProvider.overrideWith((_) => _DemoSpeech()),
            companionControllerProvider.overrideWith(
              (_) => CompanionController(_UnusedGateway()),
            ),
            coachControllerProvider.overrideWith((_) => coach),
            aiRuntimeBootstrapProvider.overrideWith((_) async {}),
            aiRuntimeStorageProvider.overrideWithValue(
              runtime.AiRuntimeStorage(
                sharedStoreRoot: Directory('${temporary!.path}/shared'),
                applicationDataRoot: Directory('${temporary.path}/private'),
                applicationId: 'store-demo',
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: godsenseTheme(),
            home: RepaintBoundary(
              key: _boundary,
              child: Scaffold(
                body: Column(
                  children: [
                    GodSenseTitleBar(
                      selectedPage: page,
                      onSelectPage: (_) {},
                      overlayEditing: false,
                      onToggleEditing: () {},
                      onResetPanels: null,
                      onHelp: () {},
                      sessionLabel: 'Demostración',
                      isOnline: false,
                    ),
                    Container(
                      width: double.infinity,
                      color: const Color(0xff142437),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      child: const Text(
                        'DATOS DE DEMOSTRACIÓN · Perfil y estadísticas ficticios · Sin vinculación con jugadores reales',
                        style: TextStyle(
                          color: Color(0xffb8d2e8),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      debugPrint('STORE_ART mounted $name');
      await tester.pumpAndSettle();
      // Decode fixture image bytes outside the fake test clock, then paint.
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      if (scroll > 0) {
        await tester.drag(find.byType(Scrollable).first, Offset(0, -scroll));
        await tester.pumpAndSettle();
        final export = find.text('Exportar mis datos');
        expect(export, findsOneWidget);
        expect(tester.getRect(export).bottom, lessThan(1000));
      }
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_boundary),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$_output/$name.png')
              .writeAsBytes(data!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }

    await capture('01-scout', 4, const ScoutPage(), _inputs());
    await capture('02-draft', 3, const CoachPage(), _inputs(draft: true));
    await capture(
      '03-coach-en-partida',
      3,
      const CoachPage(),
      _inputs(live: true),
    );
    await capture('04-voz-y-privacidad', 5, const SettingsPage(), _inputs());
    await capture(
      '05-datos-locales',
      5,
      const SettingsPage(),
      _inputs(),
      scroll: 1600,
    );
    await capture('06-mapa', 2, const VisionPage(), _inputs());
    await tester.runAsync(() async {
      final allowedPrefix =
          '${Directory.systemTemp.resolveSymbolicLinksSync()}${Platform.pathSeparator}godsense-store-demo-';
      if (!temporary!.resolveSymbolicLinksSync().startsWith(allowedPrefix)) {
        throw StateError(
          'Refusing to clean an unexpected screenshot runtime directory.',
        );
      }
      await temporary.delete(recursive: true);
    });
    debugNetworkImageHttpClientProvider = null;
  });
}

LocalScoutState _scout() => LocalScoutState(
  subjectAccount: LeagueAccountProfile(
    puuid: Puuid('demo-profile-not-a-real-account'),
    platformId: PlatformId('LA1'),
    firstSeenAt: DateTime.parse(_now),
    lastSeenAt: DateTime.parse(_now),
    riotId: const RiotId(gameName: 'Hide on bush', tagLine: 'DEMO'),
    summonerId: 0,
  ),
  profile: const {
    'game_name': 'Hide on bush',
    'tag_line': 'DEMO',
    'icon_url': '$_art/Ahri.png',
    'rank': {'tier': 'PLATINUM', 'division': 'II', 'lp': 64, 'winrate': 60},
  },
  typedMatches: [
    for (final game in [
      (103, 'Ahri', true, 8, 2, 11),
      (268, 'Azir', false, 5, 4, 7),
      (61, 'Orianna', true, 6, 1, 14),
    ])
      ScoutMatchSummary(
        matchId: game.$1,
        queueId: 420,
        queueLabel: 'Clasificatoria Solo/Dúo',
        startedAt: DateTime.parse(_now),
        durationMinutes: 28.5,
        isWin: game.$3,
        championId: game.$1,
        championName: game.$2,
        championIconUrl: '$_art/${game.$2}.png',
        role: ScoutRole.mid,
        kills: game.$4,
        deaths: game.$5,
        assists: game.$6,
        kdaRatio: (game.$4 + game.$6) / game.$5,
        cs: 230,
        csm: 8.1,
        damage: 26500,
        gold: 14200,
        visionScore: 28,
        killParticipation: 65.5,
        items: const [6655, 3020, 3089, 0, 0, 0, 3340],
        hasFullDetails: true,
      ),
  ],
  analytics: const ScoutProfileAnalytics(
    gamesCount: 20,
    winsCount: 12,
    lossesCount: 8,
    recentForm: [true, false, true, true, true, false, true, false, true, true],
    kpis: ScoutKpis(
      sampleSize: 20,
      wins: 12,
      losses: 8,
      recentWinRate: 60,
      avgKda: 4.3,
      avgDamage: 26500,
      killParticipation: 65.5,
      avgCsPerMin: 8.1,
      avgGoldPerMin: 480,
      avgVisionPerMin: .9,
      damagePerMinute: 930,
      objectiveDamagePerMinute: 240,
      damageShare: 28,
      goldShare: 24,
      damageEfficiency: 1.8,
    ),
    topChampions: [
      ScoutChampionStats(
        championId: 103,
        name: 'Ahri',
        iconUrl: '$_art/Ahri.png',
        games: 10,
        wins: 7,
        losses: 3,
        winrate: 70,
        kda: 4.8,
      ),
      ScoutChampionStats(
        championId: 268,
        name: 'Azir',
        iconUrl: '$_art/Azir.png',
        games: 6,
        wins: 3,
        losses: 3,
        winrate: 50,
        kda: 3.9,
      ),
      ScoutChampionStats(
        championId: 61,
        name: 'Orianna',
        iconUrl: '$_art/Orianna.png',
        games: 4,
        wins: 2,
        losses: 2,
        winrate: 50,
        kda: 4.2,
      ),
    ],
    roleDistribution: [
      ScoutRoleStats(
        role: ScoutRole.mid,
        games: 16,
        percentage: 80,
        winrate: 62.5,
        wins: 10,
        losses: 6,
      ),
      ScoutRoleStats(
        role: ScoutRole.bottom,
        games: 4,
        percentage: 20,
        winrate: 50,
        wins: 2,
        losses: 2,
      ),
    ],
    recentTeammates: [],
    recentOpponents: [],
    badges: [],
    gpi: [],
  ),
);

CoachInputs _inputs({bool draft = false, bool live = false}) => CoachInputs(
  gameflowPhase: draft
      ? 'IN_SELECT'
      : live
      ? 'InProgress'
      : 'None',
  session: const GameSessionState(),
  liveGame: live
      ? {
          'team_gold_diff': 1250,
          'gold_points': [
            {'game_time': 300, 'value': 100},
            {'game_time': 600, 'value': 450},
            {'game_time': 900, 'value': 200},
            {'game_time': 1200, 'value': 1250},
          ],
        }
      : null,
  lobby: draft
      ? LobbyState.fromJson({
          'phase': 'IN_SELECT',
          'snapshot': {
            'my_team': [
              for (final c in [
                (86, 'Garen', 'TOP'),
                (64, 'Lee Sin', 'JUNGLE'),
                (103, 'Ahri', 'MIDDLE'),
                (22, 'Ashe', 'BOTTOM'),
                (89, 'Leona', 'UTILITY'),
              ])
                {
                  'cell_id': c.$1,
                  'champion_id': c.$1,
                  'champion_name': c.$2,
                  'position': c.$3,
                  'selection_state': 'locked',
                  'locked': true,
                  'champion_profile': _composition(c.$3),
                  'is_local': c.$1 == 103,
                },
            ],
            'their_team': [
              for (final c in [
                (122, 'Darius', 'TOP'),
                (254, 'Vi', 'JUNGLE'),
                (127, 'Lissandra', 'MIDDLE'),
                (222, 'Jinx', 'BOTTOM'),
                (412, 'Thresh', 'UTILITY'),
              ])
                {
                  'cell_id': c.$1,
                  'champion_id': c.$1,
                  'champion_name': c.$2,
                  'position': c.$3,
                  'selection_state': 'locked',
                  'locked': true,
                  'champion_profile': _composition(c.$3),
                },
            ],
            'bans': {
              'my_team_bans': [11, 238],
              'their_team_bans': [157, 55],
            },
          },
        })
      : null,
  runes: null,
  items: null,
  jungle: null,
  directives: live
      ? [
          _advice,
          TacticalAdvice(
            id: 'demo-wave',
            title: 'Prepara la oleada central',
            hints: const ['Ventana de rotación'],
            rationale: 'Empuja con tu equipo antes de moverte al río.',
            ttsText: 'Prepara la oleada central.',
            priority: 2,
            evidence: const [],
          ),
        ]
      : const [],
  threats: live
      ? [
          CoachThreatViewData(
            isGank: true,
            champion: 'Vi',
            location: 'RÍO INFERIOR',
            region: 'bottom_river',
            observedAt: DateTime.now().add(const Duration(minutes: 10)),
            confidence: .92,
          ),
        ]
      : const [],
  voiceProcessing: false,
  voiceQuestion: live ? '¿Qué preparo antes del dragón?' : '',
  voiceAdvice: live ? _advice : null,
  voiceAnsweredAt: live ? DateTime.parse(_now) : null,
);

final _advice = TacticalAdvice(
  id: 'demo-vision',
  title: 'Prepara visión alrededor del dragón',
  hints: const ['Juega con tu equipo', 'Revisa el río inferior'],
  rationale: 'Aprovecha la prioridad central para preparar una entrada segura al objetivo.',
  ttsText: 'Prepara visión con tu equipo antes del dragón.',
  priority: 1,
  evidence: const [],
);

Map<String, dynamic> _composition(String role) => {
  'classes': [
    switch (role) {
      'MIDDLE' => 'Mage',
      'BOTTOM' => 'Marksman',
      'UTILITY' => 'Tank',
      _ => 'Fighter',
    },
  ],
  'tactical': {
    'damageType': role == 'MIDDLE' || role == 'UTILITY' ? 'magic' : 'physical',
  },
  'playstyle': {
    'damage': role == 'UTILITY' ? 1 : 3,
    'durability': role == 'TOP' || role == 'UTILITY' ? 3 : 1,
    'crowdControl': role == 'UTILITY' ? 3 : 2,
    'mobility': role == 'JUNGLE' || role == 'MIDDLE' ? 3 : 1,
    'utility': role == 'UTILITY' ? 3 : 2,
  },
};

class _DemoCalibration extends NativeCalibrationController {
  _DemoCalibration()
    : super(
        SharedPreferencesCalibrationRepository(contextReader: () async => {}),
      ) {
    state = const NativeCalibrationState(
      loading: false,
      calibration: CalibrationState(
        calibrated: true,
        recalibrationSuggested: false,
        bounds: {
          'left': 1408,
          'top': 568,
          'width': 512,
          'height': 512,
          'monitor': 0,
        },
      ),
    );
  }
  @override
  Future<void> refreshContext() async {}
}

class _DemoVision extends NativeVisionController {
  _DemoVision() {
    final png = File('build/store-art-assets/map11.png').readAsBytesSync();
    final now = DateTime.parse(_now);
    state = NativeVisionState(
      running: true,
      frame: NativeVisionFrame(
        capturedAt: now,
        processedAt: now,
        capturePng: png,
        maskPng: png,
        annotatedPng: png,
        detections: const [],
        stageMicroseconds: const {},
        previewMicroseconds: 0,
      ),
    );
  }
}

class _DemoSpeech extends NativeSpeechController {
  _DemoSpeech()
    : super(repository: SharedPreferencesSpeechSettingsRepository()) {
    state = const NativeSpeechState(
      loading: false,
      settings: NativeSpeechSettings(pushToTalkEnabled: true, ttsEnabled: true),
      modelsChecked: true,
      speechModelInstalled: true,
      ttsModelInstalled: true,
    );
  }
}

class _UnusedGateway implements CompanionGateway {
  @override
  Future<void> closeAlerts() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Screenshot attempted a live backend call: ${invocation.memberName}',
  );
}

// All HTTP requests are fulfilled from downloaded public art. No sockets,
// cookies, tokens, personal cache or real provider connections are available.
class _OfflineImages extends HttpOverrides {
  _OfflineImages(this.pictures);
  final Map<String, List<int>> pictures;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _ImageClient(pictures);
}

class _ImageClient implements HttpClient {
  _ImageClient(this.pictures);
  final Map<String, List<int>> pictures;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _ImageRequest(pictures[url.pathSegments.last]);
  @override
  set autoUncompress(bool value) {}
  @override
  set badCertificateCallback(
    bool Function(X509Certificate, String, int)? value,
  ) {}
  @override
  set connectionTimeout(Duration? value) {}
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unsupported offline image request: ${invocation.memberName}',
  );
}

class _ImageRequest implements HttpClientRequest {
  _ImageRequest(this.bytes);
  final List<int>? bytes;
  @override
  HttpHeaders get headers => _ImageHeaders();
  @override
  Future<HttpClientResponse> close() async => _ImageResponse(bytes);
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
  _ImageResponse(this.bytes);
  final List<int>? bytes;
  @override
  int get statusCode => bytes == null ? 404 : 200;
  @override
  int get contentLength => bytes?.length ?? 0;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable([bytes ?? []]).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
