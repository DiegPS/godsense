import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/companion_gateway.dart';
import '../domain/companion_models.dart';

class CompanionController extends StateNotifier<CompanionState> {
  CompanionController(
    this.client, {
    required this.runtime,
    required this.coach,
    required this.coachRuntime,
  }) : super(const CompanionState());

  final CompanionGateway client;
  final CompanionRuntime runtime;
  final CoachGateway coach;
  final CoachRuntime coachRuntime;
  final List<Timer> _timers = [];
  StreamSubscription<Map<String, dynamic>>? _alertsSubscription;
  Timer? _reconnectTimer;
  bool _started = false;
  bool _fastPolling = false;
  bool _mediumPolling = false;
  bool _slowPolling = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await coachRuntime.ensureStarted();
    await runtime.ensureStarted();
    try {
      final results = await Future.wait([client.health(), coach.health()]);
      final health = CompanionHealth.fromJson(results[0]);
      state = state.copyWith(
        connection: CompanionConnection.online,
        health: health,
        localCoachHealth: results[1],
        clearError: true,
      );
    } catch (_) {}
    unawaited(_pollFast());
    unawaited(_pollMedium());
    unawaited(_pollSlow());
    _connectAlerts();
    _timers.addAll([
      Timer.periodic(const Duration(seconds: 1), (_) => _pollFast()),
      Timer.periodic(const Duration(seconds: 5), (_) => _pollMedium()),
      Timer.periodic(const Duration(seconds: 10), (_) => _pollSlow()),
    ]);
  }

  Future<void> _pollFast() async {
    if (_fastPolling) return;
    _fastPolling = true;
    try {
      final results = await Future.wait<Object?>([
        client.gameState(),
        client.lobbyState(),
        client.lobbyHealth(),
        client.coachingStatus(),
        client.directives(),
      ]);
      final gameJson = results[0] as Map<String, dynamic>?;
      final directiveJson = results[4] as List<Map<String, dynamic>>;
      state = state.copyWith(
        connection: CompanionConnection.online,
        game: gameJson == null ? null : GameSnapshot.fromJson(gameJson),
        clearGame: gameJson == null,
        lobby: LobbyState.fromJson(results[1] as Map<String, dynamic>),
        lobbyHealth: results[2] as Map<String, dynamic>,
        coachingStatus: results[3] as Map<String, dynamic>,
        directives: directiveJson.map(CoachDirective.fromJson).toList(),
        clearError: true,
      );
    } catch (error) {
      _recordFailure(error);
    } finally {
      _fastPolling = false;
    }
  }

  Future<void> _pollMedium() async {
    if (_mediumPolling) return;
    _mediumPolling = true;
    try {
      final coaching = await _optional(client.coaching);
      final players = await _optional(client.players);
      final timeline = await _optional(client.timeline);
      final config = await _optional(client.config);
      final calibration = await _optional(client.calibration);
      final settings = await _optional(client.settings);
      final highlights = await _optional(client.highlights);
      state = state.copyWith(
        connection: CompanionConnection.online,
        coaching: coaching ?? state.coaching,
        players: players ?? state.players,
        timeline: timeline ?? state.timeline,
        config: config ?? state.config,
        calibration: calibration == null
            ? state.calibration
            : CalibrationState.fromJson(calibration),
        settings: settings == null
            ? state.settings
            : CompanionSettings.fromJson(settings),
        highlights: highlights ?? state.highlights,
      );
    } catch (error) {
      state = state.copyWith(lastError: error.toString());
    } finally {
      _mediumPolling = false;
    }
  }

  Future<Map<String, dynamic>?> _optional(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } catch (_) {
      return null;
    }
  }

  Future<void> _pollSlow() async {
    if (_slowPolling) return;
    _slowPolling = true;
    try {
      final results = await Future.wait([client.health(), coach.health()]);
      final health = CompanionHealth.fromJson(results[0]);
      state = state.copyWith(
        connection: CompanionConnection.online,
        health: health,
        localCoachHealth: results[1],
        clearError: true,
      );
    } catch (error) {
      _recordFailure(error);
    } finally {
      _slowPolling = false;
    }
  }

  void _connectAlerts() {
    _reconnectTimer?.cancel();
    final stream = client.alertEvents();
    state = state.copyWith(webSocketConnected: true);
    _alertsSubscription = stream.listen(
      (event) {
        final alert = CompanionAlert.fromJson(event);
        final alerts = [alert, ...state.alerts].take(20).toList();
        state = state.copyWith(webSocketConnected: true, alerts: alerts);
      },
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
      cancelOnError: true,
    );
  }

  void _scheduleReconnect() {
    if (!_started) return;
    _alertsSubscription = null;
    state = state.copyWith(webSocketConnected: false);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), _connectAlerts);
  }

  Future<void> autoCalibrate() async {
    state = state.copyWith(operationInProgress: true, clearError: true);
    try {
      final detected = await client.detectCalibration();
      final bounds = detected['bounds'];
      if (bounds is! Map) {
        throw const CompanionGatewayException(
          'Calibration returned no bounds.',
        );
      }
      final normalized = bounds.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final width = (normalized['width'] as num?)?.toDouble() ?? 0;
      final height = (normalized['height'] as num?)?.toDouble() ?? 0;
      final ratio = height == 0 ? double.infinity : width / height;
      if (width <= 0 || height <= 0 || ratio < 0.75 || ratio > 1.33) {
        throw CompanionGatewayException(
          'Calibration detectó bounds inválidos '
          '${width.round()}x${height.round()}. Usa calibración manual.',
        );
      }
      final saved = await client.saveCalibration(normalized);
      state = state.copyWith(
        calibration: CalibrationState.fromJson(saved),
        operationInProgress: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        operationInProgress: false,
        lastError: error.toString(),
      );
    }
  }

  Future<void> saveManualCalibration(Map<String, dynamic> bounds) async {
    state = state.copyWith(operationInProgress: true, clearError: true);
    try {
      final saved = await client.saveCalibration(bounds, source: 'manual');
      state = state.copyWith(
        calibration: CalibrationState.fromJson(saved),
        operationInProgress: false,
        lastOperationResult: saved,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        operationInProgress: false,
        lastError: error.toString(),
      );
    }
  }

  Future<void> updateSettings(Map<String, dynamic> patch) async {
    state = state.copyWith(operationInProgress: true, clearError: true);
    try {
      final result = await client.updateSettings(patch);
      final settings = CompanionSettings.fromJson(await client.settings());
      state = state.copyWith(
        settings: settings,
        lastOperationResult: result,
        operationInProgress: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        operationInProgress: false,
        lastError: error.toString(),
      );
    }
  }

  Future<void> testVoice() async {
    state = state.copyWith(operationInProgress: true, clearError: true);
    try {
      final result = await client.testVoice();
      state = state.copyWith(
        operationInProgress: false,
        lastOperationResult: result,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        operationInProgress: false,
        lastError: error.toString(),
      );
    }
  }

  Future<void> importLobbySetup() async {
    state = state.copyWith(operationInProgress: true, clearError: true);
    try {
      final result = await client.importAll();
      state = state.copyWith(
        operationInProgress: false,
        lastOperationResult: result,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        operationInProgress: false,
        lastError: error.toString(),
      );
    }
  }

  Future<void> generateLobbyBrief(String candidate) async {
    state = state.copyWith(operationInProgress: true, clearError: true);
    try {
      await client.generateLobbyBrief(candidate);
      await _pollFast();
      await _pollMedium();
      state = state.copyWith(operationInProgress: false, clearError: true);
    } catch (error) {
      state = state.copyWith(
        operationInProgress: false,
        lastError: error.toString(),
      );
    }
  }

  Future<void> scoutSummoner({
    required String name,
    required String tag,
    required String region,
  }) async {
    state = state.copyWith(operationInProgress: true, clearError: true);
    try {
      final result = await client.scoutSummoner(
        name: name,
        tag: tag,
        region: region,
      );
      state = state.copyWith(
        scoutProfile: result,
        scoutMatch: const {},
        operationInProgress: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        operationInProgress: false,
        lastError: error.toString(),
      );
    }
  }

  Future<void> scoutMatch({
    required int matchId,
    required String region,
    required String name,
    required String tag,
  }) async {
    state = state.copyWith(operationInProgress: true, clearError: true);
    try {
      final result = await client.scoutMatch(
        matchId: matchId,
        region: region,
        name: name,
        tag: tag,
      );
      state = state.copyWith(
        scoutMatch: result,
        operationInProgress: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        operationInProgress: false,
        lastError: error.toString(),
      );
    }
  }

  Future<void> createSupportBundle() async {
    state = state.copyWith(operationInProgress: true, clearError: true);
    try {
      final result = await client.createSupportBundle();
      state = state.copyWith(
        supportResult: result,
        operationInProgress: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        operationInProgress: false,
        lastError: error.toString(),
      );
    }
  }

  Future<void> reportSupport(String note) async {
    state = state.copyWith(operationInProgress: true, clearError: true);
    try {
      final result = await client.reportSupport(note: note);
      state = state.copyWith(
        supportResult: result,
        operationInProgress: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        operationInProgress: false,
        lastError: error.toString(),
      );
    }
  }

  Uri highlightClipUri(int slot) => client.highlightClipUri(slot);

  void _recordFailure(Object error) {
    state = state.copyWith(
      connection: CompanionConnection.offline,
      lastError: error.toString(),
    );
  }

  @override
  void dispose() {
    _started = false;
    for (final timer in _timers) {
      timer.cancel();
    }
    _reconnectTimer?.cancel();
    unawaited(_alertsSubscription?.cancel() ?? Future<void>.value());
    unawaited(client.closeAlerts());
    runtime.dispose();
    coachRuntime.dispose();
    super.dispose();
  }
}
