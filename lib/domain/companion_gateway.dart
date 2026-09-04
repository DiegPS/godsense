abstract interface class CompanionGateway {
  Future<Map<String, dynamic>> health();
  Future<Map<String, dynamic>> coaching();
  Future<Map<String, dynamic>> coachingStatus();
  Future<List<Map<String, dynamic>>> directives();
  Future<Map<String, dynamic>> lobbyState();
  Future<Map<String, dynamic>> lobbyHealth();
  Future<Map<String, dynamic>> generateLobbyBrief(String candidate);
  Future<Map<String, dynamic>> settings();
  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> patch);
  Stream<Map<String, dynamic>> alertEvents();
  Future<void> closeAlerts();
}

class CompanionGatewayException implements Exception {
  const CompanionGatewayException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
