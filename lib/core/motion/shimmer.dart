import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/tokens.dart';
import 'motion_level.dart';

/// One shared shimmer phase (0..1, 1200 ms linear) so every skeleton on screen
/// sweeps together. Its ticker runs only while a [ShimmerBox] is mounted at
/// Expressive.
class ShimmerClock {
  ShimmerClock._();
  static final ShimmerClock instance = ShimmerClock._();
  static const period = Duration(milliseconds: 1200);

  final ValueNotifier<double> phase = ValueNotifier(0);
  Ticker? _ticker;
  int _users = 0;

  void acquire() {
    if (_users++ > 0) return;
    _ticker = Ticker((d) =>
        phase.value = (d.inMicroseconds % period.inMicroseconds) / period.inMicroseconds)
      ..start();
  }

  void release() {
    if (--_users > 0) return;
    _ticker?.dispose();
    _ticker = null;
  }
}

/// A rounded placeholder block. At Expressive a highlight band translates
/// across it (1200 ms, linear, painted directly: no saveLayer). At Subtle and
/// Off it is static.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    required this.radius,
    required this.base,
    required this.highlight,
  });

  final double? width;
  final double? height;
  final double radius;
  final Color base;
  final Color highlight;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> {
  bool _on = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final want = Motion.levelOf(context) == MotionLevel.expressive;
    if (want == _on) return;
    _on = want;
    want ? ShimmerClock.instance.acquire() : ShimmerClock.instance.release();
  }

  @override
  void dispose() {
    if (_on) ShimmerClock.instance.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: _ShimmerPainter(
            on: _on,
            radius: widget.radius,
            base: widget.base,
            highlight: widget.highlight,
            phase: ShimmerClock.instance.phase,
          ),
          // Container (not SizedBox): with no size it expands to its constraints.
          // ignore: sized_box_for_whitespace
          child: Container(width: widget.width, height: widget.height),
        ),
      );
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({
    required this.on,
    required this.radius,
    required this.base,
    required this.highlight,
    required this.phase,
  }) : super(repaint: on ? phase : null);

  final bool on;
  final double radius;
  final Color base, highlight;
  final ValueNotifier<double> phase;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()..color = base;
    if (on && size.width > 0) {
      // A band as wide as the block, sliding from -100 % to +100 %.
      final dx = (phase.value * 2 - 1) * size.width;
      paint.shader = LinearGradient(
        colors: [base, highlight, base],
        stops: const [0.25, 0.5, 0.75],
      ).createShader(Rect.fromLTWH(dx, 0, size.width, size.height));
    }
    canvas.drawRRect(rr, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter o) =>
      o.on != on ||
      o.radius != radius ||
      o.base != base ||
      o.highlight != highlight;
}
