import '../domain/tactical/tactical_models.dart';

class NativeTacticalEngine {
  NativeTacticalEngine({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  Map<String, dynamic> analyze({
    Map<String, dynamic>? lobby,
    Map<String, dynamic>? game,
    String? selectedEnemy,
  }) {
    final normalizedLobby = lobby ?? const <String, dynamic>{};
    final snapshot = _map(normalizedLobby['snapshot']);
    final allies = _mapList(snapshot['my_team']);
    final enemies = _mapList(snapshot['their_team']);
    final local = allies
        .where((player) => player['is_local'] == true)
        .firstOrNull;
    final localChampion = _champion(local);
    final opponent =
        selectedEnemy ??
        enemies.map(_champion).where((name) => name.isNotEmpty).firstOrNull;
    final matchup = localChampion.isEmpty || opponent == null
        ? null
        : _matchup(localChampion, opponent);
    final comp = _teamComposition(allies, enemies);
    return {
      'matchup': ?matchup,
      'team_comp': comp,
      'comp_analysis': {'ally': _profile(allies), 'enemy': _profile(enemies)},
      'knowledge': {
        'producer': 'native-tactical-engine',
        'producer_version': '1',
        'builds_withheld': true,
        'reason': 'No patch-exact champion build contract is loaded.',
      },
      if (game != null) 'live_context': {'phase': game['phase']},
    };
  }

  List<TacticalAdvice> directives(Map<String, dynamic>? game) {
    if (game == null || game['_game_ended'] == true) return const [];
    final now = _now().toUtc();
    final gameTime = (game['game_time'] as num?)?.toDouble();
    final active = _map(game['active_player']);
    final derived = _map(game['derived']);
    final objectiveAdvice = _objectiveDirective(
      _map(derived['objectives']),
      now,
      gameTime,
    );
    if (active['is_dead'] == true) {
      return [
        TacticalAdvice(
          id: 'death_reset',
          title: 'Planifica el siguiente reset',
          hints: const [
            'Revisa el temporizador del próximo objetivo.',
            'Decide la ruta antes de reaparecer.',
          ],
          rationale: 'Estás muerto; comprar y planificar no arriesga recursos.',
          ttsText: 'Mientras reapareces, compra y decide tu ruta al próximo objetivo.',
          priority: 100,
          evidence: [
            _evidence(
              'active_player_dead',
              FactSource.liveClient,
              now,
              gameTime,
            ),
          ],
        ),
      ];
    }
    if (objectiveAdvice != null) return [objectiveAdvice];

    final gold = (game['team_gold_diff'] as num?)?.toInt() ?? 0;
    if (gold <= -1000) {
      return [
        TacticalAdvice(
          id: 'recover_resources',
          title: 'Recupera recursos sin forzar',
          hints: const [
            'Recoge la oleada segura más cercana.',
            'Cede visión profunda si no tienes prioridad.',
          ],
          rationale: 'El equipo está por detrás en oro ($gold).',
          ttsText: 'Están por detrás. Recoge recursos seguros y evita pelear sin ventaja.',
          priority: 70,
          evidence: [
            _evidence('team_gold_deficit', FactSource.derived, now, gameTime),
          ],
        ),
      ];
    }
    if (gold >= 1000) {
      return [
        TacticalAdvice(
          id: 'convert_lead',
          title: 'Convierte la ventaja',
          hints: const [
            'Empuja antes de entrar al río.',
            'Invade sólo con líneas con prioridad.',
          ],
          rationale: 'El equipo tiene una ventaja de oro de $gold.',
          ttsText: 'Tienen ventaja. Empuja y conviértela en visión u objetivo.',
          priority: 60,
          evidence: [
            _evidence('team_gold_lead', FactSource.derived, now, gameTime),
          ],
        ),
      ];
    }
    return [
      TacticalAdvice(
        id: 'neutral_setup',
        title: 'Prepara la siguiente jugada',
        hints: const [
          'Empuja tu oleada antes de moverte.',
          'Comprueba posiciones enemigas en el minimapa.',
        ],
        rationale: 'La diferencia de oro está equilibrada ($gold).',
        ttsText:
            'La partida está pareja. Empuja primero y juega con información.',
        priority: 40,
        evidence: [
          _evidence('team_gold_even', FactSource.derived, now, gameTime),
        ],
      ),
    ];
  }

  TacticalQualityMetrics evaluate(List<TacticalAdvice> advice) {
    if (advice.isEmpty) {
      return const TacticalQualityMetrics(
        evidenceCoverage: 1,
        actionability: 1,
        temporalRelevance: 1,
        contradictionCount: 0,
      );
    }
    final withEvidence = advice
        .where((item) => item.evidence.isNotEmpty)
        .length;
    final actionable = advice
        .where((item) => item.hints.isNotEmpty && item.ttsText.isNotEmpty)
        .length;
    final relevant = advice.where((item) {
      return item.evidence.every((evidence) => evidence.confidence >= 0.5);
    }).length;
    final ids = <String>{};
    var contradictions = 0;
    for (final item in advice) {
      if (!ids.add(item.id)) contradictions++;
    }
    return TacticalQualityMetrics(
      evidenceCoverage: withEvidence / advice.length,
      actionability: actionable / advice.length,
      temporalRelevance: relevant / advice.length,
      contradictionCount: contradictions,
    );
  }

  TacticalAdvice? _objectiveDirective(
    Map<String, dynamic> objectives,
    DateTime now,
    double? gameTime,
  ) {
    final candidates = <(String, double)>[];
    for (final entry in objectives.entries) {
      final value = _map(entry.value);
      final seconds = (value['respawn_in'] as num?)?.toDouble();
      if (seconds != null && seconds >= 0 && seconds <= 75) {
        candidates.add((entry.key, seconds));
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.$2.compareTo(b.$2));
    final target = candidates.first;
    final label = _objectiveLabel(target.$1);
    final seconds = target.$2.round();
    return TacticalAdvice(
      id: 'prepare_${target.$1}',
      title: 'Prepara $label',
      hints: [
        'Empuja la línea antes de moverte.',
        'Limpia y coloca visión en los accesos.',
      ],
      rationale: '$label estará disponible en $seconds segundos.',
      ttsText: '$label en $seconds segundos. Empuja y prepara visión.',
      priority: 90,
      evidence: [
        _evidence('${target.$1}_timer', FactSource.derived, now, gameTime),
      ],
    );
  }
}

TacticalEvidence _evidence(
  String fact,
  FactSource source,
  DateTime observedAt,
  double? gameTime,
) => TacticalEvidence(
  factType: fact,
  source: source,
  observedAt: observedAt,
  confidence: 1,
  gameTimeSeconds: gameTime,
);

Map<String, dynamic> _matchup(String champion, String enemy) => {
  'trading_patterns': [
    'Busca intercambios después de que $enemy gaste su habilidad principal.',
    'Conserva una salida hasta localizar al jungla enemigo.',
  ],
  'power_spikes': ['Nivel 6 de $champion.', 'Primer objeto completo.'],
  'win_condition':
      'Controla la oleada y fuerza acciones sólo con información del jungla.',
  'avoid': [
    'Intercambiar dentro de una oleada enemiga grande.',
    'Entrar al río sin prioridad ni visión.',
  ],
  'matchup_intel_n': 0,
  'confidence': 0.55,
  'source': 'deterministic_general_rule',
};

Map<String, dynamic> _teamComposition(
  List<Map<String, dynamic>> allies,
  List<Map<String, dynamic>> enemies,
) {
  final ally = _profile(allies);
  final known = ally?['known'] as int? ?? 0;
  return {
    'identity': known == 5
        ? 'Composición equilibrada por roles'
        : 'Composición pendiente ($known/5)',
    'guidelines': const [
      'Agrupa después de empujar las líneas laterales.',
      'No inicies sin identificar la amenaza principal.',
    ],
    'teamfight_positioning':
        'Frente y retaguardia deben mantener distancia de apoyo.',
    'teamfight_hints': const [
      'Guarda control para la primera amenaza que alcance a tus carries.',
      'Evita perseguir fuera de visión tras ganar espacio.',
    ],
    'ally_profile': ally,
    'enemy_profile': _profile(enemies),
  };
}

Map<String, dynamic>? _profile(List<Map<String, dynamic>> team) {
  final known = team.where((player) => _champion(player).isNotEmpty).length;
  if (known == 0) return null;
  final roles = team
      .map((player) => player['position']?.toString().toUpperCase() ?? '')
      .where((role) => role.isNotEmpty)
      .toSet();
  return {
    'axes': {
      'engage': _axis(roles, {'JUNGLE', 'UTILITY', 'SUPPORT', 'TOP'}),
      'pick': _axis(roles, {'JUNGLE', 'MIDDLE', 'MID'}),
      'poke': _axis(roles, {'MIDDLE', 'MID', 'BOTTOM', 'BOT'}),
      'split': _axis(roles, {'TOP', 'MIDDLE', 'MID'}),
      'peel': _axis(roles, {'UTILITY', 'SUPPORT', 'JUNGLE'}),
    },
    'known': known,
    'total': team.length,
    'archetype': roles.length >= 4 ? 'balanced' : 'incomplete',
    'confidence': known / 5,
  };
}

int _axis(Set<String> roles, Set<String> contributing) =>
    (roles.intersection(contributing).length * 2).clamp(0, 10);

String _champion(Map<String, dynamic>? player) =>
    player?['champion_name']?.toString().trim() ?? '';

String _objectiveLabel(String key) => switch (key) {
  'dragon' => 'dragón',
  'baron' => 'Barón',
  'herald' => 'Heraldo',
  'void_grubs' => 'larvas del Vacío',
  _ => key,
};

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : const {};

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false)
    : const [];
