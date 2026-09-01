abstract interface class CompanionGateway {
  Future<Map<String, dynamic>> health();
  Future<Map<String, dynamic>> coaching();
  Future<Map<String, dynamic>> coachingStatus();
  Future<List<Map<String, dynamic>>> directives();
  Future<Map<String, dynamic>> players();
  Future<Map<String, dynamic>> config();
  Future<Map<String, dynamic>> lobbyState();
  Future<Map<String, dynamic>> lobbyHealth();
  Future<Map<String, dynamic>> generateLobbyBrief(String candidate);
  Future<Map<String, dynamic>> settings();
  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> patch);
  Future<Map<String, dynamic>> testVoice();
  Future<Map<String, dynamic>> importAll();
  Future<Map<String, dynamic>> scoutSummoner({
    required String name,
    required String tag,
    required String region,
  });
  Future<Map<String, dynamic>> scoutMatch({
    required int matchId,
    required String region,
    required String name,
    required String tag,
  });
  Future<Map<String, dynamic>> createSupportBundle();
  Future<Map<String, dynamic>> reportSupport({String? note});
  Stream<Map<String, dynamic>> alertEvents();
  Future<void> closeAlerts();
}

abstract interface class CompanionRuntime {
  Future<bool> ensureStarted();
  void dispose();
}

abstract interface class CoachGateway {
  Future<Map<String, dynamic>> health();
}

abstract interface class CoachRuntime {
  Future<bool> ensureStarted();
  void dispose();
}

class CompanionGatewayException implements Exception {
  const CompanionGatewayException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
