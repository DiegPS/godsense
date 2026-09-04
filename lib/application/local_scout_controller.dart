// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/identity/league_identity.dart';
import '../domain/league/account_context.dart';
import '../domain/league/local_scout.dart';
import 'scout_profile_analyzer.dart';

export '../domain/league/scout_models.dart';

typedef LoadLocalMatches = Future<List<LocalMatchRecord>> Function(
  Puuid puuid, {
  int limit,
});

typedef LoadLocalRanked = Future<LocalRankedSnapshot?> Function(Puuid puuid);
typedef ResolveScoutAccount = Future<LeagueAccountProfile> Function({
  required String gameName,
  required String tagLine,
});
typedef SynchronizeScoutAccount = Future<LocalScoutSyncResult> Function(
  LeagueAccountProfile account, {
  Future<void> Function(LocalScoutSyncProgress progress)? onProgress,
});
typedef LoadChampionNames = Future<Map<int, String>> Function();
typedef LoadScoutMatchDetails = Future<LocalMatchRecord> Function(
  LocalMatchRecord cached,
);

class LocalScoutState {
  const LocalScoutState({
    this.loading = false,
    this.loadingLabel,
    this.subjectAccount,
    this.activeUserAccount,
    this.rankedSnapshot,
    this.analytics,
    this.typedMatches = const [],
    this.typedSelectedMatch,
    this.loadingMatchIds = const {},
    this.matchDetailErrors = const {},
    this.lastError,
    // Compatibility projections kept while callers migrate to typed models.
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>>? matches,
    Map<String, dynamic>? selectedMatch,
  }) : _compatibilityProfile = profile,
       _compatibilityMatches = matches,
       _compatibilitySelectedMatch = selectedMatch;

  final bool loading;
  final String? loadingLabel;
  final LeagueAccountProfile? subjectAccount;
  final AccountContext? activeUserAccount;
  final LocalRankedSnapshot? rankedSnapshot;
  final ScoutProfileAnalytics? analytics;
  final List<ScoutMatchSummary> typedMatches;
  final ScoutMatchSummary? typedSelectedMatch;
  final Set<int> loadingMatchIds;
  final Map<int, String> matchDetailErrors;
  final String? lastError;

  final Map<String, dynamic>? _compatibilityProfile;
  final List<Map<String, dynamic>>? _compatibilityMatches;
  final Map<String, dynamic>? _compatibilitySelectedMatch;

  /// Backwards-compatible profile map
  Map<String, dynamic> get profile {
    final compatibility = _compatibilityProfile;
    if (compatibility != null && compatibility.isNotEmpty) {
      return compatibility;
    }
    final account = subjectAccount;
    if (account == null) return const {};

    final rankedPayload = _map(_decode(rankedSnapshot?.payloadJson));
    final queueMap = _map(rankedPayload['queueMap']);
    final solo = _map(
      queueMap['RANKED_SOLO_5x5'] ??
          queueMap['RANKED_SOLO_5X5'] ??
          rankedPayload,
    );
    final wins = (solo['wins'] as num?)?.toInt() ?? 0;
    final losses = (solo['losses'] as num?)?.toInt() ?? 0;
    final total = wins + losses;

    return {
      'game_name': account.riotId?.gameName ?? 'Cuenta local',
      'tag_line': account.riotId?.tagLine ?? account.platformId.value,
      'profile_icon_id': account.profileIconId,
      'icon_url': account.profileIconId == null
          ? null
          : 'https://raw.communitydragon.org/latest/plugins/'
                'rcp-be-lol-game-data/global/default/v1/profile-icons/'
                '${account.profileIconId}.jpg',
      'rank': {
        'tier': solo['tier'] ?? 'UNRANKED',
        'division': solo['division'] ?? solo['rank'] ?? '',
        'lp': solo['leaguePoints'] ?? solo['league_points'] ?? 0,
        'wins': wins,
        'losses': losses,
        'winrate': total == 0 ? 0 : (wins * 100 / total).round(),
      },
      'sample_size': analytics?.gamesCount ?? 0,
      'badges': analytics?.badges ?? const [],
      'gpi': analytics?.gpi ?? const [],
      'signature_champions': analytics?.signatureChampions ?? const [],
      'local_only': false,
      'last_ranked_sync': rankedSnapshot?.observedAt.toIso8601String(),
    };
  }

