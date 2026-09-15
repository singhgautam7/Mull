import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/tokens.dart';

/// `page.push`: a container-transform-shaped push, 240 ms on the spring. The
/// incoming page fades and scales up from 96%; under reduced motion it
/// cross-fades at 90 ms.
CustomTransitionPage<T> mullPage<T>({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: Motion.containerTransform,
    reverseTransitionDuration: Motion.containerTransform,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondary,
      Widget child,
    ) {
      final bool reduced = Motion.reduced(context);
      final Animation<double> curved = CurvedAnimation(
        parent: animation,
        curve: reduced ? Curves.linear : Motion.decelerate,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: reduced
            ? child
            : ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(
                  CurvedAnimation(parent: animation, curve: Motion.spring),
                ),
                child: child,
              ),
      );
    },
  );
}
