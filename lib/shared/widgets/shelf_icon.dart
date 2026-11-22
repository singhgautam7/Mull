import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/shelf_icons.dart';

/// A user shelf's tile (Kuber's `CategoryIcon`): a squircle in the container
/// tone of the shelf's tag hue with the glyph in the strong tone of the same
/// hue. [color] is an index into `MullColors.tagHues`; null is the accent.
class ShelfIcon extends StatelessWidget {
  const ShelfIcon({this.icon, this.color, this.size = 40, super.key});

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
        borderRadius: BorderRadius.circular(Radii.medium * size / 40),
      ),
      child: Icon(ShelfIcons.of(icon), color: c.tagOnContainer(color), size: size * 0.55),
    );
  }
}
