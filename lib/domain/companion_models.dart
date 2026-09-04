import 'league/draft_models.dart';

enum CompanionConnection { connecting, online, offline }

class ComponentHealth {
  const ComponentHealth({
    required this.alive,
    this.lastBeatAgeSeconds,
    this.error,
  });

  factory ComponentHealth.fromJson(Map<String, dynamic> json) {
    return ComponentHealth(
      alive: json['alive'] == true,
      lastBeatAgeSeconds: (json['last_beat_age_s'] as num?)?.toDouble(),
      error: json['error'] as String?,
    );
  }

  final bool alive;
  final double? lastBeatAgeSeconds;
  final String? error;
}

class CompanionHealth {
  const CompanionHealth({
    required this.status,
    required this.gameDetected,
    required this.degraded,
    required this.components,
  });

  factory CompanionHealth.fromJson(Map<String, dynamic> json) {
    final components = _map(json['components']);
    return CompanionHealth(
      status: json['status'] as String? ?? 'unknown',
      gameDetected: json['game_detected'] == true,
      degraded: json['degraded'] == true,
      components: components.map(
        (key, value) => MapEntry(key, ComponentHealth.fromJson(_map(value))),
      ),
    );
  }

  final String status;
  final bool gameDetected;
  final bool degraded;
  final Map<String, ComponentHealth> components;
}

class GameSnapshot {
  const GameSnapshot({
    required this.gameTime,
    required this.phase,
    required this.gameEnded,
    required this.allies,
    required this.enemies,
    required this.events,
    required this.raw,
  });

  factory GameSnapshot.fromJson(Map<String, dynamic> json) {
    return GameSnapshot(
      gameTime: (json['game_time'] as num?)?.toDouble() ?? 0,
      phase: json['phase']?.toString() ?? 'unknown',
      gameEnded: json['_game_ended'] == true,
      allies: _mapList(json['allies']),
      enemies: _mapList(json['enemies']),
      events: _mapList(json['events']),
      raw: json,
    );
  }

  final double gameTime;
  final String phase;
  final bool gameEnded;
  final List<Map<String, dynamic>> allies;
  final List<Map<String, dynamic>> enemies;
  final List<Map<String, dynamic>> events;
  final Map<String, dynamic> raw;
}

class LobbyState {
  const LobbyState({
    required this.phase,
    required this.briefReady,
    required this.myTeam,
    required this.enemyTeam,
    required this.allLocked,
    this.draft = DraftSnapshot.empty,
    this.candidate,
    this.timerPhase,
    this.timeLeftMilliseconds,
    this.builds,
    this.pickAdvice = const [],
    this.compAnalysis,
  });

  factory LobbyState.fromJson(Map<String, dynamic> json) {
    final snapshot = _map(json['snapshot']);
    return LobbyState(
      phase: json['phase']?.toString() ?? 'NO_LCU',
      briefReady: json['brief_ready'] == true,
      myTeam: _mapList(snapshot['my_team']),
      enemyTeam: _mapList(snapshot['their_team']),
      allLocked: snapshot['all_locked'] == true,
      draft: DraftSnapshot.fromMap(snapshot),
      candidate: json['candidate'] as String?,
      timerPhase: snapshot['timer_phase']?.toString(),
      timeLeftMilliseconds: (snapshot['time_left_ms'] as num?)?.toInt(),
      builds: _nullableMap(json['builds']),
      pickAdvice: _mapList(json['pick_advice']),
      compAnalysis: _nullableMap(json['comp_analysis']),
    );
  }

  final String phase;
  final bool briefReady;
  final List<Map<String, dynamic>> myTeam;
  final List<Map<String, dynamic>> enemyTeam;
  final bool allLocked;
  final DraftSnapshot draft;
  final String? candidate;
  final String? timerPhase;
  final int? timeLeftMilliseconds;
  final Map<String, dynamic>? builds;
  final List<Map<String, dynamic>> pickAdvice;
  final Map<String, dynamic>? compAnalysis;

  bool get lcuConnected => phase != 'NO_LCU';

  Map<String, dynamic>? get localPlayer {
    for (final player in myTeam) {
      if (player['is_local'] == true) return player;
    }
    return null;
  }

  int get lockedEnemyCount =>
      enemyTeam.where((player) => player['locked'] == true).length;
}

