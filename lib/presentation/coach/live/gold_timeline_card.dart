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
    return CoachSurface(
      title: 'Evolución económica',
      icon: Icons.show_chart_rounded,
      action: Semantics(
        label:
            '${differential.abs()} de oro de ${favorable ? 'ventaja' : 'desventaja'}',
        child: Text(
          '${favorable ? '+' : '−'}${differential.abs()}',
          style: TextStyle(
            color: favorable ? CoachColors.emerald : CoachColors.crimson,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      child: points.length < 2
          ? const CoachEmptyState(
              message: 'Esperando más muestras de Live Client.',
            )
          : Semantics(
              label:
                  'Gráfica de diferencia de oro con ${points.length} muestras.',
              child: SizedBox(
                height: 150,
                child: CustomPaint(
                  painter: _GoldPainter(points),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
    );
  }
}

class _GoldPainter extends CustomPainter {
  const _GoldPainter(this.points);

  final List<GoldPointViewData> points;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = points.fold<int>(
      1,
      (value, point) => math.max(value, point.value.abs()),
    );
    final zero = size.height / 2;
    canvas.drawLine(
      Offset(0, zero),
      Offset(size.width, zero),
      Paint()
        ..color = CoachColors.border
        ..strokeWidth = 1,
    );
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final x = index / (points.length - 1) * size.width;
      final y = zero - points[index].value / maxValue * (zero - 8);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = points.last.value >= 0
            ? CoachColors.emerald
            : CoachColors.crimson
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _GoldPainter oldDelegate) =>
      oldDelegate.points != points;
}
