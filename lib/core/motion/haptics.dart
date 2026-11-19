import 'package:flutter/services.dart';

/// The five Mull haptics (motion.md "Haptics"). Rules enforced here: the
/// Haptics switch must be on ([enabled], default off), at most one haptic per
/// 50 ms, none while a scroll is active ([scrolling], set by the listener in
/// app.dart). They do not depend on the Motion level.
///
/// Flutter has no CONFIRM / REJECT / GESTURE_THRESHOLD constants, so those use
/// the closest call (confirm = light, reject = heavy, threshold = medium).
abstract final class MullHaptics {
  /// The Haptics switch. Mirrors [hapticsEnabledProvider].
  static bool enabled = false;

  /// True between a scroll start and its end (fling included).
  static bool scrolling = false;

  static const Duration minGap = Duration(milliseconds: 50);

  /// Clock, replaceable in tests.
  static DateTime Function() now = DateTime.now;
  static DateTime? _last;

  /// Clears the throttle (tests).
  static void reset() => _last = null;

  static bool _allow() {
    if (!enabled || scrolling) return false;
    final t = now();
    final l = _last;
    if (l != null && t.difference(l) < minGap) return false;
    _last = t;
    return true;
  }

  /// A selection changed: switch, checkbox, radio, chip, segmented, tab, nav.
  static void tick() {
    if (_allow()) HapticFeedback.selectionClick();
  }

  /// A long press triggered (only at the trigger, not the hold).
  static void longPress() {
    if (_allow()) HapticFeedback.mediumImpact();
  }

  /// A drag crossed its commit point.
  static void threshold() {
    if (_allow()) HapticFeedback.mediumImpact();
  }

  /// Save or success.
  static void confirm() {
    if (_allow()) HapticFeedback.lightImpact();
  }

  /// An action failed.
  static void reject() {
    if (_allow()) HapticFeedback.heavyImpact();
  }
}
