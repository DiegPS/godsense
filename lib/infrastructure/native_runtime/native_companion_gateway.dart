import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/companion_gateway.dart';
import '../../domain/tactical/tactical_models.dart';
import 'native_support_service.dart';

typedef TacticalAnalysisCallback = Map<String, dynamic> Function({
  Map<String, dynamic>? lobby,
  Map<String, dynamic>? game,
  String? selectedEnemy,
});

typedef TacticalDirectivesCallback = List<TacticalAdvice> Function(
  Map<String, dynamic>? game,
);

class NativeCompanionGateway implements CompanionGateway {
  NativeCompanionGateway({
    Future<SharedPreferences> Function()? preferences,
    Map<String, dynamic>? Function()? lobbySnapshot,
    Map<String, dynamic>? Function()? gameSnapshot,
    this._tacticalAnalysis,
    this._tacticalDirectives,
    NativeSupportService? support,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _lobbySnapshot = lobbySnapshot ?? (() => null),
       _gameSnapshot = gameSnapshot ?? (() => null),
       _support = support ?? NativeSupportService();

  final Future<SharedPreferences> Function() _preferences;
  final Map<String, dynamic>? Function() _lobbySnapshot;
  final Map<String, dynamic>? Function() _gameSnapshot;
  final TacticalAnalysisCallback? _tacticalAnalysis;
  final TacticalDirectivesCallback? _tacticalDirectives;
  final NativeSupportService _support;
  final StreamController<Map<String, dynamic>> _alerts =
      StreamController<Map<String, dynamic>>.broadcast();

  static const _settingsKey = 'native_companion_settings_v1';
  Map<String, dynamic>? _settingsCache;
  String? _selectedEnemy;

  @override
  Future<Map<String, dynamic>> health() async => {
    'status': 'ok',
    'game_detected': _gameSnapshot() != null,
    'degraded': false,
    'runtime': 'in_process',
    'components': {
      for (final name in ['tick', 'gank', 'cv', 'tts', 'publisher'])
        name: {'alive': true},
    },
  };

  @override
  Future<Map<String, dynamic>> coaching() async =>
      _tacticalAnalysis?.call(
        lobby: _lobbySnapshot(),
        game: _gameSnapshot(),
        selectedEnemy: _selectedEnemy,
      ) ??
      const {};

  @override
  Future<Map<String, dynamic>> coachingStatus() async => const {
    'runtime': 'in_process',
    'matchup_refresh_in_progress': false,
  };

  @override
  Future<List<Map<String, dynamic>>> directives() async =>
      (_tacticalDirectives?.call(_gameSnapshot()) ?? const <TacticalAdvice>[])
          .map((item) => item.toJson())
          .toList(growable: false);

  @override
  Future<Map<String, dynamic>> players() async => const {};

  @override
  Future<Map<String, dynamic>> config() async => const {
    'runtime': 'in_process',
  };

  @override
  Future<Map<String, dynamic>> lobbyState() async =>
      _lobbySnapshot() ??
      const {
        'phase': 'NO_LCU',
        'brief_ready': false,
        'snapshot': {
          'my_team': <Object?>[],
          'their_team': <Object?>[],
          'all_locked': false,
        },
      };

  @override
  Future<Map<String, dynamic>> lobbyHealth() async => const {
    'runtime': 'in_process',
    'healthy': true,
  };

  @override
  Future<Map<String, dynamic>> generateLobbyBrief(String candidate) async {
    _selectedEnemy = candidate.trim().isEmpty ? null : candidate.trim();
    return {
      'accepted': _selectedEnemy != null,
      'candidate': _selectedEnemy,
      'coaching': await coaching(),
    };
  }

  @override
  Future<Map<String, dynamic>> settings() async => {
    'settings': await _loadSettings(),
    'meta': const {
      'runtime': 'in_process',
      'cadence_editable': true,
      'highlights_editable': false,
      'highlights_ready': false,
      'language_restart_required': false,
      'locks': <String, Object?>{},
    },
  };

  @override
  Future<Map<String, dynamic>> updateSettings(
    Map<String, dynamic> patch,
  ) async {
    final current = await _loadSettings();
    final next = {...current, ..._sanitizeSettings(patch)};
    _settingsCache = next;
    final preferences = await _preferences();
    await preferences.setStringList(
      _settingsKey,
      next.entries
          .map((entry) => '${entry.key}\u0000${_encode(entry.value)}')
          .toList(),
    );
    return {
      'updated': _sanitizeSettings(patch).keys.toList(),
      'settings': next,
    };
  }

  @override
  Future<Map<String, dynamic>> testVoice() async => const {
    'ok': true,
    'runtime': 'native_sherpa',
    'message': 'Use the native speech test in Voice settings.',
  };

  @override
  Future<Map<String, dynamic>> highlights() async => const {
    'enabled': false,
    'clips': <Object?>[],
  };

  @override
  Uri highlightClipUri(int slot) =>
      Uri(scheme: 'godsense', host: 'local-highlight', path: '/$slot');

  @override
  Future<Map<String, dynamic>> importAll() async => const {
    'ok': false,
    'reason': 'Use the native League import action.',
  };

  @override
  Future<Map<String, dynamic>> scoutSummoner({
    required String name,
    required String tag,
    required String region,
  }) async => {
    'game_name': name,
    'tag_line': tag,
    'region': region,
    'matches': const <Object?>[],
    'local_only': true,
  };

  @override
  Future<Map<String, dynamic>> scoutMatch({
    required int matchId,
    required String region,
    required String name,
    required String tag,
  }) async => {
    'match_id': matchId,
    'region': region,
    'players': const <Object?>[],
    'teams': const <Object?>[],
    'local_only': true,
  };

  @override
  Future<Map<String, dynamic>> createSupportBundle() async => _support
      .createBundle(settings: await _loadSettings(), health: await health());

  @override
  Future<Map<String, dynamic>> reportSupport({String? note}) =>
      _support.saveReport(note ?? '');

  @override
  Stream<Map<String, dynamic>> alertEvents() => _alerts.stream;

  void publishAlert(Map<String, dynamic> event) {
    if (!_alerts.isClosed) _alerts.add(Map.unmodifiable(event));
  }

  @override
  Future<void> closeAlerts() => _alerts.close();

  Future<Map<String, dynamic>> _loadSettings() async {
    final cached = _settingsCache;
    if (cached != null) return Map.of(cached);
    final preferences = await _preferences();
    final entries = preferences.getStringList(_settingsKey) ?? const [];
    final loaded = <String, dynamic>{..._defaultSettings};
    for (final entry in entries) {
      final separator = entry.indexOf('\u0000');
      if (separator < 1) continue;
      final key = entry.substring(0, separator);
      final value = _decode(entry.substring(separator + 1));
      if (_allowedSettingKeys.contains(key)) loaded[key] = value;
    }
    return Map.of(_settingsCache = loaded);
  }
}

class InProcessCompanionRuntime implements CompanionRuntime, CoachRuntime {
  const InProcessCompanionRuntime();

  @override
  Future<bool> ensureStarted() async => true;

  @override
  void dispose() {}
}

class NativeCoachHealthGateway implements CoachGateway {
  const NativeCoachHealthGateway();

  @override
  Future<Map<String, dynamic>> health() async => const {
    'status': 'ok',
    'runtime': 'in_process',
    'opencode': {'state': 'not_required'},
  };
}

const _defaultSettings = <String, dynamic>{
  'ptt_key': 'delete',
  'tts_enabled': true,
  'tts_volume': 1.0,
  'language': 'auto',
  'cadence': 'normal',
  'highlights_enabled': false,
  'overlay_hidden_panels': <String>[],
};

const _allowedSettingKeys = <String>{
  'ptt_key',
  'tts_enabled',
  'tts_volume',
  'language',
  'cadence',
  'highlights_enabled',
  'overlay_hidden_panels',
};

Map<String, dynamic> _sanitizeSettings(Map<String, dynamic> patch) => {
  for (final entry in patch.entries)
    if (_allowedSettingKeys.contains(entry.key)) entry.key: entry.value,
};

String _encode(Object? value) => switch (value) {
  bool value => 'b:${value ? 1 : 0}',
  num value => 'n:$value',
  List value => 'l:${value.map((item) => item.toString()).join('\u001f')}',
  _ => 's:${value ?? ''}',
};

Object _decode(String value) {
  if (value.startsWith('b:')) return value.substring(2) == '1';
  if (value.startsWith('n:')) return num.tryParse(value.substring(2)) ?? 0;
  if (value.startsWith('l:')) {
    final body = value.substring(2);
    return body.isEmpty ? <String>[] : body.split('\u001f');
  }
  return value.startsWith('s:') ? value.substring(2) : value;
}
