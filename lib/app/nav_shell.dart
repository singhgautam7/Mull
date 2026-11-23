import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_theme.dart';
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

/// The five branches as pages side by side, switched as Kuber's tab pager
/// does: a tap slides the whole page over in 300 ms, ease in and out (a far
/// tab slides in from next door), a sideways drag follows the finger, and a
/// new tap mid-slide carries on from where the pages are. The same at Subtle
/// (a slide has no overshoot and costs less than a fade); Off switches at once.
///
/// Not a `PageView`: that lays out a third page in the frame of a far jump and
/// cannot build or paint a page ahead of its visit. Here every built tab
/// keeps its layout, a slide moves finished layers, and a tab being warmed
/// ([WarmTab]) is painted for two frames at an opacity nobody can see.
class BranchStack extends StatefulWidget {
  const BranchStack({required this.index, required this.onSelect, required this.children, super.key});

  final int index;
  final ValueChanged<int> onSelect;
  final List<Widget> children;

  /// The branch being painted ahead of its first visit, if any.
  static final ValueNotifier<int?> warming = ValueNotifier<int?>(null);

  @override
  State<BranchStack> createState() => _BranchStackState();
}

class _BranchStackState extends State<BranchStack> with SingleTickerProviderStateMixin {
  /// One step of 8-bit alpha: painted, and not visible.
  static const double _unseen = 1 / 255;

  /// Where the view is on the strip, in pages.
  late final AnimationController _cam = AnimationController.unbounded(vsync: this, value: widget.index.toDouble());

  /// Pages on the strip now, and where. At rest only the active one.
  late Map<int, int> _strip = <int, int>{widget.index: widget.index};

  bool _dragging = false;