class CalibrationState {
  const CalibrationState({
    required this.calibrated,
    required this.recalibrationSuggested,
    this.bounds,
    this.iconSize,
    this.confidence,
    this.defaultBounds,
    this.defaultIconSize,
    this.defaultTrustworthy = false,
    this.provenance,
  });

  factory CalibrationState.fromJson(Map<String, dynamic> json) {
    return CalibrationState(
      calibrated: json['calibrated'] == true,
      recalibrationSuggested: json['recalibration_suggested'] == true,
      bounds: _nullableMap(json['bounds']),
      iconSize: (json['icon_size'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      defaultBounds: _nullableMap(json['default_bounds']),
      defaultIconSize: (json['default_icon_size'] as num?)?.toDouble(),
      defaultTrustworthy: json['default_trustworthy'] == true,
      provenance: _nullableMap(json['provenance']),
    );
  }

  final bool calibrated;
  final bool recalibrationSuggested;
  final Map<String, dynamic>? bounds;
  final double? iconSize;
  final double? confidence;
  final Map<String, dynamic>? defaultBounds;
  final double? defaultIconSize;
  final bool defaultTrustworthy;
  final Map<String, dynamic>? provenance;

  bool boundsAreUsable(Map<String, dynamic>? value) {
    if (value == null) return false;
    final width = (value['width'] as num?)?.toDouble() ?? 0;
    final height = (value['height'] as num?)?.toDouble() ?? 0;
    if (width < trackingIconSize || height < trackingIconSize) return false;
    final ratio = width / height;
    return ratio >= 0.75 && ratio <= 1.33;
  }

  Map<String, dynamic>? get effectiveBounds =>
      boundsAreUsable(bounds) ? bounds : defaultBounds;
  Map<String, dynamic>? get trackingBounds {
    if (boundsAreUsable(bounds)) return bounds;
    if (defaultTrustworthy && boundsAreUsable(defaultBounds)) {
      return defaultBounds;
    }
    return null;
  }

  int get trackingIconSize => (iconSize ?? defaultIconSize ?? 28).round();
}

class CoachDirective {
  const CoachDirective({
    required this.id,
    required this.title,
    required this.hints,
    required this.rationale,
    required this.ttsText,
  });

  factory CoachDirective.fromJson(Map<String, dynamic> json) {
    return CoachDirective(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Directive',
      hints: _stringList(json['hints']),
      rationale: json['rationale']?.toString() ?? '',
      ttsText: json['tts_text']?.toString() ?? '',
    );
  }

  final String id;
  final String title;
  final List<String> hints;
  final String rationale;
  final String ttsText;
}

class CompanionSettings {
  const CompanionSettings({
    required this.pttKey,
    required this.ttsEnabled,
    required this.ttsVolume,
    required this.language,
    required this.cadence,
    required this.overlayHiddenPanels,
    required this.meta,
  });

  factory CompanionSettings.fromJson(Map<String, dynamic> response) {
    final json = _map(response['settings']);
    return CompanionSettings(
      pttKey: json['ptt_key']?.toString() ?? 'delete',
      ttsEnabled: json['tts_enabled'] != false,
      ttsVolume: (json['tts_volume'] as num?)?.toDouble() ?? 1,
      language: json['language']?.toString() ?? 'auto',
      cadence: json['cadence']?.toString() ?? 'normal',
      overlayHiddenPanels: _stringList(json['overlay_hidden_panels']),
      meta: _map(response['meta']),
    );
  }

  final String pttKey;
  final bool ttsEnabled;
  final double ttsVolume;
  final String language;
  final String cadence;
  final List<String> overlayHiddenPanels;
  final Map<String, dynamic> meta;
}

enum CompanionAlertKind {
  junglerSighting,
  gank,
  voice,
  calibrationNeeded,
  overlayVisibility,
  overlayEdit,
  unknown,
}

class CompanionAlert {
  const CompanionAlert({
    required this.kind,
    required this.title,
    required this.message,
    required this.receivedAt,
    required this.raw,
  });

  factory CompanionAlert.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString();
    final kind = switch (type) {
      'jungler_sighting' => CompanionAlertKind.junglerSighting,
      'voice_ask' => CompanionAlertKind.voice,
      'calibration_needed' => CompanionAlertKind.calibrationNeeded,
      'overlay_visibility' => CompanionAlertKind.overlayVisibility,
      'overlay_edit' => CompanionAlertKind.overlayEdit,
      _ when json.containsKey('champion_name') => CompanionAlertKind.gank,
      _ => CompanionAlertKind.unknown,
    };
    final (title, message) = switch (kind) {
      CompanionAlertKind.junglerSighting => (
        '${json['champion'] ?? 'Enemy jungler'} sighted',
        '${json['location'] ?? json['region'] ?? 'Unknown location'}',
      ),
      CompanionAlertKind.gank => (
        '${json['threat_level'] ?? 'Warning'}: ${json['champion_name'] ?? 'Gank'}',
        '${json['zone'] ?? 'Nearby'} · ${json['role'] ?? 'enemy'}',
      ),
      CompanionAlertKind.voice => (
        'Voice coach',
        '${json['text'] ?? json['state'] ?? json['reason'] ?? ''}',
      ),
      CompanionAlertKind.calibrationNeeded => (
        'Minimap calibration needed',
        'Open Vision settings to calibrate the tracker.',
      ),
      CompanionAlertKind.overlayVisibility => (
        'Overlay visibility',
        json['visible'] == true ? 'Visible' : 'Hidden',
      ),
      CompanionAlertKind.overlayEdit => (
        'Overlay edit mode',
        json['edit'] == true ? 'Enabled' : 'Disabled',
      ),
      CompanionAlertKind.unknown => ('Evento de GodSense', type ?? 'Evento'),
    };
    return CompanionAlert(
      kind: kind,
      title: title,
      message: message,
      receivedAt: DateTime.now(),
      raw: json,
    );
  }

  final CompanionAlertKind kind;
  final String title;
  final String message;
  final DateTime receivedAt;
  final Map<String, dynamic> raw;

  bool get isVisibleAlert =>
      kind == CompanionAlertKind.junglerSighting ||
      kind == CompanionAlertKind.gank ||
      kind == CompanionAlertKind.voice ||
      kind == CompanionAlertKind.calibrationNeeded;
}

class CompanionState {
  const CompanionState({
    this.connection = CompanionConnection.connecting,
    this.webSocketConnected = false,
    this.health,
    this.lobby,
    this.lobbyHealth = const {},
    this.settings,
    this.coaching = const {},
    this.coachingStatus = const {},
    this.directives = const [],
    this.alerts = const [],
    this.lastError,
    this.operationInProgress = false,
    this.lastOperationResult = const {},
  });

