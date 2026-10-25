import 'package:flutter/material.dart';

import '../../../application/coach_controller.dart';
import '../shared/coach_surface.dart';

class VoiceCoachCard extends StatelessWidget {
  const VoiceCoachCard({
    super.key,
    required this.processing,
    required this.history,
    this.onAdviceRequested,
    this.onStopSpeaking,
    this.speaking = false,
    this.statusMessage,
  });

  final bool processing;
  final List<VoiceCoachEntry> history;
  final VoidCallback? onAdviceRequested;
  final VoidCallback? onStopSpeaking;
  final bool speaking;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      title: 'Preguntas por voz',
      subtitle: 'Mantén tu tecla configurada, pregunta y escucha la respuesta.',
      icon: Icons.mic_none_rounded,
      child: Column(
        children: [
          if (speaking && onStopSpeaking != null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onStopSpeaking,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Detener voz'),
              ),
            ),
          if (statusMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(statusMessage!),
            ),
          if (onAdviceRequested != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: processing ? null : onAdviceRequested,
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('Consejo ahora'),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recomendación local con los datos de la partida, sin usar el micrófono.',
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (processing) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
          ],
          if (history.isEmpty)
            CoachEmptyState(
              message: statusMessage == null
                  ? 'Mantén Push-to-Talk y formula una pregunta táctica.'
                  : 'Puedes pedir un consejo local con Consejo ahora.',
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