  @override
  void didUpdateWidget(BranchStack old) {
    super.didUpdateWidget(old);
    if (widget.index == old.index) return;
    if (Motion.levelOf(context) == MotionLevel.off) {
      _rest();
      return;
    }
    _strip.putIfAbsent(widget.index, () {
      final int at = _strip[old.index]! + (widget.index > old.index ? 1 : -1);
      // Whatever was mid-slide there gives up its place.
      _strip.removeWhere((int _, int p) => p == at);
      return at;
    });
    // After this frame: a first visit builds the page in it, and the slide
    // must not spend its start on that.
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted && !_dragging) _settle(duration: Motion.tabSlide, curve: Curves.easeInOut);
    });
  }

  /// Slides to the active page and then leaves only it on the strip.
  void _settle({Duration? duration, Curve curve = Curves.easeOut}) {
    final double to = _strip[widget.index]!.toDouble();
    if (duration != null) {
      _cam.animateTo(to, duration: duration, curve: curve).whenComplete(_trim);
    } else {
      _cam.springTo(to, Motion.springStandard).whenComplete(_trim);
    }
  }

  void _trim() {
    if (!mounted || _dragging || _cam.isAnimating) return;
    setState(_rest);
  }

  void _rest() {
    _strip = <int, int>{widget.index: widget.index};
    _cam.value = widget.index.toDouble();
  }

  // ---- The finger. Vertical drags and the rows that scroll sideways win
  // ---- the arena before this does.

  void _dragStart(DragStartDetails d) {
    if (Motion.levelOf(context) == MotionLevel.off) return;
    _cam.stop();
    final int at = _strip[widget.index]!;
    setState(() {
      _dragging = true;
      if (widget.index > 0) _place(widget.index - 1, at - 1);
      if (widget.index < widget.children.length - 1) _place(widget.index + 1, at + 1);
    });
  }

  void _place(int page, int at) {
    _strip
      ..remove(page)
      ..removeWhere((int _, int p) => p == at)
      ..[page] = at;
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    final int at = _strip[widget.index]!;
    final double lo = at - (widget.index > 0 ? 1.0 : 0.0);
    final double hi = at + (widget.index < widget.children.length - 1 ? 1.0 : 0.0);
    _cam.value = (_cam.value - d.primaryDelta! / context.size!.width).clamp(lo, hi);
  }

  void _dragEnd(DragEndDetails d) {
    final double v = d.primaryVelocity ?? 0;
    final int step = !_dragging
        ? (v.abs() < 240 ? 0 : (v < 0 ? 1 : -1))
        : v.abs() >= 240
        ? (v < 0 ? 1 : -1)
        : (_cam.value - _strip[widget.index]!).round().clamp(-1, 1);
    _dragging = false;
    final int next = widget.index + step;
    if (step != 0 && next >= 0 && next < widget.children.length) {
      widget.onSelect(next); // didUpdateWidget slides the rest of the way
    } else {
      _settle();
    }
  }

  @override
  void dispose() {
    _cam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: _dragStart,
    onHorizontalDragUpdate: _dragUpdate,
    onHorizontalDragEnd: _dragEnd,
    onHorizontalDragCancel: () {
      if (!_dragging) return;
      _dragging = false;
      _settle();
    },
    child: ValueListenableBuilder<int?>(
      valueListenable: BranchStack.warming,
      builder: (BuildContext context, int? warm, Widget? _) => Stack(
        fit: StackFit.expand,
        children: <Widget>[for (int i = 0; i < widget.children.length; i++) _page(i, warm)],
      ),
    ),
  );

  Widget _page(int i, int? warm) {
    final bool active = i == widget.index;
    final int? at = _strip[i];
    return Offstage(
      offstage: at == null && i != warm,
      child: IgnorePointer(
        ignoring: !active,
        child: ExcludeSemantics(
          excluding: !active,
          child: ExcludeFocus(
            excluding: !active,
            child: AnimatedBuilder(
              animation: _cam,
              builder: (BuildContext _, Widget? child) =>
                  FractionalTranslation(translation: Offset(at == null ? 0 : at - _cam.value, 0), child: child),
              child: Opacity(
                opacity: at == null ? _unseen : 1,
                child: RepaintBoundary(
                  // A branch not visited yet is empty: its page still has a ground.
                  child: ColoredBox(
                    color: context.colors.surface,
                    child: TickerMode(enabled: active, child: widget.children[i]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds, lays out and paints a tab while the app idles on another one, so
/// its first visit is a repaint (Shelves took 100 to 120 ms to its first
/// frame on the API 36 AVD, 50 to 60 of it building). The router preloads the
/// branch; its [child] waits here until it is visited, or until [delay] after
/// start-up with no animation or scroll under way. Once built it stays.
class WarmTab extends StatefulWidget {
  const WarmTab({required this.branch, required this.delay, required this.child, super.key});

  /// Index in [kDestinations].
  final int branch;
  final Duration delay;
  final Widget child;

  @override
  State<WarmTab> createState() => _WarmTabState();
}

class _WarmTabState extends State<WarmTab> {
  bool _built = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, _tryWarm);
  }

  Future<void> _tryWarm() async {
    if (!mounted || _built) return;
    if (MullHaptics.scrolling || SchedulerBinding.instance.transientCallbackCount > 0) {
      _timer = Timer(const Duration(milliseconds: 200), _tryWarm);
      return;
    }
    setState(() => _built = true);
    await WidgetsBinding.instance.endOfFrame;
    BranchStack.warming.value = widget.branch;
    await WidgetsBinding.instance.endOfFrame;
    if (BranchStack.warming.value == widget.branch) BranchStack.warming.value = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (TickerMode.valuesOf(context).enabled) _built = true;
    return _built ? widget.child : const SizedBox.expand();
  }
}

/// True while a full-screen surface wants the pill gone (the multi-select
/// header, a full-screen word view). The pill leaves downward on `navHide`.
final NotifierProvider<NavHidden, bool> navHiddenProvider = NotifierProvider<NavHidden, bool>(NavHidden.new);

class NavHidden extends Notifier<bool> {
  @override
  bool build() => false;

  void set({required bool hidden}) => state = hidden;
}

/// Hosts the five destinations ([BranchStack]) and the floating nav.
///
/// The pill translates down 72 and fades out on scroll-down past 24px, and
/// comes back on any scroll-up, as in Perch. The Mull tab pages vertically,
/// so scrolling there never hides it.
class NavShell extends ConsumerStatefulWidget {
  const NavShell({required this.child, required this.index, required this.onSelect, super.key});

  final Widget child;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  ConsumerState<NavShell> createState() => _NavShellState();
}

class _NavShellState extends ConsumerState<NavShell> with TickerProviderStateMixin {
  late final AnimationController _hide = AnimationController(vsync: this, duration: Motion.navHide);
  double _lastOffset = 0;

  static const int _mullTab = 1;

  @override
  void didUpdateWidget(NavShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _lastOffset = 0;
      _hide.reverse();
    }
  }

  @override
  void dispose() {
    _hide.dispose();
    super.dispose();
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
              widget.child,
              Positioned(
                left: 0,
                right: 0,
                bottom: MullNavPill.bottomOf(context),
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