  /// Backwards-compatible match list
  List<Map<String, dynamic>> get matches {
    final compatibility = _compatibilityMatches;
    if (compatibility != null && compatibility.isNotEmpty) {
      return compatibility;
    }
    return typedMatches
        .map((m) {
          return {
            'match_id': m.matchId,
            'result': m.isWin ? 'Victoria' : 'Derrota',
            'champion': {'name': m.championName, 'icon_url': m.championIconUrl},
            'kills': m.kills,
            'deaths': m.deaths,
            'assists': m.assists,
            'role': m.role.rawLane,
            'csm': m.csm,
            'patch': m.patch,
            'queue_id': m.queueId,
            'started_at': m.startedAt?.toIso8601String(),
          };
        })
        .toList(growable: false);
  }

  /// Backwards-compatible selected match detail
  Map<String, dynamic> get selectedMatch {
    final compatibility = _compatibilitySelectedMatch;
    if (compatibility != null && compatibility.isNotEmpty) {
      return compatibility;
    }
    final m = typedSelectedMatch;
    if (m == null) return const {};
    return {
      'match_id': m.matchId,
      'patch': m.patch,
      'queue_id': m.queueId,
      'timeline_available': m.hasFullDetails,
      'teams': m.teams,
      'players': m.participants
          .map(
            (p) => {
              'name': p.name,
              'tag': p.tag,
              'champion': {
                'name': p.championName,
                'icon_url': p.championIconUrl,
              },
              'role': p.role.label,
              'kills': p.kills,
              'deaths': p.deaths,
              'assists': p.assists,
              'cs': p.cs,
              'damage': p.damage,
              'is_subject': p.isSubject,
            },
          )
          .toList(),
    };
  }

  LocalScoutState copyWith({
    bool? loading,
    String? loadingLabel,
    LeagueAccountProfile? subjectAccount,
    AccountContext? activeUserAccount,
    LocalRankedSnapshot? rankedSnapshot,
    ScoutProfileAnalytics? analytics,
    List<ScoutMatchSummary>? typedMatches,
    ScoutMatchSummary? typedSelectedMatch,
    Set<int>? loadingMatchIds,
    Map<int, String>? matchDetailErrors,
    bool clearSubject = false,
    bool clearSelection = false,
    String? lastError,
    bool clearError = false,
    bool clearLoadingLabel = false,
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>>? matches,
    Map<String, dynamic>? selectedMatch,
  }) => LocalScoutState(
    loading: loading ?? this.loading,
    loadingLabel: clearLoadingLabel ? null : loadingLabel ?? this.loadingLabel,
    subjectAccount: clearSubject ? null : subjectAccount ?? this.subjectAccount,
    activeUserAccount: activeUserAccount ?? this.activeUserAccount,
    rankedSnapshot: rankedSnapshot ?? this.rankedSnapshot,
    analytics: analytics ?? this.analytics,
    typedMatches: typedMatches ?? this.typedMatches,
    loadingMatchIds: loadingMatchIds ?? this.loadingMatchIds,
    matchDetailErrors: matchDetailErrors ?? this.matchDetailErrors,
    typedSelectedMatch: clearSelection
        ? null
        : typedSelectedMatch ?? this.typedSelectedMatch,
    lastError: clearError ? null : lastError ?? this.lastError,
    profile: profile,
    matches: matches,
    selectedMatch: clearSelection ? const {} : selectedMatch,
  );
}

