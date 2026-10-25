import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/league/scout_models.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/identity/league_identity.dart';
import '../domain/jungle/jungle_recommendation.dart';
import '../domain/league/account_context.dart';
import '../domain/league/game_session.dart';
import '../domain/league/item_recommendation.dart';
import '../domain/league/lcu_capabilities.dart';
import '../domain/league/local_scout.dart';
import '../domain/league/rune_recommendation.dart';
import '../domain/tactical/tactical_models.dart';
import '../domain/vision/vision_observation.dart';
import '../infrastructure/data_dragon/data_dragon_catalog_service.dart';
import '../infrastructure/jungle/jungle_map_transport.dart';
import '../infrastructure/jungle/jungle_recommendation_source.dart';
import '../infrastructure/jungle/jungle_recommendation_cache.dart';
import '../infrastructure/league/league_clients.dart';
import '../infrastructure/league/item_recommendation_cache.dart';
import '../infrastructure/league/lcu_event_stream.dart';
import '../infrastructure/league/lcu_rune_recommendation_source.dart';
import '../infrastructure/league/riot_item_recommendation_source.dart';
import '../infrastructure/league/riot_item_recommendation_transport.dart';
import 'account_context_coordinator.dart';
import 'champion_pick_advisor.dart';
import 'live_game_processor.dart';
import 'live_ranked_profile_loader.dart';
import 'native_league_foundation.dart';

// WebSocket events provide immediacy. These intervals only reconcile state and
// recover from missed events.
const _lcuReconciliationInterval = Duration(seconds: 1);
const _reconciliationCoalesceWindow = Duration(milliseconds: 800);
const _lcuEventDebounce = Duration(milliseconds: 40);
const _backgroundLiveProbeInterval = Duration(seconds: 5);

class NativeLeagueState {
  const NativeLeagueState({
    this.lcuConnected = false,
    this.lcuEventConnected = false,
    this.gameflowPhase = 'NO_LCU',
    this.lobby = const {},
    this.liveGame,
    this.liveApiConnected = false,
    this.liveApiLatencyMilliseconds = 0,
    this.consecutiveLiveFailures = 0,
    this.lastLiveUpdate,
    this.timeline = const {},
    this.sessionId,
    this.lastError,
    this.operationInProgress = false,
    this.lastOperationResult = const {},
    this.accountContext,
    this.lcuCapabilities,
    this.gameSession = const GameSessionState(),
    this.runeRecommendations,
    this.runeRecommendationsLoading = false,
    this.runeRecommendationsError,
    this.jungleRecommendations,
    this.jungleRecommendationsLoading = false,
    this.jungleRecommendationsError,
    this.itemRecommendations,
    this.itemRecommendationsLoading = false,
    this.itemRecommendationsError,
  });

  final bool lcuConnected;
  final bool lcuEventConnected;
  final String gameflowPhase;
  final Map<String, dynamic> lobby;
  final Map<String, dynamic>? liveGame;
  final bool liveApiConnected;
  final double liveApiLatencyMilliseconds;
  final int consecutiveLiveFailures;
  final DateTime? lastLiveUpdate;
  final Map<String, dynamic> timeline;
  final String? sessionId;
  final String? lastError;
  final bool operationInProgress;
  final Map<String, dynamic> lastOperationResult;
  final AccountContextState? accountContext;
  final LcuCapabilities? lcuCapabilities;
  final GameSessionState gameSession;
  final RuneRecommendationBundle? runeRecommendations;
  final bool runeRecommendationsLoading;
  final String? runeRecommendationsError;
  final JungleRecommendationBundle? jungleRecommendations;
  final bool jungleRecommendationsLoading;
  final String? jungleRecommendationsError;
  final ItemRecommendationBundle? itemRecommendations;
  final bool itemRecommendationsLoading;
  final String? itemRecommendationsError;

  bool get inGame => liveGame != null && liveGame!['_game_ended'] != true;

  NativeLeagueState copyWith({
    bool? lcuConnected,
    bool? lcuEventConnected,
    String? gameflowPhase,
    Map<String, dynamic>? lobby,
    Map<String, dynamic>? liveGame,
    bool clearLiveGame = false,
    bool? liveApiConnected,
    double? liveApiLatencyMilliseconds,
    int? consecutiveLiveFailures,
    DateTime? lastLiveUpdate,
    Map<String, dynamic>? timeline,
    String? sessionId,
    bool clearSessionId = false,
    String? lastError,
    bool clearError = false,
    bool? operationInProgress,
    Map<String, dynamic>? lastOperationResult,
    AccountContextState? accountContext,
    LcuCapabilities? lcuCapabilities,
    GameSessionState? gameSession,
    RuneRecommendationBundle? runeRecommendations,
    bool clearRuneRecommendations = false,
    bool? runeRecommendationsLoading,
    String? runeRecommendationsError,
    bool clearRuneRecommendationsError = false,
    JungleRecommendationBundle? jungleRecommendations,
    bool? jungleRecommendationsLoading,
    String? jungleRecommendationsError,
    bool clearJungleRecommendationsError = false,
    ItemRecommendationBundle? itemRecommendations,
    bool clearItemRecommendations = false,
    bool? itemRecommendationsLoading,
    String? itemRecommendationsError,
    bool clearItemRecommendationsError = false,
  }) {
    return NativeLeagueState(
      lcuConnected: lcuConnected ?? this.lcuConnected,
      lcuEventConnected: lcuEventConnected ?? this.lcuEventConnected,
      gameflowPhase: gameflowPhase ?? this.gameflowPhase,
      lobby: lobby ?? this.lobby,
      liveGame: clearLiveGame ? null : liveGame ?? this.liveGame,
      liveApiConnected: liveApiConnected ?? this.liveApiConnected,
      liveApiLatencyMilliseconds:
          liveApiLatencyMilliseconds ?? this.liveApiLatencyMilliseconds,
      consecutiveLiveFailures:
          consecutiveLiveFailures ?? this.consecutiveLiveFailures,
      lastLiveUpdate: lastLiveUpdate ?? this.lastLiveUpdate,
      timeline: timeline ?? this.timeline,
      sessionId: clearSessionId ? null : sessionId ?? this.sessionId,
      lastError: clearError ? null : lastError ?? this.lastError,
      operationInProgress: operationInProgress ?? this.operationInProgress,
      lastOperationResult: lastOperationResult ?? this.lastOperationResult,
      accountContext: accountContext ?? this.accountContext,
      lcuCapabilities: lcuCapabilities ?? this.lcuCapabilities,
      gameSession: gameSession ?? this.gameSession,
      runeRecommendations: clearRuneRecommendations
          ? null
          : runeRecommendations ?? this.runeRecommendations,
      runeRecommendationsLoading:
          runeRecommendationsLoading ?? this.runeRecommendationsLoading,
      runeRecommendationsError: clearRuneRecommendationsError
          ? null
          : runeRecommendationsError ?? this.runeRecommendationsError,
      jungleRecommendations:
          jungleRecommendations ?? this.jungleRecommendations,
      jungleRecommendationsLoading:
          jungleRecommendationsLoading ?? this.jungleRecommendationsLoading,
      jungleRecommendationsError: clearJungleRecommendationsError
          ? null
          : jungleRecommendationsError ?? this.jungleRecommendationsError,
      itemRecommendations: clearItemRecommendations
          ? null
          : itemRecommendations ?? this.itemRecommendations,
      itemRecommendationsLoading:
          itemRecommendationsLoading ?? this.itemRecommendationsLoading,
      itemRecommendationsError: clearItemRecommendationsError
          ? null
          : itemRecommendationsError ?? this.itemRecommendationsError,
    );
  }
}

