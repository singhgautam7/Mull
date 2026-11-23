import 'dart:math' as math;

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

/// Kuber's anchored menu: surface container, card radius, 1dp outline, no
/// shadow, padding 8, 200 to 320 wide. Opens below the anchor, or above it
/// when there is no room below. Pass [anchorContext] for a menu off an icon
/// button, or [globalPosition] for a long-press.
///
/// Its own route, not `showMenu`: that fades every row in by itself, so a
/// shelf's 17 rows were 17 offscreen layers on each of about 30 frames, and
/// it laid the rows out twice on open. Here one panel fades and slides.
Future<T?> showAppMenu<T>({
  required BuildContext context,
  required List<AppMenuEntry<T>> entries,
  BuildContext? anchorContext,
  Offset? globalPosition,
  double minWidth = 200,
}) {
  final NavigatorState nav = Navigator.of(context, rootNavigator: true);
  final RenderBox overlay = nav.overlay!.context.findRenderObject()! as RenderBox;
  final RenderObject? box = anchorContext?.findRenderObject();
  final Rect anchor = box is RenderBox
      ? Rect.fromPoints(
          box.localToGlobal(Offset.zero, ancestor: overlay),
          box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
        )
      : (globalPosition ?? Offset.zero) & Size.zero;
  return nav.push(
    _AppMenuRoute<T>(
      entries: entries,
      anchor: anchor,
      minWidth: minWidth,
      level: Motion.levelOf(context),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      themes: InheritedTheme.capture(from: context, to: nav.context),
    ),
  );
}

class _AppMenuRoute<T> extends PopupRoute<T> {
  _AppMenuRoute({
    required this.entries,
    required this.anchor,
    required this.minWidth,
    required this.level,
    required this.barrierLabel,
    required this.themes,
  });

  final List<AppMenuEntry<T>> entries;
  final Rect anchor;
  final double minWidth;
  final MotionLevel level;
  final CapturedThemes themes;

  @override
  final String barrierLabel;
  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => true;
  @override
  Duration get transitionDuration => level == MotionLevel.off ? Motion.fxInstant : Motion.fxFast;
  @override
  Duration get reverseTransitionDuration => Motion.fxInstant;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondary) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return CustomSingleChildLayout(
      delegate: _MenuLayout(anchor, safe),
      child: themes.wrap(
        Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: MaterialLocalizations.of(context).popupMenuLabel,
          child: RepaintBoundary(
            child: AppMenuPanel(
              minWidth: minWidth,
              children: <Widget>[
                for (final AppMenuEntry<T> e in entries)
                  if (e.divider)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                      child: Divider(color: context.colors.outline, height: 1),
                    )
                  else
                    AppMenuRow(
                      icon: e.icon!,
                      label: e.label,
                      subtitle: e.subtitle,
                      selected: e.selected,
                      danger: e.danger,
                      enabled: e.enabled,
                      onTap: e.enabled ? () => Navigator.of(context).pop(e.value) : null,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondary, Widget child) {
    final Widget faded = FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Motion.curveEffects, reverseCurve: Curves.linear),
      child: child,
    );
    if (level != MotionLevel.expressive) return faded;
    return AnimatedBuilder(
      animation: animation,
      child: faded,
      // A short drop, no scale: scaled text is re-rasterised every frame.
      builder: (BuildContext _, Widget? child) => Transform.translate(
        offset: Offset(0, -Space.sm * (1 - Motion.decelerate.transform(animation.value))),
        child: child,
      ),
    );
  }
}

/// Below [anchor], or above when it does not fit below; clamped to the safe
/// area. Aligned to whichever edge of the anchor is nearer its screen edge.
class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout(this.anchor, this.safe);

  final Rect anchor;
  final EdgeInsets safe;

  static const double _edge = Space.sm;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest).deflate(safe + const EdgeInsets.all(_edge));

  @override
  Offset getPositionForChild(Size size, Size child) {
    final double maxY = math.max(safe.top + _edge, size.height - safe.bottom - _edge - child.height);
    final double maxX = math.max(_edge, size.width - _edge - child.width);
    final double below = anchor.bottom + Space.xs;
    final double above = anchor.top - Space.xs - child.height;
    final double y = below > maxY && above >= safe.top + _edge ? above : below;
    final double x = anchor.center.dx > size.width / 2 && !anchor.isEmpty ? anchor.right - child.width : anchor.left;
    return Offset(x.clamp(_edge, maxX), y.clamp(safe.top + _edge, maxY));
  }

  @override
  bool shouldRelayout(_MenuLayout old) => anchor != old.anchor || safe != old.safe;
}

/// The menu card, shared by [showAppMenu] and the menu laid out by hand (the
/// long-press Define / Copy menu). Scrolls when taller than its room. Not
/// animated.
class AppMenuPanel extends StatelessWidget {
  const AppMenuPanel({required this.children, this.minWidth = 200, super.key});

  final List<Widget> children;
  final double minWidth;

  static const double maxWidth = 320;

  /// The long-press menu's entrance: spring fast in (subtle spring at
  /// Subtle), 90 ms fade out; Off 90 ms.
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
      // Card radius, 1dp outline.
      shape: RoundedRectangleBorder(
        borderRadius: Radii.cardR,
        side: BorderSide(color: c.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
        child: IntrinsicWidth(
          child: SingleChildScrollView(
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
/// subtitle. Selected: selected-container fill and a trailing check. No
/// [onTap] is a disabled row.
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

    // An unselected row draws no box of its own, so the ink shows.
    final Widget row = Container(
      constraints: const BoxConstraints(minHeight: IconSpec.tapTarget),
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      decoration: selected ? BoxDecoration(color: c.primaryContainer, borderRadius: Radii.mediumR) : null,
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
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: subtitle == null ? label : '$label, $subtitle',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(onTap: onTap, borderRadius: Radii.mediumR, child: row),
    );
  }
}
