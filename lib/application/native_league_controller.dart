import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/identity/league_identity.dart';
import '../domain/league/game_session.dart';
import '../domain/league/lcu_capabilities.dart';
import '../domain/tactical/tactical_models.dart';
import '../infrastructure/data_dragon/data_dragon_catalog_service.dart';
import '../infrastructure/league/league_clients.dart';
import 'account_context_coordinator.dart';
import 'live_game_processor.dart';
import 'native_league_foundation.dart';

class NativeLeagueState {
  const NativeLeagueState({
    this.lcuConnected = false,
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
  });

  final bool lcuConnected;
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

  bool get inGame => liveGame != null && liveGame!['_game_ended'] != true;

  NativeLeagueState copyWith({
    bool? lcuConnected,
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
  }) {
    return NativeLeagueState(
      lcuConnected: lcuConnected ?? this.lcuConnected,
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
    LiveGameProcessor? processor,
    this.dataDragonCatalog,
    this.foundation,
  }) : _lcu = lcu ?? LcuClient(),
       _live = live ?? LiveClientApi(),
       _processor = processor ?? LiveGameProcessor(),
       super(const NativeLeagueState());

  final LcuClient _lcu;
  final LiveClientApi _live;
  final LiveGameProcessor _processor;
  DataDragonCatalogService? dataDragonCatalog;
  NativeLeagueFoundation? foundation;
  Timer? _timer;
  bool _polling = false;
  final Map<int, String> _championNames = {};
  int? _localSummonerId;
  Map<int, Map<String, dynamic>> _itemCatalog = const {};
  bool _itemCatalogLoading = false;
  DateTime? _lastItemCatalogAttempt;
  int _consecutiveLiveFailures = 0;
  String? _currentGameId;

  int? get localSummonerId => _localSummonerId;

  Future<bool> recordTacticalAdvice({
    required String question,
    required TacticalAdvice advice,
  }) => (foundation ??= NativeLeagueFoundation(
    client: _lcu,
  )).recordTacticalAdvice(question: question, advice: advice);

  void start() {
    if (_timer != null) return;
    unawaited(_poll());
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => unawaited(_poll()),
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
            if (session is Map) lobby = await _normalizeLobby(session);
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
        if (data is Map) _championNames[id] = data['name']?.toString() ?? '$id';
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
      'builds': null,
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
          existing.add({
            'uid': uid,
            'title': 'GodSense Recommended',
            'type': 'custom',
            'map': 'any',
            'mode': 'any',
            'priority': true,
            'sortrank': 0,
            'startedFrom': 'blank',
            'associatedChampions': const [],
            'associatedMaps': const [],
            'blocks': groups.map((group) {
              return {
                'type': group['category']?.toString() ?? 'Items',
                'items': _mapList(group['items'])
                    .map(
                      (item) => {
                        'id': '${item['item_id'] ?? item['id']}',
                        'count': 1,
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
    _lcu.dispose();
    _live.dispose();
    unawaited(foundation?.dispose());
    super.dispose();
  }
}

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
