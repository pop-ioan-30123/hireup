import 'package:flutter/material.dart';

class MeteorBorderPainter extends CustomPainter {
  final double progress;
  final Color color;

  MeteorBorderPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final roundedRect = RRect.fromRectAndRadius(rect, const Radius.circular(20));

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = color.withValues(alpha: 0.16);
    canvas.drawRRect(roundedRect, basePaint);

    final path = Path()..addRRect(roundedRect.deflate(1));
    final iterator = path.computeMetrics().iterator;
    if (!iterator.moveNext()) return;
    final metric = iterator.current;

    final meteorLength = metric.length * 0.27;
    final headOffset = (progress * metric.length) % metric.length;
    final tailOffset = headOffset - meteorLength;

    final meteorPath = Path();
    if (tailOffset >= 0) {
      meteorPath.addPath(metric.extractPath(tailOffset, headOffset), Offset.zero);
    } else {
      meteorPath.addPath(metric.extractPath(metric.length + tailOffset, metric.length), Offset.zero);
      meteorPath.addPath(metric.extractPath(0, headOffset), Offset.zero);
    }

    final tailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.6
      ..color = color.withValues(alpha: 0.6);
    canvas.drawPath(meteorPath, tailPaint);

    final headTangent = metric.getTangentForOffset(headOffset);
    if (headTangent != null) {
      final glowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.5);
      canvas.drawCircle(headTangent.position, 13.0, glowPaint);

      final headPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 1);
      canvas.drawCircle(headTangent.position, 7.2, headPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MeteorBorderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
