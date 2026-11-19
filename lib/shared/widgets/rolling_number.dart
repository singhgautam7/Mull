import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';

/// An integer count whose changed digits roll (Kuber's `AnimatedAmount`).
///
/// Expressive: each changed digit rolls up (value grew) or down over
/// [Motion.digitRoll] on `curveEffects`, 20 ms apart from right to left,
/// clipped to its line. Subtle: the whole number cross-fades in `fxFast`.
/// Off: it swaps. Settled, it is one plain [Text] with tabular figures, and no
/// ticker runs.
class RollingNumber extends StatefulWidget {
  const RollingNumber(this.value, {this.style, this.textAlign, super.key});

  final int value;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  String _from = '';
  bool _up = true;

  @override
  void didUpdateWidget(RollingNumber old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value || Motion.levelOf(context) != MotionLevel.expressive) return;
    _from = '${old.value}';
    _up = widget.value >= old.value;
    final int changed = _changed();
    final Duration total = Motion.digitRoll + const Duration(milliseconds: 20) * (changed > 1 ? changed - 1 : 0);
    (_c ??= AnimationController(vsync: this)
      ..addStatusListener((AnimationStatus st) {
        if (st == AnimationStatus.completed && mounted) setState(() {});
      })).duration = total;
    _c!.forward(from: 0);
  }

  int _changed() {
    final String to = '${widget.value}';
    int n = 0;
    for (int j = 0; j < to.length; j++) {
      final String? o = j < _from.length ? _from[_from.length - 1 - j] : null;
      if (o != to[to.length - 1 - j]) n++;
    }
    return n;
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  TextStyle _style(BuildContext context) =>
      (widget.style ?? DefaultTextStyle.of(context).style).copyWith(
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      );

  @override
  Widget build(BuildContext context) {
    final String to = '${widget.value}';
    final TextStyle style = _style(context);
    final MotionLevel level = Motion.levelOf(context);
    if (level == MotionLevel.subtle) {
      return AnimatedSwitcher(
        duration: Motion.fxFast,
        switchInCurve: Motion.curveEffects,
        switchOutCurve: Motion.curveEffects,
        layoutBuilder: (Widget? cur, List<Widget> prev) =>
            Stack(alignment: AlignmentDirectional.centerStart, children: <Widget>[...prev, ?cur]),
        child: Text(to, key: ValueKey<String>(to), style: style, textAlign: widget.textAlign),
      );
    }
    final AnimationController? c = _c;
    if (level != MotionLevel.expressive || c == null || !c.isAnimating) {
      return Text(to, style: style, textAlign: widget.textAlign);
    }
    final int total = Motion.digitRoll.inMilliseconds;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: c,
        builder: (BuildContext context, Widget? _) {
          final double ms = c.value * c.duration!.inMilliseconds;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < to.length; i++)
                _digit(
                  i < to.length - _from.length ? null : _from[_from.length - (to.length - i)],
                  to[i],
                  // Right to left: the last digit starts first.
                  ((ms - 20.0 * (to.length - 1 - i)) / total).clamp(0.0, 1.0),
                  style,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _digit(String? from, String to, double p, TextStyle style) {
    if (from == to || from == null) return Text(to, style: style);
    final double t = Motion.curveEffects.transform(p);
    final double d = _up ? 1 : -1;
    return ClipRect(
      child: Stack(
        children: <Widget>[
          FractionalTranslation(translation: Offset(0, -d * t), child: Text(from, style: style)),
          FractionalTranslation(translation: Offset(0, d * (1 - t)), child: Text(to, style: style)),
        ],
      ),
    );
  }
}