class LocalScoutController extends StateNotifier<LocalScoutState> {
  LocalScoutController({
    required LoadLocalMatches loadMatches,
    required LoadLocalRanked loadRanked,
    ResolveScoutAccount? resolveAccount,
    SynchronizeScoutAccount? synchronizeAccount,
    LoadChampionNames? loadChampionNames,
    LoadScoutMatchDetails? loadMatchDetails,
    ScoutProfileAnalyzer analyzer = const ScoutProfileAnalyzer(),
    LocalScoutState initialState = const LocalScoutState(),
  }) : _loadMatches = loadMatches,
       _loadRanked = loadRanked,
       _resolveAccount = resolveAccount,
       _synchronizeAccount = synchronizeAccount,
       _loadChampionNames = loadChampionNames,
       _loadMatchDetails = loadMatchDetails,
       _analyzer = analyzer,
       super(initialState);

  final LoadLocalMatches _loadMatches;
  final LoadLocalRanked _loadRanked;
  final ResolveScoutAccount? _resolveAccount;
  final SynchronizeScoutAccount? _synchronizeAccount;
  final LoadChampionNames? _loadChampionNames;
  final LoadScoutMatchDetails? _loadMatchDetails;
  final ScoutProfileAnalyzer _analyzer;
  Map<int, String> _championNames = const {};
  LeagueAccountProfile? _subjectAccount;
  LeagueAccountProfile? _connectedAccount;
  bool _showingConnectedAccount = true;
  int _revision = 0;
  int _detailRevision = 0;

  Future<void> loadAccount(LeagueAccountProfile? account) async {
    _connectedAccount = account;
    if (account == null) {
      if (_showingConnectedAccount) {
        _revision++;
        _detailRevision++;
        _subjectAccount = null;
        state = const LocalScoutState();
      }
      return;
    }
    if (!_showingConnectedAccount) {
      return;
    }
    _showingConnectedAccount = true;
    _subjectAccount = account;
    await _hydrate(account, synchronizeIfAvailable: true);
  }

  Future<void> searchRiotId({
    required String gameName,
    required String tagLine,
  }) async {
    final resolver = _resolveAccount;
    if (resolver == null) {
      state = state.copyWith(lastError: 'Resolución de cuentas no disponible.');
      return;
    }

    final revision = ++_revision;
    _detailRevision++;
    state = state.copyWith(
      loading: true,
      loadingLabel: 'Buscando invocador $gameName#$tagLine…',
      loadingMatchIds: const {},
      matchDetailErrors: const {},
      clearError: true,
    );

    try {
      final account = await resolver(gameName: gameName, tagLine: tagLine);
      if (revision != _revision) return;
      _showingConnectedAccount = false;
      _subjectAccount = account;
      _detailRevision++;
      state = LocalScoutState(
        loading: true,
        subjectAccount: account,
        activeUserAccount: state.activeUserAccount,
        loadingLabel: 'Invocador encontrado. Sincronizando historial…',
      );
      await _hydrate(account, synchronizeIfAvailable: true);
    } catch (error) {
      if (revision != _revision) return;
      state = state.copyWith(
        loading: false,
        clearLoadingLabel: true,
        lastError: error.toString(),
      );
    }
  }

  Future<void> useConnectedAccount() async {
    final connected = _connectedAccount;
    if (connected == null) {
      state = state.copyWith(
        lastError: 'No hay cuenta conectada al cliente de League.',
      );
      return;
    }
    _showingConnectedAccount = true;
    _subjectAccount = connected;
    await _hydrate(connected, synchronizeIfAvailable: true);
  }

  Future<void> refresh() async {
    final account = _subjectAccount ?? _connectedAccount;
    if (account == null) return;
    await _hydrate(account, synchronizeIfAvailable: true);
  }

