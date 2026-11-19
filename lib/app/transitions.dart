import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/motion/motion.dart';
import '../core/theme/tokens.dart';

final double _offShare = Motion.instant.inMilliseconds / Motion.containerTransform.inMilliseconds;

/// `page.push`: a container-transform-shaped push, 240 ms. Expressive: the
/// incoming page fades and scales up from 96% on the spring. Subtle: a fade
/// with a small rise on a curve that never overshoots. Off: a 90 ms fade.
CustomTransitionPage<T> mullPage<T>({required Widget child, required GoRouterState state}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: Motion.containerTransform,
    reverseTransitionDuration: Motion.containerTransform,
    transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondary, Widget child) {
      final MotionLevel level = Motion.levelOf(context);
      final Animation<double> curved = CurvedAnimation(
        parent: animation,
        curve: level == MotionLevel.off ? Curves.linear : Motion.decelerate,
        reverseCurve: level == MotionLevel.off ? Curves.linear : Curves.easeInCubic,
      );
      final Widget faded = FadeTransition(opacity: curved, child: child);
      return switch (level) {
        // The route runs 240 ms; the fade takes its first (or last) 90.
        MotionLevel.off => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Interval(0, _offShare),
            reverseCurve: Interval(1 - _offShare, 1),
          ),
          child: child,
        ),
        MotionLevel.subtle => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved),
          child: faded,
        ),
        MotionLevel.expressive => FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(CurvedAnimation(parent: animation, curve: Motion.spring)),
            child: child,
          ),
        ),
      };
    },
  );
}
