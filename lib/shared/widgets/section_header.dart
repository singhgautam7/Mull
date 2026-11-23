import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
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
          // An action's 48dp hit region already holds the space around the text.
          ? trailing is SectionHeaderAction
              ? const EdgeInsets.symmetric(horizontal: Space.screen)
              : const EdgeInsets.fromLTRB(Space.screen, 2, Space.screen, Space.row)
          : EdgeInsets.zero,
      // Both sides keep their natural width (each may take at most half, so
      // the largest font scale wraps instead of overflowing) and spaceBetween
      // puts the trailing's right edge on the content edge. The trailing must
      // not expand itself (no bare Center): SectionHeaderAction does not.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: MullType.sectionHeader.copyWith(
                color: accent ? c.accent : c.onSurfaceVariant,
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: Space.md),
            Flexible(child: trailing!),
          ],
        ],
      ),
    );
  }
}

/// The right-hand action of a [SectionHeader] ("See all"): a 48dp tall hit
/// region, the text flush with the content edge.
class SectionHeaderAction extends StatelessWidget {
  const SectionHeaderAction({
    required this.label,
    required this.onTap,
    this.icon,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Pressable(
        kind: PressKind.row,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: IconSpec.tapTarget),
          child: Align(
            widthFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: Space.xs,
              children: <Widget>[
                if (icon != null) Icon(icon, size: 14, color: c.accent),
                Flexible(child: Text(label, style: MullType.monoLabel.copyWith(color: c.accent))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A `monoLabel` note that sits at the right of a section header:
/// `easiest first`, `pick by interest`.
class SectionNote extends StatelessWidget {
  const SectionNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: MullType.monoLabel.copyWith(color: context.colors.onSurfaceMuted),
  );
}

/// A quiet line of help with an info glyph, under the control it explains.
class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: <Widget>[
        Icon(Icons.info_outline_rounded, size: 14, color: c.onSurfaceVariant),
        Expanded(
          child: Text(text, style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant)),
        ),
      ],
    );
  }
}
