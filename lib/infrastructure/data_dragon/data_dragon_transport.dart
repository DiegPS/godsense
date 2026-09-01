import 'dart:io';

abstract interface class DataDragonTransport {
  Future<List<int>> get(Uri uri);
}

class HttpDataDragonTransport implements DataDragonTransport {
  HttpDataDragonTransport({HttpClient? client})
    : _client =
          client ??
          (HttpClient()..connectionTimeout = const Duration(seconds: 5));

  final HttpClient _client;

  @override
  Future<List<int>> get(Uri uri) async {
    final request = await _client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException(
        'Data Dragon returned HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    return response.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
  }

  void close() => _client.close(force: true);
}
