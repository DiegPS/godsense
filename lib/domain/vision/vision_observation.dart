import '../identity/league_identity.dart';

enum VisionObservationKind { enemySighting, gankThreat }

class VisionObservation {
  const VisionObservation({
    required this.kind,
    required this.champion,
    required this.location,
    required this.region,
    required this.observedAt,
    required this.confidence,
    this.role,
    this.gameTime,
  });

  final VisionObservationKind kind;
  final String champion;
  final String location;
  final String region;
  final String? role;
  final DateTime observedAt;
  final double confidence;
  final GameTime? gameTime;
}
