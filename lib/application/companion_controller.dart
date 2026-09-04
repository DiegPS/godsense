import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/companion_gateway.dart';
import '../domain/companion_models.dart';

class CompanionController extends StateNotifier<CompanionState> {
  CompanionController(this.client) : super(const CompanionState());

  final CompanionGateway client;
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
    try {
      final health = CompanionHealth.fromJson(await client.health());
      state = state.copyWith(
        connection: CompanionConnection.online,
        health: health,
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
        client.lobbyState(),
        client.lobbyHealth(),
        client.coachingStatus(),
        client.directives(),
      ]);
      final directiveJson = results[3] as List<Map<String, dynamic>>;
      state = state.copyWith(
        connection: CompanionConnection.online,
        lobby: LobbyState.fromJson(results[0] as Map<String, dynamic>),
        lobbyHealth: results[1] as Map<String, dynamic>,
        coachingStatus: results[2] as Map<String, dynamic>,
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
      final settings = await _optional(client.settings);
      state = state.copyWith(
        connection: CompanionConnection.online,
        coaching: coaching ?? state.coaching,
        settings: settings == null
            ? state.settings
            : CompanionSettings.fromJson(settings),
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
      final health = CompanionHealth.fromJson(await client.health());
      state = state.copyWith(
        connection: CompanionConnection.online,
        health: health,
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
    super.dispose();
  }
}
