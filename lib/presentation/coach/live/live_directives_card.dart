import 'package:flutter/material.dart';

import '../../../domain/tactical/tactical_models.dart';
import '../shared/coach_surface.dart';

class LiveDirectivesCard extends StatelessWidget {
  const LiveDirectivesCard({super.key, required this.directives});

  final List<TacticalAdvice> directives;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      title: 'Directivas tácticas locales',
      icon: Icons.record_voice_over_outlined,
      child: directives.isEmpty
          ? const CoachEmptyState(
              message: 'No hay una directiva prioritaria en este momento.',
            )
          : Column(
              children: [
                for (final directive in directives)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: CoachColors.cyan.withValues(alpha: .14),
                      child: Text(
                        '${directive.priority}',
                        style: const TextStyle(color: CoachColors.cyan),
                      ),
                    ),
                    title: Text(directive.title),
                    subtitle: Text(
                      directive.hints.isEmpty
                          ? directive.rationale
                          : directive.hints.join(' · '),
                    ),
                  ),
              ],
            ),
    );
  }
}
