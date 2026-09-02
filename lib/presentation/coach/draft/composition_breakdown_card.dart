import 'package:flutter/material.dart';

import '../../../domain/tactical/composition_models.dart';
import '../shared/coach_surface.dart';

class CompositionBreakdownCard extends StatelessWidget {
  const CompositionBreakdownCard({
    super.key,
    required this.ally,
    required this.enemy,
  });

  final DeterministicCompositionProfile? ally;
  final DeterministicCompositionProfile? enemy;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      title: 'Evaluación determinista de composición',
      subtitle: 'Atributos estáticos · evaluador v1 · escala 0–3',
      icon: Icons.balance_outlined,
      child: ally == null && enemy == null
          ? const CoachEmptyState(
              message: 'Esperando que los equipos seleccionen sus campeones.',
            )
          : Column(
              children: [
                for (final axis in const [
                  ('Daño', 'damage'),
                  ('Resistencia', 'durability'),
                  ('Control', 'crowdControl'),
                  ('Movilidad', 'mobility'),
                  ('Utilidad', 'utility'),
                ])
                  _AxisComparison(
                    label: axis.$1,
                    ally: ally?.axes.toMap()[axis.$2] ?? 0,
                    enemy: enemy?.axes.toMap()[axis.$2] ?? 0,
                  ),
                const SizedBox(height: 8),
                Text(
                  'Aliado: ${ally?.archetype ?? 'sin datos'} · '
                  'Rival: ${enemy?.archetype ?? 'sin datos'}',
                  style: const TextStyle(color: CoachColors.secondaryText),
                ),
              ],
            ),
    );
  }
}

class _AxisComparison extends StatelessWidget {
  const _AxisComparison({
    required this.label,
    required this.ally,
    required this.enemy,
  });

  final String label;
  final double ally;
  final double enemy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, aliados $ally de 3, rivales $enemy de 3',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: 82,
              child: Text(
                label,
                style: const TextStyle(color: CoachColors.secondaryText),
              ),
            ),
            Expanded(
              child: _Bar(value: ally, color: CoachColors.cyan),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 28,
              child: Text(
                ally.toStringAsFixed(1),
                style: const TextStyle(color: CoachColors.cyan, fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Bar(value: enemy, color: CoachColors.crimson),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 28,
              child: Text(
                enemy.toStringAsFixed(1),
                style: const TextStyle(
                  color: CoachColors.crimson,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: (value / 3).clamp(0, 1),
        minHeight: 8,
        color: color,
        backgroundColor: CoachColors.elevated,
      ),
    );
  }
}
