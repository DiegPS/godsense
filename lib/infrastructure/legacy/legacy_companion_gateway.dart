import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/companion_gateway.dart';

class LegacyCompanionGateway implements CompanionGateway {
  LegacyCompanionGateway({String baseUrl = 'http://127.0.0.1:8420', Dio? dio})
    : baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl.replaceFirst(RegExp(r'/$'), ''),
              connectTimeout: const Duration(seconds: 2),
              receiveTimeout: const Duration(seconds: 5),
              sendTimeout: const Duration(seconds: 5),
              validateStatus: (_) => true,
            ),
          );

  final String baseUrl;
  final Dio _dio;
  WebSocketChannel? _alertsChannel;

  @override
  Future<Map<String, dynamic>> health() => _getMap('/api/health');
  @override
  Future<Map<String, dynamic>?> gameState() =>
      _getOptionalMap('/api/state', waitingStatus: 503);
  @override
  Future<Map<String, dynamic>> coaching() => _getMap('/api/coaching');
  @override
  Future<Map<String, dynamic>> coachingStatus() =>
      _getMap('/api/coaching_status');
  @override
  Future<List<Map<String, dynamic>>> directives() =>
      _getMapList('/api/directives');
  @override
  Future<Map<String, dynamic>> players() => _getMap('/api/players');
  @override
  Future<Map<String, dynamic>> timeline({int lastN = 3600}) =>
      _getMap('/api/timeline', query: {'last_n': lastN});
  @override
  Future<Map<String, dynamic>> config() async {
    final config = await _getMap('/api/config');
    const excluded = {
      'pricing',
      'plans',
      'subscription',
      'quota',
      'credits',
      'checkout',
      'billing',
      'telemetry',
    };
    return Map.fromEntries(
      config.entries.where((entry) => !excluded.contains(entry.key)),
    );
  }

  @override
  Future<Map<String, dynamic>> lobbyState() => _getMap('/api/lobby/state');
  @override
  Future<Map<String, dynamic>> lobbyHealth() => _getMap('/api/lobby/health');
  @override
  Future<Map<String, dynamic>> generateLobbyBrief(String candidate) =>
      _postMap('/api/lobby/brief/generate', data: {'candidate': candidate});
  Future<Map<String, dynamic>> importRunes() =>
      _postMap('/api/lobby/runes/import');
  Future<Map<String, dynamic>> importBuilds() =>
      _postMap('/api/lobby/builds/import');
  @override
  Future<Map<String, dynamic>> importAll() =>
      _postMap('/api/lobby/import_all', data: const {});

  @override
  Future<Map<String, dynamic>> calibration() => _getMap('/api/calibration');
  @override
  Future<Map<String, dynamic>> detectCalibration() =>
      _postMap('/api/calibration/detect');
  @override
  Future<Map<String, dynamic>> saveCalibration(
    Map<String, dynamic> bounds, {
    String source = 'auto',
  }) => _postMap(
    '/api/calibration/save',
    data: {'bounds': bounds, 'source': source},
  );

  @override
  Future<Map<String, dynamic>> settings() => _getMap('/api/settings');
  @override
  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> patch) =>
      _postMap('/api/settings', data: patch);
  @override
  Future<Map<String, dynamic>> testVoice() =>
      _postMap('/api/settings/test-voice');

  @override
  Future<Map<String, dynamic>> highlights() => _getMap('/api/highlights');
  @override
  Uri highlightClipUri(int slot) =>
      Uri.parse('$baseUrl/api/highlights/clips/$slot');

  @override
  @override
  Future<Map<String, dynamic>> scoutSummoner({
    required String name,
    required String tag,
    required String region,
  }) => _getMap(
    '/api/scout/summoner',
    query: {'name': name, 'tag': tag, 'region': region},
  );
  @override
  @override
  Future<Map<String, dynamic>> scoutMatch({
    required int matchId,
    required String region,
    required String name,
    required String tag,
  }) => _getMap(
    '/api/scout/match',
    query: {'match_id': matchId, 'region': region, 'name': name, 'tag': tag},
  );

  @override
  @override
  Future<Map<String, dynamic>> createSupportBundle() =>
      _postMap('/api/support/bundle');
  @override
  @override
  Future<Map<String, dynamic>> reportSupport({String? note}) =>
      _postMap('/api/support/report', data: {'note': note});

  Future<Map<String, dynamic>> setCoachToken(String token) =>
      _postMap('/api/coach/token', data: {'token': token});
  Future<Map<String, dynamic>> startSignIn() =>
      _postMap('/api/auth/signin/start');
  Future<Map<String, dynamic>> redeemToken(String token) =>
      _postMap('/api/auth/redeem', data: {'token': token});
  Future<Map<String, dynamic>> signOut() => _postMap('/api/auth/signout');

  @override
  Stream<Map<String, dynamic>> alertEvents() {
    final uri = Uri.parse(baseUrl).replace(
      scheme: Uri.parse(baseUrl).scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/alerts',
      query: null,
    );
    final channel = WebSocketChannel.connect(uri);
    _alertsChannel = channel;
    unawaited(channel.ready.then<void>((_) {}, onError: (_) {}));
    return channel.stream.map(decodeBackendEvent);
  }

  @override
  Future<void> closeAlerts() async {
    await _alertsChannel?.sink.close();
    _alertsChannel = null;
  }

  Future<Map<String, dynamic>> _getMap(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _dio.get<Object?>(path, queryParameters: query);
    return _mapResponse(response);
  }

  Future<Map<String, dynamic>?> _getOptionalMap(
    String path, {
    required int waitingStatus,
  }) async {
    final response = await _dio.get<Object?>(path);
    if (response.statusCode == waitingStatus) return null;
    return _mapResponse(response);
  }

  Future<List<Map<String, dynamic>>> _getMapList(String path) async {
    final response = await _dio.get<Object?>(path);
    _ensureSuccess(response);
    final value = response.data;
    if (value is! List) {
      throw const CompanionGatewayException(
        'Backend returned an invalid list.',
      );
    }
    return value.whereType<Map>().map(_stringMap).toList(growable: false);
  }

  Future<Map<String, dynamic>> _postMap(String path, {Object? data}) async {
    final response = await _dio.post<Object?>(path, data: data);
    return _mapResponse(response);
  }

  Map<String, dynamic> _mapResponse(Response<Object?> response) {
    _ensureSuccess(response);
    final value = response.data;
    if (value is Map) return _stringMap(value);
    throw const CompanionGatewayException(
      'Backend returned an invalid object.',
    );
  }

  void _ensureSuccess(Response<Object?> response) {
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) return;
    final body = response.data;
    final detail = body is Map
        ? body['detail'] ?? body['error'] ?? body['message']
        : body;
    throw CompanionGatewayException(
      detail?.toString() ?? 'Backend request failed ($status).',
      statusCode: status,
    );
  }
}

