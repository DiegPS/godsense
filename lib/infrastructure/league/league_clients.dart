import 'dart:convert';
import 'dart:io';

import 'lcu_probe_transport.dart';

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

class LcuClient implements LcuProbeTransport {
  LcuClient({HttpClient? httpClient, this.credentialsProvider})
    : _httpClient =
          httpClient ??
          (HttpClient()
            ..badCertificateCallback = ((_, _, _) => true)
            ..connectionTimeout = const Duration(seconds: 2));

  final HttpClient _httpClient;
  final LcuCredentials? Function()? credentialsProvider;
  LcuCredentials? _credentials;

  LcuCredentials? discover() {
    final provider = credentialsProvider;
    if (provider != null) return _credentials = provider();
    final explicit = Platform.environment['GODSENSE_LCU_LOCKFILE'];
    final candidates = [
      explicit,
      r'C:\Riot Games\League of Legends\lockfile',
      r'C:\Program Files\Riot Games\League of Legends\lockfile',
      if (Platform.environment['PROGRAMDATA'] != null)
        '${Platform.environment['PROGRAMDATA']}\\Riot Games\\League of Legends\\lockfile',
    ];
    for (final path in candidates) {
      if (path == null) continue;
      final file = File(path);
      if (!file.existsSync()) continue;
      try {
        final parts = file.readAsStringSync().trim().split(':');
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
    final credentials = _credentials ?? discover();
    if (credentials == null) {
      return const LcuProbeResponse.failure(
        failureKind: LcuProbeFailureKind.disconnected,
        error: 'LCU lockfile was not found.',
      );
    }
    try {
      final uri = Uri.parse(
        '${credentials.protocol}://127.0.0.1:${credentials.port}$path',
      );
      final request = await _httpClient.openUrl(method, uri);
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
        await response.fold<List<int>>(
          [],
          (bytes, chunk) => bytes..addAll(chunk),
        ),
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
  LiveClientApi({HttpClient? httpClient})
    : _httpClient =
          httpClient ??
          (HttpClient()
            ..badCertificateCallback = ((_, _, _) => true)
            ..connectionTimeout = const Duration(milliseconds: 700));

  final HttpClient _httpClient;

  Future<Map<String, dynamic>?> allGameData() async {
    try {
      final request = await _httpClient.getUrl(
        Uri.parse('https://127.0.0.1:2999/liveclientdata/allgamedata'),
      );
      final response = await request.close();
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final text = utf8.decode(
        await response.fold<List<int>>(
          [],
          (bytes, chunk) => bytes..addAll(chunk),
        ),
        allowMalformed: true,
      );
      final decoded = jsonDecode(text);
      return decoded is Map
          ? decoded.map((key, value) => MapEntry(key.toString(), value))
          : null;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _httpClient.close(force: true);
}
