import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Two columns of cards whose height follows their text. A grid delegate
/// needs a fixed extent, which is the overflow at a large font scale; here
/// each row is as tall as its taller card and no taller.
class TwoColumnGrid extends StatelessWidget {
  const TwoColumnGrid({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: Space.row,
      children: <Widget>[
        for (int i = 0; i < children.length; i += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Space.row,
              children: <Widget>[
                Expanded(child: children[i]),
                Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
              ],
            ),
          ),
      ],
    );
  }
}
