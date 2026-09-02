import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/companion_models.dart';
import '../domain/summoners_rift_map.dart';
import '../infrastructure/native_vision/dartcv_minimap_tracker.dart';
import '../infrastructure/native_vision/native_minimap_calibrator.dart';
import '../infrastructure/native_vision/win32_screen_capture.dart';
import '../infrastructure/native_vision/vision_icon_cache.dart';

enum TrackerLogSource { native, legacy }

class TrackerLogEntry {
  const TrackerLogEntry({
    required this.timestamp,
    required this.source,
    required this.event,
    required this.message,
    this.detectionCount,
  });

  final DateTime timestamp;
  final TrackerLogSource source;
  final String event;
  final String message;
  final int? detectionCount;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'source': source.name,
    'event': event,
    'message': message,
    'detection_count': detectionCount,
  };
}

class NativeVisionState {
  const NativeVisionState({
    this.running = false,
    this.processing = false,
    this.fps = 0,
    this.frame,
    this.bounds,
    this.logs = const [],
    this.error,
    this.identified = const {},
    this.lastKnown = const {},
    this.averageCvMilliseconds = 0,
    this.p95CvMilliseconds = 0,
    this.averageCaptureMilliseconds = 0,
    this.calibrationProposal,
    this.events = const [],
    this.workingSetBytes = 0,
  });

  final bool running;
  final bool processing;
  final double fps;
  final NativeVisionFrame? frame;
  final Map<String, dynamic>? bounds;
  final List<TrackerLogEntry> logs;
  final String? error;
  final Map<String, NativeIdentifiedChampion> identified;
  final Map<String, NativeIdentifiedChampion> lastKnown;
  final double averageCvMilliseconds;
  final double p95CvMilliseconds;
  final double averageCaptureMilliseconds;
  final NativeCalibrationResult? calibrationProposal;
  final List<NativeTrackerEvent> events;
  final int workingSetBytes;

  NativeVisionState copyWith({
    bool? running,
    bool? processing,
    double? fps,
    NativeVisionFrame? frame,
    Map<String, dynamic>? bounds,
    List<TrackerLogEntry>? logs,
    String? error,
    bool clearError = false,
    Map<String, NativeIdentifiedChampion>? identified,
    Map<String, NativeIdentifiedChampion>? lastKnown,
    double? averageCvMilliseconds,
    double? p95CvMilliseconds,
    double? averageCaptureMilliseconds,
    NativeCalibrationResult? calibrationProposal,
    List<NativeTrackerEvent>? events,
    int? workingSetBytes,
  }) {
    return NativeVisionState(
      running: running ?? this.running,
      processing: processing ?? this.processing,
      fps: fps ?? this.fps,
      frame: frame ?? this.frame,
      bounds: bounds ?? this.bounds,
      logs: logs ?? this.logs,
      error: clearError ? null : error ?? this.error,
      identified: identified ?? this.identified,
      lastKnown: lastKnown ?? this.lastKnown,
      averageCvMilliseconds:
          averageCvMilliseconds ?? this.averageCvMilliseconds,
      p95CvMilliseconds: p95CvMilliseconds ?? this.p95CvMilliseconds,
      averageCaptureMilliseconds:
          averageCaptureMilliseconds ?? this.averageCaptureMilliseconds,
      calibrationProposal: calibrationProposal ?? this.calibrationProposal,
      events: events ?? this.events,
      workingSetBytes: workingSetBytes ?? this.workingSetBytes,
    );
  }
}

enum NativeTrackerEventKind { gank, junglerSighting }

class NativeTrackerEvent {
  const NativeTrackerEvent({
    required this.kind,
    required this.champion,
    required this.location,
    required this.region,
    required this.timestamp,
    this.role,
    this.unseenSeconds = 0,
  });

  final NativeTrackerEventKind kind;
  final String champion;
  final String location;
  final String region;
  final DateTime timestamp;
  final String? role;
  final double unseenSeconds;
}

class _NativeSightingState {
  _NativeSightingState({
    required this.lastSeen,
    required this.lastRegion,
    required this.lastAlertAt,
  });

  DateTime lastSeen;
  String lastRegion;
  DateTime lastAlertAt;
}

class NativeIdentifiedChampion {
  const NativeIdentifiedChampion({
    required this.name,
    required this.region,
    required this.x,
    required this.y,
    required this.confidence,
    required this.lastSeen,
  });

