import 'dart:convert';
import 'dart:io';

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

class LcuClient {
  LcuClient({HttpClient? httpClient})
    : _httpClient =
          httpClient ??
          (HttpClient()
            ..badCertificateCallback = ((_, _, _) => true)
            ..connectionTimeout = const Duration(seconds: 2));

  final HttpClient _httpClient;
  LcuCredentials? _credentials;

  LcuCredentials? discover() {
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

  Future<Object?> _request(String method, String path, {Object? body}) async {
    final credentials = _credentials ?? discover();
    if (credentials == null) throw const SocketException('LCU not found');
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
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('LCU $method $path: ${response.statusCode} $text');
    }
    if (text.isEmpty) return const <String, dynamic>{};
    return jsonDecode(text);
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
