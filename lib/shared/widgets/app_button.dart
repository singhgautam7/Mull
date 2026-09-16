import 'package:flutter/material.dart';

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

    final bool dashed = type == AppButtonType.dotted && !disabled;
    // A minimum height, not a fixed one: the pill grows with its text.
    Widget button = ConstrainedBox(
      constraints: BoxConstraints(minHeight: height, minWidth: fullWidth ? double.infinity : 0),
      child: Material(
        color: skin.bg,
        shape: StadiumBorder(
          side: skin.border == null || dashed
              ? BorderSide.none
              : BorderSide(color: skin.border!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 22, vertical: 4),
            child: content,
          ),
        ),
      ),
    );
    if (dashed) {
      button = CustomPaint(
        foregroundPainter: DashedBorderPainter(skin.border!),
        child: button,
      );
    }
    return Semantics(button: true, enabled: !disabled, label: label, child: button);
  }

  _Skin _skin(MullColors c, {required bool disabled}) {
    if (disabled) return _Skin(bg: c.surfaceContainerHigh, fg: c.onSurfaceMuted);
    return switch (type) {
      AppButtonType.primary => _Skin(bg: c.primary, fg: c.onPrimary),
      AppButtonType.secondary => _Skin(bg: c.surfaceContainerHigh, fg: c.onSurface),
      AppButtonType.outlined => _Skin(bg: Colors.transparent, fg: c.onSurface, border: c.outline),
      AppButtonType.dotted => _Skin(bg: Colors.transparent, fg: c.onSurfaceVariant, border: c.outline),
      AppButtonType.danger => _Skin(bg: c.dangerContainer, fg: c.onDangerContainer),
    };
  }
}

class _Skin {
  const _Skin({required this.bg, required this.fg, this.border});

  final Color bg;
  final Color fg;
  final Color? border;
}
