enum LcuProbeFailureKind {
  disconnected,
  unauthorized,
  timeout,
  serverError,
  clientError,
  invalidPayload,
}

class LcuProbeResponse {
  const LcuProbeResponse.success({required this.body, required this.statusCode})
    : failureKind = null,
      error = null;

  const LcuProbeResponse.failure({
    required this.failureKind,
    this.statusCode,
    this.body,
    this.error,
  });

  final int? statusCode;
  final Object? body;
  final LcuProbeFailureKind? failureKind;
  final String? error;

  bool get isSuccess => failureKind == null;
}

abstract interface class LcuProbeTransport {
  Future<LcuProbeResponse> getDetailed(String path);
}

abstract interface class LcuReadTransport implements LcuProbeTransport {
  Future<Object?> get(String path);
}
