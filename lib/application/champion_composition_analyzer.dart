import '../domain/tactical/composition_models.dart';

class ChampionCompositionAnalyzer {
  const ChampionCompositionAnalyzer();

  Map<String, dynamic>? profile(List<Map<String, dynamic>> team) {
    return typedProfile(team)?.toJson();
  }

  DeterministicCompositionProfile? typedProfile(
    List<Map<String, dynamic>> team,
  ) {
    final profiles = team
        .map((player) => _map(player['champion_profile']))
        .where((profile) => _map(profile['playstyle']).isNotEmpty)
        .toList();
    if (profiles.isEmpty) return null;
    const fields = [
      'damage',
      'durability',
      'crowdControl',
      'mobility',
      'utility',
    ];
    final axes = <String, double>{};
    for (final field in fields) {
      final values = profiles
          .map((profile) => _map(profile['playstyle'])[field])
          .whereType<num>()
          .where((value) => value >= 0 && value <= 3)
          .toList();
      if (values.isNotEmpty) {
        axes[field] =
            (values.fold<num>(0, (sum, value) => sum + value) /
                    values.length *
                    10)
                .round() /
            10;
      }
    }
    final classes = <String, int>{};
    final damageTypes = <String, int>{};
    for (final profile in profiles) {
      final roles = profile['classes'];
      if (roles is List) {
        for (final role in roles.whereType<String>()) {
          classes.update(role, (count) => count + 1, ifAbsent: () => 1);
        }
      }
      final type = _map(profile['tactical'])['damageType']?.toString();
      if (type != null) {
        damageTypes.update(type, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final control = axes['crowdControl'] ?? 0;
    final durability = axes['durability'] ?? 0;
    final mobility = axes['mobility'] ?? 0;
    return DeterministicCompositionProfile(
      axes: CompositionAxes(
        damage: axes['damage'],
        durability: axes['durability'],
        crowdControl: axes['crowdControl'],
        mobility: axes['mobility'],
        utility: axes['utility'],
      ),
      knownChampions: profiles.length,
      totalChampions: team.length,
      damageTypes: Map.unmodifiable(damageTypes),
      archetype: control >= 2 && durability >= 2
          ? 'Control y resistencia'
          : mobility >= 2
          ? 'Movilidad'
          : 'Perfil mixto',
      confidence: profiles.length / (team.isEmpty ? 1 : team.length) * 0.7,
    );
  }

  Map<String, dynamic> analyze(
    List<Map<String, dynamic>> allies,
    List<Map<String, dynamic>> enemies,
  ) {
    final ally = profile(allies);
    final enemy = profile(enemies);
    final axes = _map(ally?['axes']);
    final guidelines = <String>[];
    if (ally == null) {
      guidelines.add('Esperando atributos de campeones del cliente de League.');
    } else {
      if ((axes['durability'] as num? ?? 0) < 1.5) {
        guidelines.add(
          'Resistencia limitada: evita iniciar de frente sin ventaja numérica.',
        );
      } else {
        guidelines.add(
          'Usa la primera línea para crear espacio antes de comprometer a los carries.',
        );
      }
      if ((axes['crowdControl'] as num? ?? 0) >= 2) {
        guidelines.add(
          'Encadena el control de masas; evita gastar todo sobre el mismo objetivo a la vez.',
        );
      } else {
        guidelines.add(
          'Control limitado: prepara la pelea con visión y evita perseguir sin recursos.',
        );
      }
      final damage = _map(ally['damage_types']);
      if (damage.length == 1 && allies.length >= 3) {
        guidelines.add(
          'Predomina un solo tipo de daño; considera diversificar los picks restantes.',
        );
      }
    }
    return {
      'identity': ally?['archetype'] ?? 'Composición pendiente',
      'guidelines': guidelines,
      'teamfight_positioning': (axes['mobility'] as num? ?? 0) >= 2
          ? 'Coordina los flancos con la llegada del resto del equipo.'
          : 'Mantén una formación conectada y una ruta de retirada visible.',
      'teamfight_hints': guidelines,
      'ally_profile': ally,
      'enemy_profile': enemy,
      'source': 'lcu_champion_playstyle',
    };
  }
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : const {};
