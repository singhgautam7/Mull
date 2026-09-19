import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// One of a small set of mutually exclusive choices laid out as cards:
/// CSV / PDF on the shelf export sheet, Merge / Replace on the import page.
/// The selected card takes a `primary` outline; [danger] swaps it for `danger`.
class SelectableCard extends StatelessWidget {
  const SelectableCard({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.danger = false,
    super.key,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final Color accent = danger ? c.danger : c.primary;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.cardR,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.instant),
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: selected
                ? (danger ? c.dangerContainer : c.primaryContainer)
                : c.surfaceContainer,
            borderRadius: Radii.cardR,
            border: Border.all(
              color: selected ? accent : c.outline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: MullType.titleMedium
                    .copyWith(
                      color: selected
                          ? (danger ? c.onDangerContainer : c.onPrimaryContainer)
                          : c.onSurface,
                    )
                    .weight(600),
              ),
              const SizedBox(height: Space.xs),
              Text(
                description,
                style: MullType.note.copyWith(
                  color: selected
                      ? (danger ? c.onDangerContainer : c.onPrimaryContainer)
                      : c.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
