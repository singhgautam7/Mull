import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/shelf_icons.dart';

/// A user shelf's tile (Kuber's `CategoryIcon`): a squircle in the container
/// tone of the shelf's tag hue with the glyph in the strong tone of the same
/// hue. [color] is an index into `MullColors.tags`; null is the accent. The
/// corner is Kuber's 12dp at every size.
class ShelfIcon extends StatelessWidget {
  const ShelfIcon({this.icon, this.color, this.size = 40, super.key});

  /// Any of the user's shelves: their own icon and colour, or, for the two
  /// system shelves, a fixed glyph in the accent (Bookmarks, From my reading).
  factory ShelfIcon.of({required String slug, required String? icon, required int? color, double size = 40, Key? key}) =>
      ShelfIcon(
        icon: switch (slug) {
          'bookmarks' => 'bookmark',
          'reading' => 'auto_stories',
          _ => icon,
        },
        color: slug == 'bookmarks' || slug == 'reading' ? null : color,
        size: size,
        key: key,
      );

  final String? icon;
  final int? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.tagContainer(color),
        borderRadius: Radii.mediumR,
      ),
      child: Icon(ShelfIcons.of(icon), color: c.tagOnContainer(color), size: size * 0.55),
    );
  }
}
