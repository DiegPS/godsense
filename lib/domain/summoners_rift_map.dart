import 'dart:math' as math;

class MapLocation {
  const MapLocation(this.name, this.x, this.y, this.region);

  final String name;
  final double x;
  final double y;
  final String region;
}

const summonersRiftLocations = <MapLocation>[
  MapLocation('Dragon Pit', .680, .693, 'BOT_RIVER'),
  MapLocation('Baron Pit', .350, .320, 'TOP_RIVER'),
  MapLocation('Blue Red Buff', .541, .718, 'BLUE_JUNGLE_BOT'),
  MapLocation('Blue Blue Buff', .271, .478, 'BLUE_JUNGLE_TOP'),
  MapLocation('Red Red Buff', .489, .282, 'RED_JUNGLE_TOP'),
  MapLocation('Red Blue Buff', .756, .540, 'RED_JUNGLE_BOT'),
  MapLocation('Blue Raptors', .487, .636, 'BLUE_JUNGLE_BOT'),
  MapLocation('Blue Wolves', .284, .567, 'BLUE_JUNGLE_TOP'),
  MapLocation('Blue Gromp', .179, .440, 'BLUE_JUNGLE_TOP'),
  MapLocation('Blue Krugs', .577, .811, 'BLUE_JUNGLE_BOT'),
  MapLocation('Red Raptors', .539, .373, 'RED_JUNGLE_TOP'),
  MapLocation('Red Wolves', .752, .447, 'RED_JUNGLE_BOT'),
  MapLocation('Red Gromp', .855, .560, 'RED_JUNGLE_BOT'),
  MapLocation('Red Krugs', .444, .204, 'RED_JUNGLE_TOP'),
  MapLocation('Top Scuttler', .312, .358, 'TOP_RIVER'),
  MapLocation('Bot Scuttler', .714, .642, 'BOT_RIVER'),
  MapLocation('Top River', .246, .258, 'TOP_RIVER'),
  MapLocation('Bot River', .784, .727, 'BOT_RIVER'),
  MapLocation('Top Tri-bush', .310, .225, 'TOP_RIVER'),
  MapLocation('Bot Tri-bush', .714, .782, 'BOT_RIVER'),
  MapLocation('Top Lane Bush', .141, .164, 'TOP_LANE'),
  MapLocation('Mid Top Bush', .447, .455, 'MID_LANE'),
  MapLocation('Mid Bot Bush', .585, .567, 'MID_LANE'),
  MapLocation('Bot Lane Bush', .880, .842, 'BOT_LANE'),
  MapLocation('Top Alcove', .118, .144, 'TOP_LANE'),
  MapLocation('Bot Alcove', .917, .876, 'BOT_LANE'),
  MapLocation('Blue Top Outer Turret', .094, .293, 'TOP_LANE'),
  MapLocation('Blue Top Inner Turret', .132, .549, 'TOP_LANE'),
  MapLocation('Blue Mid Outer Turret', .410, .573, 'MID_LANE'),
  MapLocation('Blue Mid Inner Turret', .357, .682, 'MID_LANE'),
  MapLocation('Blue Bot Outer Turret', .720, .911, 'BOT_LANE'),
  MapLocation('Blue Bot Inner Turret', .481, .887, 'BOT_LANE'),
  MapLocation('Red Top Outer Turret', .308, .111, 'TOP_LANE'),
  MapLocation('Red Top Inner Turret', .551, .136, 'TOP_LANE'),
  MapLocation('Red Mid Outer Turret', .615, .442, 'MID_LANE'),
  MapLocation('Red Mid Inner Turret', .662, .336, 'MID_LANE'),
  MapLocation('Red Bot Outer Turret', .938, .702, 'BOT_LANE'),
  MapLocation('Red Bot Inner Turret', .893, .462, 'BOT_LANE'),
  MapLocation('Blue Top Lane (outer-inner)', .107, .418, 'TOP_LANE'),
  MapLocation('Blue Mid Lane (outer-inner)', .376, .624, 'MID_LANE'),
  MapLocation('Blue Bot Lane (outer-inner)', .590, .902, 'BOT_LANE'),
  MapLocation('Red Top Lane (outer-inner)', .434, .115, 'TOP_LANE'),
  MapLocation('Red Mid Lane (outer-inner)', .639, .391, 'MID_LANE'),
  MapLocation('Red Bot Lane (outer-inner)', .915, .585, 'BOT_LANE'),
  MapLocation('Blue Top Lane (inner-inhib)', .117, .631, 'TOP_LANE'),
  MapLocation('Blue Mid Lane (inner-inhib)', .306, .700, 'MID_LANE'),
  MapLocation('Blue Bot Lane (inner-inhib)', .408, .889, 'BOT_LANE'),
  MapLocation('Red Top Lane (inner-inhib)', .622, .109, 'TOP_LANE'),
  MapLocation('Red Mid Lane (inner-inhib)', .714, .311, 'MID_LANE'),
  MapLocation('Red Bot Lane (inner-inhib)', .917, .387, 'BOT_LANE'),
  MapLocation('Blue Top Inhibitor', .103, .749, 'BLUE_BASE'),
  MapLocation('Blue Mid Inhibitor', .237, .771, 'BLUE_BASE'),
  MapLocation('Blue Bot Inhibitor', .254, .896, 'BLUE_BASE'),
  MapLocation('Red Top Inhibitor', .763, .116, 'RED_BASE'),
  MapLocation('Red Mid Inhibitor', .782, .240, 'RED_BASE'),
  MapLocation('Red Bot Inhibitor', .915, .253, 'RED_BASE'),
  MapLocation('Top Lane Center', .100, .140, 'TOP_LANE'),
  MapLocation('Mid Lane Center', .500, .500, 'MID_LANE'),
  MapLocation('Bot Lane Center', .900, .860, 'BOT_LANE'),
  MapLocation('Blue Nexus', .132, .865, 'BLUE_BASE'),
  MapLocation('Red Nexus', .895, .136, 'RED_BASE'),
];

const gankZonesByRole = <String, Set<String>>{
  'TOP': {
    'Top River',
    'Top Tri-bush',
    'Top Scuttler',
    'Blue Gromp',
    'Red Krugs',
  },
  'MIDDLE': {
    'Top River',
    'Bot River',
    'Top Scuttler',
    'Bot Scuttler',
    'Blue Raptors',
    'Red Raptors',
  },
  'BOTTOM': {
    'Bot River',
    'Bot Tri-bush',
    'Bot Scuttler',
    'Red Gromp',
    'Blue Krugs',
  },
  'UTILITY': {
    'Bot River',
    'Bot Tri-bush',
    'Bot Scuttler',
    'Red Gromp',
    'Blue Krugs',
  },
  'JUNGLE': {},
};

MapLocation resolveMapLocation(
  double x,
  double y,
  double width,
  double height,
) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('Minimap dimensions must be positive.');
  }
  final nx = x / width;
  final ny = y / height;
  return summonersRiftLocations.reduce((best, candidate) {
    final bestDistance = math.pow(nx - best.x, 2) + math.pow(ny - best.y, 2);
    final candidateDistance =
        math.pow(nx - candidate.x, 2) + math.pow(ny - candidate.y, 2);
    return candidateDistance < bestDistance ? candidate : best;
  });
}
