import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import '../shared/widgets/mull_icons.dart';

class NavDestination {
  const NavDestination(this.glyph, this.label);

  final MullGlyph glyph;
  final String label;
}

/// Home · Mull · Shelves · Search · More. Evenly spaced, nothing between them. There is
/// no FAB and no centre button: Mull is a destination, not an action.
const List<NavDestination> kDestinations = <NavDestination>[
  NavDestination(MullGlyph.home, 'Home'),
  NavDestination(MullGlyph.mull, 'Mull'),
  NavDestination(MullGlyph.collections, 'Shelves'),
  NavDestination(MullGlyph.search, 'Search'),
  NavDestination(MullGlyph.more, 'More'),
];

/// Height 56, 8dp padding, radius full, `surface`, 1px outline, the nav
/// shadow. Only the selected destination shows its label, inside a
/// `primaryContainer` indicator that travels on `navIndicator`.
class MullNavPill extends StatelessWidget {
  const MullNavPill({required this.index, required this.onSelect, super.key});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return RepaintBoundary(
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: Radii.fullR,
          border: Border.all(color: c.outline),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.shadow,
              blurRadius: Elevations.navPillBlur,
              offset: const Offset(0, Elevations.navPill),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: <Widget>[
            for (int i = 0; i < kDestinations.length; i++)
              _NavItem(
                destination: kDestinations[i],
                selected: i == index,
                onTap: () => onSelect(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.selected, required this.onTap});

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final Color glyphColor = selected ? c.onPrimaryContainer : c.iconMuted;
    // Under a large OS text scale the labels drop and the glyphs stay.
    final bool showLabel = selected && MediaQuery.textScalerOf(context).scale(13.5) <= 20;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.navIndicator),
          curve: Motion.curveOf(context, Motion.spring),
          height: 40,
          // Inactive items are 44x40; the selected item grows to fit its label.
          padding: EdgeInsets.only(left: showLabel ? 11 : 12, right: showLabel ? 14 : 12),
          decoration: BoxDecoration(
            color: selected ? c.primaryContainer : Colors.transparent,
            borderRadius: Radii.fullR,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: showLabel ? Space.sm : 0,
            children: <Widget>[
              MullIcon(
                destination.glyph,
                color: glyphColor,
                background: selected ? c.primaryContainer : c.surface,
              ),
              AnimatedSize(
                duration: Motion.of(context, Motion.navIndicator),
                curve: Motion.curveOf(context, Motion.spring),
                child: showLabel
                    ? Text(destination.label, style: MullType.titleSmall.copyWith(color: c.onPrimaryContainer))
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
