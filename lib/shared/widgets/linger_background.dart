import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// The Mull tab's page background: true black in dark, pure white in light,
/// regardless of family and of the AMOLED toggle. Cards inside keep the
/// theme's `surfaceContainer`.
///
/// Entering and leaving is a cross-fade on `cardBackground`, never a hard
/// cut: wrap the surface in this and flip [active].
class LingerBackground extends StatelessWidget {
  const LingerBackground({required this.active, required this.child, super.key});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.of(context, Motion.cardBackground),
      curve: Motion.curveOf(context, Motion.decelerate),
      color: active ? context.colors.lingerSurface : context.colors.surface,
      child: child,
    );
  }
}
