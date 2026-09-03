class AiModelInfo {
  const AiModelInfo({
    required this.id,
    required this.name,
    required this.providerId,
    required this.isFree,
    this.supportsReasoning = false,
  });

  final String id;
  final String name;
  final String providerId;
  final bool isFree;
  final bool supportsReasoning;
}

class AiProviderInfo {
  const AiProviderInfo({
    required this.id,
    required this.name,
    required this.connected,
    required this.models,
  });

  final String id;
  final String name;
  final bool connected;
  final List<AiModelInfo> models;
}

class AiAuthMethod {
  const AiAuthMethod({
    required this.providerId,
    required this.type,
    required this.label,
    required this.index,
  });

  final String providerId;
  final String type;
  final String label;
  final int index;
}

class AiSession {
  const AiSession({required this.id, this.title});

  final String id;
  final String? title;

  factory AiSession.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Runtime session response has no id.');
    }
    return AiSession(id: id, title: json['title']?.toString());
  }
}

class AiPrompt {
  const AiPrompt({
    required this.providerId,
    required this.modelId,
    required this.system,
    required this.text,
  });

  final String providerId;
  final String modelId;
  final String system;
  final String text;

  Map<String, Object> toJson() => {
    'model': {'providerID': providerId, 'modelID': modelId},
    'system': system,
    // En Kilo / OpenCode prompt.ts, tools es un mapa de patrones a permisos booleanos.
    // {'*': false} deniega expresamente la ejecución de cualquier herramienta.
    'tools': const <String, Object>{'*': false},
    'parts': [
      {'type': 'text', 'text': text},
    ],
  };
}

class AiRuntimeEvent {
  const AiRuntimeEvent({
    required this.type,
    required this.properties,
    required this.raw,
  });

  final String type;
  final Map<String, dynamic> properties;
  final Map<String, dynamic> raw;

  factory AiRuntimeEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : json;
    return AiRuntimeEvent(
      type: payload['type']?.toString() ?? 'unknown',
      properties: payload['properties'] is Map
          ? Map<String, dynamic>.from(payload['properties'] as Map)
          : const {},
      raw: json,
    );
  }

  /// Retorna exclusivamente fragmentos incrementales emitidos por message.part.delta
  String? get textDelta {
    final delta = properties['delta'];
    if (delta is String) return delta;
    return null;
  }

  /// Retorna el texto consolidado de la parte cuando Kilo emite message.part.updated o message.updated
  String? get fullPartText {
    final part = properties['part'];
    if (part is Map && part['text'] is String) return part['text'] as String;
    final text = properties['text'];
    if (text is String && type != 'message.part.delta') return text;
    return null;
  }

  String? get sessionId {
    final id = properties['sessionID'] ??
        properties['sessionId'] ??
        properties['id'] ??
        (properties['info'] is Map ? (properties['info'] as Map)['sessionID'] : null) ??
        (properties['part'] is Map ? (properties['part'] as Map)['sessionID'] : null) ??
        raw['sessionID'];
    return id?.toString();
  }

  String? get messageId {
    final id = properties['messageID'] ??
        properties['messageId'] ??
        (properties['info'] is Map ? (properties['info'] as Map)['id'] : null) ??
        (properties['part'] is Map ? (properties['part'] as Map)['messageID'] : null) ??
        raw['messageID'];
    return id?.toString();
  }

  String? get partId {
    final id = properties['partID'] ??
        properties['partId'] ??
        (properties['part'] is Map ? (properties['part'] as Map)['id'] : null) ??
        raw['partID'];
    return id?.toString();
  }

  bool get isCompleted {
    if (type == 'message.completed' || type == 'session.idle') return true;
    if (type == 'message.status' && properties['status'] == 'completed') return true;
    final status = properties['status'];
    if (type == 'session.status') {
      if (status is Map && status['type'] == 'idle') return true;
      if (status == 'idle') return true;
    }
    final info = properties['info'];
    if (type == 'message.updated' && info is Map) {
      final finish = info['finish'];
      if (finish != null && finish.toString() != 'null') return true;
    }
    return false;
  }

  bool get isError =>
      type.toLowerCase().contains('error') || properties.containsKey('error');
}
