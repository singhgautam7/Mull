import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// One row of an [showAppMenu], or, with [divider], the rule above the
/// destructive tail.
class AppMenuEntry<T> {
  const AppMenuEntry({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.selected = false,
    this.danger = false,
    this.radio = false,
    this.enabled = true,
  }) : divider = false;

  const AppMenuEntry.divider()
    : value = null,
      label = '',
      subtitle = null,
      icon = null,
      selected = false,
      danger = false,
      radio = false,
      enabled = true,
      divider = true;

  final T? value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final bool danger;
  final bool radio;

  /// A disabled row stays visible, muted, with its [subtitle] as the reason.
  final bool enabled;
  final bool divider;
}

/// Perch's anchored menu: a rounded card of rows opened beside whatever
/// raised it. Pass [anchorContext] for a menu off an icon button, or
/// [globalPosition] for a long-press.
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
    position = RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy + anchor.size.height,
      overlay.size.width - topLeft.dx - anchor.size.width,
      0,
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
    position: position,
    useRootNavigator: true,
    color: c.surface,
    shadowColor: c.shadow,
    elevation: 8,
    constraints: BoxConstraints(minWidth: minWidth),
    shape: RoundedRectangleBorder(
      borderRadius: Radii.cardR,
      side: BorderSide(color: c.outline),
    ),
    menuPadding: const EdgeInsets.all(Space.sm),
    items: <PopupMenuEntry<T>>[
      for (final AppMenuEntry<T> e in entries)
        if (e.divider)
          PopupMenuItem<T>(
            enabled: false,
            height: 1,
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.row, vertical: 6),
              child: Divider(color: c.outline, height: 1),
            ),
          )
        else
          PopupMenuItem<T>(
            value: e.value,
            enabled: e.enabled,
            height: 0,
            padding: EdgeInsets.zero,
            child: _MenuRow<T>(entry: e),
          ),
    ],
  );
}

class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({required this.entry});

  final AppMenuEntry<T> entry;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final Color fg = !entry.enabled
        ? c.onSurfaceMuted
        : entry.danger
        ? c.danger
        : (entry.selected ? c.onPrimaryContainer : c.onSurface);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: entry.selected ? c.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        spacing: Space.row,
        children: <Widget>[
          if (entry.radio)
            SizedBox(width: 16, child: _Radio(checked: entry.selected, color: fg))
          else if (entry.icon != null)
            SizedBox(width: 18, child: Icon(entry.icon, size: 17, color: fg)),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  entry.label,
                  style: MullType.label
                      .copyWith(fontSize: 13.5, height: 1.35, color: fg)
                      .weight(entry.selected ? 600 : 500),
                ),
                if (entry.subtitle != null) ...<Widget>[
                  const SizedBox(height: 1),
                  Text(
                    entry.subtitle!,
                    style: MullType.monoLabel.copyWith(
                      fontSize: 11,
                      color: entry.selected ? c.onPrimaryContainer.withValues(alpha: 0.8) : c.onSurfaceMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.checked, required this.color});

  final bool checked;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: checked ? color : c.outline, width: 1.6),
      ),
      child: checked
          ? Center(
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            )
          : null,
    );
  }
}
