import 'package:flutter/material.dart';

import '../../../domain/jungle/jungle_recommendation.dart';
import '../shared/coach_surface.dart';

class RiotJungleRouteView extends StatelessWidget {
  const RiotJungleRouteView({super.key, required this.bundle});

  final JungleRecommendationBundle? bundle;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      title: 'Ruta recomendada por Riot',
      subtitle: bundle == null ? null : 'Parche ${bundle!.patch.value}',
      icon: Icons.route_outlined,
      child: bundle == null
          ? const CoachEmptyState(
              message: 'Esperando datos compatibles del cliente instalado.',
            )
          : Column(
              children: [
                _Route(label: 'ORDER', route: bundle!.order),
                const SizedBox(height: 12),
                _Route(label: 'CHAOS', route: bundle!.chaos),
              ],
            ),
    );
  }
}

class _Route extends StatelessWidget {
  const _Route({required this.label, required this.route});

  final String label;
  final JungleRoute route;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, ${route.camps.map((camp) => camp.name).join(', ')}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(
                color: CoachColors.cyan,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var index = 0; index < route.camps.length; index++) ...[
                  Chip(label: Text(route.camps[index].name.split(' ').last)),
                  if (index < route.camps.length - 1)
                    const ExcludeSemantics(
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: CoachColors.mutedText,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
