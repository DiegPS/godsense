import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'lcu_probe_transport.dart';
import 'league_installation.dart';

class LcuCredentials {
  const LcuCredentials({
    required this.port,
    required this.password,
    required this.protocol,
    required this.lockfilePath,
  });

  final int port;
  final String password;
  final String protocol;
  final String lockfilePath;
}

class LcuClient implements LcuReadTransport {
  LcuClient({
    HttpClient? httpClient,
    this.credentialsProvider,
    this.requestTimeout = const Duration(seconds: 4),
    this.maxResponseBytes = 16 * 1024 * 1024,
  }) : _httpClient =
           httpClient ??
           (HttpClient()
             ..badCertificateCallback = ((_, _, _) => true)
             ..connectionTimeout = const Duration(seconds: 2));

  final HttpClient _httpClient;
  final LcuCredentials? Function()? credentialsProvider;
  final Duration requestTimeout;
  final int maxResponseBytes;
  LcuCredentials? _credentials;
  String? _activeDirectory;
  DateTime? _lastDiscovery;
  Future<LcuCredentials?>? _discovery;

  Future<LcuCredentials?> discover() {
    return _discovery ??= _discover().whenComplete(() => _discovery = null);
  }

  Future<LcuCredentials?> _discover() async {
    final provider = credentialsProvider;
    if (provider != null) return _credentials = provider();
    final explicit = Platform.environment['GODSENSE_LCU_LOCKFILE'];
    if (explicit == null &&
        (_lastDiscovery == null ||
            DateTime.now().difference(_lastDiscovery!).inSeconds >= 10)) {
      _lastDiscovery = DateTime.now();
      _activeDirectory = await Isolate.run(activeLeagueDirectory);
    }
    final candidates = explicit != null && explicit.trim().isNotEmpty
        ? <String?>[explicit]
        : <String?>[
            if (_activeDirectory != null) '$_activeDirectory\\lockfile',
            r'C:\Riot Games\League of Legends\lockfile',
            r'C:\Program Files\Riot Games\League of Legends\lockfile',
            if (Platform.environment['PROGRAMDATA'] != null)
              '${Platform.environment['PROGRAMDATA']}\\Riot Games\\League of Legends\\lockfile',
          ];
    for (final path in candidates) {
      if (path == null) continue;
      final file = File(path);
      try {
        final parts = (await file.readAsString()).trim().split(':');
        if (parts.length < 5) continue;
        final port = int.tryParse(parts[2]);
        if (port == null) continue;
        return _credentials = LcuCredentials(
          port: port,
          password: parts[3],
          protocol: parts[4],
          lockfilePath: path,
        );
      } catch (_) {}
    }
    _credentials = null;
    return null;
  }

  @override
  Future<Object?> get(String path) => _request('GET', path);
  Future<Object?> post(String path, Object? body) =>
      _request('POST', path, body: body);
  Future<Object?> put(String path, Object? body) =>
      _request('PUT', path, body: body);
  Future<Object?> delete(String path) => _request('DELETE', path);

  @override
  Future<LcuProbeResponse> getDetailed(String path) =>
      _requestDetailed('GET', path);

  Future<Object?> _request(String method, String path, {Object? body}) async {
    final result = await _requestDetailed(method, path, body: body);
    if (result.isSuccess) return result.body;
    if (result.statusCode == 404) return null;
    if (result.failureKind == LcuProbeFailureKind.disconnected) {
      throw SocketException(result.error ?? 'LCU not found');
    }
    throw HttpException(
      'LCU $method $path: ${result.statusCode ?? 'transport'} '
      '${result.error ?? ''}',
    );
  }

