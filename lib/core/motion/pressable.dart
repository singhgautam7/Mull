import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'haptics.dart';
import 'motion_level.dart';
import 'spring_curve.dart';

/// What is being pressed. Sets the scale and the corner morph (motion.md
/// "Press amounts").
enum PressKind { card, row, button, iconButton, fab, chip }

/// Press response: scale (card / row .98, fab / chip .96; Subtle .99 for
/// card / row / button; none at Off) and, for buttons, a corner morph.
///
/// Listener-based, so an InkWell / GestureDetector inside keeps its own tap
/// and state layer. Pass [onTap] / [onLongPress] only when there is no inner
/// tap handler. Down on springFast, up on springDefault (card / row) or
/// springFast (buttons); Subtle uses springSubtle; Off does nothing. Retargets
/// from the current value and velocity; no ticker runs at rest.
///
/// Use [child] for scale only. For the corner morph use [builder], which gets
/// the current corner radius (dp) to apply to the shape and the press
/// progress (0 at rest, 1 pressed, can overshoot) for fills.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    this.child,
    this.builder,
    this.onTap,
    this.onLongPress,
    this.kind = PressKind.card,
    this.restRadius,
    this.pressedRadius,
    this.morphCorners,
    this.enabled = true,
  }) : assert((child == null) != (builder == null));

  final Widget? child;

  /// Gets the animated corner radius (dp). Only buttons / icon buttons / fab /
  /// chips morph, and only at Expressive; otherwise it stays [restRadius].
  final Widget Function(BuildContext context, double radius, double pressed)?
      builder;
  final VoidCallback? onTap;

  /// Fires with the long-press haptic.
  final VoidCallback? onLongPress;
  final PressKind kind;

  /// Corner radius at rest (pill: half the height). Defaults by [kind].
  final double? restRadius;

  /// Corner radius while pressed. Defaults by [kind] (button 8, icon 12,
  /// fab 12, chip 6).
  final double? pressedRadius;

  /// Morph the corners on press. Null: buttons, icon buttons, fab and chips
  /// do; cards and rows do not (they keep the parent's shape).
  final bool? morphCorners;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _v = ValueNotifier(0);
  AnimationController? _c;
  Offset? _down;

  AnimationController get _ctrl => _c ??= AnimationController.unbounded(vsync: this)
    ..addListener(() => _v.value = _c!.value);

  @override
  void dispose() {
    _c?.dispose();
    _v.dispose();
    super.dispose();
  }

  bool get _morphs =>
      widget.morphCorners ??
      switch (widget.kind) {
        PressKind.card || PressKind.row => false,
        _ => true,
      };

  double _scale(MotionLevel l) {
    if (l == MotionLevel.off) return 1;
    if (l == MotionLevel.subtle) {
      return switch (widget.kind) {
        PressKind.card || PressKind.row || PressKind.button => Motion.pressScaleSubtle,
        _ => 1,
      };
    }
    return switch (widget.kind) {
      PressKind.card || PressKind.row => Motion.pressScaleCard,
      PressKind.fab => Motion.pressScaleFab,
      PressKind.chip => Motion.pressScaleChip,
      _ => 1,
    };
  }

  double get _rest =>
      widget.restRadius ??
      switch (widget.kind) {
        PressKind.button || PressKind.iconButton => 20,
        PressKind.fab => 16,
        PressKind.chip => 8,
        _ => Radii.card,
      };

  double get _pressed =>
      widget.pressedRadius ??
      switch (widget.kind) {
        PressKind.button => 8,
        PressKind.iconButton || PressKind.fab => 12,
        PressKind.chip => 6,
        _ => _rest,
      };

  void _press(PointerDownEvent e) {
    if (!widget.enabled) return;
    final l = Motion.levelOf(context);
    if (l == MotionLevel.off) return;
    _down = e.position;
    _ctrl.springTo(1, Motion.spatial(l, Motion.springFast));
  }

  void _release([PointerEvent? e]) {
    if (_down == null) return;
    _down = null;
    final l = Motion.levelOf(context);
    final up = _morphs ? Motion.springFast : Motion.springDefault;
    _ctrl.springTo(0, Motion.spatial(l, up));
  }

  void _move(PointerMoveEvent e) {
    final d = _down;
    // A drag (scroll) is not a press: let go once it passes the touch slop.
    if (d != null && (e.position - d).distance > kTouchSlop) _release();
  }

  @override
  Widget build(BuildContext context) {
    final level = Motion.levelOf(context);
    final scale = _scale(level);
    final morph = _morphs && level == MotionLevel.expressive;
    final rest = _rest, pressed = _pressed;

    Widget body = AnimatedBuilder(
      animation: _v,
      child: widget.child,
      builder: (context, child) {
        final v = _v.value;
        final inner = widget.builder?.call(
              context,
              morph ? math.max(0.0, rest + (pressed - rest) * v) : rest,
              v,
            ) ??
            child!;
        return Transform.scale(scale: 1 + (scale - 1) * v, child: inner);
      },
    );
    if (widget.onTap != null || widget.onLongPress != null) {
      body = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled && widget.onLongPress != null
            ? () {
                MullHaptics.longPress();
                widget.onLongPress!();
              }
            : null,
        child: body,
      );
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _press,
      onPointerMove: _move,
      onPointerUp: _release,
      onPointerCancel: _release,
      child: body,
    );
  }
}
