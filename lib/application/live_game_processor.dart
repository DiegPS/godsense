import 'dart:convert';
import 'dart:math' as math;

class LiveGameProcessingResult {
  const LiveGameProcessingResult({
    required this.snapshot,
    required this.timeline,
    required this.sessionId,
  });

  final Map<String, dynamic> snapshot;
  final Map<String, dynamic> timeline;
  final String sessionId;
}

class LiveGameProcessor {
  String? _sessionId;
  double? _lastGameTime;
  Map<String, dynamic>? _lastSnapshot;
  final List<Map<String, dynamic>> _goldPoints = [];
  final List<Map<String, dynamic>> _timelineEvents = [];
  final Set<String> _eventKeys = {};

  Map<String, dynamic>? get lastSnapshot =>
      _lastSnapshot == null ? null : Map<String, dynamic>.from(_lastSnapshot!);

  LiveGameProcessingResult process(
    Map<String, dynamic> raw, {
    required Map<int, Map<String, dynamic>> itemCatalog,
    Map<String, List<Map<String, dynamic>>> championAbilities = const {},
    String? gameId,
    DateTime? observedAt,
  }) {
    final gameData = _stringMap(raw['gameData']);
    final active = _stringMap(raw['activePlayer']);
    final rawPlayers = _mapList(raw['allPlayers']);
    final gameTime = (gameData['gameTime'] as num?)?.toDouble() ?? 0;
    final rosterSignature =
        rawPlayers
            .map((player) => _playerName(player))
            .where((name) => name.isNotEmpty)
            .toList()
          ..sort();
    final resolvedSessionId = gameId?.isNotEmpty == true
        ? gameId!
        : rosterSignature.join('|');
    if (_sessionId != resolvedSessionId ||
        (_lastGameTime != null && gameTime + 5 < _lastGameTime!)) {
      reset(sessionId: resolvedSessionId);
    }
    _sessionId ??= resolvedSessionId;

    final activeName = _firstNonEmpty([
      active['summonerName'],
      active['riotIdGameName'],
      active['displayName'],
    ]);
    final activeIdentity = _canonicalIdentity(activeName);
    final local = rawPlayers.where((player) {
      final names = {
        _canonicalIdentity(_playerName(player)),
        _canonicalIdentity(player['summonerName']),
        _canonicalIdentity(player['riotIdGameName']),
      };
      return activeIdentity.isNotEmpty && names.contains(activeIdentity);
    }).firstOrNull;
    final localTeam = local?['team']?.toString();

    Map<String, dynamic> normalizePlayer(Map<String, dynamic> value) {
      final scores = _stringMap(value['scores']);
      final items = _mapList(value['items'])
          .map((item) {
            final id = (item['itemID'] as num?)?.toInt() ?? 0;
            final catalog = itemCatalog[id];
            return {
              ...item,
              'name': catalog?['name'] ?? item['displayName'] ?? '',
              'icon_url': catalog == null
                  ? ''
                  : 'https://ddragon.leagueoflegends.com/cdn/'
                        '${catalog['_version']}/img/item/$id.png',
            };
          })
          .toList(growable: false);
      final cs = (scores['creepScore'] as num?)?.toInt() ?? 0;
      final kills = (scores['kills'] as num?)?.toInt() ?? 0;
      final deaths = (scores['deaths'] as num?)?.toInt() ?? 0;
      final assists = (scores['assists'] as num?)?.toInt() ?? 0;
      final inventoryGold = items.fold<int>(0, (total, item) {
        final id = (item['itemID'] as num?)?.toInt() ?? 0;
        final count = (item['count'] as num?)?.toInt() ?? 1;
        final gold = _stringMap(itemCatalog[id]?['gold']);
        return total + ((gold['total'] as num?)?.toInt() ?? 0) * count;
      });
      final currentGold = _samePlayer(value, local)
          ? (active['currentGold'] as num?)?.toInt() ?? 0
          : 0;
      final statisticalGold = _estimatedEarnedGold(
        gameTime: gameTime,
        creepScore: cs,
        kills: kills,
        assists: assists,
      );
      final observableGold = inventoryGold + currentGold;
      final goldTotal = math.max(observableGold, statisticalGold);
      final championName = value['championName']?.toString() ?? '';
      return {
        'champion_name': championName,
        'summoner_name': _playerName(value),
        'tag_line': value['riotIdTagLine'] ?? '',
        'team': value['team'] ?? '',
        'role': _canonicalRole(value['position']?.toString()),
        'level': value['level'] ?? 0,
        'kda': [kills, deaths, assists],
        'cs': cs,
        'items': items,
        'gold_total': goldTotal,
        'gold_observable': observableGold,
        'gold_estimated': statisticalGold,
        'gold_current': currentGold,
        'summoner_spells': _stringMap(value['summonerSpells']).values
            .whereType<Map>()
            .map((spell) => spell['displayName']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toList(growable: false),
        'runes': value['runes'] ?? const {},
        'abilities': championAbilities[_championKey(championName)] ?? const [],
        'position': null,
        'map_location': null,
        'is_mia': false,
        'mia_duration': 0.0,
        'last_known_location': null,
        'icon_url':
            'https://cdn.communitydragon.org/latest/champion/'
            '${Uri.encodeComponent(championName)}/square',
        'is_dead': value['isDead'] == true,
        'respawn_timer': value['respawnTimer'] ?? 0,
      };
    }

    final allies = rawPlayers
        .where((value) => value['team']?.toString() == localTeam)
        .map(normalizePlayer)
        .toList(growable: false);
    final enemies = rawPlayers
        .where((value) => value['team']?.toString() != localTeam)
        .map(normalizePlayer)
        .toList(growable: false);
    final allyGold = _teamGold(allies);
    final enemyGold = _teamGold(enemies);
    final teamGoldDiff = allyGold - enemyGold;
    final rawEvents = _mapList(_stringMap(raw['events'])['Events']);
    final enrichedEvents = _updateEvents(rawEvents, allies, enemies);
    final derived = _deriveState(
      gameTime: gameTime,
      events: rawEvents,
      allies: allies,
      enemies: enemies,
      localTeam: localTeam,
    );
    final laneStates = _laneStates(allies, enemies);
    final teamThreshold = math.max(
      750,
      ((allyGold + enemyGold) * 0.0125).round(),
    );
    final teamState = teamGoldDiff > teamThreshold
        ? 'AHEAD'
        : teamGoldDiff < -teamThreshold
        ? 'BEHIND'
        : 'EVEN';
    _appendGoldPoint(gameTime, teamGoldDiff);
    final activePlayer = local == null
        ? null
        : {
            ...normalizePlayer(local),
            'abilities': active['abilities'] ?? const {},
            'active_stats': active['championStats'] ?? const {},
          };
    final snapshot = <String, dynamic>{
      'game_time': gameTime,
      'timestamp': (observedAt ?? DateTime.now()).millisecondsSinceEpoch / 1000,
      'session_id': _sessionId,
      'game_mode': gameData['gameMode'] ?? '',
      'map_name': gameData['mapName'] ?? '',
      'map_number': gameData['mapNumber'],
      'map_terrain': gameData['mapTerrain'] ?? '',
      'phase': _phase(gameTime),
      'allies': allies,
      'enemies': enemies,
      'active_player': activePlayer,
      'team_gold_diff': teamGoldDiff,
      'team_state': teamState,
      'team_state_threshold': teamThreshold,
      'lane_states': laneStates,
      'events': enrichedEvents,
      'derived': derived,
      '_game_ended': false,
      'directives_pacing': const {},
    };
    _lastGameTime = gameTime;
    _lastSnapshot = snapshot;
    return LiveGameProcessingResult(
      snapshot: snapshot,
      timeline: _timeline(gameTime),
      sessionId: _sessionId!,
    );
  }

  Map<String, dynamic>? completeLast({DateTime? endedAt}) {
    final previous = _lastSnapshot;
    if (previous == null) return null;
    final completed = {
      ...previous,
      '_game_ended': true,
      'ended_at': (endedAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
    _lastSnapshot = completed;
    return completed;
  }

  Map<String, dynamic> currentTimeline() => _timeline(_lastGameTime ?? 0);

  void reset({String? sessionId}) {
    _sessionId = sessionId;
    _lastGameTime = null;
    _lastSnapshot = null;
    _goldPoints.clear();
    _timelineEvents.clear();
    _eventKeys.clear();
  }

  List<Map<String, dynamic>> _updateEvents(
    List<Map<String, dynamic>> rawEvents,
    List<Map<String, dynamic>> allies,
    List<Map<String, dynamic>> enemies,
  ) {
    final allyNames = _playerIdentifiers(allies);
    final enemyNames = _playerIdentifiers(enemies);
    for (final event in rawEvents) {
      final key = _eventKey(event);
      if (!_eventKeys.add(key)) continue;
      final actor = _firstNonEmpty([
        event['KillerName'],
        event['Acer'],
        event['Recipient'],
      ]).toLowerCase();
      final isAlly = allyNames.contains(actor)
          ? true
          : enemyNames.contains(actor)
          ? false
          : null;
      final time = (event['EventTime'] as num?)?.toDouble() ?? 0;
      _timelineEvents.add({
        ...event,
        'game_time': time,
        'game_time_fmt': _formatTime(time),
        'is_ally': isAlly,
        'label': _eventLabel(event),
      });
    }
    _timelineEvents.sort(
      (a, b) => ((b['game_time'] as num?) ?? 0).compareTo(
        (a['game_time'] as num?) ?? 0,
      ),
    );
    if (_timelineEvents.length > 500) {
      _timelineEvents.removeRange(500, _timelineEvents.length);
    }
    return List.unmodifiable(_timelineEvents);
  }

  Map<String, dynamic> _deriveState({
    required double gameTime,
    required List<Map<String, dynamic>> events,
    required List<Map<String, dynamic>> allies,
    required List<Map<String, dynamic>> enemies,
    required String? localTeam,
  }) {
    final allyNames = _playerIdentifiers(allies);
    final enemyNames = _playerIdentifiers(enemies);
    final dragonKills = {'ally': 0, 'enemy': 0};
    final structures = {
      'ally_turrets_destroyed': 0,
      'enemy_turrets_destroyed': 0,
      'ally_inhibitors_destroyed': 0,
      'enemy_inhibitors_destroyed': 0,
    };
    for (final event in events) {
      final name = event['EventName']?.toString() ?? '';
      final actor = event['KillerName']?.toString().toLowerCase() ?? '';
      final ally = allyNames.contains(actor);
      final enemy = enemyNames.contains(actor);
      if (name == 'DragonKill') {
        if (ally) dragonKills['ally'] = dragonKills['ally']! + 1;
        if (enemy) dragonKills['enemy'] = dragonKills['enemy']! + 1;
      }
      if (name == 'TurretKilled') {
        if (ally) {
          structures['enemy_turrets_destroyed'] =
              structures['enemy_turrets_destroyed']! + 1;
        } else if (enemy) {
          structures['ally_turrets_destroyed'] =
              structures['ally_turrets_destroyed']! + 1;
        }
      }
      if (name == 'InhibKilled') {
        if (ally) {
          structures['enemy_inhibitors_destroyed'] =
              structures['enemy_inhibitors_destroyed']! + 1;
        } else if (enemy) {
          structures['ally_inhibitors_destroyed'] =
              structures['ally_inhibitors_destroyed']! + 1;
        }
      }
    }
    return {
      'objectives': {
        'dragon': _objectiveState(
          gameTime,
          events,
          eventNames: const {'DragonKill'},
          initialSpawn: 300,
          respawnSeconds: 300,
        ),
        'baron': _objectiveState(
          gameTime,
          events,
          eventNames: const {'BaronKill'},
          initialSpawn: 1200,
          respawnSeconds: 360,
        ),
        'herald': _objectiveState(
          gameTime,
          events,
          eventNames: const {'HeraldKill'},
          initialSpawn: 840,
          respawnSeconds: null,
          unavailableAfter: 1185,
        ),
        'void_grubs': _objectiveState(
          gameTime,
          events,
          eventNames: const {'HordeKill'},
          initialSpawn: 360,
          respawnSeconds: 240,
          unavailableAfter: 840,
        ),
      },
      'structures': structures,
      'dragon_kills': dragonKills,
      'soul': dragonKills['ally']! >= 4
          ? 'ALLY'
          : dragonKills['enemy']! >= 4
          ? 'ENEMY'
          : 'NONE',
      'local_team': localTeam,
    };
  }

  Map<String, dynamic> _objectiveState(
    double gameTime,
    List<Map<String, dynamic>> events, {
    required Set<String> eventNames,
    required double initialSpawn,
    required double? respawnSeconds,
    double? unavailableAfter,
  }) {
    if (unavailableAfter != null && gameTime >= unavailableAfter) {
      return {'status': 'unavailable', 'respawn_in': null};
    }
    final kills = events.where(
      (event) => eventNames.contains(event['EventName']?.toString()),
    );
    final lastKill = kills.fold<double?>(null, (latest, event) {
      final time = (event['EventTime'] as num?)?.toDouble();
      if (time == null || (latest != null && latest >= time)) return latest;
      return time;
    });
    if (lastKill == null) {
      final remaining = math.max(0, initialSpawn - gameTime);
      return {
        'status': remaining == 0 ? 'alive' : 'spawning',
        'respawn_in': remaining,
      };
    }
    if (respawnSeconds == null) {
      return {'status': 'slain', 'respawn_in': null, 'last_kill': lastKill};
    }
    final remaining = math.max(0, lastKill + respawnSeconds - gameTime);
    return {
      'status': remaining == 0 ? 'alive' : 'respawning',
      'respawn_in': remaining,
      'last_kill': lastKill,
    };
  }

  Map<String, dynamic> _laneStates(
    List<Map<String, dynamic>> allies,
    List<Map<String, dynamic>> enemies,
  ) {
    final result = <String, dynamic>{};
    for (final ally in allies) {
      final role = ally['role']?.toString() ?? '';
      if (role.isEmpty || role == 'UNKNOWN') continue;
      final opponents = enemies.where((enemy) => enemy['role'] == role);
      if (opponents.isEmpty) continue;
      final enemy = opponents.first;
      final advantage = _lanePower(ally) - _lanePower(enemy);
      result[role] = {
        'state': advantage > 600
            ? 'AHEAD'
            : advantage < -600
            ? 'BEHIND'
            : 'EVEN',
        'advantage_score': advantage,
        'ally': ally['champion_name'],
        'enemy': enemy['champion_name'],
      };
    }
    return result;
  }

  int _lanePower(Map<String, dynamic> player) {
    final kda = player['kda'] is List ? player['kda'] as List : const [];
    final kills = kda.isNotEmpty ? (kda[0] as num?)?.toInt() ?? 0 : 0;
    final deaths = kda.length > 1 ? (kda[1] as num?)?.toInt() ?? 0 : 0;
    final assists = kda.length > 2 ? (kda[2] as num?)?.toInt() ?? 0 : 0;
    return ((player['gold_total'] as num?)?.toInt() ?? 0) +
        ((player['level'] as num?)?.toInt() ?? 0) * 350 +
        ((player['cs'] as num?)?.toInt() ?? 0) * 12 +
        kills * 250 +
        assists * 90 -
        deaths * 180;
  }

  void _appendGoldPoint(double gameTime, int value) {
    if (_goldPoints.isNotEmpty) {
      final previous = (_goldPoints.last['game_time'] as num).toDouble();
      if (gameTime - previous < 1) return;
    }
    _goldPoints.add({'game_time': gameTime, 'value': value});
    if (_goldPoints.length > 3600) _goldPoints.removeAt(0);
  }

  Map<String, dynamic> _timeline(double gameTime) {
    final recent = _goldPoints.where(
      (point) =>
          gameTime - ((point['game_time'] as num?)?.toDouble() ?? 0) <= 60,
    );
    final trend = recent.length < 2
        ? 0
        : ((recent.last['value'] as num?)?.toInt() ?? 0) -
              ((recent.first['value'] as num?)?.toInt() ?? 0);
    return {
      'gold_points': List.unmodifiable(_goldPoints),
      'gold_trend_60s': trend,
      'events': List.unmodifiable(_timelineEvents),
    };
  }

  int _estimatedEarnedGold({
    required double gameTime,
    required int creepScore,
    required int kills,
    required int assists,
  }) {
    final passive = math.max(0, gameTime - 110) * 2.04;
    return (500 + passive + creepScore * 20 + kills * 300 + assists * 100)
        .round();
  }

  int _teamGold(List<Map<String, dynamic>> players) => players.fold(
    0,
    (total, player) => total + ((player['gold_total'] as num?)?.toInt() ?? 0),
  );

  Set<String> _playerIdentifiers(List<Map<String, dynamic>> players) => {
    for (final player in players) ...{
      _canonicalIdentity(player['summoner_name']),
      _canonicalIdentity(player['champion_name']),
    },
  }..remove('');

  String _eventKey(Map<String, dynamic> event) {
    final id = event['EventID'];
    if (id != null) return 'id:$id';
    return jsonEncode([
      event['EventName'],
      event['EventTime'],
      event['KillerName'],
      event['VictimName'],
      event['TurretKilled'],
      event['InhibKilled'],
    ]);
  }

  String _eventLabel(Map<String, dynamic> event) {
    final name = event['EventName']?.toString() ?? 'Event';
    return switch (name) {
      'ChampionKill' =>
        '${event['KillerName'] ?? 'Unknown'} eliminó a ${event['VictimName'] ?? 'Unknown'}',
      'DragonKill' => 'Dragón: ${event['DragonType'] ?? 'unknown'}',
      'BaronKill' => 'Barón eliminado',
      'HeraldKill' => 'Heraldo eliminado',
      'HordeKill' => 'Engendros del Vacío eliminados',
      'TurretKilled' => 'Torre destruida',
      'InhibKilled' => 'Inhibidor destruido',
      'FirstBlood' => 'Primera sangre',
      'GameStart' => 'Comienza la partida',
      'GameEnd' => 'Termina la partida',
      _ => name,
    };
  }

  String _phase(double gameTime) => gameTime < 14 * 60
      ? 'EARLY'
      : gameTime < 25 * 60
      ? 'MID'
      : 'LATE';

  String _canonicalRole(String? value) {
    return switch (value?.toUpperCase()) {
      'TOP' => 'TOP',
      'JUNGLE' => 'JUNGLE',
      'MIDDLE' || 'MID' => 'MIDDLE',
      'BOTTOM' || 'BOT' || 'ADC' => 'BOTTOM',
      'UTILITY' || 'SUPPORT' => 'UTILITY',
      _ => 'UNKNOWN',
    };
  }

  String _playerName(Map<String, dynamic> value) => _firstNonEmpty([
    value['riotIdGameName'],
    value['summonerName'],
    value['displayName'],
  ]);

  bool _samePlayer(Map<String, dynamic> value, Map<String, dynamic>? other) =>
      other != null &&
      _canonicalIdentity(_playerName(value)) ==
          _canonicalIdentity(_playerName(other));

  String _canonicalIdentity(Object? value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    final tagSeparator = text.indexOf('#');
    return tagSeparator < 0 ? text : text.substring(0, tagSeparator).trim();
  }

  String _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _formatTime(double seconds) {
    final total = math.max(0, seconds).floor();
    final minutes = total ~/ 60;
    return '$minutes:${(total % 60).toString().padLeft(2, '0')}';
  }
}

String _championKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]"), '');

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
