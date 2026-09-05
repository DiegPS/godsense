import 'package:flutter/material.dart';

import '../../../application/coach_controller.dart';
import '../../shared/resilient_network_image.dart';
import '../shared/asset_portrait.dart';
import '../shared/coach_surface.dart';

class ThreatAndSightingsCard extends StatelessWidget {
  const ThreatAndSightingsCard({super.key, required this.threats});

  final List<CoachThreatViewData> threats;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      title: 'Estado de amenaza y avistamientos',
      subtitle: 'Avistamientos y amenazas detectadas en el minimapa.',
      icon: Icons.radar_outlined,
      child: threats.isEmpty
          ? const CoachEmptyState(
              message: 'Sin amenazas recientes detectadas.',
              icon: Icons.visibility_outlined,
            )
          : Column(
              children: [
                for (var i = 0; i < threats.take(6).length; i++) ...[
                  _ThreatRow(threat: threats[i]),
                  if (i != threats.take(6).length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

class _ThreatRow extends StatelessWidget {
  const _ThreatRow({required this.threat});

  final CoachThreatViewData threat;

  @override
  Widget build(BuildContext context) {
    final isFresh = DateTime.now().difference(threat.observedAt).inSeconds < 12;
    final accent = threat.isGank
        ? const Color(0xFFF43F5E)
        : const Color(0xFF38BDF8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1017),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: threat.isGank
              ? const Color(0x33F43F5E)
              : const Color(0x1AFFFFFF),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 1.5),
              boxShadow: threat.isGank
                  ? const [BoxShadow(color: Color(0x40F43F5E), blurRadius: 6)]
                  : null,
            ),
            child: AssetPortrait(
              semanticLabel: threat.champion,
              url: communityDragonChampionIcon(0), // fallback champion name
              size: 36,
              circular: true,
              fallback: threat.isGank
                  ? Icons.warning_amber_rounded
                  : Icons.radar_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      threat.champion,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CoachColors.primaryText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        threat.location.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${threat.role ?? 'Rol sin confirmar'} · confianza ${(threat.confidence * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 11,
                    color: CoachColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isFresh
                  ? accent.withValues(alpha: .12)
                  : const Color(0x0FFFFFFF),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isFresh) ...[
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  _age(threat.observedAt),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isFresh ? FontWeight.w600 : FontWeight.w400,
                    color: isFresh ? accent : CoachColors.secondaryText,
                  ),
                ),
              ],
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
