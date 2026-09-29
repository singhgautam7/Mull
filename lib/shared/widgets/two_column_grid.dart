import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Two columns of cards whose height follows their text. A grid delegate
/// needs a fixed extent, which is the overflow at a large font scale; here
/// each row is as tall as its taller card and no taller.
class TwoColumnGrid extends StatelessWidget {
  const TwoColumnGrid({required this.children, super.key});

  final List<Widget> children;

  /// One row of the grid. A lazy list builds its rows one at a time, so the
  /// row shape lives here rather than being duplicated at the call site.
  static Widget row(Widget left, Widget? right) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.row,
      children: <Widget>[
        Expanded(child: left),
        Expanded(child: right ?? const SizedBox.shrink()),
      ],
    ),
  );

  /// How many rows [count] cards make.
  static int rowsFor(int count) => (count + 1) ~/ 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: Space.row,
      children: <Widget>[
        for (int i = 0; i < children.length; i += 2)
          row(children[i], i + 1 < children.length ? children[i + 1] : null),
      ],
    );
  }
}
