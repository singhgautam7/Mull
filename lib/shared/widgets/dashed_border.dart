import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// The dashed outline behind every "add another one of these" affordance:
/// the New list card, the empty Recently looked up card.
///
/// [radius] null draws a stadium; a value draws a rounded rectangle.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter(this.color, {this.radius});

  final Color color;
  final double? radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius ?? size.height / 2),
        ),
      );
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
        distance += 7;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