  Future<void> _hydrate(
    LeagueAccountProfile account, {
    required bool synchronizeIfAvailable,
  }) async {
    final revision = ++_revision;
    final subjectChanged =
        state.subjectAccount?.puuid != account.puuid ||
        state.subjectAccount?.platformId != account.platformId;
    if (subjectChanged) {
      _detailRevision++;
      state = LocalScoutState(
        subjectAccount: account,
        activeUserAccount: state.activeUserAccount,
      );
    }
    state = state.copyWith(
      loading: true,
      loadingLabel: 'Cargando datos locales…',
      loadingMatchIds: subjectChanged ? const {} : null,
      matchDetailErrors: subjectChanged ? const {} : null,
      clearSelection: subjectChanged,
      clearError: true,
    );

    try {
      await _ensureChampionNames();
      if (revision != _revision) return;

      var ranked = await _loadRanked(account.puuid);
      var records = await _loadMatches(account.puuid, limit: 30);
      if (revision != _revision) return;

      final analytics = _analyzer.analyze(
        records,
        puuid: account.puuid,
        championNames: _championNames,
      );

      final typedMatches = records
          .map((r) => _buildMatchSummary(r, account.puuid, _championNames))
          .toList(growable: false);

      state = state.copyWith(
        subjectAccount: account,
        rankedSnapshot: ranked,
        analytics: analytics,
        typedMatches: _preserveLoadedDetails(typedMatches, account),
        loading: synchronizeIfAvailable && _synchronizeAccount != null,
        loadingLabel: synchronizeIfAvailable && _synchronizeAccount != null
            ? 'Sincronizando con League Client…'
            : null,
        clearError: true,
      );

      final syncService = _synchronizeAccount;
      if (synchronizeIfAvailable && syncService != null) {
        final syncResult = await syncService(
          account,
          onProgress: (progress) async {
            if (revision != _revision) return;
            state = state.copyWith(
              loading: true,
              loadingLabel: _progressLabel(progress),
            );
          },
        );

        if (revision != _revision) return;
        ranked = await _loadRanked(account.puuid);
        records = await _loadMatches(account.puuid, limit: 30);
        if (revision != _revision) return;

        final freshAnalytics = _analyzer.analyze(
          records,
          puuid: account.puuid,
          championNames: _championNames,
        );

        final freshTypedMatches = records
            .map((r) => _buildMatchSummary(r, account.puuid, _championNames))
            .toList(growable: false);

        state = state.copyWith(
          loading: false,
          clearLoadingLabel: true,
          subjectAccount: account,
          rankedSnapshot: ranked,
          analytics: freshAnalytics,
          typedMatches: _preserveLoadedDetails(freshTypedMatches, account),
          lastError: syncResult.error,
        );
      } else {
        state = state.copyWith(loading: false, clearLoadingLabel: true);
      }
    } catch (error) {
      if (revision != _revision) return;
      state = state.copyWith(
        loading: false,
        clearLoadingLabel: true,
        lastError: error.toString(),
      );
    }
  }

  Future<void> _ensureChampionNames() async {
    if (_championNames.isNotEmpty) return;
    final loader = _loadChampionNames;
    if (loader == null) return;
    try {
      _championNames = await loader();
    } catch (_) {}
  }

  List<ScoutMatchSummary> _preserveLoadedDetails(
    List<ScoutMatchSummary> matches,
    LeagueAccountProfile account,
  ) {
    if (state.subjectAccount?.puuid != account.puuid ||
        state.subjectAccount?.platformId != account.platformId) {
      return matches;
    }
    final loaded = {
      for (final match in state.typedMatches)
        if (match.hasFullDetails) match.matchId: match,
    };
    return [
      for (final match in matches)
        if (!match.hasFullDetails && loaded.containsKey(match.matchId))
          loaded[match.matchId]!
        else
          match,
    ];
  }

