import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// The one tooltip in the app: a surface chip with a hairline, holding the same
/// label a screen reader announces.
///
/// Long-pressing any icon button reveals what it does.
/// The wrapper takes the label out of the semantics tree ([excludeFromSemantics])
/// on the assumption that the caller already named the control.
class AppTooltip extends StatelessWidget {
  const AppTooltip({
    required this.message,
    required this.child,
    super.key,
  });

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return child;
    final MullColors c = context.colors;
    return Tooltip(
      message: message,
      excludeFromSemantics: true,
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.chipR,
        border: Border.all(color: c.outline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      textStyle: MullType.label.copyWith(
        fontSize: 12,
        color: c.onSurface,
      ),
      child: child,
    );
  }
}
