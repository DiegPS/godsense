import 'package:flutter/material.dart';

import '../../../application/coach_controller.dart';
import '../shared/coach_surface.dart';

class PickAdviceCard extends StatelessWidget {
  const PickAdviceCard({super.key, required this.advice});

  final List<PickAdviceViewData> advice;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      title: 'Sugerencias de selección',
      icon: Icons.recommend_outlined,
      child: advice.isEmpty
          ? const CoachEmptyState(
              message: 'Aún no hay sugerencias con experiencia registrada en tu posición. Juega y sincroniza partidas para ampliar tu selección.',
            )
          : Column(
              children: [
                for (final suggestion in advice.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.shield_outlined,
                      color: CoachColors.cyan,
                    ),
                    title: Text(suggestion.champion),
                    subtitle: suggestion.reasons.isEmpty
                        ? null
                        : Text(suggestion.reasons.join('\n')),
                    trailing: suggestion.scoreLabel == null
                        ? null
                        : Text(suggestion.scoreLabel!),
                  ),
              ],
            ),
    );
  }
}
