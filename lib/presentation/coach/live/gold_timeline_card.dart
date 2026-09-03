import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../application/coach_controller.dart';
import '../shared/coach_surface.dart';

class GoldTimelineCard extends StatelessWidget {
  const GoldTimelineCard({
    super.key,
    required this.differential,
    required this.points,
  });

  final int differential;
  final List<GoldPointViewData> points;

  @override
  Widget build(BuildContext context) {
    final favorable = differential >= 0;
    final accentColor = favorable ? const Color(0xFF10B981) : const Color(0xFFF43F5E);

    return CoachSurface(
      title: 'Evolución económica',
      subtitle: 'Diferencial de oro neto entre aliados y rivales en la partida.',
      icon: Icons.show_chart_rounded,
      action: Semantics(
        label:
            '${differential.abs()} de oro de ${favorable ? 'ventaja' : 'desventaja'}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accentColor.withValues(alpha: .3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                favorable ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 16,
                color: accentColor,
              ),
              const SizedBox(width: 4),
              Text(
                '${favorable ? '+' : '−'}${differential.abs()}',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
      child: points.length < 2
          ? const CoachEmptyState(
              message: 'Esperando más muestras de Live Client.',
              icon: Icons.show_chart_rounded,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label:
                      'Gráfica de diferencia de oro con ${points.length} muestras.',
                  child: Container(
                    height: 140,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C1017),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x1AFFFFFF)),
                    ),
                    child: CustomPaint(
                      painter: _GoldPainter(points, accentColor),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatGameTime(points.first.gameTime),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const Text(
                      'Línea base (0)',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF475569),
                      ),
                    ),
                    Text(
                      _formatGameTime(points.last.gameTime),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

String _formatGameTime(double seconds) {
  final mins = (seconds / 60).floor();
  final secs = (seconds % 60).floor();
  return '${mins}m ${secs.toString().padLeft(2, '0')}s';
}

class _GoldPainter extends CustomPainter {
  const _GoldPainter(this.points, this.accentColor);

  final List<GoldPointViewData> points;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = points.fold<int>(
      1,
      (value, point) => math.max(value, point.value.abs()),
    );
    final zero = size.height / 2;

    // Zero baseline
    canvas.drawLine(
      Offset(0, zero),
      Offset(size.width, zero),
      Paint()
        ..color = const Color(0x26FFFFFF)
        ..strokeWidth = 1,
    );

    final linePath = Path();
    final areaPath = Path();
    areaPath.moveTo(0, zero);

    Offset? lastPoint;

    for (var index = 0; index < points.length; index++) {
      final x = index / (points.length - 1) * size.width;
      final y = zero - points[index].value / maxValue * (zero - 12);
      final current = Offset(x, y);

      if (index == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
      areaPath.lineTo(x, y);
      lastPoint = current;
    }

    if (lastPoint != null) {
      areaPath.lineTo(lastPoint.dx, zero);
      areaPath.close();

      // Shaded area under/above the line
      final areaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor.withValues(alpha: .25),
            accentColor.withValues(alpha: .02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;
      canvas.drawPath(areaPath, areaPaint);

      // Stroke line
      canvas.drawPath(
        linePath,
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      // Glowing dot on the current live value
      canvas.drawCircle(
        lastPoint,
        6,
        Paint()..color = accentColor.withValues(alpha: .35),
      );
      canvas.drawCircle(
        lastPoint,
        3.5,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoldPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.accentColor != accentColor;
}
