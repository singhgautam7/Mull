import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';

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
    this.filled = true,
    this.active = false,
    this.tint,
    this.background,
    super.key,
  });

  /// Either an [icon] or a custom [child] glyph, never both.
  final IconData? icon;
  final Widget Function(Color color)? child;
  final VoidCallback? onPressed;

  /// Required: an icon-only control is invisible to a screen reader without it.
  final String semanticLabel;

  /// 40 in headers; 52 on the word card's action row; 30 for the speaker.
  final double size;
  final double glyphSize;

  /// False for the quiet in-field dismisses that sit on a tinted card.
  final bool filled;

  /// The one variation allowed: a toggled state (bookmarked, open menu).
  final bool active;
  final Color? tint;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final Color fg = tint ?? (active ? c.onPrimaryContainer : c.icon);
    final Color bg = background ??
        (active
            ? c.primaryContainer
            : (filled ? c.surfaceContainerHigh : Colors.transparent));
    final double target = size > IconSpec.tapTarget ? size : IconSpec.tapTarget;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        // The visual is `size`; the tap target is never below 48.
        width: target,
        height: target,
        child: Center(
          child: Material(
            color: bg,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
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
          ),
        ),
      ),
    );
  }
}
