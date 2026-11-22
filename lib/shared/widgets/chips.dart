import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// `surfaceContainerHigh`, radius 8, `monoLabel` uppercase. COMMON / UNCOMMON /
/// RARE, or FORMAL / INFORMAL / DATED / NEUTRAL for idioms. Never a number.
class BandChip extends StatelessWidget {
  const BandChip(this.label, {this.tinted = false, super.key});

  final String label;

  /// `primaryContainer` fill, for the matched run on an idiom card.
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: tinted ? c.primaryContainer : c.surfaceContainerHigh,
        borderRadius: Radii.chipR,
      ),
      child: Text(
        label.toUpperCase(),
        style: MullType.monoLabel.copyWith(
          color: tinted ? c.onPrimaryContainer : c.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Selected squircle radius of a single-choice group (Kuber button group).
const double kSelectedRadius = 12;

/// Duration of the fill and shape of a selection change at [level].
Duration _selectDuration(MotionLevel level) =>
    level == MotionLevel.off ? Duration.zero : Motion.fxFast;

/// A synonym chip on the card, or a filter chip (Kuber's `KuberChip`).
///
/// Unselected: a stadium with a 1dp outline and no fill. Selected: a 12dp
/// squircle with the selected-container fill and a transparent border. The
/// shape follows the selection (not the press) on the fast spring at
/// Expressive, the subtle spring at Subtle, at once at Off; fill and border
/// fade on `fxFast`. Press is a scale only. [selected] null is a tap-only
/// chip: it looks unselected. 32dp tall, with a 48dp tall hit region when
/// it has an [onTap]. A changed selection plays the tick.
class PillChip extends StatelessWidget {
  const PillChip({
    required this.label,
    this.onTap,
    this.selected,
    this.count,
    this.showCountWhenSelectedOnly = false,
    this.trailing,
    this.showCheck = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool? selected;
  final int? count;
  final bool showCountWhenSelectedOnly;
  final Widget? trailing;

  /// A check that grows 0 to 18dp on the selected chip (springStandard).
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final MotionLevel level = Motion.levelOf(context);
    final bool sel = selected ?? false;
    final bool off = level == MotionLevel.off;
    final bool showCount = count != null && (!showCountWhenSelectedOnly || sel);
    final Color fg = sel ? c.onPrimaryContainer : c.onSurfaceVariant;
    final SpringCurve shapeC = Motion.spatialCurve(level, Motion.fastCurve);
    final SpringCurve checkC = Motion.spatialCurve(level, Motion.standardCurve);
    final Duration fade = off ? Motion.fxInstant : Motion.fxFast;
    final bool tappable = onTap != null;

    Widget body(double k) => Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: EdgeInsets.symmetric(horizontal: Space.md + 2 - (showCheck ? 4 * k : 0)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showCheck)
            ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: k,
                child: Opacity(
                  opacity: k.clamp(0.0, 1.0),
                  child: Padding(
                    padding: const EdgeInsets.only(right: Space.sm),
                    child: Icon(Icons.check_rounded, size: 18, color: c.onPrimaryContainer),
                  ),
                ),
              ),
            ),
          AnimatedWeight(label, isActive: sel, rest: 500, active: 650, style: MullType.label.copyWith(fontSize: 13, color: fg)),
          if (showCount) ...<Widget>[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: sel ? c.surface : c.surfaceContainerHigh,
                borderRadius: Radii.fullR,
              ),
              child: Text(
                '$count',
                style: MullType.monoLabel.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sel ? c.onPrimaryContainer : c.onSurfaceVariant,
                ),
              ),
            ),
          ],
          if (trailing != null) ...<Widget>[const SizedBox(width: 6), trailing!],
        ],
      ),
    );

    Widget chip = Pressable(
      kind: PressKind.chip,
      enabled: tappable,
      morphCorners: false,
      haptic: false,
      builder: (BuildContext context, double _, double _) => TweenAnimationBuilder<double>(
        tween: Tween<double>(end: sel ? 1 : 0),
        duration: off ? Duration.zero : shapeC.settle,
        curve: shapeC.clamped,
        builder: (BuildContext context, double sq, Widget? child) => TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: sel ? c.primaryContainer : Colors.transparent),
          duration: fade,
          curve: Motion.curveEffects,
          builder: (BuildContext context, Color? fill, Widget? child) => Material(
            color: fill,
            animationDuration: Duration.zero,
            shape: _chipShape(sq, c.outline, sel),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: tappable
                  ? () {
                      if (!sel) MullHaptics.tick();
                      onTap!();
                    }
                  : null,
              child: child,
            ),
          ),
          child: child,
        ),
        child: showCheck
            ? TweenAnimationBuilder<double>(
                tween: Tween<double>(end: sel ? 1 : 0),
                duration: off ? Duration.zero : checkC.settle,
                curve: checkC.clamped,
                builder: (BuildContext context, double k, Widget? _) => body(k),
              )
            : body(0),
      ),
    );
    if (tappable) {
      // The chip is 32dp; the hit region is 48dp tall.
      chip = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!sel) MullHaptics.tick();
          onTap!();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: IconSpec.tapTarget),
          child: Center(widthFactor: 1, child: chip),
        ),
      );
    }
    return Semantics(button: tappable, selected: sel, child: chip);
  }
}

