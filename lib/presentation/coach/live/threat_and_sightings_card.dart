import 'package:flutter/material.dart';

import '../../../application/coach_controller.dart';
import '../shared/coach_surface.dart';

class ThreatAndSightingsCard extends StatelessWidget {
  const ThreatAndSightingsCard({super.key, required this.threats});

  final List<CoachThreatViewData> threats;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      title: 'Estado de amenaza y avistamientos',
      subtitle: 'Fuente: visión nativa DartCV',
      icon: Icons.radar_outlined,
      child: threats.isEmpty
          ? const CoachEmptyState(
              message: 'Sin amenazas recientes detectadas.',
              icon: Icons.visibility_outlined,
            )
          : Column(
              children: [
                for (final threat in threats.take(8))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      threat.isGank
                          ? Icons.warning_amber_rounded
                          : Icons.visibility_outlined,
                      color: threat.isGank
                          ? CoachColors.crimson
                          : CoachColors.amber,
                    ),
                    title: Text('${threat.champion} · ${threat.location}'),
                    subtitle: Text(
                      '${threat.role ?? 'Rol sin confirmar'} · '
                      'confianza ${(threat.confidence * 100).round()}%',
                    ),
                    trailing: Text(
                      _age(threat.observedAt),
                      style: const TextStyle(
                        color: CoachColors.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

String _age(DateTime timestamp) {
  final seconds = DateTime.now().difference(timestamp).inSeconds.clamp(0, 9999);
  if (seconds < 60) return '${seconds}s';
  return '${seconds ~/ 60}m';
}