  final String name;
  final String region;
  final double x;
  final double y;
  final double confidence;
  final DateTime lastSeen;
}

final nativeVisionProvider =
    StateNotifierProvider<NativeVisionController, NativeVisionState>((ref) {
      return NativeVisionController();
    });

class NativeVisionController extends StateNotifier<NativeVisionState> {
  NativeVisionController({
    Win32ScreenCapture? capture,
    DartCvMinimapTracker? tracker,
    VisionIconCache? iconCache,
  }) : _capture = capture ?? Win32ScreenCapture(),
       _tracker = tracker ?? DartCvMinimapTracker(),
       _iconCache = iconCache ?? VisionIconCache(),
       super(const NativeVisionState());

  final Win32ScreenCapture _capture;
  final DartCvMinimapTracker _tracker;
  Timer? _timer;
  int _framesSinceSample = 0;
  int _iconSize = 28;
  DateTime _fpsSample = DateTime.now();
  bool _loggedCaptureStart = false;
  Future<void> _logWriteQueue = Future.value();
  String _targetSignature = '';
  String? _loadingTargetSignature;
  bool _targetsUpdating = false;
  final VisionIconCache _iconCache;
  int _targetGeneration = 0;
  int? _targetIconSize;
  String _rosterKey = '';
  String _requestedTargetSignature = '';
  DateTime? _targetAttempt;
  bool _disposed = false;
  String? _lastErrorMessage;
  DateTime? _lastErrorLoggedAt;
  int _previewFrame = 0;
  final List<int> _cvSamples = [];
  final List<int> _captureSamples = [];
  int _performanceLogFrame = 0;
  bool _calibrating = false;
  DateTime? _lastCalibrationAttempt;
  String _localRole = '';
  Map<String, String> _enemyRoles = const {};
  final Set<String> _activeGanks = {};
  final Map<String, _NativeSightingState> _sightingStates = {};

  void configure({
    required bool enabled,
    required Map<String, dynamic>? bounds,
    int iconSize = 28,
  }) {
    if (!enabled) {
      stop();
      return;
    }
    if (bounds == null) {
      stop();
      state = state.copyWith(error: 'Calibrando minimapa automáticamente…');
      final now = DateTime.now();
      if (!_calibrating &&
          (_lastCalibrationAttempt == null ||
              now.difference(_lastCalibrationAttempt!).inSeconds >= 10)) {
        _lastCalibrationAttempt = now;
        unawaited(_autoDetectAndStart());
      }
      return;
    }
    final width = (bounds['width'] as num?)?.round() ?? 0;
    final height = (bounds['height'] as num?)?.round() ?? 0;
    final ratio = height == 0 ? double.infinity : width / height;
    if (width < iconSize || height < iconSize || ratio < 0.75 || ratio > 1.33) {
      stop();
      state = state.copyWith(
        error:
            'Bounds inválidos ${width}x$height para icono ${iconSize}px. '
            'El minimapa debe ser aproximadamente cuadrado.',
      );
      return;
    }
    state = state.copyWith(bounds: bounds);
    _iconSize = iconSize;
    if (state.running) return;
    state = state.copyWith(running: true, clearError: true);
    _timer = Timer.periodic(
      const Duration(milliseconds: 167),
      (_) => unawaited(_captureAndProcess()),
    );
    unawaited(_captureAndProcess());
  }

