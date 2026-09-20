import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// One theme family as a card: three swatches, the name, the blurb. The
/// theme screen and the welcome page both pick from these.
class FamilyCard extends StatelessWidget {
  const FamilyCard({required this.family, required this.colors, required this.selected, required this.onTap, super.key});

  final ThemeFamily family;
  final MullColors colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: '${family.name} theme',
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.cardR,
        child: Container(
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(minHeight: 116),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: Radii.cardR,
            border: Border.all(color: selected ? c.primary : c.outline, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                spacing: 6,
                children: <Widget>[
                  ThemeDot(colors.primary),
                  ThemeDot(colors.primaryContainer),
                  ThemeDot(colors.surfaceContainerHigh, border: c.outline),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(family.name, style: MullType.titleMedium.copyWith(color: c.onSurface)),
                  Text(family.hasAmoled ? '${family.blurb} · true black' : family.blurb, style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThemeDot extends StatelessWidget {
  const ThemeDot(this.color, {this.size = 34, this.border, super.key});

  final Color color;
  final double size;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: border == null ? null : Border.all(color: border!)),
  );
}
