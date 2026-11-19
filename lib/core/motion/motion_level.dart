import 'package:flutter/widgets.dart';

/// How much Mull moves (Kuber v7.0.0 motion levels).
enum MotionLevel { expressive, subtle, off }

/// What the user picked in Settings. Auto resolves from the phone
/// ([resolveMotionLevel]).
enum MotionPreference { auto, expressive, subtle, off }

/// Result of the one-off device check, cached in prefs. [unknown] until the
/// check has run (Auto then behaves as Expressive).
enum DeviceClass { unknown, normal, low }

/// Total RAM under this (MB, as Android reports it) is a low-end phone
/// ("under 4 GB"). Android reports less than the nominal size (a 4 GB phone
/// shows about 3.6 to 3.8 GB, a 3 GB phone about 2.8 GB), so the cut is 3.5 GB.
const int kLowRamMb = 3584;

DeviceClass classifyDevice({required int? ramMb, bool lowRamFlag = false}) =>
    lowRamFlag || (ramMb != null && ramMb < kLowRamMb) ? DeviceClass.low : DeviceClass.normal;

/// Level for [pref] on a phone of class [device]. The phone wins: with
/// [systemOff] (Remove animations, or an accessibility navigation service) the
/// answer is always Off.
MotionLevel resolveMotionLevel(MotionPreference pref, DeviceClass device, {bool systemOff = false}) {
  if (systemOff) return MotionLevel.off;
  return switch (pref) {
    MotionPreference.expressive => MotionLevel.expressive,
    MotionPreference.subtle => MotionLevel.subtle,
    MotionPreference.off => MotionLevel.off,
    MotionPreference.auto => device == DeviceClass.low ? MotionLevel.subtle : MotionLevel.expressive,
  };
}

/// True when the phone asks for no animation: Remove animations
/// (`disableAnimations`) or an accessibility navigation service.
bool systemMotionOff(BuildContext context) =>
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
    (MediaQuery.maybeAccessibleNavigationOf(context) ?? false);

/// The level for everything below it. One instance sits above the router (see
/// `app.dart`); [Motion.levelOf] reads it. Rebuilds dependants only when the
/// level changes.
class MotionScope extends InheritedWidget {
  const MotionScope({super.key, required this.level, required this.systemOff, required super.child});

  /// Effective level (already Off when [systemOff]).
  final MotionLevel level;

  /// The phone's Remove animations (or accessibility navigation) is on.
  final bool systemOff;

  static MotionScope? maybeOf(BuildContext c) => c.dependOnInheritedWidgetOfExactType<MotionScope>();

  @override
  bool updateShouldNotify(MotionScope old) => old.level != level || old.systemOff != systemOff;
}
