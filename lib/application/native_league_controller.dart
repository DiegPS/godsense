import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/league/league_clients.dart';

class NativeLeagueState {
  const NativeLeagueState({
    this.lcuConnected = false,
    this.gameflowPhase = 'NO_LCU',
    this.lobby = const {},
    this.liveGame,
    this.lastError,
    this.operationInProgress = false,
    this.lastOperationResult = const {},
  });

  final bool lcuConnected;
  final String gameflowPhase;
  final Map<String, dynamic> lobby;
  final Map<String, dynamic>? liveGame;
  final String? lastError;
  final bool operationInProgress;
  final Map<String, dynamic> lastOperationResult;

  bool get inGame => liveGame != null;

  NativeLeagueState copyWith({
    bool? lcuConnected,
    String? gameflowPhase,
    Map<String, dynamic>? lobby,
    Map<String, dynamic>? liveGame,
    bool clearLiveGame = false,
    String? lastError,
    bool clearError = false,
    bool? operationInProgress,
    Map<String, dynamic>? lastOperationResult,
  }) {
    return NativeLeagueState(
      lcuConnected: lcuConnected ?? this.lcuConnected,
      gameflowPhase: gameflowPhase ?? this.gameflowPhase,
      lobby: lobby ?? this.lobby,
      liveGame: clearLiveGame ? null : liveGame ?? this.liveGame,
      lastError: clearError ? null : lastError ?? this.lastError,
      operationInProgress: operationInProgress ?? this.operationInProgress,
      lastOperationResult: lastOperationResult ?? this.lastOperationResult,
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
  NativeLeagueController({LcuClient? lcu, LiveClientApi? live})
    : _lcu = lcu ?? LcuClient(),
      _live = live ?? LiveClientApi(),
      super(const NativeLeagueState());

  final LcuClient _lcu;
  final LiveClientApi _live;
  Timer? _timer;
  bool _polling = false;
  final Map<int, String> _championNames = {};
  int? _localSummonerId;

  int? get localSummonerId => _localSummonerId;

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
      final credentials = _lcu.discover();
      if (credentials == null) {
        state = state.copyWith(
          lcuConnected: false,
          gameflowPhase: 'NO_LCU',
          lobby: const {},
          clearLiveGame: true,
        );
        return;
      }
      final phaseRaw = await _lcu.get('/lol-gameflow/v1/gameflow-phase');
      final phase = phaseRaw?.toString() ?? 'None';
      Map<String, dynamic> lobby = const {};
      if (phase == 'ChampSelect') {
        final summoner = await _lcu.get('/lol-summoner/v1/current-summoner');
        if (summoner is Map) {
          _localSummonerId = (summoner['summonerId'] as num?)?.toInt();
        }
        final session = await _lcu.get('/lol-champ-select/v1/session');
        if (session is Map) lobby = await _normalizeLobby(session);
      }
      final liveData = await _live.allGameData();
      state = state.copyWith(
        lcuConnected: true,
        gameflowPhase: phase,
        lobby: lobby,
        liveGame: liveData == null ? null : _normalizeLive(liveData),
        clearLiveGame: liveData == null,
        clearError: true,
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

  Map<String, dynamic> _normalizeLive(Map<String, dynamic> raw) {
    final gameData = _stringMap(raw['gameData']);
    final active = _stringMap(raw['activePlayer']);
    final players = _mapList(raw['allPlayers']);
    final activeName = active['summonerName']?.toString();
    final local = players
        .where((player) => player['summonerName']?.toString() == activeName)
        .firstOrNull;
    final localTeam = local?['team']?.toString();
    Map<String, dynamic> player(Map<String, dynamic> value) {
      final scores = _stringMap(value['scores']);
      return {
        'champion_name': value['championName'] ?? '',
        'summoner_name': value['summonerName'] ?? '',
        'tag_line': value['riotIdTagLine'] ?? '',
        'team': value['team'] ?? '',
        'role': value['position'] ?? '',
        'level': value['level'] ?? 0,
        'kda': [
          scores['kills'] ?? 0,
          scores['deaths'] ?? 0,
          scores['assists'] ?? 0,
        ],
        'cs': scores['creepScore'] ?? 0,
        'items': _mapList(value['items']),
        'gold_total': 0,
        'gold_current': value['summonerName'] == activeName
            ? active['currentGold'] ?? 0
            : 0,
        'summoner_spells': _stringMap(value['summonerSpells']).values
            .whereType<Map>()
            .map((spell) => spell['displayName']?.toString() ?? '')
            .toList(),
        'runes': value['runes'] ?? const {},
        'position': null,
        'map_location': null,
        'is_mia': false,
        'mia_duration': 0.0,
        'last_known_location': null,
        'icon_url':
            'https://cdn.communitydragon.org/latest/champion/${Uri.encodeComponent(value['championName']?.toString() ?? '')}/square',
        'is_dead': value['isDead'] == true,
        'respawn_timer': value['respawnTimer'] ?? 0,
      };
    }

    final allies = players
        .where((value) => value['team']?.toString() == localTeam)
        .map(player)
        .toList();
    final enemies = players
        .where((value) => value['team']?.toString() != localTeam)
        .map(player)
        .toList();
    final gameTime = (gameData['gameTime'] as num?)?.toDouble() ?? 0;
    final events = _mapList(_stringMap(raw['events'])['Events']);
    final objectives = <String, dynamic>{};
    for (final event in events) {
      final name = event['EventName']?.toString() ?? '';
      if (name == 'DragonKill') objectives['dragon_last'] = event;
      if (name == 'BaronKill') objectives['baron_last'] = event;
      if (name == 'HeraldKill') objectives['herald_last'] = event;
    }
    return {
      'game_time': gameTime,
      'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
      'phase': gameTime < 900
          ? 'EARLY'
          : gameTime < 1800
          ? 'MID'
          : 'LATE',
      'allies': allies,
      'enemies': enemies,
      'active_player': local == null ? null : player(local),
      'team_gold_diff': 0,
      'team_state': 'EVEN',
      'lane_states': const {},
      'events': events,
      'derived': {'objectives': objectives},
      '_game_ended': false,
      'directives_pacing': const {},
    };
  }

  @override
  void dispose() {
    _timer?.cancel();
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
