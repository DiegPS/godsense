import 'package:flutter/material.dart';

import '../../../domain/league/game_session.dart';
import '../../../application/coach_controller.dart';
import '../shared/coach_surface.dart';

class PostGameSummary extends StatelessWidget {
  const PostGameSummary({
    super.key,
    required this.session,
    required this.report,
  });

  final GameSession? session;
  final PostGameReport? report;

  @override
  Widget build(BuildContext context) {
    return CoachSurface(
      title: 'Resumen de sesión',
      subtitle: report == null
          ? 'Esperando el cierre completo de la partida'
          : 'Rendimiento, objetivos y momentos observados durante la partida',
      icon: Icons.fact_check_outlined,
      child: session == null && report == null
          ? const CoachEmptyState(
              message: 'No hay una sesión terminada disponible.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _Fact(
                      label: 'Sesión',
                      value:
                          report?.sessionId ??
                          session?.sessionId ??
                          'Sesión guardada',
                    ),
                    _Fact(
                      label: 'Partida',
                      value:
                          report?.matchLabel ??
                          session?.match?.toString() ??
                          'Sin Game ID',
                    ),
                    _Fact(
                      label: 'Campeón',
                      value: report?.champion ?? 'Sin datos',
                    ),
                    _Fact(
                      label: 'KDA',
                      value: report == null
                          ? 'Sin datos'
                          : '${report!.kills}/${report!.deaths}/${report!.assists} · ${report!.kda.toStringAsFixed(2)}',
                    ),
                    _Fact(
                      label: 'CS',
                      value: report?.cs.toString() ?? 'Sin datos',
                    ),
                    _Fact(
                      label: 'Diferencia final',
                      value: report == null
                          ? 'Sin datos'
                          : '${report!.finalGoldDifference >= 0 ? '+' : ''}${report!.finalGoldDifference} oro',
                    ),
                    _Fact(
                      label: 'Dragones',
                      value: report == null
                          ? 'Sin datos'
                          : '${report!.allyDragons} – ${report!.enemyDragons}',
                    ),
                    _Fact(
                      label: 'Torres',
                      value: report == null
                          ? 'Sin datos'
                          : '${report!.enemyTurretsDestroyed} – ${report!.allyTurretsLost}',
                    ),
                    _Fact(
                      label: 'Duración observada',
                      value: _duration(
                        report?.durationSeconds ??
                            ((session!.lastGameTime?.elapsed.inMilliseconds ??
                                    0) /
                                1000),
                      ),
                    ),
                  ],
                ),
                if (report != null) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'REVISIÓN ACCIONABLE',
                    style: TextStyle(
                      color: CoachColors.mutedText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...report!.review.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.arrow_right_rounded,
                            color: CoachColors.cyan,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                  ),
                  if (report!.keyEvents.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'MOMENTOS CLAVE',
                      style: TextStyle(
                        color: CoachColors.mutedText,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: report!.keyEvents
                          .map(
                            (event) => Chip(
                              label: Text(
                                '${_duration(event.timeSeconds)} · ${event.label}',
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ],
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
              fontWeight: FontWeight.w700,
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
