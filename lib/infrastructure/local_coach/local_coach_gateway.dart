import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../domain/companion_gateway.dart';

class LocalCoachGateway implements CoachGateway {
  LocalCoachGateway({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'http://127.0.0.1:9150',
              connectTimeout: const Duration(seconds: 2),
              receiveTimeout: const Duration(seconds: 2),
            ),
          );

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> health() async {
    final response = await _dio.get<Object?>('/health');
    final value = response.data;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    throw const CompanionGatewayException(
      'Local coach returned invalid health.',
    );
  }
}

class LocalCoachRuntime implements CoachRuntime {
  Process? _process;

  @override
  Future<bool> ensureStarted() async {
    if (await _responds()) return true;
    if (_process != null) return false;
    final directory = _findDirectory();
    if (directory == null) return false;
    final appData = Platform.environment['APPDATA'];
    final opencodeData = appData == null
        ? '$directory\\.opencode'
        : '$appData\\GodSense\\opencode';
    await Directory(opencodeData).create(recursive: true);
    _process = await Process.start(
      'node',
      ['$directory\\server.js'],
      workingDirectory: directory,
      environment: {
        ...Platform.environment,
        'COACH_PORT': '9150',
        'OPENCODE_DATA_DIRECTORY': opencodeData,
        'OPENCODE_PROVIDER_ID':
            Platform.environment['OPENCODE_PROVIDER_ID'] ?? 'opencode',
        'OPENCODE_MODEL_ID':
            Platform.environment['OPENCODE_MODEL_ID'] ?? 'mimo-v2.5-free',
      },
      mode: ProcessStartMode.normal,
    );
    unawaited(_process!.stdout.transform(utf8.decoder).drain<void>());
    unawaited(_process!.stderr.transform(utf8.decoder).drain<void>());
    unawaited(_process!.exitCode.then((_) => _process = null));
    for (var attempt = 0; attempt < 40; attempt++) {
      if (await _responds()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  Future<bool> _responds() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:9150/health'),
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

  String? _findDirectory() {
    final explicit = Platform.environment['GODSENSE_LOCAL_COACH_DIR'];
    final userProfile = Platform.environment['USERPROFILE'];
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      explicit,
      '$executableDir\\local-coach',
      if (userProfile != null) '$userProfile\\scoutr-local-coach',
    ];
    for (final candidate in candidates) {
      if (candidate != null && File('$candidate\\server.js').existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _process?.kill();
    _process = null;
  }
}
