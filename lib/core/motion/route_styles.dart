import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import 'motion_level.dart';
import 'spring_curve.dart';

/// `sheetAnimationStyle:` for showModalBottomSheet at the current level.
///
/// Expressive: in on springSlow (clamped, so no overshoot gap shows), out on
/// springStandard (clamped). Subtle: springSubtle both ways. Off: 90 ms
/// (Flutter's sheet route slides, it cannot fade in place).
AnimationStyle sheetStyle(BuildContext context) =>
    _style(Motion.levelOf(context), Motion.slowCurve,
        reverse: Motion.standardCurve);

/// `animationStyle:` for showDialog at the current level. Expressive:
/// springDefault clamped, out on the same. Subtle: springSubtle. Off: 90 ms.
/// (Flutter's dialog transition is a fade; there is no scale hook.)
AnimationStyle dialogStyle(BuildContext context) =>
    _style(Motion.levelOf(context), Motion.defaultCurve);

AnimationStyle _style(MotionLevel level, SpringCurve spring,
    {SpringCurve? reverse}) {
  if (level == MotionLevel.off) {
    return const AnimationStyle(
      curve: Curves.linear,
      duration: Motion.fxInstant,
      reverseCurve: Curves.linear,
      reverseDuration: Motion.fxInstant,
    );
  }
  final inC = Motion.spatialCurve(level, spring);
  final outC = level == MotionLevel.subtle
      ? Motion.subtleCurve
      : (reverse ?? spring);
  return AnimationStyle(
    curve: inC.clamped,
    duration: inC.settle,
    reverseCurve: outC.clamped,
    reverseDuration: outC.settle,
  );
}