final nativeLeagueProvider =
    StateNotifierProvider<NativeLeagueController, NativeLeagueState>((ref) {
      final controller = NativeLeagueController();
      controller.start();
      return controller;
    });

class NativeLeagueController extends StateNotifier<NativeLeagueState> {
  NativeLeagueController({
    LcuClient? lcu,
    LiveClientApi? live,
    LcuEventStream? lcuEvents,
    LiveGameProcessor? processor,
    this.dataDragonCatalog,
    this.foundation,
    LcuRuneRecommendationSource? runeRecommendationSource,
    JungleRecommendationSource? jungleRecommendationSource,
    RiotItemRecommendationSource? itemRecommendationSource,
  }) : _lcu = lcu ?? LcuClient(),
       _live = live ?? LiveClientApi(),
       _processor = processor ?? LiveGameProcessor(),
       super(const NativeLeagueState()) {
    _lcuEvents =
        lcuEvents ?? LcuEventStream(credentialsProvider: _lcu.discover);
    _runeRecommendationSource =
        runeRecommendationSource ?? LcuRuneRecommendationSource(client: _lcu);
    if (jungleRecommendationSource != null) {
      _jungleRecommendationSource = jungleRecommendationSource;
    } else {
      _jungleTransport = CommunityDragonJungleMapTransport();
      _jungleRecommendationSource = JungleRecommendationSource(
        transport: _jungleTransport!,
        cache: FileJungleRecommendationCache.defaultCache(),
      );
    }
    if (itemRecommendationSource != null) {
      _itemRecommendationSource = itemRecommendationSource;
    } else {
      _itemRecommendationTransport =
          CommunityDragonItemRecommendationTransport();
      _itemRecommendationSource = RiotItemRecommendationSource(
        transport: _itemRecommendationTransport!,
        cache: FileItemRecommendationCache.defaultCache(),
      );
    }
  }

  final LcuClient _lcu;
  final LiveClientApi _live;
  final LiveGameProcessor _processor;
  late final LcuEventStream _lcuEvents;
  late final LcuRuneRecommendationSource _runeRecommendationSource;
  late final JungleRecommendationSource _jungleRecommendationSource;
  CommunityDragonJungleMapTransport? _jungleTransport;
  late final RiotItemRecommendationSource _itemRecommendationSource;
  CommunityDragonItemRecommendationTransport? _itemRecommendationTransport;
  DataDragonCatalogService? dataDragonCatalog;
  NativeLeagueFoundation? foundation;
  Timer? _timer;
  Timer? _eventDebounce;
  StreamSubscription<LcuApiEvent>? _eventSubscription;
  StreamSubscription<LcuEventConnectionState>? _eventStateSubscription;
  bool _polling = false;
  final Map<int, String> _championNames = {};
  final Map<int, String> _championAliases = {};
  final Map<int, Map<String, dynamic>> _championProfiles = {};
  final Map<int, Future<void>> _championProfileLoads = {};
  String? _championProfilesVersion;
  final Map<String, String> _championPortraits = {};
  String? _portraitPatch;
  bool _portraitsLoading = false;
  DateTime? _portraitAttempt;
  int? _localSummonerId;
  Map<int, Map<String, dynamic>> _itemCatalog = const {};
  final Map<String, List<Map<String, dynamic>>> _championAbilities = {};
  bool _itemCatalogLoading = false;
  bool _championAbilitiesLoading = false;
  DateTime? _lastItemCatalogAttempt;
  DateTime? _lastChampionAbilitiesAttempt;
  String? _championAbilitiesPatch;
  final Map<String, Map<String, dynamic>> _liveRankedProfiles = {};
  String? _rankedRosterKey;
  bool _rankedProfilesLoading = false;
  DateTime? _lastRankedProfilesAttempt;
  int _consecutiveLiveFailures = 0;
  String? _currentGameId;
  String? _runeRequestKey;
  String? _jungleRequestPatch;
  String? _itemRecommendationRequestKey;
  List<Map<String, dynamic>> _draftMastery = const [];
  Set<int> _draftPickableIds = const {};
  String? _draftAccountKey;
  bool _draftPoolLoading = false;
  DateTime? _lastDraftPoolAttempt;
  DateTime? _lastLiveProbe;
  String? _lastObservedPhase;
  String? _rankedRosterCompleteKey;
  bool _draftPoolLoaded = false;
  final Map<int, Set<String>> _draftChampionPositions = {};
  bool _forceAccountSync = false;
  bool _forceCapabilityProbe = false;
  DateTime? _lastPollStarted;

  int? get localSummonerId => _localSummonerId;

  Future<File> exportLocalData(File destination) =>
      (foundation ??= NativeLeagueFoundation(
        client: _lcu,
      )).exportLocalData(destination);

  Future<LocalDataRetentionResult> applyLocalDataRetention() =>
      (foundation ??= NativeLeagueFoundation(
        client: _lcu,
      )).applyLocalDataRetention();

  Future<void> deleteAllLocalData() async {
    await (foundation ??= NativeLeagueFoundation(
      client: _lcu,
    )).deleteAllLocalData();
    state = NativeLeagueState(
      lcuConnected: state.lcuConnected,
      lcuEventConnected: state.lcuEventConnected,
      gameflowPhase: state.gameflowPhase,
      liveApiConnected: state.liveApiConnected,
    );
  }

  Future<bool> recordTacticalAdvice({
    required String question,
    required TacticalAdvice advice,
  }) => (foundation ??= NativeLeagueFoundation(
    client: _lcu,
  )).recordTacticalAdvice(question: question, advice: advice);

  Future<bool> recordVisionObservation(VisionObservation observation) =>
      (foundation ??= NativeLeagueFoundation(
        client: _lcu,
      )).recordVisionObservation(observation);

