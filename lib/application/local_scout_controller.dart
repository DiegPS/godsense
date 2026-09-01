// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/identity/league_identity.dart';
import '../domain/league/account_context.dart';
import '../domain/league/local_scout.dart';
import 'scout_profile_analyzer.dart';

typedef LoadLocalMatches = Future<List<LocalMatchRecord>> Function(
  Puuid puuid, {
  int limit,
});

typedef LoadLocalRanked = Future<LocalRankedSnapshot?> Function(Puuid puuid);
typedef ResolveScoutAccount = Future<LeagueAccountProfile> Function({
  required String gameName,
  required String tagLine,
});
typedef LoadChampionNames = Future<Map<int, String>> Function();

class LocalScoutState {
  const LocalScoutState({
    this.loading = false,
    this.profile = const {},
    this.matches = const [],
    this.selectedMatch = const {},
    this.lastError,
  });

  final bool loading;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> matches;
  final Map<String, dynamic> selectedMatch;
  final String? lastError;

  LocalScoutState copyWith({
    bool? loading,
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>>? matches,
    Map<String, dynamic>? selectedMatch,
    bool clearSelection = false,
    String? lastError,
    bool clearError = false,
  }) => LocalScoutState(
    loading: loading ?? this.loading,
    profile: profile ?? this.profile,
    matches: matches ?? this.matches,
    selectedMatch: clearSelection
        ? const {}
        : selectedMatch ?? this.selectedMatch,
    lastError: clearError ? null : lastError ?? this.lastError,
  );
}

class LocalScoutController extends StateNotifier<LocalScoutState> {
  LocalScoutController({
    required LoadLocalMatches loadMatches,
    required LoadLocalRanked loadRanked,
    ResolveScoutAccount? resolveAccount,
    LoadChampionNames? loadChampionNames,
    ScoutProfileAnalyzer analyzer = const ScoutProfileAnalyzer(),
    LocalScoutState initialState = const LocalScoutState(),
  }) : _loadMatches = loadMatches,
       _loadRanked = loadRanked,
       _resolveAccount = resolveAccount,
       _loadChampionNames = loadChampionNames,
       _analyzer = analyzer,
       super(initialState);

  final LoadLocalMatches _loadMatches;
  final LoadLocalRanked _loadRanked;
  final ResolveScoutAccount? _resolveAccount;
  final LoadChampionNames? _loadChampionNames;
  final ScoutProfileAnalyzer _analyzer;
  Map<int, String> _championNames = const {};
  LeagueAccountProfile? _account;
  LeagueAccountProfile? _connectedAccount;
  int _revision = 0;

  Future<void> loadAccount(LeagueAccountProfile? account) async {
    _connectedAccount = account;
    await _showAccount(account);
  }

  Future<void> _showAccount(LeagueAccountProfile? account) async {
    _account = account;
    final revision = ++_revision;
    if (account == null) {
      state = const LocalScoutState();
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait<Object?>([
        _loadMatches(account.puuid, limit: 30),
        _loadRanked(account.puuid),
        _loadChampionNamesSafely(),
      ]);
      if (revision != _revision) return;
      final matches = results[0] as List<LocalMatchRecord>;
      final ranked = results[1] as LocalRankedSnapshot?;
      _championNames = results[2] as Map<int, String>;
      final analytics = _analyzer.analyze(
        matches,
        puuid: account.puuid,
        championNames: _championNames,
      );
      state = LocalScoutState(
        profile: _profile(account, ranked, analytics),
        matches: matches
            .map((match) => _matchSummary(match, _championNames))
            .toList(growable: false),
      );
    } catch (error) {
      if (revision != _revision) return;
      state = state.copyWith(loading: false, lastError: error.toString());
    }
  }

  Future<void> searchRiotId({
    required String gameName,
    required String tagLine,
  }) async {
    final resolver = _resolveAccount;
    if (resolver == null) {
      state = state.copyWith(lastError: 'La búsqueda LCU no está disponible.');
      return;
    }
    final revision = ++_revision;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final account = await resolver(gameName: gameName, tagLine: tagLine);
      if (revision != _revision) return;
      _account = account;
      final results = await Future.wait<Object?>([
        _loadMatches(account.puuid, limit: 30),
        _loadRanked(account.puuid),
        _loadChampionNamesSafely(),
      ]);
      if (revision != _revision) return;
      final matches = results[0] as List<LocalMatchRecord>;
      final ranked = results[1] as LocalRankedSnapshot?;
      _championNames = results[2] as Map<int, String>;
      final analytics = _analyzer.analyze(
        matches,
        puuid: account.puuid,
        championNames: _championNames,
      );
      state = LocalScoutState(
        profile: _profile(account, ranked, analytics),
        matches: matches
            .map((match) => _matchSummary(match, _championNames))
            .toList(growable: false),
      );
    } catch (error) {
      if (revision != _revision) return;
      state = state.copyWith(loading: false, lastError: error.toString());
    }
  }

  Future<void> useConnectedAccount() => _showAccount(_connectedAccount);

  Future<Map<int, String>> _loadChampionNamesSafely() async {
    try {
      return await _loadChampionNames?.call() ?? _championNames;
    } catch (_) {
      return _championNames;
    }
  }

  Future<void> refresh() => loadAccount(_account);

  Future<void> selectMatch(int gameId) async {
    final account = _account;
    if (account == null) return;
    final revision = _revision;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final matches = await _loadMatches(account.puuid, limit: 100);
      if (revision != _revision) return;
      final match = matches
          .where((item) => item.match.gameId == gameId)
          .firstOrNull;
      if (match == null) {
        throw StateError('La partida $gameId no está en caché.');
      }
      state = state.copyWith(
        loading: false,
        selectedMatch: _matchDetail(match, _championNames),
      );
    } catch (error) {
      if (revision != _revision) return;
      state = state.copyWith(loading: false, lastError: error.toString());
    }
  }

  @override
  void dispose() {
    _revision++;
    super.dispose();
  }
}