  final CompanionConnection connection;
  final bool webSocketConnected;
  final CompanionHealth? health;
  final LobbyState? lobby;
  final Map<String, dynamic> lobbyHealth;
  final CompanionSettings? settings;
  final Map<String, dynamic> coaching;
  final Map<String, dynamic> coachingStatus;
  final List<CoachDirective> directives;
  final List<CompanionAlert> alerts;
  final String? lastError;
  final bool operationInProgress;
  final Map<String, dynamic> lastOperationResult;

  CompanionState copyWith({
    CompanionConnection? connection,
    bool? webSocketConnected,
    CompanionHealth? health,
    LobbyState? lobby,
    Map<String, dynamic>? lobbyHealth,
    CompanionSettings? settings,
    Map<String, dynamic>? coaching,
    Map<String, dynamic>? coachingStatus,
    List<CoachDirective>? directives,
    List<CompanionAlert>? alerts,
    String? lastError,
    bool clearError = false,
    bool? operationInProgress,
    Map<String, dynamic>? lastOperationResult,
  }) {
    return CompanionState(
      connection: connection ?? this.connection,
      webSocketConnected: webSocketConnected ?? this.webSocketConnected,
      health: health ?? this.health,
      lobby: lobby ?? this.lobby,
      lobbyHealth: lobbyHealth ?? this.lobbyHealth,
      settings: settings ?? this.settings,
      coaching: coaching ?? this.coaching,
      coachingStatus: coachingStatus ?? this.coachingStatus,
      directives: directives ?? this.directives,
      alerts: alerts ?? this.alerts,
      lastError: clearError ? null : lastError ?? this.lastError,
      operationInProgress: operationInProgress ?? this.operationInProgress,
      lastOperationResult: lastOperationResult ?? this.lastOperationResult,
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

Map<String, dynamic>? _nullableMap(Object? value) {
  return value is Map ? _map(value) : null;
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map(_map).toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}