  Future<List<LocalMatchRecord>> loadLocalMatches(
    Puuid puuid, {
    int limit = 20,
  }) => (foundation ??= NativeLeagueFoundation(
    client: _lcu,
  )).loadLocalMatches(puuid, limit: limit);

  Future<LocalRankedSnapshot?> loadLocalRanked(Puuid puuid) =>
      (foundation ??= NativeLeagueFoundation(
        client: _lcu,
      )).loadLocalRanked(puuid);

  Future<LocalMatchRecord> loadScoutMatchDetails(LocalMatchRecord cached) =>
      (foundation ??= NativeLeagueFoundation(
        client: _lcu,
      )).loadScoutMatchDetails(cached);

  Future<LeagueAccountProfile> scoutByRiotId({
    required String gameName,
    required String tagLine,
  }) => (foundation ??= NativeLeagueFoundation(
    client: _lcu,
  )).resolveAndSyncScout(gameName: gameName, tagLine: tagLine);

  Future<LeagueAccountProfile> resolveScoutAccount({
    required String gameName,
    required String tagLine,
  }) => (foundation ??= NativeLeagueFoundation(
    client: _lcu,
  )).resolveScoutAccount(gameName: gameName, tagLine: tagLine);

  Future<LocalScoutSyncResult> synchronizeScoutAccount(
    LeagueAccountProfile account, {
    Future<void> Function(LocalScoutSyncProgress progress)? onProgress,
  }) => (foundation ??= NativeLeagueFoundation(
    client: _lcu,
  )).synchronizeScoutAccount(account, onProgress: onProgress);

  Future<Map<int, String>> loadChampionNames() async {
    if (_championNames.length >= 150) return Map.unmodifiable(_championNames);
    final response = await _lcu.get(
      '/lol-game-data/assets/v1/champion-summary.json',
    );
    if (response is List) {
      for (final raw in response.whereType<Map>()) {
        final id = (raw['id'] as num?)?.toInt();
        final name = raw['name']?.toString().trim() ?? '';
        if (id != null && id > 0 && name.isNotEmpty) {
          _championNames[id] = name;
          final alias = raw['alias']?.toString() ?? '';
          if (alias.isNotEmpty) _championAliases[id] = alias;
        }
      }
    }
    return Map.unmodifiable(_championNames);
  }

  Future<void> _ensureChampionProfileLoaded(int id) async {
    if (id <= 0) return;
    if (_championNames.containsKey(id) &&
        (_championAliases[id]?.isNotEmpty ?? false) &&
        _championProfiles.containsKey(id)) {
      return;
    }
    final existing = _championProfileLoads[id];
    if (existing != null) return existing;
    final loading = _loadChampionProfile(id);
    _championProfileLoads[id] = loading;
    try {
      await loading;
    } finally {
      _championProfileLoads.remove(id);
    }
  }

  Future<void> _loadChampionProfile(int id) async {
    final version = _championProfilesVersion;
    final data = await _lcu.get('/lol-game-data/assets/v1/champions/$id.json');
    if (data is! Map || _championProfilesVersion != version) return;
    _championNames[id] = data['name']?.toString() ?? '$id';
    _championAliases[id] = data['alias']?.toString() ?? '';
    _championProfiles[id] = {
      'champion_id': id,
      'champion_alias': data['alias']?.toString() ?? '',
      'icon_url':
          'https://raw.communitydragon.org/latest/plugins/'
          'rcp-be-lol-game-data/global/default/v1/champion-icons/$id.png',
      'classes': data['roles'] ?? const [],
      'playstyle': data['playstyleInfo'] ?? const {},
      'tactical': data['tacticalInfo'] ?? const {},
      'abilities': _normalizeLcuChampionAbilities(data['spells']),
      'attack_range':
          data['attackRange'] ?? _stringMap(data['stats'])['attackRange'],
      'power_curve':
          data['powerCurve'] ?? _stringMap(data['tacticalInfo'])['powerCurve'],
      'source': 'lcu_champion_data',
      'source_version': version,
    };
  }

  void start() {
    if (_timer != null) return;
    _eventSubscription = _lcuEvents.events.listen(_onLcuEvent);
    _eventStateSubscription = _lcuEvents.states.listen((connection) {
      state = state.copyWith(
        lcuEventConnected: connection == LcuEventConnectionState.connected,
      );
    });
    _lcuEvents.start();
    unawaited(_poll());
    _timer = Timer.periodic(
      _lcuReconciliationInterval,
      (_) => unawaited(_poll()),
    );
  }

  void _onLcuEvent(LcuApiEvent event) {
    if (event.uri.startsWith('/lol-summoner/')) {
      _forceAccountSync = true;
      _localSummonerId = null;
    }
    if (_capabilityRelevantLcuFamilies.any(event.uri.startsWith)) {
      _forceCapabilityProbe = true;
    }
    if (!_immediateLcuFamilies.any(event.uri.startsWith)) return;
    _eventDebounce?.cancel();
    _eventDebounce = Timer(
      _lcuEventDebounce,
      () => unawaited(_poll(eventDriven: true)),
    );
  }