  Future<void> selectMatch(int gameId) async {
    final account =
        state.subjectAccount ?? _subjectAccount ?? _connectedAccount;
    if (account == null || state.loadingMatchIds.contains(gameId)) return;
    final revision = _detailRevision;
    state = state.copyWith(
      loadingMatchIds: {...state.loadingMatchIds, gameId},
      matchDetailErrors: {...state.matchDetailErrors}..remove(gameId),
    );
    try {
      final matches = await _loadMatches(account.puuid, limit: 100);
      if (revision != _detailRevision) return;
      var match = matches
          .where(
            (item) =>
                item.match.gameId == gameId &&
                item.match.platformId == account.platformId,
          )
          .firstOrNull;
      if (match == null) {
        throw StateError('La partida $gameId no está en caché.');
      }
      var typedSummary = _buildMatchSummary(
        match,
        account.puuid,
        _championNames,
      );
      if (!typedSummary.hasFullDetails) {
        final loader = _loadMatchDetails;
        if (loader == null) {
          throw StateError(
            'Conecta League para cargar los detalles de esta partida.',
          );
        }
        match = await loader(match);
        if (revision != _detailRevision) return;
        typedSummary = _buildMatchSummary(match, account.puuid, _championNames);
        if (!typedSummary.hasFullDetails) {
          throw StateError(
            'League devolvió detalles incompletos para esta partida.',
          );
        }
      }
      state = state.copyWith(
        typedSelectedMatch: typedSummary,
        typedMatches: [
          for (final item in state.typedMatches)
            if (item.matchId == gameId) typedSummary else item,
        ],
        clearError: true,
      );
    } catch (error) {
      if (revision != _detailRevision) return;
      state = state.copyWith(
        matchDetailErrors: {
          ...state.matchDetailErrors,
          gameId: error is StateError
              ? error.message
              : 'No se pudieron cargar los detalles. Vuelve a intentarlo.',
        },
      );
    } finally {
      if (revision == _detailRevision) {
        state = state.copyWith(
          loadingMatchIds: {...state.loadingMatchIds}..remove(gameId),
        );
      }
    }
  }

  @override
  void dispose() {
    _revision++;
    _detailRevision++;
    super.dispose();
  }
}

String _progressLabel(LocalScoutSyncProgress progress) =>
    switch (progress.stage) {
      LocalScoutSyncStage.ranked => 'Rango recibido. Solicitando partidas…',
      LocalScoutSyncStage.matches =>
        '${progress.completed} partidas recibidas. Cargando detalles…',
      LocalScoutSyncStage.documents =>
        'Detalles ${progress.completed}/${progress.total} recibidos…',
    };