class LegacyCompanionRuntime implements CompanionRuntime {
  Process? _process;

  @override
  Future<bool> ensureStarted() async {
    if (_process != null) return true;
    if (await _backendResponds()) return true;
    final executable = _findExecutable();
    if (executable == null) return false;

    final appData = Platform.environment['APPDATA'];
    final dataDir = appData == null ? null : '$appData\\GodSense';
    if (dataDir != null) await Directory(dataDir).create(recursive: true);
    _process = await Process.start(
      executable,
      ['--no-window', '--port', '8420', '--shell-pid', '$pid'],
      environment: {
        ...Platform.environment,
        'LOL_COMPANION_DATA_DIR': ?dataDir,
        'LOL_COMPANION_COACH_API_URL': 'http://127.0.0.1:9150',
        'LOL_COMPANION_COACH_API_TOKEN': 'local-dev',
      },
      mode: ProcessStartMode.normal,
    );
    unawaited(_process!.stdout.drain<void>());
    unawaited(_process!.stderr.drain<void>());
    unawaited(_process!.exitCode.then((_) => _process = null));
    return true;
  }

  Future<bool> _backendResponds() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:8420/api/health'),
      );
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  String? _findExecutable() {
    final explicit = Platform.environment['GODSENSE_BACKEND_EXE'];
    final localAppData = Platform.environment['LOCALAPPDATA'];
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      explicit,
      '$executableDir\\backend\\scoutr-backend.exe',
      '$executableDir\\resources\\backend\\scoutr-backend.exe',
      if (localAppData != null)
        '$localAppData\\Programs\\@frontendshell\\resources\\backend\\scoutr-backend.exe',
    ];
    for (final candidate in candidates) {
      if (candidate != null && File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  @override
  void dispose() {
    _process?.kill();
    _process = null;
  }
}

Map<String, dynamic> decodeBackendEvent(Object? event) {
  final decoded = event is String ? jsonDecode(event) : event;
  if (decoded is! Map) {
    throw const FormatException('Invalid backend event.');
  }
  return _stringMap(decoded);
}

Map<String, dynamic> _stringMap(Map<dynamic, dynamic> value) {
  return value.map((key, item) => MapEntry(key.toString(), item));
}