  Future<void> _poll({bool eventDriven = false}) async {
    if (_polling) return;
    final now = DateTime.now();
    if (!eventDriven &&
        _lastPollStarted != null &&
        now.difference(_lastPollStarted!) < _reconciliationCoalesceWindow) {
      return;
    }
    _polling = true;
    _lastPollStarted = now;
    try {
      var lcuConnected = false;
      var phase = 'NO_LCU';
      var lobby = const <String, dynamic>{};
      Object? champSelectSession;
      final credentials = await _lcu.discover();
      if (credentials != null) {
        try {
          final phaseRaw = await _lcu.get('/lol-gameflow/v1/gameflow-phase');
          phase = phaseRaw?.toString() ?? 'None';
          lcuConnected = true;
          _updatePhaseScopedCaches(phase);
          if (phase == 'ChampSelect') {
            var draftPuuid =
                foundation?.state.account.context?.account.puuid.value;
            if (_localSummonerId == null || draftPuuid == null) {
              final summoner = await _lcu.get(
                '/lol-summoner/v1/current-summoner',
              );
              if (summoner is Map) {
                _localSummonerId = (summoner['summonerId'] as num?)?.toInt();
                draftPuuid = summoner['puuid']?.toString();
              }
            }
            _ensureDraftPoolLoaded(draftPuuid);
            final session = await _lcu.get('/lol-champ-select/v1/session');
            champSelectSession = session;
            if (session is Map) {
              lobby = await _normalizeLobby(session);
              _ensureRuneRecommendationsLoaded(lobby);
              _ensureItemRecommendationsLoaded(lobby);
            }
          }
          if (phase == 'InProgress' && _currentGameId == null) {
            final session = await _lcu.get('/lol-gameflow/v1/session');
            if (session is Map) {
              final gameData = _stringMap(session['gameData']);
              _currentGameId =
                  gameData['gameId']?.toString() ??
                  session['gameId']?.toString();
            }
          }
        } catch (_) {
          // Live Client remains useful while LCU is restarting or its
          // credentials rotate, so an LCU failure must not abort this poll.
          lcuConnected = false;
          phase = 'NO_LCU';
        }
      }
      NativeLeagueFoundationState? foundationState;
      try {
        foundationState =
            await (foundation ??= NativeLeagueFoundation(
              client: _lcu,
            )).observeLcu(
              connected: lcuConnected,
              gameflowPhase: phase,
              champSelectSession: champSelectSession,
              gameId: int.tryParse(_currentGameId ?? ''),
              forceAccountSync: _takeForcedAccountSync(),
              forceCapabilityProbe: _takeForcedCapabilityProbe(),
            );
        _localSummonerId =
            foundationState.account.context?.account.summonerId ??
            _localSummonerId;
      } catch (_) {
        // Persistence and account enrichment must never interrupt live data.
      }
      Map<String, dynamic>? liveData;
      var liveLatency = state.liveApiLatencyMilliseconds;
      final liveProbed = _shouldProbeLiveClient(phase);
      if (liveProbed) {
        _lastLiveProbe = DateTime.now();
        final liveStopwatch = Stopwatch()..start();
        liveData = await _live.allGameData();
        liveLatency = liveStopwatch.elapsedMicroseconds / 1000;
      }
      if (!liveProbed) {
        state = state.copyWith(
          lcuConnected: lcuConnected,
          gameflowPhase: phase,
          lobby: lobby,
          accountContext: foundationState?.account,
          lcuCapabilities: foundationState?.capabilities,
          gameSession: foundationState?.gameSession,
          clearError: true,
        );
        return;
      }
      await (foundation ??= NativeLeagueFoundation(
        client: _lcu,
      )).observeLiveClient(
        allGameData: liveData,
        gameId: int.tryParse(_currentGameId ?? ''),
      );
      foundationState = foundation?.state ?? foundationState;
      _ensureJungleRecommendationsLoaded(
        foundationState?.account.context?.account.patchKey,
      );
      if (liveData != null && _itemCatalog.isEmpty) {
        _ensureItemCatalogLoaded();
      }
      if (liveData != null) {
        _ensureChampionPortraitsLoaded();
        _ensureChampionAbilitiesLoaded(liveData);
        if (lcuConnected) _ensureRankedProfilesLoaded(liveData);
      }
      if (liveData != null) {
        _consecutiveLiveFailures = 0;
        final processed = _processor.process(
          liveData,
          itemCatalog: _itemCatalog,
          championAbilities: _championAbilities,
          championPortraits: _championPortraits,
          rankedProfiles: _liveRankedProfiles,
          championProfiles: {
            for (final entry in _championProfiles.entries)
              _championKey(_championNames[entry.key] ?? ''): entry.value,
          },
          gameId: _currentGameId,
        );
        _ensureLiveItemRecommendationsLoaded(processed.snapshot);
        state = state.copyWith(
          lcuConnected: lcuConnected,
          gameflowPhase: phase,
          lobby: lobby,
          liveGame: {
            ...processed.snapshot,
            'builds': ?_liveItemBuild(processed.snapshot),
          },
          liveApiConnected: true,
          liveApiLatencyMilliseconds: liveLatency,
          consecutiveLiveFailures: 0,
          lastLiveUpdate: DateTime.now(),
          timeline: processed.timeline,
          sessionId: processed.sessionId,
          clearError: true,
          accountContext: foundationState?.account,
          lcuCapabilities: foundationState?.capabilities,
          gameSession: foundationState?.gameSession,
        );
        return;
      }

      _consecutiveLiveFailures++;
      final gameMayStillBeRunning =
          phase == 'InProgress' ||
          _consecutiveLiveFailures < 3 ||
          (!lcuConnected && _consecutiveLiveFailures < 20);
      if ((state.inGame && gameMayStillBeRunning) ||
          (!state.inGame && _consecutiveLiveFailures < 3)) {
        state = state.copyWith(
          lcuConnected: lcuConnected,
          gameflowPhase: phase,
          lobby: lobby,
          liveApiConnected: false,
          liveApiLatencyMilliseconds: liveLatency,
          consecutiveLiveFailures: _consecutiveLiveFailures,
          accountContext: foundationState?.account,
          lcuCapabilities: foundationState?.capabilities,
          gameSession: foundationState?.gameSession,
        );
        return;
      }
      final completed = state.inGame
          ? _processor.completeLast()
          : state.liveGame;
      if (phase != 'InProgress') _currentGameId = null;
      state = state.copyWith(
        lcuConnected: lcuConnected,
        gameflowPhase: phase,
        lobby: lobby,
        liveGame: completed,
        liveApiConnected: false,
        liveApiLatencyMilliseconds: liveLatency,
        consecutiveLiveFailures: _consecutiveLiveFailures,
        timeline: _processor.currentTimeline(),
        clearError: true,
        accountContext: foundationState?.account,
        lcuCapabilities: foundationState?.capabilities,
        gameSession: foundationState?.gameSession,
      );
    } catch (error) {
      state = state.copyWith(lastError: error.toString());
    } finally {
      _polling = false;
    }
  }

  bool _takeForcedAccountSync() {
    final value = _forceAccountSync;
    _forceAccountSync = false;
    return value;
  }

  bool _takeForcedCapabilityProbe() {
    final value = _forceCapabilityProbe;
    _forceCapabilityProbe = false;
    return value;
  }

  bool _shouldProbeLiveClient(String phase) {
    if (phase == 'InProgress' || state.inGame) return true;
    final last = _lastLiveProbe;
    return last == null ||
        DateTime.now().difference(last) >= _backgroundLiveProbeInterval;
  }

  void _updatePhaseScopedCaches(String phase) {
    final previous = _lastObservedPhase;
    if (phase == previous) return;
    _lastObservedPhase = phase;
    if (phase == 'ChampSelect') {
      _draftPoolLoaded = false;
      _lastDraftPoolAttempt = null;
      _draftMastery = const [];
      _draftPickableIds = const {};
      _runeRequestKey = null;
      _itemRecommendationRequestKey = null;
    }
    if (previous == 'InProgress' && phase != 'InProgress') {
      _rankedRosterCompleteKey = null;
    }
  }