ScoutMatchSummary _buildMatchSummary(
  LocalMatchRecord record,
  Puuid puuid,
  Map<int, String> championNames,
) {
  final summary = _map(_decode(record.summaryJson));
  final detailsJson = record.detailsJson;
  final details = detailsJson != null ? _map(_decode(detailsJson)) : summary;
  final persistedTimeline = _map(_decode(record.timelineJson));

  final summaryParticipant = _subjectParticipant(summary, puuid);
  final detailParticipant = _subjectParticipant(details, puuid);
  final participant = {
    ...summaryParticipant,
    ...detailParticipant,
    'stats': {
      ..._map(summaryParticipant['stats']),
      ..._map(detailParticipant['stats']),
    },
    'timeline': {
      ..._map(summaryParticipant['timeline']),
      ..._map(detailParticipant['timeline']),
    },
  };
  final stats = _map(participant['stats']);
  final timeline = _map(participant['timeline']);
  final championId = (participant['championId'] as num?)?.toInt() ?? 0;
  final seconds =
      ((details['gameDuration'] ?? summary['gameDuration']) as num?)
          ?.toDouble() ??
      0;
  final durationMinutes = seconds <= 0 ? 0.0 : seconds / 60;

  final kills = (stats['kills'] as num?)?.toInt() ?? 0;
  final deaths = (stats['deaths'] as num?)?.toInt() ?? 0;
  final assists = (stats['assists'] as num?)?.toInt() ?? 0;
  final cs =
      ((stats['totalMinionsKilled'] as num?)?.toInt() ?? 0) +
      ((stats['neutralMinionsKilled'] as num?)?.toInt() ?? 0);
  final csm = durationMinutes <= 0
      ? 0.0
      : (cs / durationMinutes * 10).round() / 10;
  final kdaRatio = (kills + assists) / (deaths <= 0 ? 1 : deaths);
  final isWin = stats['win'] == true || participant['win'] == true;

  final role = ScoutRole.parse(
    timeline['lane']?.toString(),
    timeline['role']?.toString() ?? participant['role']?.toString(),
  );

  final patchVersion = record.patch?.value ?? '14.17.1';
  final championName =
      participant['championName']?.toString() ??
      championNames[championId] ??
      'Partida ${record.match.gameId}';

  // 7 Items list (items 0 to 6)
  final items = <int>[
    (stats['item0'] as num?)?.toInt() ?? 0,
    (stats['item1'] as num?)?.toInt() ?? 0,
    (stats['item2'] as num?)?.toInt() ?? 0,
    (stats['item3'] as num?)?.toInt() ?? 0,
    (stats['item4'] as num?)?.toInt() ?? 0,
    (stats['item5'] as num?)?.toInt() ?? 0,
    (stats['item6'] as num?)?.toInt() ?? 0, // Trinket / Ward
  ];

  final spell1Id = (participant['spell1Id'] as num?)?.toInt();
  final spell2Id = (participant['spell2Id'] as num?)?.toInt();
  final champLevel = (stats['champLevel'] as num?)?.toInt();
  final damage = (stats['totalDamageDealtToChampions'] as num?)?.toInt();
  final gold = (stats['goldEarned'] as num?)?.toInt();
  final visionScore = (stats['visionScore'] as num?)?.toInt();
  final objectiveDamage =
      (stats['damageDealtToObjectives'] as num?)?.toInt() ?? 0;

  // Compute team kills for KP%
  final teamId = (participant['teamId'] as num?)?.toInt();
  final allParticipants = _mapList(details['participants']);
  int teamKills = 0;
  if (teamId != null) {
    for (final p in allParticipants) {
      if ((p['teamId'] as num?)?.toInt() == teamId) {
        final pStats = _map(p['stats']);
        teamKills += (pStats['kills'] as num?)?.toInt() ?? 0;
      }
    }
  }

  final killParticipation = teamKills > 0
      ? ((kills + assists) / teamKills * 1000).round() / 10
      : null;

  final performanceScore = ScoutProfileAnalyzer.calculatePerformanceScore(
    role: role,
    kills: kills,
    deaths: deaths,
    assists: assists,
    cs: cs,
    durationMinutes: durationMinutes,
    damage: damage ?? 0,
    teamKills: teamKills,
    visionScore: visionScore ?? 0,
    objectiveDamage: objectiveDamage,
  );

  // Teams & 5v5 Participants if details available
  final teams = <Map<String, dynamic>>[];
  final participantsList = <ScoutMatchParticipant>[];

  if (details.isNotEmpty && details['participants'] != null) {
    final identityById = <int, Map<String, dynamic>>{};
    for (final identity in _mapList(details['participantIdentities'])) {
      final id = (identity['participantId'] as num?)?.toInt();
      if (id != null) identityById[id] = _map(identity['player']);
    }

    for (final t in _mapList(details['teams'])) {
      final tId = (t['teamId'] as num?)?.toInt();
      teams.add({
        'team_id': tId,
        'side': tId == 100
            ? 'Azul'
            : tId == 200
            ? 'Rojo'
            : '$tId',
        'win': t['win'] == true || t['win'] == 'Win',
        'kills': 0,
        'barons': t['baronKills'] ?? 0,
        'drakes': t['dragonKills'] ?? 0,
        'towers': t['towerKills'] ?? 0,
      });
    }

    for (final p in _mapList(details['participants'])) {
      final pId = (p['participantId'] as num?)?.toInt() ?? 0;
      final pIdentity = identityById[pId] ?? const <String, dynamic>{};
      final pStats = _map(p['stats']);
      final pTimeline = _map(p['timeline']);
      final pChampId = (p['championId'] as num?)?.toInt() ?? 0;
      final pPuuid = pIdentity['puuid']?.toString() ?? '';
      final pTeamId = (p['teamId'] as num?)?.toInt();
      final pRole = ScoutRole.parse(
        pTimeline['lane']?.toString(),
        pTimeline['role']?.toString(),
      );
      final pKills = (pStats['kills'] as num?)?.toInt() ?? 0;
      final pDeaths = (pStats['deaths'] as num?)?.toInt() ?? 0;
      final pAssists = (pStats['assists'] as num?)?.toInt() ?? 0;
      final pCs =
          ((pStats['totalMinionsKilled'] as num?)?.toInt() ?? 0) +
          ((pStats['neutralMinionsKilled'] as num?)?.toInt() ?? 0);
      final pDmg =
          (pStats['totalDamageDealtToChampions'] as num?)?.toInt() ?? 0;
      final pGold = (pStats['goldEarned'] as num?)?.toInt() ?? 0;
      final pVision = (pStats['visionScore'] as num?)?.toInt() ?? 0;
      final pItems = <int>[
        (pStats['item0'] as num?)?.toInt() ?? 0,
        (pStats['item1'] as num?)?.toInt() ?? 0,
        (pStats['item2'] as num?)?.toInt() ?? 0,
        (pStats['item3'] as num?)?.toInt() ?? 0,
        (pStats['item4'] as num?)?.toInt() ?? 0,
        (pStats['item5'] as num?)?.toInt() ?? 0,
        (pStats['item6'] as num?)?.toInt() ?? 0,
      ];

      participantsList.add(
        ScoutMatchParticipant(
          participantId: pId,
          puuid: pPuuid,
          name:
              pIdentity['gameName']?.toString() ??
              pIdentity['summonerName']?.toString() ??
              'Invocador',
          tag: pIdentity['tagLine']?.toString() ?? '',
          championId: pChampId,
          championName: championNames[pChampId] ?? '$pChampId',
          championIconUrl: _championIcon(pChampId),
          role: pRole,
          kills: pKills,
          deaths: pDeaths,
          assists: pAssists,
          cs: pCs,
          damage: pDmg,
          gold: pGold,
          visionScore: pVision,
          items: pItems,
          isSubject: pPuuid == puuid.value,
          isAlly: teamId != null && pTeamId == teamId,
        ),
      );
    }
  }

  final subjectParticipantId =
      (participant['participantId'] as num?)?.toInt() ?? 0;
  final timelineProjection = _projectTimeline(
    persistedTimeline,
    subjectParticipantId: subjectParticipantId,
  );

  final queueId = record.queueId;
  final queueLabel = queueId == 420
      ? 'Clasificatoria Solo/Dúo'
      : queueId == 440
      ? 'Clasificatoria Flexible'
      : queueId == 450
      ? 'ARAM'
      : queueId == 400
      ? 'Normal Reclutamiento'
      : 'Partida';

  return ScoutMatchSummary(
    matchId: record.match.gameId,
    queueId: queueId,
    queueLabel: queueLabel,
    startedAt: record.startedAt,
    durationMinutes: durationMinutes,
    isWin: isWin,
    patch: patchVersion,
    championId: championId,
    championName: championName,
    championIconUrl: championId > 0 ? _championIcon(championId) : null,
    championLevel: champLevel,
    role: role,
    kills: kills,
    deaths: deaths,
    assists: assists,
    kdaRatio: (kdaRatio * 100).round() / 100,
    cs: cs,
    csm: csm,
    damage: damage,
    gold: gold,
    visionScore: visionScore,
    killParticipation: killParticipation,
    items: items,
    spell1IconUrl: spell1Id != null ? _spellIcon(spell1Id, patchVersion) : null,
    spell2IconUrl: spell2Id != null ? _spellIcon(spell2Id, patchVersion) : null,
    performanceScore: performanceScore,
    hasFullDetails: detailsJson != null && participantsList.isNotEmpty,
    teams: teams,
    participants: participantsList,
    timelineEvents: timelineProjection.events,
    goldTimeline: timelineProjection.gold,
  );
}

