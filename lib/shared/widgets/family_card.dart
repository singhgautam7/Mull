import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// One theme family as a card: three swatches, the name, the blurb. The
/// theme screen and the welcome page both pick from these.
///
/// Selecting a card morphs its shape (corner and border) on the fast spring
/// and draws a check in beside the swatches (width and opacity inside a clip,
/// standard spring). At Subtle only the colours fade; at Off nothing animates.
class FamilyCard extends StatelessWidget {
  const FamilyCard({
    required this.family,
    required this.colors,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final ThemeFamily family;
  final MullColors colors;
  final bool selected;
  final VoidCallback onTap;

  /// Border width of an unselected / selected card.
  static const double _borderRest = 1;
  static const double _borderSelected = 2;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final MotionLevel level = Motion.levelOf(context);
    final bool expressive = level == MotionLevel.expressive;
    final SpringCurve shape = Motion.spatialCurve(level, Motion.fastCurve);
    final SpringCurve check = Motion.spatialCurve(level, Motion.standardCurve);
    final Duration shapeDuration = switch (level) {
      MotionLevel.expressive => shape.settle,
      MotionLevel.subtle => Motion.fxDefault,
      MotionLevel.off => Duration.zero,
    };
    final Curve shapeCurve = expressive ? shape.clamped : Motion.curveEffects;
    return Pressable(
      kind: PressKind.card,
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        label: '${family.name} theme',
        excludeSemantics: true,
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: selected ? 1 : 0),
          duration: shapeDuration,
          curve: shapeCurve,
          builder: (BuildContext context, double t, Widget? child) {
            // Expressive morphs the shape; Subtle snaps it and fades colour.
            final double shapeT = expressive ? t : (selected ? 1 : 0);
            final double radius =
                Radii.card + (Radii.thumb - Radii.card) * shapeT;
            final double width =
                _borderRest + (_borderSelected - _borderRest) * shapeT;
            final BorderRadius r = BorderRadius.circular(radius);
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: r,
                child: Container(
                  // The border grows inward, so the padding gives it back and
                  // the content never shifts.
                  padding: EdgeInsets.all(16 - width),
                  constraints: const BoxConstraints(minHeight: 116),
                  decoration: BoxDecoration(
                    color: c.surfaceContainer,
                    borderRadius: r,
                    border: Border.all(
                      color: Color.lerp(
                        c.outline,
                        c.primary,
                        t.clamp(0.0, 1.0),
                      )!,
                      width: width,
                    ),
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                spacing: 6,
                children: <Widget>[
                  ThemeDot(colors.primary),
                  ThemeDot(colors.primaryContainer),
                  ThemeDot(colors.surfaceContainerHigh, border: c.outline),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          family.name,
                          style: MullType.titleMedium.copyWith(
                            color: c.onSurface,
                          ),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: selected ? 1 : 0),
                        duration: level == MotionLevel.off
                            ? Duration.zero
                            : check.settle,
                        curve: check.clamped,
                        builder:
                            (BuildContext context, double k, Widget? icon) =>
                                ClipRect(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: k,
                                    child: Opacity(
                                      opacity: k.clamp(0.0, 1.0),
                                      child: icon,
                                    ),
                                  ),
                                ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: c.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    family.blurb,
                    style: MullType.monoLabel.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThemeDot extends StatelessWidget {
  const ThemeDot(this.color, {this.size = 34, this.border, super.key});

  final Color color;
  final double size;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: border == null ? null : Border.all(color: border!),
    ),
  );
}
