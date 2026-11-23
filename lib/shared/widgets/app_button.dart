import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'dashed_border.dart';

/// Kuber's button types, under Mull's names.
enum AppButtonType {
  /// Filled: `primary` / `onPrimary`. One per screen.
  primary,

  /// Kuber's `normal`: tonal, the selected-container pair.
  secondary,

  /// Kuber's `outline`: transparent, 1dp outline, `onSurface` label.
  outlined,

  /// Dashed outline, low emphasis: "add another one of these".
  dotted,

  /// Kuber's `danger`: the danger container (tonal); [AppButton.filled] makes it
  /// a solid danger fill for high-stakes confirms.
  danger,

  /// Mull only: a ghost button with no fill or border and a muted label.
  muted;

  /// Alias for [outlined].
  static const AppButtonType outline = AppButtonType.outlined;
}

/// The one button, ported from Kuber's `shared/widgets/app_button.dart`: a
/// stadium 56 high (padding 24, label 16) or, [compact], 40 high (padding 16,
/// label 14), icon 20 with an 8 gap. Disabled is `onSurface` at 12% / 38%.
/// Pressed, the corners morph from the pill to 12dp (56) / 8dp (40) on the
/// fast spring at Expressive; Material's own shape tween is off so the spring
/// drives it frame by frame. The fill fades on `fxFast`.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.icon,
    this.iconAfterLabel = false,
    this.fullWidth = false,
    this.compact = false,
    this.width,
    this.padding,
    this.isLoading = false,
    this.filled = false,
    super.key,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final AppButtonType type;
  final IconData? icon;
  final bool iconAfterLabel;
  final bool fullWidth;

  /// Kuber's 40dp size (below 48); the default is the 56dp size.
  final bool compact;

  /// A fixed width. Below 120 a 56dp button takes the 16dp side padding.
  final double? width;

  /// Overrides the side padding (24 on a 56dp button, 16 otherwise).
  final EdgeInsetsGeometry? padding;

  /// A shape loader in place of the icon; the button is inert meanwhile.
  final bool isLoading;

  /// For [AppButtonType.danger] only: a solid danger fill.
  final bool filled;

  static const double _large = 56;
  static const double _small = 40;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final bool large = !compact;
    final double h = large ? _large : _small;
    final bool disabled = onPressed == null || isLoading;

    var (Color bg, Color fg, BorderSide side) = switch (type) {
      AppButtonType.primary => (c.primary, c.onPrimary, BorderSide.none),
      AppButtonType.secondary => (c.primaryContainer, c.onPrimaryContainer, BorderSide.none),
      AppButtonType.outlined => (Colors.transparent, c.onSurface, BorderSide(color: c.outline)),
      AppButtonType.danger => filled
          ? (c.danger, c.onPrimary, BorderSide.none)
          : (c.dangerContainer, c.onDangerContainer, BorderSide.none),
      AppButtonType.dotted => (Colors.transparent, c.onSurfaceVariant, BorderSide.none),
      AppButtonType.muted => (Colors.transparent, c.onSurfaceMuted, BorderSide.none),
    };
    if (disabled && !isLoading) {
      final bool hollow = type == AppButtonType.outlined || type == AppButtonType.dotted || type == AppButtonType.muted;
      bg = hollow ? Colors.transparent : c.onSurface.withValues(alpha: 0.12);
      fg = c.onSurface.withValues(alpha: 0.38);
      if (type == AppButtonType.outlined) side = BorderSide(color: c.onSurface.withValues(alpha: 0.12));
    }

    final TextStyle textStyle = (large ? MullType.buttonLarge : MullType.buttonSmall).copyWith(color: fg);
    final Widget iconWidget = Icon(icon, size: 20, color: fg);
    final Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (isLoading)
          SizedBox(width: 20, height: 20, child: ShapeLoader(size: 20, color: fg))
        else if (icon != null && !iconAfterLabel) ...<Widget>[iconWidget, const SizedBox(width: 8)],
        if (isLoading) const SizedBox(width: 8),
        // Flexible so a long label at a large font scale ellipsises.
        Flexible(child: Text(label, style: textStyle, overflow: TextOverflow.ellipsis, maxLines: 1)),
        if (!isLoading && icon != null && iconAfterLabel) ...<Widget>[const SizedBox(width: 8), iconWidget],
      ],
    );

    final Duration fade = Motion.levelOf(context) == MotionLevel.off ? Motion.fxInstant : Motion.fxFast;
    final double hPad = large && (width == null || width! >= 120) ? 24 : 16;
    final EdgeInsetsGeometry pad = padding ?? EdgeInsets.symmetric(horizontal: hPad);

    final Widget button = Pressable(
      kind: PressKind.button,
      enabled: !disabled,
      restRadius: h / 2,
      pressedRadius: large ? 12 : 8,
      builder: (BuildContext context, double radius, double _) {
        final RoundedRectangleBorder shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: side,
        );
        Widget b = ConstrainedBox(
          constraints: BoxConstraints(minHeight: h),
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: bg),
            duration: fade,
            curve: Motion.curveEffects,
            builder: (BuildContext context, Color? color, Widget? child) => Material(
              color: color,
              animationDuration: Duration.zero,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: disabled ? null : onPressed,
                child: Padding(padding: pad, child: child),
              ),
            ),
            child: Center(widthFactor: 1, heightFactor: 1, child: content),
          ),
        );
        if (type == AppButtonType.dotted) {
          b = CustomPaint(
            foregroundPainter: DashedBorderPainter(c.outline, radius: radius),
            child: b,
          );
        }
        return b;
      },
    );

    // A minimum height, not Kuber's fixed one: at the largest font scale a
    // 40dp button's label would be clipped.
    return Semantics(
      button: true,
      enabled: !disabled,
      child: SizedBox(
        width: fullWidth ? double.infinity : width,
        child: ConstrainedBox(constraints: BoxConstraints(minHeight: h), child: button),
      ),
    );
  }
}
