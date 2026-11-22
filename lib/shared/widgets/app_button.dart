import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'dashed_border.dart';

enum AppButtonType {
  /// Accent fill. One per screen.
  primary,

  /// Filled, quiet; sits next to a primary.
  secondary,

  /// 1px outline on the page surface.
  outlined,

  /// Dashed: "add another one of these".
  dotted,

  /// The danger well: `dangerContainer` with `onDangerContainer` label.
  /// There are no filled red buttons in Mull.
  danger,

  /// Subtle ghost button with no border and muted label.
  muted;

  /// Alias for [outlined].
  static const AppButtonType outline = AppButtonType.outlined;
}

/// The one button. Height, radius, padding and label style all come from
/// tokens, so a button never drifts from the sheet.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.icon,
    this.fullWidth = false,
    this.compact = false,
    this.padding,
    super.key,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final AppButtonType type;
  final IconData? icon;
  final bool fullWidth;

  /// The 32dp inline form.
  final bool compact;

  /// Optional custom padding inside the pill.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final bool disabled = onPressed == null;
    final _Skin skin = _skin(c, disabled: disabled);
    final double height = compact ? 32 : 46;

    final Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: Space.sm,
      children: <Widget>[
        if (icon != null) Icon(icon, size: compact ? 16 : 18, color: skin.fg),
        // Flexible so a long label at a large font scale ellipsises
        // rather than pushing past the pill.
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact ? MullType.label.weight(600) : MullType.titleMedium)
                .copyWith(color: skin.fg),
          ),
        ),
      ],
    );

    final Duration fade = Motion.levelOf(context) == MotionLevel.off ? Motion.fxInstant : Motion.fxFast;
    final bool dashed = type == AppButtonType.dotted && !disabled;
    // A minimum height, not a fixed one: the pill grows with its text.
    // Pill at rest, radius 8 while pressed (Expressive).
    final Widget button = Pressable(
      kind: PressKind.button,
      restRadius: height / 2,
      pressedRadius: compact ? 8 : 12,
      enabled: !disabled,
      builder: (BuildContext context, double radius, double _) {
        final BorderRadius br = BorderRadius.circular(radius);
        final BorderSide side =
            skin.border == null || dashed ? BorderSide.none : BorderSide(color: skin.border!);
        Widget b = ConstrainedBox(
          constraints: BoxConstraints(minHeight: height, minWidth: fullWidth ? double.infinity : 0),
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: skin.bg),
            duration: fade,
            curve: Motion.curveEffects,
            builder: (BuildContext context, Color? color, Widget? child) => Material(
            color: color,
            animationDuration: Duration.zero,
            // A stadium at rest; a rounded rectangle only while it morphs.
            shape: radius >= height / 2
                ? StadiumBorder(side: side)
                : RoundedRectangleBorder(borderRadius: br, side: side),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: disabled ? null : onPressed,
              child: Padding(
                padding: padding ?? EdgeInsets.symmetric(horizontal: compact ? 13 : 22, vertical: 4),
                child: child,
              ),
            ),
            ),
            child: content,
          ),
        );
        if (dashed) {
          b = CustomPaint(
            foregroundPainter: DashedBorderPainter(skin.border!, radius: radius),
            child: b,
          );
        }
        return b;
      },
    );
    return Semantics(button: true, enabled: !disabled, label: label, child: button);
  }

  _Skin _skin(MullColors c, {required bool disabled}) {
    if (disabled) return _Skin(bg: c.surfaceContainerHigh, fg: c.onSurfaceMuted);
    return switch (type) {
      AppButtonType.primary => _Skin(bg: c.primary, fg: c.onPrimary),
      AppButtonType.secondary => _Skin(bg: c.surfaceContainerHigh, fg: c.onSurface),
      AppButtonType.outlined => _Skin(bg: c.surface, fg: c.onSurface, border: c.accent),
      AppButtonType.dotted => _Skin(bg: Colors.transparent, fg: c.onSurfaceVariant, border: c.outline),
      AppButtonType.danger => _Skin(bg: c.dangerContainer, fg: c.onDangerContainer),
      AppButtonType.muted => _Skin(bg: Colors.transparent, fg: c.onSurfaceMuted),
    };
  }
}

class _Skin {
  const _Skin({required this.bg, required this.fg, this.border});

  final Color bg;
  final Color fg;
  final Color? border;
}
