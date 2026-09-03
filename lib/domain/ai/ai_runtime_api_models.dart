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
    'tools': <String, Object>{},
    'toolChoice': 'none',
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

  String? get textDelta {
    final delta = properties['delta'];
    if (delta is String) return delta;
    final text = properties['text'];
    if (text is String) return text;
    final part = properties['part'];
    if (part is Map && part['text'] is String) return part['text'] as String;
    return null;
  }

  String? get sessionId {
    final id = properties['sessionID'] ?? properties['sessionId'] ?? raw['sessionID'];
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
