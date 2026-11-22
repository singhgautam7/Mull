import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import 'app_tooltip.dart';

/// Back, search, share, overflow, close and the card actions are all *this*
/// button. One place decides the hit area, the shape, the fill and the tint.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.onPressed,
    required this.semanticLabel,
    this.icon,
    this.child,
    this.size = 40,
    this.glyphSize = 20,
    this.targetSize,
    this.tooltip,
    this.filled = true,
    this.active = false,
    this.tint,
    this.background,
    this.onLongPress,
    super.key,
  });

  /// Either an [icon] or a custom [child] glyph, never both.
  final IconData? icon;
  final Widget Function(Color color)? child;
  final VoidCallback? onPressed;

  /// Required: an icon-only control is invisible to a screen reader without it.
  final String semanticLabel;

  /// Optional tooltip message shown on long-press. Defaults to [semanticLabel].
  final String? tooltip;

  /// 40 in headers; 52 on the word card's action row; 30 for the speaker.
  final double size;
  final double glyphSize;

  /// Overrides the tap target size if specified (defaults to at least 48).
  final double? targetSize;

  /// False for the quiet in-field dismisses that sit on a tinted card.
  final bool filled;

  /// The one variation allowed: a toggled state (bookmarked, open menu).
  final bool active;
  final Color? tint;
  final Color? background;

  /// Fires with the long-press haptic.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final Color fg = tint ?? (active ? c.onPrimaryContainer : c.icon);
    final Color bg = background ??
        (active
            ? c.primaryContainer
            : (filled ? c.surfaceContainerHigh : Colors.transparent));
    final double defaultTarget =
        size > IconSpec.tapTarget ? size : IconSpec.tapTarget;
    final double target = targetSize ?? defaultTarget;
    final String tip = tooltip ?? semanticLabel;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: AppTooltip(
        message: tip,
        child: SizedBox(
          // The visual is `size`; the tap target is never below 48 unless overridden.
          width: target,
          height: target,
          child: Center(
            // Circle at rest, squircle (radius 12) while pressed at Expressive.
            child: Pressable(
              kind: PressKind.iconButton,
              restRadius: size / 2,
              enabled: onPressed != null,
              builder: (BuildContext context, double radius, double pressed) {
                final BorderRadius shape = BorderRadius.circular(radius);
                // Standard fill warms toward the pressed tone (Kuber).
                final Color fill = filled &&
                        !active &&
                        background == null &&
                        Motion.levelOf(context) == MotionLevel.expressive
                    ? Color.lerp(
                        bg,
                        Color.alphaBlend(c.onSurface.withValues(alpha: 0.08), bg),
                        pressed.clamp(0.0, 1.0),
                      )!
                    : bg;
                return Material(
                  color: fill,
                  animationDuration: Duration.zero,
                  shape: RoundedRectangleBorder(borderRadius: shape),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onPressed,
                    onLongPress: onLongPress == null
                        ? null
                        : () {
                            MullHaptics.longPress();
                            onLongPress!();
                          },
                    customBorder: RoundedRectangleBorder(borderRadius: shape),
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: Center(
                        child: child != null
                            ? child!(fg)
                            : Icon(icon, size: glyphSize, color: fg),
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
}