  Future<void> configureTargets(
    List<Map<String, dynamic>> enemies, {
    String? localRole,
    required int iconSize,
  }) async {
    _localRole = localRole?.toUpperCase() ?? '';
    _enemyRoles = {
      for (final enemy in enemies)
        if ((enemy['champion_name']?.toString() ?? '').isNotEmpty)
          enemy['champion_name'].toString():
              enemy['role']?.toString().toUpperCase() ?? 'UNKNOWN',
    };
    final tracked = enemies;
    final entries = tracked
        .map(
          (enemy) => (
            name: enemy['champion_name']?.toString() ?? '',
            urls: _visionAssetUrls(enemy),
          ),
        )
        .where((entry) => entry.name.isNotEmpty)
        .toList();
    if (_disposed || iconSize < 4) return;
    final names = entries.map((entry) => entry.name).toList()..sort();
    final rosterKey = names.join('|');
    if (rosterKey != _rosterKey) {
      _rosterKey = rosterKey;
      _targetGeneration++;
      _targetSignature = '';
      _targetAttempt = null;
      _targetIconSize = null;
      _tracker.setTargets(const {}, iconSize: iconSize);
      _activeGanks.clear();
      _sightingStates.clear();
      state = state.copyWith(
        identified: const {},
        lastKnown: const {},
        events: const [],
      );
    }
    if (entries.isEmpty) return;

    // Templates and live crops MUST use exactly the same calibrated size.
    final stableIconSize = iconSize;
    final signature = [
      stableIconSize,
      ...entries.map((entry) => '${entry.name}:${entry.urls.join(',')}'),
    ].join('|');
    if (_requestedTargetSignature != signature) {
      _requestedTargetSignature = signature;
      _targetGeneration++;
      _targetAttempt = null;
    }
    if (signature == _targetSignature || _loadingTargetSignature != null) {
      return;
    }
    final now = DateTime.now();
    if (_targetAttempt != null &&
        now.difference(_targetAttempt!) < const Duration(seconds: 10)) {
      return;
    }
    _targetAttempt = now;
    final generation = _targetGeneration;
    _loadingTargetSignature = signature;

    final icons = <String, List<Uint8List>>{};
    try {
      await Future.wait(
        entries.map((entry) async {
          if (_disposed || generation != _targetGeneration) return;
          for (final url in entry.urls) {
            final bytes = await _iconCache.load(url);
            if (bytes != null) {
              icons[entry.name] = [bytes];
              break;
            }
          }

          if (entry.name.toLowerCase() == 'kayn' &&
              icons.containsKey(entry.name)) {
            const base =
                'https://raw.communitydragon.org/latest/game/assets/characters/kayn/hud';
            for (final path in const [
              'rhaast/kayn_slay_circle.png',
              'assassin/kayn_ass_circle.png',
            ]) {
              final bytes = await _iconCache.load('$base/$path');
              if (bytes != null) icons[entry.name]!.add(bytes);
            }
          }
        }),
      );
      if (_disposed || generation != _targetGeneration) return;
      _targetsUpdating = true;
      _tracker.setTargets({
        for (final entry in entries)
          if (icons.containsKey(entry.name)) entry.name: icons[entry.name]!,
      }, iconSize: stableIconSize);
      _targetIconSize = stableIconSize;
      final loadedNames = _tracker.targetNames;
      final missing = names
          .where((name) => !loadedNames.contains(name))
          .toList();
      // A partial download is not a completed roster; retry missing assets.
      _targetSignature = missing.isEmpty ? signature : '';
      // Preserve lastKnown across target updates so champion tracking history is not lost!
      state = state.copyWith(identified: const {});
      _appendLog(
        TrackerLogEntry(
          timestamp: DateTime.now(),
          source: TrackerLogSource.native,
          event: 'targets_refreshed',
          message:
              'Targets: ${loadedNames.join(', ')} · icon $stableIconSize px · '
              '${loadedNames.length}/${names.length} · missing: ${missing.join(', ')}',
        ),
      );
    } catch (error) {
      if (!_disposed && generation == _targetGeneration) {
        state = state.copyWith(
          error: 'No se pudieron preparar los retratos: $error',
        );
      }
    } finally {
      _targetsUpdating = false;
      _loadingTargetSignature = null;
    }
  }

  void configureAlertContext({
    required String localRole,
    required Map<String, String> enemyRoles,
  }) {
    _localRole = localRole.toUpperCase();
    _enemyRoles = enemyRoles.map(
      (name, role) => MapEntry(name, role.toUpperCase()),
    );
  }

  List<NativeTrackerEvent> evaluateAlerts(
    Map<String, NativeIdentifiedChampion> positions,
    DateTime timestamp,
    int width,
    int height,
  ) {
    return _deriveEvents(positions, timestamp, width, height);
  }

  Future<void> captureOnce(Map<String, dynamic> bounds) async {
    state = state.copyWith(bounds: bounds, clearError: true);
    await _captureAndProcess();
  }

