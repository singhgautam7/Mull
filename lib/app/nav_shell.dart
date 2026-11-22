import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/motion/motion.dart';
import '../core/theme/tokens.dart';
import 'nav_bar.dart';

/// The Mull tab pages vertically, so a tap on it while active does nothing.
const int kMullTab = 1;
const int kSearchTab = 3;

/// A tap on a nav destination.
///
/// Another tab: switch to it as before. The active tab: scroll its list back
/// to the top and stop there, nothing is popped (Kuber). Search also raises
/// the keyboard, as YouTube Music and Spotify do: a fresh `focus` token is
/// what tells the screen to take focus again. The Mull tab does nothing.
void onTabSelected(BuildContext context, StatefulNavigationShell shell, int i, {required String searchPath}) {
  if (i != shell.currentIndex) {
    shell.goBranch(i);
    return;
  }
  if (i == kMullTab) return;
  scrollTabToTop(shell.route.branches[i].navigatorKey.currentContext);
  if (i == kSearchTab) context.go('$searchPath?focus=${DateTime.now().millisecondsSinceEpoch}');
}

/// Scrolls the first vertical scroll view of the topmost route under [nav]
/// to its start. Runs only on the tap. A no-op at the top.
void scrollTabToTop(BuildContext? nav) {
  if (nav == null) return;
  // Each route wraps its page in a PrimaryScrollController; the last one
  // found is the route on top.
  Element? route;
  void findRoute(Element e) {
    if (e.widget is PrimaryScrollController) {
      route = e;
      return;
    }
    e.visitChildren(findRoute);
  }

  nav.visitChildElements(findRoute);
  ScrollPosition? pos;
  void findScrollable(Element e) {
    if (pos != null) return;
    if (e is StatefulElement && e.state is ScrollableState) {
      final ScrollableState s = e.state as ScrollableState;
      if (axisDirectionToAxis(s.axisDirection) == Axis.vertical) {
        pos = s.position;
        return;
      }
    }
    e.visitChildren(findScrollable);
  }

  route?.visitChildren(findScrollable);
  final ScrollPosition? p = pos;
  if (p == null || p.pixels <= p.minScrollExtent) return;
  // Never jump: a jump lays out every row on the way in one frame. Longer
  // trips get more frames, on an even-speed curve.
  final double screens = (p.pixels - p.minScrollExtent) / p.viewportDimension;
  final int ms = (250 + screens * 40).clamp(250, 800).round();
  p.animateTo(
    p.minScrollExtent,
    duration: Duration(milliseconds: ms),
    curve: Curves.easeInOutSine,
  );
}

/// True while a full-screen surface wants the pill gone (the multi-select
/// header, a full-screen word view). The pill leaves downward on `navHide`.
final NotifierProvider<NavHidden, bool> navHiddenProvider = NotifierProvider<NavHidden, bool>(NavHidden.new);

class NavHidden extends Notifier<bool> {
  @override
  bool build() => false;

  void set({required bool hidden}) => state = hidden;
}

/// Hosts the five destinations and the floating nav.
///
/// A switch animates only the incoming tab: a short slide (6% of the width,
/// from the side of travel) and a fade, at Expressive on
/// `containerTransform` / `decelerate`; a fade alone at Subtle; a 90 ms fade at
/// Off. The page sits in a [RepaintBoundary] *inside* the transition, so the
/// animation composites one cached layer and repaints nothing. The old slide
/// translated the whole shell with the boundary outside the transform, which
/// repainted the incoming tab every frame. Kuber's PageView was tried and
/// measured: its far-tab jump lays out a third page in the first frame
/// (specs/app-polish-2/performance.md).
///
/// The pill translates down 72 and fades out on scroll-down past 24px, and
/// comes back on any scroll-up, as in Perch. The Mull tab pages vertically,
/// so scrolling there never hides it.
class NavShell extends ConsumerStatefulWidget {
  const NavShell({required this.child, required this.index, required this.onSelect, this.tabCount = 5, super.key});

  final Widget child;
  final int index;
  final ValueChanged<int> onSelect;
  final int tabCount;

  @override
  ConsumerState<NavShell> createState() => _NavShellState();
}

class _NavShellState extends ConsumerState<NavShell> with TickerProviderStateMixin {
  late final AnimationController _hide = AnimationController(vsync: this, duration: Motion.navHide);
  late final AnimationController _page = AnimationController(vsync: this, value: 1.0);
  double _lastOffset = 0;
  bool _forward = true;

  static const int _mullTab = 1;

  /// How far the incoming tab travels, as a fraction of the width.
  static const double _travel = 0.06;

  @override
  void didUpdateWidget(NavShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _forward = widget.index > oldWidget.index;
      final MotionLevel level = Motion.levelOf(context);
      _page.duration = level == MotionLevel.off ? Motion.fxInstant : Motion.containerTransform;
      _page.forward(from: 0.0);
      _hide.reverse();
    }
  }

  @override
  void dispose() {
    _hide.dispose();
    _page.dispose();
    super.dispose();
  }

  /// A horizontal fling anywhere on the page moves to the next destination.
  /// Vertical drags belong to the list, so only a decisive horizontal one wins.
  void _onHorizontalFling(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 240) return;
    final int next = velocity < 0 ? widget.index + 1 : widget.index - 1;
    if (next < 0 || next >= widget.tabCount) return;
    widget.onSelect(next);
  }

  bool _onScroll(ScrollNotification n) {
    if (widget.index == _mullTab) return false;
    if (n.metrics.axis != Axis.vertical || n is! ScrollUpdateNotification) return false;
    final double offset = n.metrics.pixels;
    final double delta = offset - _lastOffset;
    if (delta.abs() < 2) return false;
    _lastOffset = offset;
    if (delta > 0 && offset > 24) {
      _hide.forward();
    } else if (delta < 0) {
      _hide.reverse();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final MotionLevel level = Motion.levelOf(context);
    final bool reduced = level != MotionLevel.expressive;
    final bool hidden = ref.watch(navHiddenProvider);
    final Animation<double> fade = CurvedAnimation(parent: _page, curve: Motion.curveEffects);
    final Animation<double> move = CurvedAnimation(parent: _page, curve: Motion.decelerate);
    final double from = reduced ? 0 : (_forward ? _travel : -_travel);
    return PopScope(
      canPop: widget.index == 0,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) widget.onSelect(0);
      },
      child: Scaffold(
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: Stack(
            children: <Widget>[
              GestureDetector(
                onHorizontalDragEnd: _onHorizontalFling,
                behavior: HitTestBehavior.translucent,
                child: FadeTransition(
                  opacity: fade,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: Offset(from, 0), end: Offset.zero).animate(move),
                    child: RepaintBoundary(child: widget.child),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 22,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _hide,
                    builder: (BuildContext context, Widget? child) {
                      final double t = hidden ? 1 : _hide.value;
                      return Opacity(
                        opacity: 1 - t,
                        child: Transform.translate(
                          offset: Offset(0, reduced ? 0 : 72 * t),
                          child: IgnorePointer(ignoring: t > 0.5, child: child),
                        ),
                      );
                    },
                    child: Center(
                      child: MullNavPill(index: widget.index, onSelect: widget.onSelect),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
