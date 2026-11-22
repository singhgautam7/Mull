import 'package:flutter/animation.dart';

/// Values that belong to the first-run flow only, copied from Kuber's
/// onboarding (`lib/features/onboarding`). Everything else comes from
/// `Space`, `Radii`, `IconSpec` and `Motion`.
abstract final class OnboardingSpec {
  /// Page change: `animateToPage`.
  static const Duration pageChange = Duration(milliseconds: 320);
  static const Curve pageCurve = Curves.easeOutCubic;

  /// Dots: 8 tall, the active one 24 wide.
  static const double dotHeight = 8;
  static const double dotInactive = 8;
  static const double dotActive = 24;
  static const double dotMargin = 4;
  static const Duration dotDuration = Duration(milliseconds: 300);
  static const Curve dotCurve = Curves.easeInOutCubicEmphasized;

  /// Bottom bar.
  static const double buttonHeight = 56;
  static const double backWidth = 112;
  static const Duration barResize = Duration(milliseconds: 260);
  static const Curve barCurve = Curves.easeOutCubic;
  static const Duration labelSwap = Duration(milliseconds: 180);
  static const Offset labelSlide = Offset(0, 0.16);
  static const Duration barEntranceDelay = Duration(milliseconds: 230);
  static const Duration barEntrance = Duration(milliseconds: 250);
  static const double barRise = 16;

  /// Skip: top right.
  static const double skipHeight = 56;

  /// Page content entrance.
  static const Duration entrance = Duration(milliseconds: 500);
  static const Curve entranceCurve = Curves.easeOut;
  static const Offset entranceSlide = Offset(0, 0.08);
  static const Duration delayArt = Duration(milliseconds: 80);
  static const Duration delayTitle = Duration(milliseconds: 160);
  static const Duration delayBody = Duration(milliseconds: 260);

  /// Large-font guard: content is laid out at this width and scaled down.
  static const double fitMin = 280;
  static const double fitMax = 520;

  /// Intro illustration box.
  static const double artHeight = 220;
  static const double artWidth = 260;
  static const double disc = 32;
}