({List<ScoutTimelineEvent> events, List<ScoutGoldTimelinePoint> gold})
_projectTimeline(
  Map<String, dynamic> timeline, {
  required int subjectParticipantId,
}) {
  final frames = _mapList(timeline['frames']);
  if (frames.isEmpty) return (events: const [], gold: const []);
  final subjectIsBlue = subjectParticipantId > 0 && subjectParticipantId <= 5;
  final events = <ScoutTimelineEvent>[];
  final gold = <ScoutGoldTimelinePoint>[];

  for (final frame in frames) {
    final timestamp = (frame['timestamp'] as num?)?.toInt() ?? 0;
    final participantFrames = _map(frame['participantFrames']);
    if (participantFrames.isNotEmpty && subjectParticipantId > 0) {
      var blueGold = 0;
      var redGold = 0;
      for (final entry in participantFrames.entries) {
        final participantId = int.tryParse(entry.key.toString()) ?? 0;
        final totalGold =
            (_map(entry.value)['totalGold'] as num?)?.toInt() ?? 0;
        if (participantId <= 5) {
          blueGold += totalGold;
        } else {
          redGold += totalGold;
        }
      }
      gold.add(
        ScoutGoldTimelinePoint(
          timestampMilliseconds: timestamp,
          difference: subjectIsBlue ? blueGold - redGold : redGold - blueGold,
        ),
      );
    }

    for (final event in _mapList(frame['events'])) {
      final type = event['type']?.toString() ?? '';
      final eventTimestamp = (event['timestamp'] as num?)?.toInt() ?? timestamp;
      final teamId = (event['teamId'] as num?)?.toInt();
      final killerId = (event['killerId'] as num?)?.toInt();
      final actorId = killerId != null && killerId > 0
          ? killerId
          : (event['creatorId'] as num?)?.toInt();
      final isAlly = teamId != null
          ? (subjectIsBlue ? teamId == 100 : teamId == 200)
          : actorId != null && actorId > 0
          ? (subjectIsBlue ? actorId <= 5 : actorId > 5)
          : null;
      final label = _timelineEventLabel(type, event);
      if (label == null) continue;
      events.add(
        ScoutTimelineEvent(
          timestampMilliseconds: eventTimestamp,
          type: type,
          label: label,
          isAlly: isAlly,
        ),
      );
    }
  }
  events.sort(
    (left, right) =>
        left.timestampMilliseconds.compareTo(right.timestampMilliseconds),
  );
  return (events: List.unmodifiable(events), gold: List.unmodifiable(gold));
}

