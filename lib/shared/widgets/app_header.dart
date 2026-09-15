import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'app_icon_button.dart';

/// The one header. Every tab root, page and settings sub-page uses this and
/// nothing else.
///
/// Left: an optional 40dp circular back button then the title. Right: up to
/// four identical circular actions, 8dp apart. Padding `20/14/20/12`, 16 on a
/// side that carries a button so the visual edge lands on the 20dp margin.
class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.title,
    this.onBack,
    this.actions = const <Widget>[],
    this.backLabel = 'Back',
    this.collapsed = false,
    this.subtitle,
    super.key,
  });

  final String title;

  /// Null on a tab root, which has nowhere to go back to.
  final VoidCallback? onBack;
  final List<Widget> actions;
  final String backLabel;

  /// Scrolled: the title steps to `screenTitle`, the bar takes `surface`
  /// with a `divider` hairline under it.
  final bool collapsed;

  /// A `monoLabel` line under the title (the collection name on the Mull tab).
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final bool hasBack = onBack != null;

    return AnimatedContainer(
      duration: Motion.of(context, Motion.fast),
      decoration: BoxDecoration(
        color: collapsed ? c.surface : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: collapsed ? c.divider : Colors.transparent),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          hasBack ? Space.lg : Space.screen,
          collapsed ? Space.sm : 14,
          actions.isEmpty ? Space.screen : Space.lg,
          collapsed ? Space.sm : Space.md,
        ),
        child: Row(
          children: <Widget>[
            if (hasBack) ...<Widget>[
              AppIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: onBack,
                semanticLabel: backLabel,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AnimatedDefaultTextStyle(
                    duration: Motion.of(context, Motion.fast),
                    style: (collapsed ? MullType.screenTitle : MullType.headerTitle)
                        .copyWith(color: c.onSurface),
                    child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Reports whether a scroll view has moved past its first 24px, so the
/// header above it can collapse.
class CollapseOnScroll extends StatefulWidget {
  const CollapseOnScroll({required this.builder, super.key});

  final Widget Function(BuildContext context, bool collapsed) builder;

  @override
  State<CollapseOnScroll> createState() => _CollapseOnScrollState();
}

class _CollapseOnScrollState extends State<CollapseOnScroll> {
  bool _collapsed = false;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    final bool next = n.metrics.pixels > 24;
    if (next != _collapsed) setState(() => _collapsed = next);
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
    onNotification: _onScroll,
    child: widget.builder(context, _collapsed),
  );
}
