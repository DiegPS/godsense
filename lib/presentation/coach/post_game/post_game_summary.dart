import 'package:flutter/material.dart';

import '../../../domain/league/game_session.dart';
import '../shared/coach_surface.dart';

class PostGameSummary extends StatelessWidget {
  const PostGameSummary({super.key, required this.session});

  final GameSession? session;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      title: 'Resumen de sesión',
      subtitle: 'Solo hechos persistidos de GameSession',
      icon: Icons.fact_check_outlined,
      child: session == null
          ? const CoachEmptyState(
              message: 'No hay una sesión terminada disponible.',
            )
          : Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                _Fact(label: 'Sesión', value: session!.sessionId),
                _Fact(
                  label: 'Partida',
                  value: session!.match?.toString() ?? 'Sin Game ID',
                ),
                _Fact(
                  label: 'Duración observada',
                  value: session!.lastGameTime == null
                      ? 'Sin datos'
                      : _duration(
                          session!.lastGameTime!.elapsed.inMilliseconds / 1000,
                        ),
                ),
                _Fact(
                  label: 'Fin',
                  value: session!.endedAt?.toLocal().toString() ?? 'Pendiente',
                ),
              ],
            ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: CoachColors.mutedText,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: CoachColors.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _duration(double seconds) {
  final whole = seconds.round();
  return '${whole ~/ 60}:${(whole % 60).toString().padLeft(2, '0')}';
}