  Future<Map<String, dynamic>> _normalizeLobby(
    Map<dynamic, dynamic> raw,
  ) async {
    final version = foundation?.state.account.context?.account.clientVersion;
    if (_championProfilesVersion != version) {
      _championProfiles.clear();
      _championProfilesVersion = version;
    }
    final myTeam = _mapList(raw['myTeam']);
    final theirTeam = _mapList(raw['theirTeam']);
    for (final player in [...myTeam, ...theirTeam]) {
      final id = (player['championId'] as num?)?.toInt() ?? 0;
      if (id > 0 &&
          (!_championNames.containsKey(id) ||
              (_championAliases[id]?.isEmpty ?? true) ||
              !_championProfiles.containsKey(id))) {
        await _ensureChampionProfileLoaded(id);
      }
    }
    final localCell = (raw['localPlayerCellId'] as num?)?.toInt();
    final actions = raw['actions'] is List ? raw['actions'] as List : const [];
    final flatActions = actions
        .whereType<List>()
        .expand((round) => round.whereType<Map>())
        .map((action) => _stringMap(action))
        .toList();
    List<Map<String, dynamic>> normalize(List<Map<String, dynamic>> players) {
      return players
          .map((player) {
            final id = (player['championId'] as num?)?.toInt() ?? 0;
            final action = flatActions
                .where(
                  (action) =>
                      action['actorCellId'] == player['cellId'] &&
                      action['type'] == 'pick',
                )
                .lastOrNull;
            final locked = action?['completed'] == true;
            final picking = action?['isInProgress'] == true;
            return {
              'cell_id': player['cellId'],
              'champion_id': id,
              'champion_name': _championNames[id] ?? '',
              'champion_alias': _championAliases[id] ?? '',
              'champion_profile': _championProfiles[id],
              'position': player['assignedPosition'] ?? '',
              'locked': locked,
              'selection_state': locked
                  ? 'locked'
                  : picking
                  ? 'picking'
                  : id > 0
                  ? 'hovering'
                  : 'unavailable',
              'is_local': player['cellId'] == localCell,
              'summoner_id': player['summonerId'],
              'spell1_id': player['spell1Id'],
              'spell2_id': player['spell2Id'],
            };
          })
          .toList(growable: false);
    }

    final timer = _stringMap(raw['timer']);
    final localActions = flatActions.where(
      (action) =>
          action['actorCellId'] == localCell && action['type'] == 'pick',
    );
    final localAction = localActions.isEmpty ? null : localActions.last;
    final candidateId = (localAction?['championId'] as num?)?.toInt() ?? 0;
    final bans = _stringMap(raw['bans']);
    final excluded = <int>{
      for (final player in [...myTeam, ...theirTeam])
        if (player['cellId'] != localCell)
          (player['championId'] as num?)?.toInt() ?? 0,
      for (final value in [
        ...?bans['myTeamBans'] as List?,
        ...?bans['theirTeamBans'] as List?,
      ].whereType<num>())
        value.toInt(),
    };
    final normalizedMyTeam = normalize(myTeam);
    final normalizedTheirTeam = normalize(theirTeam);
    return {
      'phase': 'IN_SELECT',
      'snapshot': {
        'local_player_cell_id': localCell,
        'my_team': normalizedMyTeam,
        'their_team': normalizedTheirTeam,
        'timer_phase': timer['phase'],
        'time_left_ms': timer['adjustedTimeLeftInPhase'],
        'bans': {
          'my_team_bans': bans['myTeamBans'] ?? const [],
          'their_team_bans': bans['theirTeamBans'] ?? const [],
        },
        'all_locked':
            [...myTeam, ...theirTeam].length == 10 &&
            [...myTeam, ...theirTeam].every(
              (player) => ((player['championId'] as num?)?.toInt() ?? 0) > 0,
            ),
      },
      'brief_ready': false,
      'candidate': _championNames[candidateId],
      'builds': _matchingItemBuild(candidateId),
      'pick_advice': const ChampionPickAdvisor().suggest(
        mastery: _draftMastery,
        pickableIds: _draftPickableIds,
        excludedIds: excluded,
        championNames: _championNames,
        allies: normalizedMyTeam,
        enemies: normalizedTheirTeam,
        assignedPosition: normalizedMyTeam
            .where((p) => p['is_local'] == true)
            .firstOrNull?['position']
            ?.toString(),
        championPositions: _draftChampionPositions,
        championProfiles: _championProfiles,
      ),
      'comp_analysis': null,
    };
  }

  Future<void> importRecommendedSetup(Map<String, dynamic> builds) async {
    state = state.copyWith(operationInProgress: true, clearError: true);
    final result = <String, dynamic>{};
    try {
      final preferred = builds['matchup'] is Map
          ? Map<String, dynamic>.from(builds['matchup'] as Map)
          : builds['popular'] is Map
          ? Map<String, dynamic>.from(builds['popular'] as Map)
          : builds;
      final runes = _stringMap(preferred['runes']);
      final perkIds =
          (runes['perk_ids'] as List?)
              ?.whereType<num>()
              .map((value) => value.toInt())
              .toList() ??
          const <int>[];
      if (perkIds.isNotEmpty) {
        try {
          final pages = await _lcu.get('/lol-perks/v1/pages');
          if (pages is List) {
            for (final page in pages.whereType<Map>()) {
              if (page['name'] == 'GodSense' && page['isDeletable'] == true) {
                await _lcu.delete('/lol-perks/v1/pages/${page['id']}');
              }
            }
          }
          final page = await _lcu.post('/lol-perks/v1/pages', {
            'name': 'GodSense',
            'primaryStyleId': runes['primary_tree_id'],
            'subStyleId': runes['secondary_tree_id'],
            'selectedPerkIds': perkIds,
            'current': true,
          });
          result['runes'] = {
            'page_id': page is Map ? page['id'] : null,
            'page_name': 'GodSense',
          };
        } catch (error) {
          result['runes_error'] = error.toString();
        }
      }
      final summonerId = _localSummonerId;
      final groups = _mapList(preferred['items']);
      if (summonerId != null && groups.isNotEmpty) {
        try {
          final current = await _lcu.get(
            '/lol-item-sets/v1/item-sets/$summonerId/sets',
          );
          final envelope = current is Map
              ? current.map((key, value) => MapEntry(key.toString(), value))
              : <String, dynamic>{'accountId': summonerId, 'itemSets': []};
          final existing =
              (envelope['itemSets'] as List?)
                  ?.whereType<Map>()
                  .where((item) => item['title'] != 'GodSense Recommended')
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList() ??
              <Map<String, dynamic>>[];
          final uid = 'GodSense-${DateTime.now().millisecondsSinceEpoch}';
          final associatedChampion = (preferred['champion_id'] as num?)
              ?.toInt();
          final associatedMap = (preferred['map_id'] as num?)?.toInt();
          existing.add({
            'uid': uid,
            'title': 'GodSense Recommended',
            'type': 'custom',
            'map': 'any',
            'mode': 'any',
            'priority': true,
            'sortrank': 0,
            'startedFrom': 'blank',
            'associatedChampions': [
              if (associatedChampion != null && associatedChampion > 0)
                associatedChampion,
            ],
            'associatedMaps': [
              if (associatedMap != null && associatedMap > 0) associatedMap,
            ],
            'blocks': groups.map((group) {
              return {
                'type': group['category']?.toString() ?? 'Items',
                'items': _mapList(group['items'])
                    .map(
                      (item) => {
                        'id': '${item['item_id'] ?? item['id']}',
                        'count': (item['count'] as num?)?.toInt() ?? 1,
                      },
                    )
                    .toList(),
              };
            }).toList(),
          });
          envelope
            ..['accountId'] = summonerId
            ..['itemSets'] = existing
            ..['timestamp'] = DateTime.now().millisecondsSinceEpoch;
          await _lcu.put(
            '/lol-item-sets/v1/item-sets/$summonerId/sets',
            envelope,
          );
          result['build'] = {
            'set_uid': uid,
            'set_title': 'GodSense Recommended',
          };
        } catch (error) {
          result['build_error'] = error.toString();
        }
      }
      state = state.copyWith(
        operationInProgress: false,
        lastOperationResult: result,
      );
    } catch (error) {
      state = state.copyWith(
        operationInProgress: false,
        lastError: error.toString(),
      );
    }
  }

