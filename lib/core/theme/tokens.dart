import 'package:flutter/material.dart';

import '../motion/motion_level.dart';
import '../motion/spring_curve.dart';

/// Design tokens from `specs/design/HANDOFF.md` sections 1.5 and 1.6.
///
/// Nothing in a feature names a raw color, size, radius or duration. It comes
/// from here or from [MullColors].

/// 4 · 8 · 12 · 16 · 24 · 32, plus the screen-level values.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Screen margin.
  static const double screen = 20;

  /// Gap between rows in a list.
  static const double row = 10;

  /// Gap between sections on a screen.
  static const double section = 28;

  /// Bottom padding on every scrollable so content clears the floating nav.
  static const double bottomSafe = 108;
}

/// 8 · chip, 14 · thumb, 20 · card, 28 · sheet and the word card, full · pill.
abstract final class Radii {
  static const double chip = 8;

  /// Kuber's `KuberShape.medium`: icon discs, a selected chip's squircle,
  /// menu rows.
  static const double medium = 12;
  static const double thumb = 14;

  /// Kuber's `KuberShape.large`: the ink of a list row.
  static const double large = 16;
  static const double card = 20;
  static const double sheet = 28;

  /// The word card on the Mull tab.
  static const double wordCard = 28;
  static const double full = 999;

  static const BorderRadius chipR = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius mediumR = BorderRadius.all(Radius.circular(medium));
  static const BorderRadius thumbR = BorderRadius.all(Radius.circular(thumb));
  static const BorderRadius largeR = BorderRadius.all(Radius.circular(large));
  static const BorderRadius cardR = BorderRadius.all(Radius.circular(card));
  static const BorderRadius wordCardR = BorderRadius.all(
    Radius.circular(wordCard),
  );
  static const BorderRadius sheetR = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
  static const BorderRadius fullR = BorderRadius.all(Radius.circular(full));
}

/// One rounded outline set, 24dp, 1.75 stroke, 48dp tap target.
abstract final class IconSpec {
  static const double size = 24;
  static const double stroke = 1.75;
  static const double tapTarget = 48;
}

