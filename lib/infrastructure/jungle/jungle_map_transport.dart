import 'dart:convert';
import 'dart:io';

import '../../domain/identity/league_identity.dart';

abstract interface class JungleMapTransport {
  Future<Map<String, dynamic>> loadMap11(PatchKey patch);

  Uri sourceUri(PatchKey patch);
}

class CommunityDragonJungleMapTransport implements JungleMapTransport {
  CommunityDragonJungleMapTransport({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Uri sourceUri(PatchKey patch) => Uri.parse(
    'https://raw.communitydragon.org/${patch.value}/game/data/maps/'
    'shipping/map11/map11.bin.json',
  );

  @override
  Future<Map<String, dynamic>> loadMap11(PatchKey patch) async {
    final request = await _client.getUrl(sourceUri(patch));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException(
        'Map11 extraction returned HTTP ${response.statusCode}.',
        uri: sourceUri(patch),
      );
    }
    final bytes = await response.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('Map11 extraction is not a JSON object.');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  void dispose() => _client.close(force: true);
}
