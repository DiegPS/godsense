enum ArtifactArchiveType { none, zip, tar, tarGzip, tarBzip2, tarXz }

class ArtifactPayloadSpec {
  const ArtifactPayloadSpec({
    required this.id,
    required this.uri,
    required this.sha256,
    required this.bytes,
    required this.fileName,
    this.archiveType = ArtifactArchiveType.none,
    this.targetPath,
    this.headers = const {},
  });

  final String id;
  final Uri uri;
  final String sha256;
  final int bytes;
  final String fileName;
  final ArtifactArchiveType archiveType;
  final String? targetPath;
  final Map<String, String> headers;

  factory ArtifactPayloadSpec.fromJson(Map<String, dynamic> json) {
    final archiveName = json['archiveType'] as String? ?? 'none';
    final archiveType = ArtifactArchiveType.values.where(
      (value) => value.name == archiveName,
    );
    if (archiveType.isEmpty) {
      throw FormatException('Unknown artifact archive type: $archiveName');
    }
    final rawHeaders = json['headers'];
    if (rawHeaders != null && rawHeaders is! Map) {
      throw const FormatException('Artifact headers must be an object.');
    }
    return ArtifactPayloadSpec(
      id: _requiredString(json, 'id'),
      uri: Uri.parse(_requiredString(json, 'uri')),
      sha256: _requiredString(json, 'sha256'),
      bytes: _requiredInt(json, 'bytes'),
      fileName: _requiredString(json, 'fileName'),
      archiveType: archiveType.single,
      targetPath: json['targetPath'] as String?,
      headers: rawHeaders == null
          ? const {}
          : rawHeaders.map<String, String>((key, value) {
              if (key is! String || value is! String) {
                throw const FormatException(
                  'Artifact headers must contain strings.',
                );
              }
              return MapEntry(key, value);
            }),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'uri': uri.toString(),
    'sha256': sha256,
    'bytes': bytes,
    'fileName': fileName,
    'archiveType': archiveType.name,
    if (targetPath != null) 'targetPath': targetPath,
    if (headers.isNotEmpty) 'headers': headers,
  };
}

class ArtifactSpec {
  const ArtifactSpec({
    required this.id,
    required this.version,
    required this.group,
    required this.payloads,
    required this.requiredPaths,
    this.archiveRoot,
    this.removeAfterExtract = const [],
  });

  final String id;
  final String version;
  final String group;
  final List<ArtifactPayloadSpec> payloads;
  final List<String> requiredPaths;
  final String? archiveRoot;
  final List<String> removeAfterExtract;

  factory ArtifactSpec.fromJson(Map<String, dynamic> json) => ArtifactSpec(
    id: _requiredString(json, 'id'),
    version: _requiredString(json, 'version'),
    group: _requiredString(json, 'group'),
    payloads: _requiredList(json, 'payloads')
        .map(
          (value) =>
              ArtifactPayloadSpec.fromJson(_requiredObject(value, 'payload')),
        )
        .toList(growable: false),
    requiredPaths: _stringList(json, 'requiredPaths'),
    archiveRoot: json['archiveRoot'] as String?,
    removeAfterExtract: json['removeAfterExtract'] == null
        ? const []
        : _stringList(json, 'removeAfterExtract'),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'version': version,
    'group': group,
    'payloads': payloads.map((value) => value.toJson()).toList(growable: false),
    'requiredPaths': requiredPaths,
    if (archiveRoot != null) 'archiveRoot': archiveRoot,
    if (removeAfterExtract.isNotEmpty) 'removeAfterExtract': removeAfterExtract,
  };
}

enum ArtifactInstallPhase {
  checking,
  downloading,
  verifying,
  extracting,
  validating,
  activating,
  installed,
}

class ArtifactInstallProgress {
  const ArtifactInstallProgress({
    required this.phase,
    required this.message,
    this.receivedBytes = 0,
    this.totalBytes = 0,
  });

  final ArtifactInstallPhase phase;
  final String message;
  final int receivedBytes;
  final int totalBytes;

  double? get fraction =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0, 1) : null;
}

class ArtifactInstallation {
  const ArtifactInstallation({required this.spec, required this.directoryPath});

  final ArtifactSpec spec;
  final String directoryPath;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Artifact $key must be a non-empty string.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || value.toInt() != value) {
    throw FormatException('Artifact $key must be an integer.');
  }
  return value.toInt();
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('Artifact $key must be a list.');
  return value;
}

Map<String, dynamic> _requiredObject(Object? value, String name) {
  if (value is! Map) throw FormatException('Artifact $name must be an object.');
  return Map<String, dynamic>.from(value);
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final values = _requiredList(json, key);
  if (values.any((value) => value is! String)) {
    throw FormatException('Artifact $key must contain strings.');
  }
  return values.cast<String>().toList(growable: false);
}
