import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import '../shared/widgets/mull_icons.dart';

class NavDestination {
  const NavDestination(this.glyph, this.label);

  final MullGlyph glyph;
  final String label;
}

/// Home · Mull · Shelves · Search · More. Evenly spaced, nothing between them. There is
/// no FAB and no centre button: Mull is a destination, not an action.
const List<NavDestination> kDestinations = <NavDestination>[
  NavDestination(MullGlyph.home, 'Home'),
  NavDestination(MullGlyph.mull, 'Mull'),
  NavDestination(MullGlyph.collections, 'Shelves'),
  NavDestination(MullGlyph.search, 'Search'),
  NavDestination(MullGlyph.more, 'More'),
];

/// Height 56, 8dp padding, radius full, `surface`, 1px outline, the nav
/// shadow. One painted `primaryContainer` indicator slides under the items
/// (leading edge on springFast, trailing on springDefault, so it stretches);
/// only the selected destination shows its label.
class MullNavPill extends StatelessWidget {
  const MullNavPill({required this.index, required this.onSelect, super.key});

  final int index;
  final ValueChanged<int> onSelect;

  /// An inactive item is 44 wide (12 + 20 + 12); the row gap is 2.
  static const double _item = 44;
  static const double _gap = 2;

  /// A selected item is the icon, 8, the label, and 11 / 14 of padding.
  static const double _labelExtra = 11 + 20 + 8 + 14 - _item;

  static double _labelWidth(BuildContext context, String label) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: label, style: Motion.weightStyle(MullType.titleSmall, 700)),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final double w = tp.width;
    tp.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    // Under a large OS text scale the labels drop and the glyphs stay.
    final bool labelOk = MediaQuery.textScalerOf(context).scale(13.5) <= 20;
    final double left = index * (_item + _gap);
    final double right = left + _item + (labelOk ? _labelExtra + _labelWidth(context, kDestinations[index].label) : 0);
    return RepaintBoundary(
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: Radii.fullR,
          border: Border.all(color: c.outline),
          boxShadow: <BoxShadow>[
            BoxShadow(color: c.shadow, blurRadius: Elevations.navPillBlur, offset: const Offset(0, Elevations.navPill)),
          ],
        ),
        child: Stack(
          children: <Widget>[
            // One painter driven by two spring values; the items above never
            // repaint it.
            Positioned.fill(
              child: NavIndicator(left: left, right: right, color: c.primaryContainer, destination: index),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: _gap,
              children: <Widget>[
                for (int i = 0; i < kDestinations.length; i++)
                  _NavItem(
                    destination: kDestinations[i],
                    selected: i == index,
                    showLabel: labelOk,
                    onTap: () {
                      if (i != index) MullHaptics.tick();
                      onSelect(i);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The sliding indicator: leading edge on springFast, trailing edge on
/// springDefault. Subtle: both on springSubtle. Off: a 90 ms cross-fade.
class NavIndicator extends StatefulWidget {
  const NavIndicator({
    required this.left,
    required this.right,
    required this.color,
    required this.destination,
    super.key,
  });

  final double left;
  final double right;
  final Color color;
  final int destination;

  @override
  State<NavIndicator> createState() => _NavIndicatorState();
}

class _NavIndicatorState extends State<NavIndicator> with TickerProviderStateMixin {
  late final AnimationController _l = AnimationController.unbounded(vsync: this, value: widget.left);
  late final AnimationController _r = AnimationController.unbounded(vsync: this, value: widget.right);

  @override
  void didUpdateWidget(NavIndicator old) {
    super.didUpdateWidget(old);
    if (old.left == widget.left && old.right == widget.right) return;
    final MotionLevel level = Motion.levelOf(context);
    if (level == MotionLevel.off) {
      _l.value = widget.left;
      _r.value = widget.right;
      return;
    }
    final bool movingRight = widget.left > old.left;
    final SpringDescription fast = Motion.spatial(level, Motion.springFast);
    final SpringDescription slow = Motion.spatial(level, Motion.springDefault);
    _l.springTo(widget.left, movingRight ? slow : fast);
    _r.springTo(widget.right, movingRight ? fast : slow);
  }

  @override
  void dispose() {
    _l.dispose();
    _r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.levelOf(context) == MotionLevel.off) {
      return AnimatedSwitcher(
        duration: Motion.fxInstant,
        child: SizedBox.expand(
          key: ValueKey<int>(widget.destination),
          child: CustomPaint(
            painter: _IndicatorPainter(
              ValueNotifier<double>(widget.left),
              ValueNotifier<double>(widget.right),
              widget.color,
            ),
          ),
        ),
      );
    }
    return RepaintBoundary(child: CustomPaint(painter: _IndicatorPainter(_l, _r, widget.color)));
  }
}

class _IndicatorPainter extends CustomPainter {
  _IndicatorPainter(this.l, this.r, this.color) : super(repaint: Listenable.merge(<Listenable>[l, r]));

  final ValueListenable<double> l;
  final ValueListenable<double> r;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double left = l.value;
    final double right = r.value;
    if (right <= left) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(left, 0, right, size.height), Radius.circular(size.height / 2)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_IndicatorPainter o) => o.color != color || o.l != l || o.r != r;
}

class _NavItem extends StatefulWidget {
  const _NavItem({required this.destination, required this.selected, required this.showLabel, required this.onTap});

  final NavDestination destination;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final MotionLevel level = Motion.levelOf(context);
    final bool selected = widget.selected;
    final Color fg = selected ? c.onPrimaryContainer : c.iconMuted;
    final bool wantLabel = widget.showLabel && selected;
    final SpringCurve curve = Motion.spatialCurve(level, Motion.defaultCurve);

    return Semantics(
      button: true,
      selected: selected,
      label: widget.destination.label,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (bool v) => setState(() => _pressed = v),
        customBorder: const StadiumBorder(),
        child: SizedBox(
          height: 40,
          // Label width 0 to auto on springDefault (clamped, never negative);
          // the padding grows with it. Icon and label change together.
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: wantLabel ? 1.0 : 0.0),
            duration: level == MotionLevel.off ? Duration.zero : curve.clamped.settle,
            curve: curve.clamped,
            builder: (BuildContext context, double t, Widget? _) => TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: fg),
              duration: level == MotionLevel.off ? Duration.zero : Motion.fxFast,
              curve: Motion.curveEffects,
              builder: (BuildContext context, Color? color, Widget? _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(width: 12 - t),
                  AnimatedScale(
                    scale: _pressed && level != MotionLevel.off ? 0.9 : 1,
                    duration: Motion.fastCurve.settle,
                    curve: Motion.fastCurve,
                    child: MullIcon(
                      widget.destination.glyph,
                      color: color!,
                      background: selected ? c.primaryContainer : c.surface,
                    ),
                  ),
                  if (t > 0.001)
                    ClipRect(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: t,
                        child: Opacity(
                          opacity: t,
                          child: Padding(
                            padding: const EdgeInsets.only(left: Space.sm),
                            // The Semantics above already says it.
                            child: ExcludeSemantics(
                              child: AnimatedWeight(
                                widget.destination.label,
                                isActive: selected,
                                style: MullType.titleSmall.copyWith(color: color),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(width: 12 + 2 * t),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
