import 'package:flutter/material.dart';

import '../../../application/coach_controller.dart';
import '../shared/coach_surface.dart';

class VoiceCoachCard extends StatelessWidget {
  const VoiceCoachCard({
    super.key,
    required this.processing,
    required this.history,
  });

  final bool processing;
  final List<VoiceCoachEntry> history;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      title: 'Preguntas por voz',
      subtitle: 'Mantén tu tecla configurada, pregunta y escucha la respuesta.',
      icon: Icons.mic_none_rounded,
      child: Column(
        children: [
          if (processing) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
          ],
          if (history.isEmpty)
            const CoachEmptyState(
              message: 'Mantén Push-to-Talk y formula una pregunta táctica.',
            )
          else
            for (final entry in history.take(6))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.graphic_eq_rounded,
                  color: CoachColors.cyan,
                ),
                title: Text(entry.question),
                subtitle: Text(entry.answer),
                trailing: Text(
                  _time(entry.answeredAt),
                  style: const TextStyle(
                    color: CoachColors.secondaryText,
                    fontSize: 10,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