  void _ensureDraftPoolLoaded(String? puuid) {
    if (puuid == null || puuid.isEmpty) return;
    if (_draftAccountKey != puuid) {
      _draftAccountKey = puuid;
      _draftPoolLoaded = false;
      _draftChampionPositions.clear();
      _draftMastery = const [];
      _draftPickableIds = const {};
      _lastDraftPoolAttempt = null;
    }
    final now = DateTime.now();
    if (_draftPoolLoaded ||
        _draftPoolLoading ||
        (_lastDraftPoolAttempt != null &&
            now.difference(_lastDraftPoolAttempt!) <
                const Duration(seconds: 10))) {
      return;
    }
    _draftPoolLoading = true;
    _lastDraftPoolAttempt = now;
    unawaited(() async {
      try {
        final mastery = await _lcu.get(
          '/lol-champion-mastery/v1/local-player/champion-mastery',
        );
        final pickable = await _lcu.get(
          '/lol-champ-select/v1/pickable-champion-ids',
        );
        await loadChampionNames();
        final matches = await loadLocalMatches(Puuid(puuid), limit: 100);
        if (_draftAccountKey != puuid) return;
        for (final match in matches) {
          try {
            final payload = _stringMap(jsonDecode(match.summaryJson));
            final identity = _mapList(payload['participantIdentities'])
                .where((p) => _stringMap(p['player'])['puuid'] == puuid)
                .firstOrNull;
            final player = _mapList(payload['participants'])
                .where(
                  (p) =>
                      p['puuid'] == puuid ||
                      (identity != null &&
                          p['participantId'] == identity['participantId']),
                )
                .firstOrNull;
            if (player == null) continue;
            final id = (player['championId'] as num?)?.toInt();
            final timeline = _stringMap(player['timeline']);
            final role = ScoutRole.parse(
              timeline['lane']?.toString(),
              timeline['role']?.toString(),
            );
            if (id != null && role != ScoutRole.unknown) {
              _draftChampionPositions
                  .putIfAbsent(id, () => {})
                  .add(role.rawLane);
            }
          } on FormatException {
            continue;
          }
        }
        if (mastery is List && pickable is List) {
          final pickableIds = pickable
              .whereType<num>()
              .map((id) => id.toInt())
              .toSet();
          final profileIds =
              _mapList(mastery)
                  .where(
                    (entry) => pickableIds.contains(
                      (entry['championId'] as num?)?.toInt(),
                    ),
                  )
                  .toList()
                ..sort(
                  (left, right) => ((right['championPoints'] as num?) ?? 0)
                      .compareTo((left['championPoints'] as num?) ?? 0),
                );
          for (final entry in profileIds.take(12)) {
            final id = (entry['championId'] as num?)?.toInt();
            if (id != null) await _ensureChampionProfileLoaded(id);
          }
        }
        if (_draftAccountKey != puuid) return;
        _draftMastery = _mapList(mastery);
        _draftPickableIds = pickable is List
            ? pickable.whereType<num>().map((value) => value.toInt()).toSet()
            : const {};
        _draftPoolLoaded = mastery is List && pickable is List;
      } catch (_) {
        // Never substitute fabricated picks if the local pool is unavailable.
      } finally {
        _draftPoolLoading = false;
      }
    }());
  }

  Future<void> loadRuneRecommendations({
    required int championId,
    required LeaguePosition position,
    int mapId = 11,
  }) async {
    state = state.copyWith(
      runeRecommendationsLoading: true,
      clearRuneRecommendationsError: true,
    );
    try {
      final account = foundation?.state.account.context?.account;
      final bundle = await _runeRecommendationSource.load(
        championId: championId,
        position: position,
        mapId: mapId,
        clientVersion: account?.clientVersion == null
            ? null
            : ClientVersion(account!.clientVersion!),
        patch: account?.patchKey,
      );
      state = state.copyWith(
        runeRecommendations: bundle,
        runeRecommendationsLoading: false,
        clearRuneRecommendationsError: true,
      );
    } catch (error) {
      _runeRequestKey = null;
      state = state.copyWith(
        runeRecommendationsLoading: false,
        runeRecommendationsError: error.toString(),
      );
    }
  }

  Future<void> importRuneRecommendation(
    RuneRecommendationVariant recommendation,
  ) => importRecommendedSetup({'runes': recommendation.toImportJson()});

  Future<void> loadJungleRecommendations(PatchKey patch) async {
    state = state.copyWith(
      jungleRecommendationsLoading: true,
      clearJungleRecommendationsError: true,
    );
    try {
      final bundle = await _jungleRecommendationSource.load(patch);
      state = state.copyWith(
        jungleRecommendations: bundle,
        jungleRecommendationsLoading: false,
        clearJungleRecommendationsError: true,
      );
    } catch (error) {
      _jungleRequestPatch = null;
      state = state.copyWith(
        jungleRecommendationsLoading: false,
        jungleRecommendationsError: error.toString(),
      );
    }
  }

  Future<void> loadItemRecommendations({
    required int championId,
    required String championAlias,
    required LeaguePosition position,
  }) async {
    state = state.copyWith(
      itemRecommendationsLoading: true,
      clearItemRecommendations: true,
      clearItemRecommendationsError: true,
    );
    try {
      final account = foundation?.state.account.context?.account;
      final patch = account?.patchKey;
      if (patch == null) {
        throw const ItemRecommendationException(
          'League patch is not available yet.',
        );
      }
      if (_itemCatalog.isEmpty) await _loadItemCatalog();
      final bundle = await _itemRecommendationSource.load(
        championId: championId,
        championAlias: championAlias,
        position: position,
        patch: patch,
        itemCatalog: _itemCatalog,
      );
      state = state.copyWith(
        itemRecommendations: bundle,
        itemRecommendationsLoading: false,
        clearItemRecommendationsError: true,
        lobby: state.lobby.isEmpty
            ? state.lobby
            : {...state.lobby, 'builds': bundle.toBuildJson()},
      );
    } catch (error) {
      _itemRecommendationRequestKey = null;
      state = state.copyWith(
        itemRecommendationsLoading: false,
        itemRecommendationsError: error.toString(),
      );
    }
  }