/// Unselected: a stadium with a 1dp outline; selected: a 12dp squircle with a
/// transparent border; in between the two morph.
OutlinedBorder _chipShape(double t, Color outline, bool selected) {
  final StadiumBorder pill = StadiumBorder(side: BorderSide(color: outline));
  final RoundedRectangleBorder squircle = RoundedRectangleBorder(
    borderRadius: Radii.mediumR,
    side: BorderSide(color: selected ? Colors.transparent : outline),
  );
  if (t <= 0) return pill;
  if (t >= 1) return squircle;
  return ShapeBorder.lerp(pill, squircle, t)! as OutlinedBorder;
}

/// Single-choice button group (Kuber's `KuberButtonGroup`): Cards/Table,
/// Words/Idioms, Light/Dark/System. Pills with 8dp gaps; the selected one is a
/// 12dp squircle in the old thumb's colours (`surface` + 1px outline, or
/// `primary` when [accent]), the others `surfaceContainerHigh`. Counts sit
/// inside the label in `monoLabel`. Heights: 38, 34 [compact], 48 [accent].
///
/// Expressive: the shape springs between pill and squircle; the pressed item
/// widens by [Motion.buttonGroupWiden] and squeezes its neighbours, corners go
/// to 8; the label weight eases 600 to 700. Subtle: the fill fades, the shape
/// and widths do not move. Off: instant. A changed selection plays the tick.
/// [showCheck] draws a check in on the selected item (default off; use it
/// only for fewer than 4 options).
class SegmentedToggle<T> extends StatefulWidget {
  const SegmentedToggle({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.counts = const <Object?, int>{},
    this.compact = false,
    this.accent = false,
    this.showCheck = false,
    super.key,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final Map<Object?, int> counts;
  final bool compact;
  final bool accent;
  final bool showCheck;

  @override
  State<SegmentedToggle<T>> createState() => _SegmentedToggleState<T>();
}

class _SegmentedToggleState<T> extends State<SegmentedToggle<T>> with SingleTickerProviderStateMixin {
  static const double _gap = Space.sm;
  final ValueNotifier<double> _v = ValueNotifier<double>(0);
  AnimationController? _c;
  int _pressed = -1; // stays set during the release so widths ease back
  bool _down = false;
  Offset? _downAt;

  AnimationController get _ctrl =>
      _c ??= (AnimationController.unbounded(vsync: this)..addListener(() => _v.value = _c!.value));

  @override
  void dispose() {
    _c?.dispose();
    _v.dispose();
    super.dispose();
  }

  void _press(int i, PointerDownEvent e) {
    setState(() {
      _pressed = i;
      _down = true;
    });
    _downAt = e.position;
    final MotionLevel l = Motion.levelOf(context);
    if (l == MotionLevel.expressive) _ctrl.springTo(1, Motion.springFast);
  }

  void _release([PointerEvent? e]) {
    if (!_down) return;
    setState(() => _down = false);
    _downAt = null;
    if (Motion.levelOf(context) == MotionLevel.expressive) _ctrl.springTo(0, Motion.springDefault);
  }

  void _select(T v) {
    if (v == widget.selected) return;
    MullHaptics.tick();
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final MotionLevel level = Motion.levelOf(context);
    final bool expressive = level == MotionLevel.expressive;
    final int n = widget.options.length;
    final double height = widget.accent ? 48 : (widget.compact ? 34 : 38);
    final Curve checkCurve = Motion.spatialCurve(level, Motion.standardCurve).clamped;
    final Duration checkTime = level == MotionLevel.off ? Duration.zero : Motion.spatialCurve(level, Motion.standardCurve).settle;

    Widget item(int i, double flex) {
      final (T value, String label) = widget.options[i];
      final bool sel = value == widget.selected;
      final bool pressed = _down && _pressed == i;
      final Color selFill = widget.accent ? c.primary : c.surface;
      final Color selFg = widget.accent ? c.onPrimary : c.onSurface;
      final Color fg = sel ? selFg : c.onSurfaceVariant;
      final int? count = widget.counts[value];
      return Flexible(
        flex: (flex * 1000).round().clamp(1, 1 << 30),
        fit: FlexFit.tight,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (PointerDownEvent e) => _press(i, e),
          onPointerMove: (PointerMoveEvent e) {
            final Offset? d = _downAt;
            if (d != null && (e.position - d).distance > kTouchSlop) _release();
          },
          onPointerUp: _release,
          onPointerCancel: _release,
          child: Semantics(
            button: true,
            selected: sel,
            inMutuallyExclusiveGroup: true,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: sel ? 1 : 0),
              duration: _selectDuration(level),
              curve: Motion.curveEffects,
              builder: (BuildContext context, double t, Widget? _) => AnimatedBuilder(
                animation: _v,
                builder: (BuildContext context, Widget? _) {
                  final double rest = expressive
                      ? height / 2 + (kSelectedRadius - height / 2) * t
                      : (sel ? kSelectedRadius : height / 2);
                  final double pr = expressive && _pressed == i ? _v.value : 0;
                  final double r = (rest + (8 - rest) * pr).clamp(0.0, 999.0);
                  final BorderRadius br = BorderRadius.circular(r);
                  final Color border = widget.accent
                      ? Colors.transparent
                      : Color.lerp(Colors.transparent, c.outline, t)!;
                  return Material(
                    color: Color.lerp(c.surfaceContainerHigh, selFill, t),
                    animationDuration: Duration.zero,
                    shape: RoundedRectangleBorder(borderRadius: br, side: BorderSide(color: border)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _select(value),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: height),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              if (widget.showCheck && n < 4)
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(end: sel ? 1 : 0),
                                  duration: checkTime,
                                  curve: checkCurve,
                                  builder: (BuildContext context, double k, Widget? child) => ClipRect(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: k,
                                      child: Opacity(opacity: k, child: child),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(Icons.check_rounded, size: 18, color: fg),
                                  ),
                                ),
                              Flexible(
                                child: AnimatedWeight(
                                  label,
                                  isActive: sel || pressed,
                                  rest: 600,
                                  active: 700,
                                  textAlign: TextAlign.center,
                                  style: MullType.titleSmall.copyWith(color: fg),
                                ),
                              ),
                              if (count != null) ...<Widget>[
                                const SizedBox(width: 6),
                                Text(
                                  '$count',
                                  style: MullType.monoLabel.copyWith(
                                    color: widget.accent && sel ? c.onPrimary.withValues(alpha: 0.8) : c.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    // The pressed item takes 1 + .15v of its share; the rest split what is left.
    return IntrinsicHeight(
      child: AnimatedBuilder(
        animation: _v,
        builder: (BuildContext context, Widget? _) {
          final double grow = expressive && _pressed >= 0 && n > 1 ? 1 + Motion.buttonGroupWiden * _v.value : 1.0;
          final double other = n > 1 ? (n - grow) / (n - 1) : 1.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < n; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: _gap),
                item(i, i == _pressed ? grow : other),
              ],
            ],
          );
        },
      ),
    );
  }
}
