import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';

/// A 3dp track, `divider` under `primary`. Proportional, and below 1% it
/// still paints a 6dp stub so progress reads at 40 words and at 2000.
/// Painted, not laid out, so a card can measure its intrinsic height.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({required this.fraction, this.onContainer = false, super.key});

  final double fraction;

  /// On a filled (complete) card the track sits on `primaryContainer`.
  final bool onContainer;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return SizedBox(
      height: 3,
      width: double.infinity,
      child: CustomPaint(
        painter: _TrackPainter(
          fraction.clamp(0, 1),
          onContainer ? c.onPrimaryContainer.withValues(alpha: 0.18) : c.divider,
          onContainer ? c.onPrimaryContainer : c.primary,
        ),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter(this.fraction, this.track, this.fill);

  final double fraction;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const Radius r = Radius.circular(2);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, r), Paint()..color = track);
    if (fraction > 0) {
      final double w = math.max(6, size.width * fraction);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, size.height), r), Paint()..color = fill);
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.fraction != fraction || old.track != track || old.fill != fill;
}

/// 46dp, 4dp stroke, `divider` track, `primary` arc from -90 degrees, round
/// cap. Never labelled with a percentage inside.
class ProgressRing extends StatelessWidget {
  const ProgressRing({required this.fraction, this.size = 46, super.key});

  final double fraction;
  final double size;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _RingPainter(fraction.clamp(0, 1), c.divider, c.primary)),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.track, this.arc);

  final double fraction;
  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = Offset.zero & size;
    final Rect inset = r.deflate(2);
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(inset, 0, math.pi * 2, false, p..color = track);
    if (fraction > 0) {
      canvas.drawArc(inset, -math.pi / 2, math.pi * 2 * fraction, false, p..color = arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.track != track || old.arc != arc;
}
