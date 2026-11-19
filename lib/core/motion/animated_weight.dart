import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'motion_level.dart';

/// Text whose variable weight ('wght') eases between [rest] and [active] over
/// fx.default on curve.effects. The width of the active weight is reserved
/// (laid out invisibly), so nothing around it shifts. Off: the weight snaps.
///
/// Works before the variable Inter lands: on a static font the weight just
/// steps to the nearest bundled one.
class AnimatedWeight extends StatelessWidget {
  const AnimatedWeight(
    this.text, {
    super.key,
    required this.isActive,
    this.style,
    this.rest = 500,
    this.active = 700,
    this.textAlign,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final bool isActive;
  final TextStyle? style;
  final double rest;
  final double active;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final off = Motion.levelOf(context) == MotionLevel.off;
    // Width of the heavier weight, measured once per build (not per frame)
    // instead of laying out a hidden copy (which finders and TalkBack would
    // see as a second label).
    final heavy = active > rest ? active : rest;
    final tp = TextPainter(
      text: TextSpan(text: text, style: Motion.weightStyle(base, heavy)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: maxLines,
    )..layout();
    final reserve = tp.width;
    tp.dispose();
    return TweenAnimationBuilder<double>(
      tween: Tween(end: isActive ? active : rest),
      duration: off ? Duration.zero : Motion.fxDefault,
      curve: Motion.curveEffects,
      builder: (context, w, _) => ConstrainedBox(
        constraints: BoxConstraints(minWidth: reserve),
        child: Text(text,
            style: Motion.weightStyle(base, w),
            textAlign: textAlign ?? TextAlign.start,
            maxLines: maxLines,
            overflow: overflow),
      ),
    );
  }
}
