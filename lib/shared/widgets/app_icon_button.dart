import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import 'app_tooltip.dart';

/// Visual weight of an [AppIconButton] (Kuber's `AppIconButtonKind`).
enum AppIconButtonKind {
  /// `surfaceContainerHigh` disc, `onSurface` glyph. The default header button.
  standard,

  /// The selected-container disc: an active toggle (bookmarked, open menu).
  tonal,

  /// `primary` disc, `onPrimary` glyph.
  filled,

  /// No disc: a quiet action inside a field or on a tinted card.
  plain,

  /// The danger container: Delete in the contextual header.
  danger,
}

/// Every icon action is this button, ported from Kuber's
/// `shared/widgets/app_icon_button.dart`: a disc ([size], 40 by default) with a
/// 20dp glyph centred in a tap target of at least 48. Pressed, the circle
/// morphs to a 12dp squircle on the fast spring and the standard fill warms
/// toward the pressed tone (Expressive). Disabled fades to 38%. A changed
/// [icon] swaps with a scale and fade; [iconTurns] rotates it like a chevron.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.onPressed,
    required this.semanticLabel,
    this.icon,
    this.child,
    this.kind,
    this.size = 40,
    this.glyphSize = 20,
    this.targetSize,
    this.tooltip,
    this.filled = true,
    this.active = false,
    this.tint,
    this.background,
    this.onLongPress,
    this.iconTurns,
    super.key,
  });

  /// Either an [icon] or a custom [child] glyph, never both.
  final IconData? icon;
  final Widget Function(Color color)? child;

  /// Null disables the button (38% opacity).
  final VoidCallback? onPressed;

  /// Required: an icon-only control is invisible to a screen reader without it.
  final String semanticLabel;

  /// The weight. When null it comes from the older flags: [active] is
  /// tonal, `filled: false` is plain, otherwise standard.
  final AppIconButtonKind? kind;

  /// 40 in headers; 52 on the word card's action row; 30 for the speaker.
  final double size;
  final double glyphSize;

  /// Overrides the tap target size (defaults to at least 48).
  final double? targetSize;

  /// Tooltip shown on long-press. Defaults to [semanticLabel].
  final String? tooltip;

  /// False is [AppIconButtonKind.plain].
  final bool filled;

  /// True is [AppIconButtonKind.tonal].
  final bool active;
  final Color? tint;
  final Color? background;

  /// Fires with the long-press haptic.
  final VoidCallback? onLongPress;

  /// Glyph rotation in turns, animated like a chevron (fast spring; Subtle
  /// the subtle spring; Off snaps). Null keeps the plain glyph.
  final double? iconTurns;

  AppIconButtonKind get _kind =>
      kind ?? (active ? AppIconButtonKind.tonal : (filled ? AppIconButtonKind.standard : AppIconButtonKind.plain));

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final bool disabled = onPressed == null;
    final AppIconButtonKind k = _kind;
    final (Color kindBg, Color kindFg) = switch (k) {
      AppIconButtonKind.standard => (c.surfaceContainerHigh, c.onSurface),
      AppIconButtonKind.tonal => (c.primaryContainer, c.onPrimaryContainer),
      AppIconButtonKind.filled => (c.primary, c.onPrimary),
      AppIconButtonKind.plain => (Colors.transparent, c.onSurfaceVariant),
      AppIconButtonKind.danger => (c.dangerContainer, c.onDangerContainer),
    };
    final Color bg = background ?? kindBg;
    final Color glyph = tint ?? kindFg;
    final double target = targetSize ?? (size < IconSpec.tapTarget ? IconSpec.tapTarget : size);
    final MotionLevel level = Motion.levelOf(context);
    final bool off = level == MotionLevel.off;
    // Mull has no surfaceContainerHighest role: the pressed tone is
    // onSurface at 8% over the fill.
    final Color pressedBg = Color.alphaBlend(c.onSurface.withValues(alpha: 0.08), bg);

    Widget glyphWidget(Color color) => child != null ? child!(color) : _IconSwap(icon: icon, size: glyphSize, color: color);

    final Widget button = SizedBox(
      width: target,
      height: target,
      child: Center(
        child: AnimatedOpacity(
          opacity: disabled ? 0.38 : 1,
          duration: off ? Motion.fxInstant : Motion.fxFast,
          curve: Motion.curveEffects,
          child: Pressable(
            kind: PressKind.iconButton,
            enabled: !disabled,
            restRadius: size / 2,
            builder: (BuildContext context, double radius, double pressed) => Material(
              color: k == AppIconButtonKind.standard && background == null && level == MotionLevel.expressive
                  ? Color.lerp(bg, pressedBg, pressed.clamp(0.0, 1.0))
                  : bg,
              animationDuration: Duration.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                onLongPress: onLongPress == null
                    ? null
                    : () {
                        MullHaptics.longPress();
                        onLongPress!();
                      },
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Center(
                    child: iconTurns == null
                        ? glyphWidget(glyph)
                        : Builder(
                            builder: (BuildContext context) {
                              final SpringCurve sc = Motion.spatialCurve(level, Motion.fastCurve);
                              return AnimatedRotation(
                                turns: iconTurns!,
                                duration: off ? Duration.zero : sc.settle,
                                curve: sc.clamped,
                                child: glyphWidget(glyph),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      label: semanticLabel,
      // The ink below is excluded, so the node carries the actions itself.
      onTap: onPressed,
      onLongPress: onLongPress,
      excludeSemantics: true,
      child: onLongPress == null ? AppTooltip(message: tooltip ?? semanticLabel, child: button) : button,
    );
  }
}

/// Kuber's icon swap: the old glyph fades out (`fxInstant`), the new one
/// scales 0.6 to 1 on the fast spring and fades in. Subtle and Off cross-fade.
class _IconSwap extends StatelessWidget {
  const _IconSwap({required this.icon, required this.size, required this.color});

  final IconData? icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final MotionLevel level = Motion.levelOf(context);
    final bool expressive = level == MotionLevel.expressive;
    return AnimatedSwitcher(
      duration: expressive ? Motion.fastCurve.settle : (level == MotionLevel.off ? Motion.fxInstant : Motion.fxFast),
      reverseDuration: Motion.fxInstant,
      switchInCurve: expressive ? Motion.fastCurve : Curves.linear,
      switchOutCurve: Curves.linear,
      transitionBuilder: (Widget child, Animation<double> anim) {
        final Widget fade = FadeTransition(opacity: anim, child: child);
        if (!expressive) return fade;
        return ScaleTransition(scale: anim.drive(Tween<double>(begin: 0.6, end: 1.0)), child: fade);
      },
      child: Icon(icon, key: ValueKey<IconData?>(icon), size: size, color: color),
    );
  }
}
