import 'dart:async';

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
import 'live_game_processor.dart';
import 'native_league_foundation.dart';

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
  int? _localSummonerId;
  Map<int, Map<String, dynamic>> _itemCatalog = const {};
  bool _itemCatalogLoading = false;
  DateTime? _lastItemCatalogAttempt;
  int _consecutiveLiveFailures = 0;
  String? _currentGameId;
  String? _runeRequestKey;
  String? _jungleRequestPatch;
  String? _itemRecommendationRequestKey;

  int? get localSummonerId => _localSummonerId;

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

  Future<LeagueAccountProfile> scoutByRiotId({
    required String gameName,
    required String tagLine,
  }) => (foundation ??= NativeLeagueFoundation(
    client: _lcu,
  )).resolveAndSyncScout(gameName: gameName, tagLine: tagLine);

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
      const Duration(milliseconds: 500),
      (_) => unawaited(_poll()),
    );
  }

  void _onLcuEvent(LcuApiEvent event) {
    if (!_reconciledLcuFamilies.any(event.uri.startsWith)) return;
    _eventDebounce?.cancel();
    _eventDebounce = Timer(
      const Duration(milliseconds: 40),
      () => unawaited(_poll()),
    );
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      var lcuConnected = false;
      var phase = 'NO_LCU';
      var lobby = const <String, dynamic>{};
      Object? champSelectSession;
      final credentials = _lcu.discover();
      if (credentials != null) {
        try {
          final phaseRaw = await _lcu.get('/lol-gameflow/v1/gameflow-phase');
          phase = phaseRaw?.toString() ?? 'None';
          lcuConnected = true;
          if (phase == 'ChampSelect') {
            final summoner = await _lcu.get(
              '/lol-summoner/v1/current-summoner',
            );
            if (summoner is Map) {
              _localSummonerId = (summoner['summonerId'] as num?)?.toInt();
            }
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
            );
      } catch (_) {
        // Persistence and account enrichment must never interrupt live data.
      }
      final liveStopwatch = Stopwatch()..start();
      final liveData = await _live.allGameData();
      final liveLatency = liveStopwatch.elapsedMicroseconds / 1000;
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
        _consecutiveLiveFailures = 0;
        final processed = _processor.process(
          liveData,
          itemCatalog: _itemCatalog,
          gameId: _currentGameId,
        );
        state = state.copyWith(
          lcuConnected: lcuConnected,
          gameflowPhase: phase,
          lobby: lobby,
          liveGame: processed.snapshot,
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

  Future<Map<String, dynamic>> _normalizeLobby(
    Map<dynamic, dynamic> raw,
  ) async {
    final myTeam = _mapList(raw['myTeam']);
    final theirTeam = _mapList(raw['theirTeam']);
    for (final player in [...myTeam, ...theirTeam]) {
      final id = (player['championId'] as num?)?.toInt() ?? 0;
      if (id > 0 && !_championNames.containsKey(id)) {
        final data = await _lcu.get(
          '/lol-game-data/assets/v1/champions/$id.json',
        );
        if (data is Map) {
          _championNames[id] = data['name']?.toString() ?? '$id';
          _championAliases[id] = data['alias']?.toString() ?? '';
        }
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
            return {
              'cell_id': player['cellId'],
              'champion_id': id,
              'champion_name': _championNames[id] ?? '',
              'champion_alias': _championAliases[id] ?? '',
              'position': player['assignedPosition'] ?? '',
              'locked': flatActions.any(
                (action) =>
                    action['actorCellId'] == player['cellId'] &&
                    action['type'] == 'pick' &&
                    action['completed'] == true,
              ),
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
    return {
      'phase': 'IN_SELECT',
      'snapshot': {
        'local_player_cell_id': localCell,
        'my_team': normalize(myTeam),
        'their_team': normalize(theirTeam),
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
      'pick_advice': const [],
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

const _reconciledLcuFamilies = <String>[
  '/lol-gameflow/',
  '/lol-champ-select/',
  '/lol-summoner/',
  '/lol-ranked/',
  '/lol-match-history/',
  '/lol-perks/',
];

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
