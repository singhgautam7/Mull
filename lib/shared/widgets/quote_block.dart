import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// A block quote, as Markdown draws a line that starts with `>`: an accent bar
/// down the left and the text beside it, no card.
class QuoteBlock extends StatelessWidget {
  const QuoteBlock({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.only(left: Space.md),
    decoration: BoxDecoration(border: Border(left: BorderSide(color: context.colors.primary, width: 3))),
    child: child,
  );
}