  Future<void> detectCalibration() async {
    if (state.processing) return;
    state = state.copyWith(processing: true, clearError: true);
    try {
      final proposal = NativeMinimapCalibrator(_capture).detect();
      final width = (proposal.bounds['width'] as num).toDouble();
      final height = (proposal.bounds['height'] as num).toDouble();
      final ratio = width / height;
      if (ratio < 0.75 || ratio > 1.33) {
        throw StateError(
          'Detector nativo propuso bounds inválidos '
          '${width.round()}x${height.round()}.',
        );
      }
      state = state.copyWith(
        processing: false,
        calibrationProposal: proposal,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(processing: false, error: error.toString());
    }
  }

  Future<void> _autoDetectAndStart() async {
    _calibrating = true;
    try {
      final proposal = NativeMinimapCalibrator(_capture).detect();
      final width = (proposal.bounds['width'] as num).toDouble();
      final height = (proposal.bounds['height'] as num).toDouble();
      final ratio = width / height;
      if (ratio < 0.75 || ratio > 1.33 || proposal.confidence < 0.25) {
        throw StateError(
          'Calibración nativa no confiable: '
          '${width.round()}x${height.round()}, '
          '${(proposal.confidence * 100).toStringAsFixed(1)}%.',
        );
      }
      state = state.copyWith(
        calibrationProposal: proposal,
        bounds: proposal.bounds,
        clearError: true,
      );
      _iconSize = proposal.iconSize;
      if (!state.running) {
        state = state.copyWith(running: true);
        _timer = Timer.periodic(
          const Duration(milliseconds: 167),
          (_) => unawaited(_captureAndProcess()),
        );
        await _captureAndProcess();
      }
      _appendLog(
        TrackerLogEntry(
          timestamp: proposal.detectedAt,
          source: TrackerLogSource.native,
          event: 'native_calibration_applied',
          message:
              '${proposal.bounds} · icon ${proposal.iconSize}px · '
              'confidence=${proposal.confidence.toStringAsFixed(3)}',
        ),
      );
    } catch (error) {
      state = state.copyWith(error: error.toString());
    } finally {
      _calibrating = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (state.running) state = state.copyWith(running: false, fps: 0);
  }

  Future<void> _captureAndProcess() async {
    if (_disposed ||
        state.processing ||
        _targetsUpdating ||
        (_targetIconSize != null && _targetIconSize != _iconSize)) {
      return;
    }
    final bounds = state.bounds;
    if (bounds == null) return;
    state = state.copyWith(processing: true);
    try {
      final capture = _capture.capture(
        left: (bounds['left'] as num?)?.round() ?? 0,
        top: (bounds['top'] as num?)?.round() ?? 0,
        width: (bounds['width'] as num?)?.round() ?? 0,
        height: (bounds['height'] as num?)?.round() ?? 0,
      );
      final previousFrame = state.frame;
      final generatePreview = previousFrame == null || _previewFrame++ % 6 == 0;
      final frame = _tracker.process(
        capture,
        iconSize: _iconSize,
        generatePreview: generatePreview,
        previousCapturePng: previousFrame?.capturePng,
        previousMaskPng: previousFrame?.maskPng,
        previousAnnotatedPng: previousFrame?.annotatedPng,
      );
      _cvSamples.add(frame.cvMicroseconds);
      _captureSamples.add(capture.captureMicroseconds);
      if (_cvSamples.length > 120) _cvSamples.removeAt(0);
      if (_captureSamples.length > 120) _captureSamples.removeAt(0);
      final sortedCv = [..._cvSamples]..sort();
      final averageCv =
          _cvSamples.reduce((a, b) => a + b) / _cvSamples.length / 1000;
      final p95Cv = sortedCv[((sortedCv.length - 1) * 0.95).round()] / 1000;
      final averageCapture =
          _captureSamples.reduce((a, b) => a + b) /
          _captureSamples.length /
          1000;
      if (++_performanceLogFrame % 60 == 0) {
        _appendLog(
          TrackerLogEntry(
            timestamp: frame.processedAt,
            source: TrackerLogSource.native,
            event: 'performance',
            message:
                'GDI avg=${averageCapture.toStringAsFixed(2)} ms · CV avg=${averageCv.toStringAsFixed(2)} ms · '
                'CV p95=${p95Cv.toStringAsFixed(2)} ms · '
                'identified=${frame.detections.where((d) => d.championName != null).length}/${frame.detections.length} · '
                'templates=${_tracker.targetNames.length} at ${_targetIconSize ?? 0}px · captureIcon=${_iconSize}px · '
                'stages=${frame.stageMicroseconds.map((key, value) => MapEntry(key, (value / 1000).toStringAsFixed(2)))}',
            detectionCount: frame.detections.length,
          ),
        );
      }
      if (!_loggedCaptureStart) {
        _loggedCaptureStart = true;
        _appendLog(
          TrackerLogEntry(
            timestamp: frame.processedAt,
            source: TrackerLogSource.native,
            event: 'capture_started',
            message:
                '${capture.width}x${capture.height} BGRA via GDI · processing ${frame.processingTime.inMilliseconds} ms',
            detectionCount: frame.detections.length,
          ),
        );
      }
      _framesSinceSample++;
      final now = DateTime.now();
      final elapsed = now.difference(_fpsSample).inMilliseconds;
      var fps = state.fps;
      if (elapsed >= 1000) {
        fps = _framesSinceSample * 1000 / elapsed;
        _framesSinceSample = 0;
        _fpsSample = now;
      }
      _recordSpatialChanges(frame);
      final identified = {...state.identified};
      final lastKnown = {...state.lastKnown};
      identified.removeWhere(
        (_, value) =>
            frame.processedAt.difference(value.lastSeen).inMilliseconds > 2000,
      );
      final frameWidth = (bounds['width'] as num?)?.round() ?? 1;
      final frameHeight = (bounds['height'] as num?)?.round() ?? 1;
      for (final detection in frame.detections) {
        final name = detection.championName;
        if (name == null || detection.confidence < 0.35) continue;
        identified[name] = NativeIdentifiedChampion(
          name: name,
          region: detection.regionFor(frameWidth, frameHeight),
          x: detection.centerX,
          y: detection.centerY,
          confidence: detection.confidence,
          lastSeen: frame.processedAt,
        );
        lastKnown[name] = identified[name]!;
      }
      final events = _deriveEvents(
        identified,
        frame.processedAt,
        frameWidth,
        frameHeight,
      );
      state = state.copyWith(
        frame: frame,
        identified: identified,
        lastKnown: lastKnown,
        averageCvMilliseconds: averageCv,
        p95CvMilliseconds: p95Cv,
        averageCaptureMilliseconds: averageCapture,
        events: events,
        workingSetBytes: ProcessInfo.currentRss,
        fps: fps,
        processing: false,
        clearError: true,
      );
    } catch (error, stackTrace) {
      final message = error.toString();
      final now = DateTime.now();
      if (_lastErrorMessage != message ||
          _lastErrorLoggedAt == null ||
          now.difference(_lastErrorLoggedAt!).inSeconds >= 5) {
        debugPrint('[TRACKER][NATIVE][ERROR] $error\n$stackTrace');
        _lastErrorMessage = message;
        _lastErrorLoggedAt = now;
      }
      state = state.copyWith(processing: false, error: error.toString());
    }
  }

  List<NativeTrackerEvent> _deriveEvents(
    Map<String, NativeIdentifiedChampion> identified,
    DateTime timestamp,
    int width,
    int height,
  ) {
    final events = [...state.events];
    final currentGanks = <String>{};
    final zones = gankZonesByRole[_localRole] ?? const {};
    for (final champion in identified.values) {
      final location = resolveMapLocation(
        champion.x,
        champion.y,
        width.toDouble(),
        height.toDouble(),
      );
      final gankKey = champion.name;
      if (zones.contains(location.name)) {
        currentGanks.add(gankKey);
        final fresh =
            timestamp.difference(champion.lastSeen).inMilliseconds <= 250;
        if (fresh && !_activeGanks.contains(gankKey)) {
          final event = NativeTrackerEvent(
            kind: NativeTrackerEventKind.gank,
            champion: champion.name,
            location: location.name,
            region: location.region,
            timestamp: timestamp,
            role: _enemyRoles[champion.name] ?? 'UNKNOWN',
          );
          events.insert(0, event);
          _appendLog(
            TrackerLogEntry(
              timestamp: timestamp,
              source: TrackerLogSource.native,
              event: 'native_gank',
              message:
                  'DANGER: ${event.champion}: ${event.location} · ${event.role}',
            ),
          );
        }
      }

      if (_enemyRoles[champion.name] == 'JUNGLE' &&
          timestamp.difference(champion.lastSeen).inMilliseconds <= 250) {
        final previous = _sightingStates[champion.name];
        final unseen = previous == null
            ? timestamp.millisecondsSinceEpoch / 1000
            : timestamp.difference(previous.lastSeen).inMilliseconds / 1000;
        final first = previous == null;
        final rearmed = unseen >= 20;
        final movedRegion =
            previous != null && previous.lastRegion != location.region;
        final hysteresisPassed =
            previous == null ||
            timestamp.difference(previous.lastAlertAt).inMilliseconds >= 3000;
        if (first || rearmed || (movedRegion && hysteresisPassed)) {
          final event = NativeTrackerEvent(
            kind: NativeTrackerEventKind.junglerSighting,
            champion: champion.name,
            location: location.name,
            region: location.region,
            timestamp: timestamp,
            role: 'JUNGLE',
            unseenSeconds: unseen,
          );
          events.insert(0, event);
          _appendLog(
            TrackerLogEntry(
              timestamp: timestamp,
              source: TrackerLogSource.native,
              event: 'native_jungler_sighting',
              message:
                  '${event.champion}: ${event.location} (${event.region}, unseen ${event.unseenSeconds.toStringAsFixed(1)}s)',
            ),
          );
        }
        _sightingStates[champion.name] = _NativeSightingState(
          lastSeen: timestamp,
          lastRegion: location.region,
          lastAlertAt: first || rearmed || (movedRegion && hysteresisPassed)
              ? timestamp
              : previous.lastAlertAt,
        );
      }
    }
    _activeGanks
      ..clear()
      ..addAll(currentGanks);
    return events.take(100).toList(growable: false);
  }

  void _recordSpatialChanges(NativeVisionFrame frame) {
    for (final detection in frame.detections) {
      final champion = detection.championName;
      if (champion == null || detection.confidence < 0.35) continue;
      final region = detection.regionFor(
        state.bounds?['width'] is num
            ? (state.bounds!['width'] as num).round()
            : 1,
        state.bounds?['height'] is num
            ? (state.bounds!['height'] as num).round()
            : 1,
      );
      final previous = state.identified[champion];
      if (previous != null && previous.region == region) continue;
      _appendLog(
        TrackerLogEntry(
          timestamp: frame.processedAt,
          source: TrackerLogSource.native,
          event: previous == null
              ? 'native_first_identified'
              : 'native_region_changed',
          message:
              '$champion · $region · confidence=${detection.confidence.toStringAsFixed(3)} '
              '(tm=${detection.templateScore.toStringAsFixed(3)}, hist=${detection.histogramScore.toStringAsFixed(3)}) · '
              'x=${detection.centerX.round()}, y=${detection.centerY.round()} · first valid frame',
          detectionCount: frame.detections.length,
        ),
      );
    }
  }

  void recordLegacy(CompanionAlert alert) {
    if (alert.kind != CompanionAlertKind.gank &&
        alert.kind != CompanionAlertKind.junglerSighting) {
      return;
    }
    _appendLog(
      TrackerLogEntry(
        timestamp: alert.receivedAt,
        source: TrackerLogSource.legacy,
        event: alert.kind.name,
        message: '${alert.title}: ${alert.message}',
      ),
    );
  }

  void clearLogs() => state = state.copyWith(logs: const []);

  void _appendLog(TrackerLogEntry entry) {
    final logs = [entry, ...state.logs].take(200).toList();
    state = state.copyWith(logs: logs);
    final line = jsonEncode(entry.toJson());
    debugPrint('[TRACKER][${entry.source.name.toUpperCase()}] $line');
    _logWriteQueue = _logWriteQueue.then((_) => _writeLog('$line\n'));
  }

  Future<void> _writeLog(String line) async {
    try {
      final appData = Platform.environment['APPDATA'];
      if (appData == null) return;
      final directory = Directory('$appData\\GodSense');
      await directory.create(recursive: true);
      await File('${directory.path}\\tracker-comparison-$pid.jsonl')
          .writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _targetGeneration++;
    stop();
    _tracker.dispose();
    _capture.dispose();
    super.dispose();
  }
}

List<String> _visionAssetUrls(Map<String, dynamic> enemy) {
  final result = <String>[];
  void add(Object? value) {
    final url = value?.toString().trim() ?? '';
    if (url.isNotEmpty && !result.contains(url)) result.add(url);
  }

  // Vision uses canonical Data Dragon portraits, not arbitrary UI fallbacks.
  void addCanonical(Object? value) {
    final uri = Uri.tryParse(value?.toString() ?? '');
    if (uri?.scheme == 'https' &&
        uri?.host == 'ddragon.leagueoflegends.com' &&
        uri!.path.contains('/img/champion/')) {
      add(value);
    }
  }

  addCanonical(enemy['vision_icon_url']);
  addCanonical(enemy['icon_url']);
  final fallbacks = enemy['icon_fallback_urls'];
  if (fallbacks is List) {
    for (final value in fallbacks) {
      addCanonical(value);
    }
  }
  return result;
}
