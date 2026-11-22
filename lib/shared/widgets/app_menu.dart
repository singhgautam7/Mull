import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// One row of an [showAppMenu], or, with [divider], the rule above the
/// destructive tail. Every row has an [icon].
class AppMenuEntry<T> {
  const AppMenuEntry({
    required this.value,
    required this.label,
    required IconData this.icon,
    this.subtitle,
    this.selected = false,
    this.danger = false,
    this.enabled = true,
  }) : divider = false;

  const AppMenuEntry.divider()
    : value = null,
      label = '',
      subtitle = null,
      icon = null,
      selected = false,
      danger = false,
      enabled = true,
      divider = true;

  final T? value;
  final String label;
  final String? subtitle;
  final IconData? icon;

  /// Selected-container row and a trailing check.
  final bool selected;
  final bool danger;

  /// A disabled row stays visible, muted, with its [subtitle] as the reason.
  final bool enabled;
  final bool divider;
}

/// Kuber's anchored menu (`showKuberMenu`): surface container, card radius,
/// 1dp outline, no shadow, padding 8, 200 to 320 wide. Opens below the anchor,
/// or above it when there is no room below. Pass [anchorContext] for a menu
/// off an icon button, or [globalPosition] for a long-press.
Future<T?> showAppMenu<T>({
  required BuildContext context,
  required List<AppMenuEntry<T>> entries,
  BuildContext? anchorContext,
  Offset? globalPosition,
  double minWidth = 200,
}) {
  final MullColors c = context.colors;
  final RenderBox overlay =
      Navigator.of(context, rootNavigator: true).overlay!.context.findRenderObject()!
          as RenderBox;

  late final RelativeRect position;
  final RenderObject? anchor = anchorContext?.findRenderObject();
  if (anchor is RenderBox) {
    final Offset topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset bottomRight = anchor.localToGlobal(anchor.size.bottomRight(Offset.zero), ancestor: overlay);
    // Below the anchor; above it when that would run off the bottom. The
    // height is estimated from the row metrics.
    final double menuHeight = 2 * Space.sm + 2 +
        entries.fold<double>(
          0,
          (double h, AppMenuEntry<T> e) => h + (e.divider ? 17 : (e.subtitle != null ? 60 : IconSpec.tapTarget)),
        );
    final double bottomLimit = overlay.size.height - MediaQuery.viewPaddingOf(context).bottom - Space.sm;
    final bool above = bottomRight.dy + Space.xs + menuHeight > bottomLimit && topLeft.dy - Space.xs - menuHeight > 0;
    final double top = above ? topLeft.dy - Space.xs - menuHeight : bottomRight.dy + Space.xs;
    position = RelativeRect.fromLTRB(
      topLeft.dx,
      top,
      overlay.size.width - bottomRight.dx,
      overlay.size.height - top,
    );
  } else {
    final Offset at = globalPosition ?? Offset.zero;
    position = RelativeRect.fromLTRB(
      at.dx,
      at.dy,
      overlay.size.width - at.dx,
      overlay.size.height - at.dy,
    );
  }

  return showMenu<T>(
    context: context,
    popUpAnimationStyle: AppMenuPanel.animationStyle(Motion.levelOf(context)),
    position: position,
    useRootNavigator: true,
    color: c.surfaceContainer,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    constraints: BoxConstraints(minWidth: minWidth, maxWidth: AppMenuPanel.maxWidth),
    shape: AppMenuPanel.shape(c),
    menuPadding: const EdgeInsets.all(Space.sm),
    items: <PopupMenuEntry<T>>[
      for (final AppMenuEntry<T> e in entries)
        if (e.divider)
          PopupMenuItem<T>(
            enabled: false,
            height: 17,
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
              child: Divider(color: c.outline, height: 1),
            ),
          )
        else
          PopupMenuItem<T>(
            value: e.value,
            enabled: e.enabled,
            height: 0,
            padding: EdgeInsets.zero,
            // The popup item's own ink is the press feel; no scale.
            child: AppMenuRow(
              icon: e.icon!,
              label: e.label,
              subtitle: e.subtitle,
              selected: e.selected,
              danger: e.danger,
              enabled: e.enabled,
            ),
          ),
    ],
  );
}

/// The menu card: what [showAppMenu] gives its popup, as a widget, for a menu
/// laid out by hand (the long-press Define / Copy menu). Not animated.
class AppMenuPanel extends StatelessWidget {
  const AppMenuPanel({required this.children, super.key});

  final List<Widget> children;

  static const double minWidth = 200;
  static const double maxWidth = 320;

  /// Card radius, 1dp outline.
  static ShapeBorder shape(MullColors c) => RoundedRectangleBorder(
    borderRadius: Radii.cardR,
    side: BorderSide(color: c.outline),
  );

  /// Spring fast in (subtle spring at Subtle), 90 ms fade out; Off 90 ms.
  static AnimationStyle animationStyle(MotionLevel level) {
    if (level == MotionLevel.off) {
      return const AnimationStyle(duration: Motion.fxInstant, reverseDuration: Motion.fxInstant);
    }
    final SpringCurve inC = Motion.spatialCurve(level, Motion.fastCurve);
    return AnimationStyle(curve: inC.clamped, duration: inC.settle, reverseDuration: Motion.fxInstant);
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Material(
      color: c.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: shape(c),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
        child: IntrinsicWidth(
          child: Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// One menu row: min 48, 12dp ink, icon 20, gap 12, label and an optional
/// subtitle. Selected: selected-container fill and a trailing check. Pass
/// [onTap] when no popup item supplies the tap and ink.
class AppMenuRow extends StatelessWidget {
  const AppMenuRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.selected = false,
    this.danger = false,
    this.enabled = true,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final bool danger;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final Color fg = !enabled
        ? c.onSurfaceMuted
        : danger
        ? c.danger
        : (selected ? c.onPrimaryContainer : c.onSurface);
    final Color iconColor = !enabled
        ? c.onSurfaceMuted
        : danger
        ? c.danger
        : (selected ? c.onPrimaryContainer : c.onSurfaceVariant);

    final Widget row = Container(
      constraints: const BoxConstraints(minHeight: IconSpec.tapTarget),
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      decoration: BoxDecoration(
        color: selected ? c.primaryContainer : Colors.transparent,
        borderRadius: Radii.mediumR,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: Space.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: MullType.titleSmall.weight(500).copyWith(color: fg)),
                  if (subtitle != null)
                    Text(subtitle!, style: MullType.bodySmall.copyWith(color: enabled ? c.onSurfaceVariant : c.onSurfaceMuted)),
                ],
              ),
            ),
          ),
          if (selected) ...<Widget>[
            const SizedBox(width: Space.md),
            Icon(Icons.check_rounded, size: 20, color: c.onPrimaryContainer),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(onTap: onTap, borderRadius: Radii.mediumR, child: row),
    );
  }
}
