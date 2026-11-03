import 'package:flutter/material.dart';
import 'package:godsense/presentation/shared/gs_tokens.dart';

import '../../../domain/tactical/tactical_models.dart';
import '../shared/coach_surface.dart';

class LiveDirectivesCard extends StatelessWidget {
  const LiveDirectivesCard({super.key, required this.directives});

  final List<TacticalAdvice> directives;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      title: 'Recomendaciones tácticas',
      subtitle: 'Alertas y directivas automáticas en tiempo real.',
      icon: Icons.record_voice_over_outlined,
      child: directives.isEmpty
          ? const CoachEmptyState(
              message: 'No hay una directiva prioritaria en este momento.',
              icon: Icons.check_circle_outline_rounded,
            )
          : Column(
              children: [
                for (var i = 0; i < directives.length; i++) ...[
                  _DirectiveCard(directive: directives[i]),
                  if (i != directives.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

class _DirectiveCard extends StatelessWidget {
  const _DirectiveCard({required this.directive});

  final TacticalAdvice directive;

  @override
  Widget build(BuildContext context) {
    final (accent, label, icon) = switch (directive.priority) {
      1 => (GsColors.crimson, 'CRÍTICA', Icons.warning_amber_rounded),
      2 => (GsColors.amber, 'OPORTUNIDAD', Icons.flag_outlined),
      _ => (GsColors.accent, 'MACRO', Icons.lightbulb_outline_rounded),
    };

    return Container(
      decoration: BoxDecoration(
        color: GsColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GsColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3.5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 14, color: accent),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: accent,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'P${directive.priority}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: GsColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        directive.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: CoachColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        directive.hints.isEmpty
                            ? directive.rationale
                            : directive.hints.join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: CoachColors.secondaryText,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