Map<String, dynamic> _profile(
  LeagueAccountProfile account,
  LocalRankedSnapshot? ranked,
  ScoutProfileAnalytics analytics,
) {
  final rankedPayload = _map(_decode(ranked?.payloadJson));
  final queueMap = _map(rankedPayload['queueMap']);
  final solo = _map(
    queueMap['RANKED_SOLO_5x5'] ?? queueMap['RANKED_SOLO_5X5'] ?? rankedPayload,
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
    'sample_size': analytics.games,
    'badges': analytics.badges,
    'gpi': analytics.gpi,
    'signature_champions': analytics.signatureChampions,
    'local_only': false,
    'last_ranked_sync': ranked?.observedAt.toIso8601String(),
  };
}

Map<String, dynamic> _matchSummary(
  LocalMatchRecord record,
  Map<int, String> championNames,
) {
  final summary = _map(_decode(record.summaryJson));
  final participant = _subjectParticipant(summary, record.puuid);
  final stats = _map(participant['stats']);
  final timeline = _map(participant['timeline']);
  final championId = (participant['championId'] as num?)?.toInt();
  final durationMinutes =
      ((summary['gameDuration'] as num?)?.toDouble() ?? 0) / 60;
  final cs =
      ((stats['totalMinionsKilled'] as num?)?.toInt() ?? 0) +
      ((stats['neutralMinionsKilled'] as num?)?.toInt() ?? 0);
  return {
    'match_id': record.match.gameId,
    'result': stats['win'] == true || participant['win'] == true
        ? 'Victoria'
        : stats['win'] == false || participant['win'] == false
        ? 'Derrota'
        : 'Resultado local',
    'champion': {
      'name':
          participant['championName'] ??
          championNames[championId] ??
          participant['champion_name'] ??
          'Partida ${record.match.gameId}',
      'icon_url': championId == null ? null : _championIcon(championId),
    },
    'kills': stats['kills'] ?? participant['kills'] ?? 0,
    'deaths': stats['deaths'] ?? participant['deaths'] ?? 0,
    'assists': stats['assists'] ?? participant['assists'] ?? 0,
    'role': timeline['lane'] ?? timeline['role'] ?? participant['role'] ?? '',
    'csm': durationMinutes <= 0 ? 0 : (cs / durationMinutes * 10).round() / 10,
    'patch': record.patch?.value,
    'queue_id': record.queueId,
    'started_at': record.startedAt?.toIso8601String(),
  };
}

Map<String, dynamic> _matchDetail(
  LocalMatchRecord record,
  Map<int, String> championNames,
) {
  final details = _map(_decode(record.detailsJson ?? record.summaryJson));
  final identityById = <int, Map<String, dynamic>>{};
  for (final identity in _mapList(details['participantIdentities'])) {
    final id = (identity['participantId'] as num?)?.toInt();
    if (id != null) identityById[id] = _map(identity['player']);
  }
  final teams = _mapList(details['teams'])
      .map((team) {
        final teamId = (team['teamId'] as num?)?.toInt();
        return {
          'side': teamId == 100
              ? 'Azul'
              : teamId == 200
              ? 'Rojo'
              : '$teamId',
          'win': team['win'] == true || team['win'] == 'Win',
          'kills': 0,
          'barons': team['baronKills'] ?? 0,
          'drakes': team['dragonKills'] ?? 0,
          'towers': team['towerKills'] ?? 0,
        };
      })
      .toList(growable: false);
  final players = _mapList(details['participants'])
      .map((participant) {
        final participantId = (participant['participantId'] as num?)?.toInt();
        final player = identityById[participantId] ?? const <String, dynamic>{};
        final stats = _map(participant['stats']);
        final timeline = _map(participant['timeline']);
        final championId = (participant['championId'] as num?)?.toInt();
        return {
          'name': player['gameName'] ?? player['summonerName'] ?? '',
          'tag': player['tagLine'] ?? '',
          'champion': {
            'name': championNames[championId] ?? '$championId',
            'icon_url': championId == null ? null : _championIcon(championId),
          },
          'role': [timeline['lane'], timeline['role']]
              .where((value) => value != null && value.toString().isNotEmpty)
              .join(' · '),
          'kills': stats['kills'] ?? 0,
          'deaths': stats['deaths'] ?? 0,
          'assists': stats['assists'] ?? 0,
          'cs':
              ((stats['totalMinionsKilled'] as num?)?.toInt() ?? 0) +
              ((stats['neutralMinionsKilled'] as num?)?.toInt() ?? 0),
          'damage': stats['totalDamageDealtToChampions'] ?? 0,
          'is_subject': player['puuid']?.toString() == record.puuid.value,
        };
      })
      .toList(growable: false);
  return {
    'match_id': record.match.gameId,
    'patch': record.patch?.value,
    'queue_id': record.queueId,
    'teams': teams,
    'players': players,
    'raw': details,
    'timeline_available': record.timelineJson != null,
    'synced_at': record.syncedAt.toIso8601String(),
  };
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

String _championIcon(int championId) =>
    'https://raw.communitydragon.org/latest/plugins/'
    'rcp-be-lol-game-data/global/default/v1/champion-icons/$championId.png';

Object? _decode(String? value) {
  if (value == null) return null;
  try {
    return jsonDecode(value);
  } on FormatException {
    return null;
  }
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
