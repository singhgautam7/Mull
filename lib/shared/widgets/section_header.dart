import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// `COLLECTIONS` on the left in `sectionHeader`, an action or a note on the
/// right. Section headers are ALL-CAPS mono.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.label,
    this.trailing,
    this.accent = false,
    this.inset = true,
    super.key,
  });

  final String label;
  final Widget? trailing;

  /// The word of the day label sits in `accent`.
  final bool accent;

  /// False inside a card that already carries its own padding.
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Padding(
      padding: inset
          ? const EdgeInsets.fromLTRB(Space.screen, 2, Space.screen, Space.row)
          : EdgeInsets.zero,
      // Both sides take their natural width and the free space sits between
      // them, so the trailing action is flush right. Only when they cannot
      // both fit do they share the row.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: MullType.sectionHeader.copyWith(
                color: accent ? c.accent : c.onSurfaceVariant,
              ),
            ),
          ),
          if (trailing != null) Flexible(child: trailing!),
        ],
      ),
    );
  }
}

/// A `monoLabel` note that sits at the right of a section header:
/// `one axis`, `pick by interest`.
class SectionNote extends StatelessWidget {
  const SectionNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: MullType.monoLabel.copyWith(color: context.colors.onSurfaceMuted),
  );
}
