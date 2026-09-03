import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../application/ai/ai_runtime_services.dart';
import '../../domain/ai/ai_runtime_api_models.dart';
import '../../domain/ai/ai_runtime_models.dart';

class OpenCodeCompatibleRuntimeClient implements AiRuntimeClient {
  OpenCodeCompatibleRuntimeClient({
    required this.endpoint,
    required this.directory,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final AiRuntimeEndpoint endpoint;
  final String directory;
  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<List<AiProviderInfo>> providers() async {
    final body = await _json('GET', '/provider');
    if (body is! Map) {
      throw const FormatException(
        'Runtime provider response is not an object.',
      );
    }
    final root = Map<String, dynamic>.from(body);
    final connected = (root['connected'] as List? ?? const [])
        .map((value) => value.toString())
        .toSet();
    final rawProviders = root['all'] is List
        ? root['all'] as List
        : root['providers'] is List
        ? root['providers'] as List
        : const [];
    return rawProviders
        .whereType<Map>()
        .map((raw) {
          final provider = Map<String, dynamic>.from(raw);
          final id = provider['id']?.toString() ?? '';
          final rawModels = provider['models'];
          final modelEntries = rawModels is Map
              ? rawModels.entries
              : const Iterable<MapEntry<dynamic, dynamic>>.empty();
          return AiProviderInfo(
            id: id,
            name: provider['name']?.toString() ?? id,
            connected: connected.contains(id),
            models: modelEntries
                .where((entry) => entry.value is Map)
                .map((entry) {
                  final model = Map<String, dynamic>.from(entry.value as Map);
                  final modelId =
                      model['id']?.toString() ?? entry.key.toString();
                  return AiModelInfo(
                    id: modelId,
                    name: model['name']?.toString() ?? modelId,
                    providerId: id,
                    isFree: _isFreeModel(id, modelId, model),
                    supportsReasoning:
                        model['reasoning'] == true ||
                        (model['capabilities'] is Map &&
                            (model['capabilities'] as Map)['reasoning'] ==
                                true),
                  );
                })
                .toList(growable: false),
          );
        })
        .where((provider) => provider.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<AiAuthMethod>> authMethods() async {
    final body = await _json('GET', '/provider/auth');
    if (body is! Map) return const [];
    final methods = <AiAuthMethod>[];
    for (final entry in body.entries) {
      final values = entry.value is List ? entry.value as List : [entry.value];
      for (var index = 0; index < values.length; index++) {
        final value = values[index];
        if (value is! Map) continue;
        final method = Map<String, dynamic>.from(value);
        methods.add(
          AiAuthMethod(
            providerId: entry.key.toString(),
            type: method['type']?.toString() ?? 'unknown',
            label:
                method['label']?.toString() ??
                method['name']?.toString() ??
                method['type']?.toString() ??
                'Authentication',
            index: index,
          ),
        );
      }
    }
    return methods;
  }

  @override
  Future<AiSession> createSession({String? title}) async => AiSession.fromJson(
    _object(
      await _json(
        'POST',
        '/session',
        body: title == null ? const {} : {'title': title},
      ),
    ),
  );

  @override
  Future<AiSession> session(String sessionId) async => AiSession.fromJson(
    _object(await _json('GET', '/session/${_segment(sessionId)}')),
  );

  @override
  Future<List<Map<String, dynamic>>> messages(String sessionId) async {
    final body = await _json('GET', '/session/${_segment(sessionId)}/message');
    if (body is! List) {
      throw const FormatException('Runtime messages response is not a list.');
    }
    return body
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList(growable: false);
  }

  @override
  Future<void> promptAsync(String sessionId, AiPrompt prompt) => _empty(
    'POST',
    '/session/${_segment(sessionId)}/prompt_async',
    body: prompt.toJson(),
  );

  @override
  Future<void> abort(String sessionId) =>
      _empty('POST', '/session/${_segment(sessionId)}/abort');

  @override
  Future<void> deleteSession(String sessionId) =>
      _empty('DELETE', '/session/${_segment(sessionId)}');

  @override
  Stream<AiRuntimeEvent> events() async* {
    final stream = await connectEvents();
    yield* stream;
  }

  @override
  Future<Stream<AiRuntimeEvent>> connectEvents() async {
    final request = http.Request('GET', _uri('/event'))
      ..headers.addAll(_headers(acceptSse: true));
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiRuntimeApiException(
        response.statusCode,
        await response.stream.bytesToString(),
      );
    }
    return _parseEventStream(response.stream);
  }

  Stream<AiRuntimeEvent> _parseEventStream(Stream<List<int>> byteStream) async* {
    final data = StringBuffer();
    String? currentEventType;
    await for (final line
        in byteStream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (data.isEmpty) {
          currentEventType = null;
          continue;
        }
        final decoded = jsonDecode(data.toString());
        data.clear();
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          if (!map.containsKey('type') && currentEventType != null) {
            map['type'] = currentEventType;
          }
          yield AiRuntimeEvent.fromJson(map);
        }
        currentEventType = null;
      } else if (line.startsWith('event:')) {
        currentEventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        if (data.isNotEmpty) data.write('\n');
        data.write(line.substring(5).trimLeft());
      }
    }
  }

  Future<Object?> _json(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final response = await _send(method, path, body: body);
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<void> _empty(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    await _send(method, path, body: body);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final request = http.Request(method, _uri(path))
      ..headers.addAll(_headers())
      ..body = body == null ? '' : jsonEncode(body);
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 10));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiRuntimeApiException(response.statusCode, response.body);
    }
    return response;
  }

  Uri _uri(String path) => endpoint.baseUri
      .resolve(path)
      .replace(queryParameters: {'directory': directory});

  Map<String, String> _headers({bool acceptSse = false}) => {
    HttpHeaders.authorizationHeader:
        'Basic ${base64Encode(utf8.encode('${endpoint.username}:${endpoint.password}'))}',
    HttpHeaders.acceptHeader: acceptSse
        ? 'text/event-stream'
        : 'application/json',
    HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
    endpoint.kind == AiRuntimeKind.openCode
            ? 'x-opencode-directory'
            : 'x-kilo-directory':
        directory,
  };

  static String _segment(String value) => Uri.encodeComponent(value);

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) {
      throw const FormatException('Runtime response is not an object.');
    }
    return Map<String, dynamic>.from(value);
  }

  static bool _isFreeModel(
    String providerId,
    String modelId,
    Map<String, dynamic> model,
  ) {
    final normalized = '$providerId/$modelId'.toLowerCase();
    if (normalized == 'kilo/kilo-auto/free' || normalized.endsWith(':free')) {
      return true;
    }
    final cost = model['cost'];
    if (cost is! Map || cost.isEmpty) return false;
    final numeric = cost.values.whereType<num>().toList(growable: false);
    return numeric.isNotEmpty && numeric.every((value) => value == 0);
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
  }
}

class AiRuntimeApiException implements Exception {
  const AiRuntimeApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'Runtime API returned HTTP $statusCode: $body';
}
