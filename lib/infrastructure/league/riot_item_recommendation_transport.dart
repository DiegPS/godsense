import 'dart:convert';
import 'dart:io';

import '../../domain/identity/league_identity.dart';

abstract interface class RiotItemRecommendationTransport {
  Future<({Map<String, dynamic> document, Uri sourceUri})> fetch({
    required PatchKey patch,
    required String championAlias,
  });
}

class CommunityDragonItemRecommendationTransport
    implements RiotItemRecommendationTransport {
  CommunityDragonItemRecommendationTransport({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<({Map<String, dynamic> document, Uri sourceUri})> fetch({
    required PatchKey patch,
    required String championAlias,
  }) async {
    final normalized = championAlias.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(normalized)) {
      throw const FormatException('Invalid champion alias.');
    }
    final uri = Uri.parse(
      'https://raw.communitydragon.org/${patch.value}/game/data/'
      'characters/$normalized/$normalized.bin.json',
    );
    final request = await _client.getUrl(uri);
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Champion recommendation artifact returned ${response.statusCode}.',
        uri: uri,
      );
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Champion BIN extraction is not an object.');
    }
    return (
      document: decoded.map((key, value) => MapEntry(key.toString(), value)),
      sourceUri: uri,
    );
  }

  void dispose() => _client.close(force: true);
}
