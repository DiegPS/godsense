// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/identity/league_identity.dart';
import '../domain/league/account_context.dart';
import '../domain/league/local_scout.dart';

typedef LoadLocalMatches = Future<List<LocalMatchRecord>> Function(
  Puuid puuid, {
  int limit,
});

typedef LoadLocalRanked = Future<LocalRankedSnapshot?> Function(Puuid puuid);

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
    LocalScoutState initialState = const LocalScoutState(),
  }) : _loadMatches = loadMatches,
       _loadRanked = loadRanked,
       super(initialState);

  final LoadLocalMatches _loadMatches;
  final LoadLocalRanked _loadRanked;
  LeagueAccountProfile? _account;
  int _revision = 0;

  Future<void> loadAccount(LeagueAccountProfile? account) async {
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
      ]);
      if (revision != _revision) return;
      final matches = results[0] as List<LocalMatchRecord>;
      final ranked = results[1] as LocalRankedSnapshot?;
      state = LocalScoutState(
        profile: _profile(account, ranked),
        matches: matches.map(_matchSummary).toList(growable: false),
      );
    } catch (error) {
      if (revision != _revision) return;
      state = state.copyWith(loading: false, lastError: error.toString());
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
        selectedMatch: _matchDetail(match),
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
    'rank': {
      'tier': solo['tier'] ?? 'UNRANKED',
      'division': solo['division'] ?? solo['rank'] ?? '',
      'lp': solo['leaguePoints'] ?? solo['league_points'] ?? 0,
      'wins': wins,
      'losses': losses,
      'winrate': total == 0 ? 0 : (wins * 100 / total).round(),
    },
    'badges': const <Object?>[],
    'gpi': const <Object?>[],
    'local_only': true,
    'last_ranked_sync': ranked?.observedAt.toIso8601String(),
  };
}

Map<String, dynamic> _matchSummary(LocalMatchRecord record) {
  final summary = _map(_decode(record.summaryJson));
  final participant = _subjectParticipant(summary, record.puuid);
  return {
    'match_id': record.match.gameId,
    'result': participant['win'] == true
        ? 'Victoria'
        : participant['win'] == false
        ? 'Derrota'
        : 'Resultado local',
    'champion': {
      'name':
          participant['championName'] ??
          participant['champion_name'] ??
          'Partida ${record.match.gameId}',
    },
    'kills': participant['kills'] ?? 0,
    'deaths': participant['deaths'] ?? 0,
    'assists': participant['assists'] ?? 0,
    'role': participant['teamPosition'] ?? participant['role'] ?? '',
    'csm': 0,
    'patch': record.patch?.value,
    'queue_id': record.queueId,
    'started_at': record.startedAt?.toIso8601String(),
  };
}

Map<String, dynamic> _matchDetail(LocalMatchRecord record) {
  final details = _map(_decode(record.detailsJson ?? record.summaryJson));
  return {
    'match_id': record.match.gameId,
    'patch': record.patch?.value,
    'queue_id': record.queueId,
    'teams': _mapList(details['teams']),
    'players': _mapList(details['participants']),
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
  return participants
          .where((item) => item['puuid']?.toString() == puuid.value)
          .firstOrNull ??
      const {};
}

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