  Future<void> importItemRecommendations() async {
    final bundle = state.itemRecommendations;
    if (bundle == null) return;
    await importRecommendedSetup({
      'champion_id': bundle.championId,
      'map_id': bundle.mapId,
      'items': bundle.toImportGroups(),
    });
  }

  Future<void> importCurrentRecommendations() async {
    final runes = state.runeRecommendations?.variants.firstOrNull;
    final items = state.itemRecommendations;
    if (runes == null && items == null) return;
    await importRecommendedSetup({
      if (runes != null) 'runes': runes.toImportJson(),
      if (items != null) ...{
        'champion_id': items.championId,
        'map_id': items.mapId,
        'items': items.toImportGroups(),
      },
    });
  }

  Map<String, dynamic>? _matchingItemBuild(int championId) {
    final bundle = state.itemRecommendations;
    if (bundle == null || bundle.championId != championId) return null;
    return bundle.toBuildJson();
  }

  Map<String, dynamic>? _liveItemBuild(Map<String, dynamic> game) {
    final bundle = state.itemRecommendations;
    if (bundle == null) return null;
    final active = _stringMap(game['active_player']);
    final champion = _championKey(active['champion_name']?.toString() ?? '');
    final role = LeaguePosition.tryParse(active['role']);
    final patch = foundation?.state.account.context?.account.patchKey;
    final mapId = (game['map_number'] as num?)?.toInt();
    if (patch != bundle.patch ||
        mapId != bundle.mapId ||
        role != bundle.position) {
      return null;
    }
    if (champion != _championKey(bundle.championAlias) &&
        champion != _championKey(_championNames[bundle.championId] ?? '')) {
      return null;
    }
    return bundle.toBuildJson();
  }

  void _ensureJungleRecommendationsLoaded(PatchKey? patch) {
    if (patch == null || _jungleRequestPatch == patch.value) return;
    _jungleRequestPatch = patch.value;
    unawaited(loadJungleRecommendations(patch));
  }

  void _ensureRuneRecommendationsLoaded(Map<String, dynamic> lobby) {
    final snapshot = _stringMap(lobby['snapshot']);
    final local = _mapList(snapshot['my_team'])
        .where((player) => player['is_local'] == true);
    if (local.isEmpty) return;
    final championId = (local.first['champion_id'] as num?)?.toInt() ?? 0;
    final position = LeaguePosition.tryParse(local.first['position']);
    if (championId <= 0 || position == null) return;
    final key = '$championId|${position.lcuValue}|11';
    if (_runeRequestKey == key &&
        (state.runeRecommendationsLoading ||
            state.runeRecommendations?.championId == championId)) {
      return;
    }
    _runeRequestKey = key;
    unawaited(
      loadRuneRecommendations(championId: championId, position: position),
    );
  }

  void _ensureItemRecommendationsLoaded(Map<String, dynamic> lobby) {
    final snapshot = _stringMap(lobby['snapshot']);
    final local = _mapList(snapshot['my_team'])
        .where((player) => player['is_local'] == true);
    if (local.isEmpty) return;
    final championId = (local.first['champion_id'] as num?)?.toInt() ?? 0;
    final championAlias = local.first['champion_alias']?.toString() ?? '';
    final position = LeaguePosition.tryParse(local.first['position']);
    final patch = foundation?.state.account.context?.account.patchKey;
    if (championId <= 0 ||
        championAlias.isEmpty ||
        position == null ||
        patch == null) {
      return;
    }
    final key =
        '$championId|$championAlias|${position.lcuValue}|${patch.value}';
    if (_itemRecommendationRequestKey == key &&
        (state.itemRecommendationsLoading ||
            state.itemRecommendations?.championId == championId)) {
      return;
    }
    _itemRecommendationRequestKey = key;
    unawaited(
      loadItemRecommendations(
        championId: championId,
        championAlias: championAlias,
        position: position,
      ),
    );
  }

  void _ensureLiveItemRecommendationsLoaded(Map<String, dynamic> game) {
    if (state.itemRecommendations != null || state.itemRecommendationsLoading) {
      return;
    }
    final active = _stringMap(game['active_player']);
    final rawChampion =
        active['championName']?.toString() ??
        active['champion_name']?.toString() ??
        '';
    if (rawChampion.isEmpty) return;
    final championKey = _championKey(rawChampion);

    int championId = 0;
    for (final entry in _championNames.entries) {
      if (_championKey(entry.value) == championKey) {
        championId = entry.key;
        break;
      }
    }
    if (championId <= 0) return;

    final position =
        LeaguePosition.tryParse(active['position']) ??
        LeaguePosition.tryParse(active['role']) ??
        LeaguePosition.middle;

    final patch = foundation?.state.account.context?.account.patchKey;
    if (patch == null) return;

    final key = '$championId|$rawChampion|${position.lcuValue}|${patch.value}';
    if (_itemRecommendationRequestKey == key) return;
    _itemRecommendationRequestKey = key;

    unawaited(
      loadItemRecommendations(
        championId: championId,
        championAlias: rawChampion,
        position: position,
      ),
    );
  }

  Future<void> _loadItemCatalog() async {
    try {
      final account = foundation?.state.account.context?.account;
      final patch = account?.patchKey;
      if (patch == null) return;
      dataDragonCatalog ??= await DataDragonCatalogService.createDefault();
      _itemCatalog = await dataDragonCatalog!.loadItems(
        patch: patch,
        platformId: account?.platformId ?? PlatformId('LA1'),
        clientVersion: account?.clientVersion == null
            ? null
            : ClientVersion(account!.clientVersion!),
      );
    } catch (_) {
      _itemCatalog = const {};
    }
  }

  void _ensureItemCatalogLoaded() {
    final now = DateTime.now();
    if (_itemCatalogLoading ||
        (_lastItemCatalogAttempt != null &&
            now.difference(_lastItemCatalogAttempt!) <
                const Duration(minutes: 5))) {
      return;
    }
    _itemCatalogLoading = true;
    _lastItemCatalogAttempt = now;
    unawaited(
      _loadItemCatalog().whenComplete(() => _itemCatalogLoading = false),
    );
  }