String? _timelineEventLabel(String type, Map<String, dynamic> event) =>
    switch (type) {
      'CHAMPION_KILL' => 'Eliminación de campeón',
      'ELITE_MONSTER_KILL' => switch (event['monsterType']?.toString()) {
        'DRAGON' => 'Dragón',
        'BARON_NASHOR' => 'Barón Nashor',
        'RIFTHERALD' => 'Heraldo de la Grieta',
        final value when value != null && value.isNotEmpty => value,
        _ => 'Objetivo épico',
      },
      'BUILDING_KILL' =>
        event['buildingType'] == 'INHIBITOR_BUILDING'
            ? 'Inhibidor destruido'
            : 'Torre destruida',
      'TURRET_PLATE_DESTROYED' => 'Placa de torre',
      'WARD_PLACED' => 'Visión colocada',
      _ => null,
    };

String _championIcon(int championId) =>
    'https://raw.communitydragon.org/latest/plugins/'
    'rcp-be-lol-game-data/global/default/v1/champion-icons/$championId.png';

String _spellIcon(int spellId, String patch) =>
    'https://raw.communitydragon.org/latest/plugins/'
    'rcp-be-lol-game-data/global/default/data/spells/icons2d/$spellId.png';

Object? _decode(String? value) {
  if (value == null) return null;
  try {
    return jsonDecode(value);
  } on FormatException {
    return null;
  }
}

Map<String, dynamic> _subjectParticipant(
  Map<String, dynamic> payload,
  Puuid puuid,
) {
  final participants = _mapList(payload['participants']);
  final identity = _mapList(payload['participantIdentities'])
      .where((item) => _map(item['player'])['puuid']?.toString() == puuid.value)
      .firstOrNull;
  if (identity == null) {
    return participants
            .where((item) => item['puuid']?.toString() == puuid.value)
            .firstOrNull ??
        const {};
  }
  final participantId = (identity['participantId'] as num?)?.toInt();
  final participant = participants
      .where(
        (item) => (item['participantId'] as num?)?.toInt() == participantId,
      )
      .firstOrNull;
  return {...?participant, ..._map(identity['player'])};
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : const {};

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false)
    : const [];