/// HANDOFF 1.6. Spring for anything the finger caused, decelerate for
/// anything the system caused.
///
/// The springs, effects curve, stagger, caps and press amounts below the
/// Perch durations come from Kuber v7.0.0 (`KuberMotion`), copied value for
/// value. Perch's own durations and curves are kept (CLAUDE.md wins); Kuber's
/// durations are the same numbers.
abstract final class Motion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);

  // ---- Effects (opacity, colour: never springs). Kuber v7.0.0. ----
  static const Duration fxInstant = instant;
  static const Duration fxFast = fast;
  static const Duration fxDefault = Duration(milliseconds: 200);

  /// Every opacity and colour change.
  static const Curve curveEffects = Cubic(0.33, 1, 0.68, 1);

  // ---- Springs (mass 1). Interruptible: retarget with `springTo`. ----
  /// Small things: press, chips, radios, switch thumb, chevrons, menus.
  static final SpringDescription springFast = SpringDescription.withDampingRatio(mass: 1, stiffness: 800, ratio: 0.6);

  /// Medium things: enter, expand, list insert, dialogs, release of cards.
  static final SpringDescription springDefault = SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 0.8);

  /// Large surfaces: sheets opening, container transform.
  static final SpringDescription springSlow = SpringDescription.withDampingRatio(mass: 1, stiffness: 200, ratio: 0.8);

  /// Reflow with no visible bounce: heights, widths, closing.
  static final SpringDescription springStandard = SpringDescription.withDampingRatio(mass: 1, stiffness: 700, ratio: 0.9);

  /// Every spatial motion at the Subtle level (critically damped).
  static final SpringDescription springSubtle = SpringDescription.withDampingRatio(mass: 1, stiffness: 600, ratio: 1.0);

  /// Cached spring curves for implicit animations (use `.settle` as the
  /// duration, `.clamped` for sizes).
  static final SpringCurve fastCurve = SpringCurve(springFast);
  static final SpringCurve defaultCurve = SpringCurve(springDefault);
  static final SpringCurve slowCurve = SpringCurve(springSlow);
  static final SpringCurve standardCurve = SpringCurve(springStandard);
  static final SpringCurve subtleCurve = SpringCurve(springSubtle);

  /// [expressive] at Expressive, [springSubtle] at Subtle. (Off: callers skip.)
  static SpringDescription spatial(MotionLevel l, SpringDescription expressive) =>
      l == MotionLevel.subtle ? springSubtle : expressive;

  /// Curve counterpart of [spatial].
  static SpringCurve spatialCurve(MotionLevel l, SpringCurve expressive) =>
      l == MotionLevel.subtle ? subtleCurve : expressive;

  // ---- Stagger (first load only, never while scrolling) ----
  static const Duration staggerStep = Duration(milliseconds: 30);
  static const int staggerLimit = 6;

  /// Delay of item [index]: 30 ms steps, items past the 6th share the 6th's.
  static Duration staggerDelay(int index) =>
      staggerStep * (index < 0 ? 0 : (index < staggerLimit ? index : staggerLimit - 1));

  // ---- Caps ----
  static const Duration reflow = Duration(milliseconds: 230);
  static const Duration digitRoll = Duration(milliseconds: 300);

  /// Theme change ripple: a timed reveal on an even ease-in-out so the circle
  /// visibly sweeps across the screen. Subtle is shorter.
  static const Duration themeReveal = Duration(milliseconds: 800);
  static const Duration themeRevealSubtle = Duration(milliseconds: 500);
  static const Curve themeRevealCurve = Curves.easeInOutSine;
  static const Curve themeRevealSubtleCurve = Curves.easeInOutSine;

  // ---- Press amounts ----
  static const double pressScaleCard = 0.98; // cards and list rows
  static const double pressScaleSubtle = 0.99;
  static const double pressScaleFab = 0.96;
  static const double pressScaleChip = 0.96;
  static const double buttonGroupWiden = 0.15;

  // ---- Header pill (Kuber v7.0.0-c floating header) ----
  /// The header turns into the pill at this scroll offset (dp)...
  static const double pillAt = 32;

  /// ...and comes back at or under this one: the 24 dp between never flickers.
  static const double headerAt = 8;

  /// Pill hides after this much continuous downward scroll (When scrolling up
  /// / When scrolling stops), and shows again after [pillShowAfter] upward.
  static const double pillHideAfter = 16;
  static const double pillShowAfter = 8;

  /// When scrolling stops: the pill returns this long after the scroll ends.
  static const Duration pillStopDelay = Duration(milliseconds: 300);

  /// Effective level here: preference + device, and the phone's Remove
  /// animations wins (Off). Cheap: reads one InheritedWidget. Without a
  /// [MotionScope] (tests, the define sheet before it mounts one) it is
  /// Expressive unless the phone asks for no animation.
  static MotionLevel levelOf(BuildContext context) {
    final MotionScope? s = MotionScope.maybeOf(context);
    if (s != null) return s.level;
    return systemMotionOff(context) ? MotionLevel.off : MotionLevel.expressive;
  }

  /// [base] at variable weight [wght] (FontVariation 'wght').
  static TextStyle weightStyle(TextStyle base, double wght) => base.copyWith(
    fontWeight: FontWeight.lerp(FontWeight.w100, FontWeight.w900, ((wght - 100) / 800).clamp(0.0, 1.0)),
    fontVariations: <FontVariation>[FontVariation('wght', wght)],
  );
  static const Duration navIndicator = Duration(milliseconds: 220);
  /// Kuber's tab pager.
  static const Duration tabSlide = Duration(milliseconds: 300);
  static const Duration containerTransform = Duration(milliseconds: 240);
  static const Duration sheet = Duration(milliseconds: 260);
  static const Duration cardSwipe = Duration(milliseconds: 260);

  /// The page background cross-fading to true black / pure white on entering
  /// the Mull tab, and back on leaving it.
  static const Duration cardBackground = Duration(milliseconds: 240);
  static const Duration lensSwap = Duration(milliseconds: 240);
  static const Duration navHide = Duration(milliseconds: 160);
  static const Duration snackEnter = Duration(milliseconds: 180);
  static const Duration snackExit = Duration(milliseconds: 140);

  /// Anything the finger caused.
  static const Curve spring = Curves.easeOutBack;

  /// Anything the system caused.
  static const Curve decelerate = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOut;

  /// Below Expressive: transforms become cross-fades, springs go linear.
  static const Duration reducedFade = Duration(milliseconds: 90);
  static const Duration reducedSpring = Duration(milliseconds: 120);

  /// Not Expressive: callers that only know "reduced" keep working (Subtle
  /// and Off both take the short fade).
  static bool reduced(BuildContext context) => levelOf(context) != MotionLevel.expressive;

  /// Duration to actually use, honouring reduced motion.
  static Duration of(BuildContext context, Duration full) =>
      reduced(context) ? reducedFade : full;

  static Curve curveOf(BuildContext context, Curve full) =>
      reduced(context) ? Curves.linear : full;
}

/// Depth lives in 1px outlines; shadow exists on exactly one object, the nav
/// pill. There is no FAB and no centre button in Mull.
abstract final class Elevations {
  static const double navPill = 6;
  static const double navPillBlur = 18;
}