  void _ensureChampionPortraitsLoaded() {
    final account = foundation?.state.account.context?.account;
    final patch = account?.patchKey;
    if (patch == null) return;
    if (_portraitPatch != patch.value) {
      _portraitPatch = patch.value;
      _championPortraits.clear();
      _portraitAttempt = null;
    }
    if (_championPortraits.isNotEmpty || _portraitsLoading) return;
    final now = DateTime.now();
    if (_portraitAttempt != null &&
        now.difference(_portraitAttempt!) < const Duration(seconds: 10)) {
      return;
    }
    _portraitAttempt = now;
    _portraitsLoading = true;
    unawaited(() async {
      try {
        dataDragonCatalog ??= await DataDragonCatalogService.createDefault();
        final portraits = await dataDragonCatalog!.loadChampionPortraits(
          patch: patch,
          platformId: account?.platformId ?? PlatformId('LA1'),
          clientVersion: account?.clientVersion == null
              ? null
              : ClientVersion(account!.clientVersion!),
        );
        if (_portraitPatch == patch.value) _championPortraits.addAll(portraits);
      } catch (_) {
        // Retry independently of ability metadata or a previous champ select.
      } finally {
        _portraitsLoading = false;
      }
    }());
  }

  void _ensureChampionAbilitiesLoaded(Map<String, dynamic> liveData) {
    final account = foundation?.state.account.context?.account;
    final patch = account?.patchKey;
    if (patch == null) return;
    if (_championAbilitiesPatch != patch.value) {
      _championAbilities.clear();
      _championAbilitiesPatch = patch.value;
      _lastChampionAbilitiesAttempt = null;
    }
    final names = _mapList(liveData['allPlayers'])
        .map((player) => player['championName']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
    final missing = names.where(
      (name) => !_championAbilities.containsKey(_championKey(name)),
    );
    if (missing.isEmpty || _championAbilitiesLoading) return;
    final now = DateTime.now();
    if (_lastChampionAbilitiesAttempt != null &&
        now.difference(_lastChampionAbilitiesAttempt!) <
            const Duration(seconds: 10)) {
      return;
    }
    _championAbilitiesLoading = true;
    _lastChampionAbilitiesAttempt = now;
    unawaited(() async {
      try {
        dataDragonCatalog ??= await DataDragonCatalogService.createDefault();
        final loaded = await dataDragonCatalog!.loadChampionAbilities(
          championNames: missing.toList(growable: false),
          patch: patch,
          platformId: account?.platformId ?? PlatformId('LA1'),
          clientVersion: account?.clientVersion == null
              ? null
              : ClientVersion(account!.clientVersion!),
        );
        if (_championAbilitiesPatch == patch.value) {
          _championAbilities.addAll(loaded);
        }
      } catch (_) {
        // Asset enrichment is optional; retry without interrupting live state.
      } finally {
        _championAbilitiesLoading = false;
      }
    }());
  }

  void _ensureRankedProfilesLoaded(Map<String, dynamic> liveData) {
    final players = _mapList(liveData['allPlayers']);
    final identities =
        players
            .map(livePlayerRiotId)
            .nonNulls
            .map((id) => id.displayName.toLowerCase())
            .toList()
          ..sort();
    final key = '${_currentGameId ?? ''}|${identities.join('|')}';
    if (_rankedRosterKey != key) {
      _rankedRosterKey = key;
      _rankedRosterCompleteKey = null;
      _liveRankedProfiles.clear();
      _lastRankedProfilesAttempt = null;
    }
    if (_rankedRosterCompleteKey == key ||
        _rankedProfilesLoading ||
        identities.isEmpty) {
      return;
    }
    final now = DateTime.now();
    if (_lastRankedProfilesAttempt != null &&
        now.difference(_lastRankedProfilesAttempt!) <
            const Duration(minutes: 2)) {
      return;
    }
    _lastRankedProfilesAttempt = now;
    _rankedProfilesLoading = true;
    for (final identity in identities) {
      _liveRankedProfiles.putIfAbsent(identity, () => {'status': 'loading'});
    }
    unawaited(() async {
      try {
        final loader = LiveRankedProfileLoader(
          resolve: ({required gameName, required tagLine}) =>
              (foundation ??= NativeLeagueFoundation(
                client: _lcu,
              )).resolveAndSyncScout(
                gameName: gameName,
                tagLine: tagLine,
                includeHistory: false,
              ),
          loadRanked: loadLocalRanked,
        );
        final profiles = await loader.load(players);
        if (_rankedRosterKey == key) {
          _liveRankedProfiles.addAll(profiles);
          _rankedRosterCompleteKey = key;
        }
      } finally {
        _rankedProfilesLoading = false;
      }
    }());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _eventDebounce?.cancel();
    unawaited(_eventSubscription?.cancel() ?? Future<void>.value());
    unawaited(_eventStateSubscription?.cancel() ?? Future<void>.value());
    unawaited(_lcuEvents.dispose());
    _lcu.dispose();
    _live.dispose();
    _jungleTransport?.dispose();
    _itemRecommendationTransport?.dispose();
    unawaited(foundation?.dispose());
    super.dispose();
  }
}

const _immediateLcuFamilies = <String>[
  '/lol-gameflow/',
  '/lol-champ-select/',
  '/lol-summoner/',
];

const _capabilityRelevantLcuFamilies = <String>['/lol-summoner/'];

Map<String, dynamic> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList(growable: false);
}

String _championKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]"), '');

List<Map<String, dynamic>> _normalizeLcuChampionAbilities(Object? value) {
  if (value is! List) return const [];
  const inferredSlots = ['Q', 'W', 'E', 'R'];
  final result = <Map<String, dynamic>>[];
  for (var index = 0; index < value.length; index++) {
    final raw = value[index];
    if (raw is! Map) continue;
    final ability = _stringMap(raw);
    final explicitSlot =
        [ability['spellKey'], ability['slot'], ability['abilitySlot']]
            .map((item) => item?.toString().trim().toUpperCase() ?? '')
            .firstWhere(
              (item) => const {'P', 'Q', 'W', 'E', 'R'}.contains(item),
              orElse: () => '',
            );
    final slot = explicitSlot.isNotEmpty
        ? explicitSlot
        : index < inferredSlots.length
        ? inferredSlots[index]
        : '';
    if (!const {'P', 'Q', 'W', 'E', 'R'}.contains(slot)) continue;
    final cooldown =
        ability['cooldownBurn'] ??
        ability['cooldown'] ??
        ability['cooldownCoefficients'];
    result.add({
      'slot': slot,
      'name': ability['name']?.toString() ?? '',
      'description':
          ability['description']?.toString() ??
          ability['dynamicTooltip']?.toString() ??
          '',
      'cooldown': cooldown is List ? cooldown.join(' / ') : '$cooldown',
      'source': 'lcu_champion_data',
    });
  }
  return List.unmodifiable(result);
}