  Future<LcuProbeResponse> _requestDetailed(
    String method,
    String path, {
    Object? body,
  }) async {
    final credentials = _credentials ?? await discover();
    if (credentials == null) {
      return const LcuProbeResponse.failure(
        failureKind: LcuProbeFailureKind.disconnected,
        error: 'LCU lockfile was not found.',
      );
    }
    HttpClientRequest? activeRequest;
    try {
      return await (() async {
        final uri = Uri.parse(
          '${credentials.protocol}://127.0.0.1:${credentials.port}$path',
        );
        final request = activeRequest = await _httpClient.openUrl(method, uri);
        request.headers
          ..set(
            HttpHeaders.authorizationHeader,
            'Basic ${base64Encode(utf8.encode('riot:${credentials.password}'))}',
          )
          ..set(HttpHeaders.acceptHeader, 'application/json');
        if (body != null) {
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(body));
        }
        final response = await request.close();
        final text = utf8.decode(
          await _readBounded(response, maxResponseBytes),
          allowMalformed: true,
        );
        Object? decoded;
        if (text.isNotEmpty) {
          try {
            decoded = jsonDecode(text);
          } on FormatException {
            decoded = text;
          }
        } else {
          decoded = const <String, dynamic>{};
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return LcuProbeResponse.success(
            body: decoded,
            statusCode: response.statusCode,
          );
        }
        final kind = switch (response.statusCode) {
          401 || 403 => LcuProbeFailureKind.unauthorized,
          >= 500 => LcuProbeFailureKind.serverError,
          _ => LcuProbeFailureKind.clientError,
        };
        return LcuProbeResponse.failure(
          failureKind: kind,
          statusCode: response.statusCode,
          body: decoded,
          error: text,
        );
      })().timeout(
        requestTimeout,
        onTimeout: () {
          activeRequest?.abort(
            TimeoutException('LCU request exceeded $requestTimeout.'),
          );
          throw TimeoutException('LCU request exceeded $requestTimeout.');
        },
      );
    } on TimeoutException catch (error) {
      _credentials = null;
      return LcuProbeResponse.failure(
        failureKind: LcuProbeFailureKind.disconnected,
        error: error.message ?? 'LCU request timed out.',
      );
    } on SocketException catch (error) {
      _credentials = null;
      return LcuProbeResponse.failure(
        failureKind: LcuProbeFailureKind.disconnected,
        error: error.message,
      );
    } on HandshakeException catch (error) {
      _credentials = null;
      return LcuProbeResponse.failure(
        failureKind: LcuProbeFailureKind.disconnected,
        error: error.message,
      );
    } on HttpException catch (error) {
      return LcuProbeResponse.failure(
        failureKind: LcuProbeFailureKind.clientError,
        error: error.message,
      );
    }
  }

  void dispose() => _httpClient.close(force: true);
}

class LiveClientApi {
  LiveClientApi({
    HttpClient? httpClient,
    this.requestTimeout = const Duration(seconds: 2),
    this.maxResponseBytes = 16 * 1024 * 1024,
  }) : _httpClient =
           httpClient ??
           (HttpClient()
             ..badCertificateCallback = ((_, _, _) => true)
             ..connectionTimeout = const Duration(milliseconds: 700));

  final HttpClient _httpClient;
  final Duration requestTimeout;
  final int maxResponseBytes;

  Future<Map<String, dynamic>?> allGameData() async {
    HttpClientRequest? activeRequest;
    try {
      return await (() async {
        final request = activeRequest = await _httpClient.getUrl(
          Uri.parse('https://127.0.0.1:2999/liveclientdata/allgamedata'),
        );
        final response = await request.close();
        if (response.statusCode != 200) {
          await response.drain<void>();
          return null;
        }
        final text = utf8.decode(
          await _readBounded(response, maxResponseBytes),
          allowMalformed: true,
        );
        final decoded = jsonDecode(text);
        return decoded is Map
            ? decoded.map((key, value) => MapEntry(key.toString(), value))
            : null;
      })().timeout(
        requestTimeout,
        onTimeout: () {
          activeRequest?.abort(
            TimeoutException('Live Client request exceeded $requestTimeout.'),
          );
          return null;
        },
      );
    } catch (_) {
      return null;
    }
  }

  void dispose() => _httpClient.close(force: true);
}

Future<List<int>> _readBounded(
  HttpClientResponse response,
  int maxResponseBytes,
) async {
  final bytes = <int>[];
  await for (final chunk in response) {
    if (bytes.length + chunk.length > maxResponseBytes) {
      throw HttpException(
        'Response exceeded the $maxResponseBytes byte safety limit.',
      );
    }
    bytes.addAll(chunk);
  }
  return bytes;
}
