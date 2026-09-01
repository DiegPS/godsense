import '../identity/league_identity.dart';

enum JungleSide { order, chaos }

class JungleCamp {
  const JungleCamp({
    required this.locationId,
    required this.name,
    required this.x,
    required this.z,
  });

  final int locationId;
  final String name;
  final double x;
  final double z;
}

class JungleRoute {
  const JungleRoute({required this.side, required this.camps});

  final JungleSide side;
  final List<JungleCamp> camps;
}

class JungleRecommendationBundle {
  const JungleRecommendationBundle({
    required this.patch,
    required this.mapId,
    required this.order,
    required this.chaos,
    required this.fetchedAt,
    required this.sourceUri,
  });

  final PatchKey patch;
  final int mapId;
  final JungleRoute order;
  final JungleRoute chaos;
  final DateTime fetchedAt;
  final Uri sourceUri;

  JungleRoute forSide(JungleSide side) =>
      side == JungleSide.order ? order : chaos;
}

class JungleRecommendationException implements Exception {
  const JungleRecommendationException(this.message);

  final String message;

  @override
  String toString() => 'JungleRecommendationException: $message';
}
