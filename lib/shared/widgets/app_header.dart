import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../features/settings/settings_controller.dart';
import 'app_icon_button.dart';

/// Geometry of the floating header (Kuber v7.0.0-c `_Fh`, same values). The
/// thresholds and timings live in `Motion` (`pillAt`, `headerAt`, ...).
abstract final class HeaderSpec {
  /// Rest: 14 above the 48dp row, 12 below it.
  static const double padTop = 14;
  static const double padBottom = Space.md;
  static const double row = 48;

  /// The pill: 12 in from each side, 8 under the status bar, 56 tall, radius 28.
  static const double margin = 12;
  static const double top = 8;
  static const double pillHeight = 56;
  static const double radius = 28;

  /// Leaving: the pill travels this far up while it fades.
  static const double hideDistance = 72;

  /// The title is 22 at rest and 16 in the pill.
  static const double titleScale = 16 / 22;

  /// Narrower than this the pill drops its title (its semantics stay).
  static const double minTitle = 96;

  /// A side without a button gives the title this much more room.
  static const double noButtonShift = 8;

  /// Where in the morph the subtitle and the dropped title are gone.
  static const double subtitleFadeEnd = 0.4;
  static const double titleDropEnd = 0.6;
}

/// A fixed floating-header setting for a preview (the settings sheet's mini
/// pages): ignores the real settings.
class HeaderPreview {
  const HeaderPreview({required this.floating, required this.pill});

  final bool floating;
  final PillMode pill;
}

/// The one header. Every tab root, page and settings sub-page uses this and
/// nothing else, inside a [HeaderPage].
///
/// Left: an optional 40dp circular back button then the title. Right: up to
/// four identical circular actions, 8dp apart. Padding `20/14/20/12`, 16 on a
/// side that carries a button so the visual edge lands on the 20dp margin.
/// Inside a [HeaderPage] it turns into a floating pill on scroll and holds
/// exactly the same widgets; outside one it is the plain header.
class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.title,
    this.onBack,
    this.actions = const <Widget>[],
    this.backLabel = 'Back',
    this.backIcon = Icons.arrow_back_rounded,
    this.collapsed = false,
    this.subtitle,
    this.pillTitle,
    super.key,
  });

  /// Counts builds. A scroll must not grow it: the header rebuilds only on a
  /// state change (the perf harness and `header_test` read it).
  static int debugBuildCount = 0;

  final String title;

  /// Null on a tab root, which has nowhere to go back to.
  final VoidCallback? onBack;
  final List<Widget> actions;
  final String backLabel;

  /// A form closes (`close_rounded`) rather than goes back.
  final IconData backIcon;

  /// Only outside a [HeaderPage] (the legacy [CollapseOnScroll] path): the
  /// title steps to `screenTitle` and the bar takes `surface` and a hairline.
  final bool collapsed;

  /// A `monoLabel` line under the title (the collection name on the Mull tab).
  final String? subtitle;

  /// What the title says once the header is the pill (Home: the greeting at
  /// rest, "Home" in the pill). The two cross-fade. Null keeps [title].
  final String? pillTitle;

  /// Line heights at the current text scale: `(title, subtitle)`.
  (double, double) _lines(BuildContext context) {
    double h(String text, TextStyle style) {
      final TextPainter tp = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout();
      final double v = tp.height;
      tp.dispose();
      return v;
    }

    return (h('Ag', MullType.headerTitle), subtitle == null ? 0.0 : h('Ag', MullType.monoLabel));
  }

  /// Exact height of the header at rest below the status bar (measured, so it
  /// holds at every text size).
  double restHeight(BuildContext context) {
    final (double t, double s) = _lines(context);
    return HeaderSpec.padTop + math.max(HeaderSpec.row, t + s) + HeaderSpec.padBottom;
  }

  @override
  Widget build(BuildContext context) {
    debugBuildCount++;
    final _HeaderScope? scope = _HeaderScope.maybeOf(context);
    if (scope == null) return _legacy(context);

    final MullColors c = context.colors;
    final bool hasBack = onBack != null;
    final (double, double) lines = _lines(context);
    final Widget content = SizedBox(
      height: scope.restHeight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          hasBack ? Space.lg : Space.screen,
          HeaderSpec.padTop,
          actions.isEmpty ? Space.screen : Space.lg,
          HeaderSpec.padBottom,
        ),
        child: Row(
          children: <Widget>[
            if (hasBack) ...<Widget>[
              AppIconButton(icon: backIcon, onPressed: onBack, semanticLabel: backLabel),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: _TitleSlot(
                title: title,
                pillTitle: pillTitle,
                subtitle: subtitle,
                titleHeight: lines.$1,
                subtitleHeight: lines.$2,
                progress: scope.floating ? scope.progress : kAlwaysDismissedAnimation,
                pilled: scope.pilled,
                leadShift: hasBack ? 0 : HeaderSpec.noButtonShift,
                trailShift: actions.isEmpty ? HeaderSpec.noButtonShift : 0,
                // Largest font: the title leaves the pill, its semantics stay.
                dropBelow: MediaQuery.textScalerOf(context).scale(1) >= 1.5 ? double.infinity : HeaderSpec.minTitle,
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );

    if (scope.floating) {
      return _FloatingSurface(scope: scope, child: content);
    }
    // Fixed (Floating header off, or a non-floating page): an overlay, so it
    // carries its own opaque fill.
    return ColoredBox(
      color: c.surface,
      child: Padding(
        padding: EdgeInsets.only(top: scope.statusBar),
        child: content,
      ),
    );
  }

  /// Outside a [HeaderPage]: the header as it was, sized by its content.
  Widget _legacy(BuildContext context) {
    final MullColors c = context.colors;
    final bool hasBack = onBack != null;

    return AnimatedContainer(
      duration: Motion.of(context, Motion.fast),
      decoration: BoxDecoration(
        color: collapsed ? c.surface : Colors.transparent,
        border: Border(bottom: BorderSide(color: collapsed ? c.divider : Colors.transparent)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          hasBack ? Space.lg : Space.screen,
          collapsed ? Space.sm : HeaderSpec.padTop,
          actions.isEmpty ? Space.screen : Space.lg,
          collapsed ? Space.sm : HeaderSpec.padBottom,
        ),
        child: Row(
          children: <Widget>[
            if (hasBack) ...<Widget>[
              AppIconButton(icon: backIcon, onPressed: onBack, semanticLabel: backLabel),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AnimatedDefaultTextStyle(
                    duration: Motion.of(context, Motion.fast),
                    style: (collapsed ? MullType.screenTitle : MullType.headerTitle).copyWith(color: c.onSurface),
                    child: Text(collapsed ? (pillTitle ?? title) : title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (subtitle != null) Text(subtitle!, style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The page: header + body, one scroll listener.
// ---------------------------------------------------------------------------

/// What a descendant [AppHeader] reads. Changes only when the level, the
/// floating flag or the metrics change; per-frame values are animations.
class _HeaderScope extends InheritedWidget {
  const _HeaderScope({
    required this.hide,
    required this.hidden,
    required this.pins,
    required this.progress,
    required this.restAlpha,
    required this.pillAlpha,
    required this.contentAlpha,
    required this.pilled,
    required this.level,
    required this.floating,
    required this.statusBar,
    required this.restHeight,
    required super.child,
  });

  /// The pill leaving and back, for a [HeaderSearchBar].
  final Animation<double> hide;
  final ValueListenable<bool> hidden;

  /// The Floating header setting: whether a [HeaderSearchBar] sticks.
  final bool pins;

  /// 0 at rest, 1 in the pill. Unbounded: the spring may overshoot.
  final Animation<double> progress;

  /// Subtle: the two layers' alphas.
  final Animation<double> restAlpha;
  final Animation<double> pillAlpha;
  final Animation<double> contentAlpha;

  /// Whether the header is the pill (for semantics), not per frame.
  final ValueListenable<bool> pilled;
  final MotionLevel level;

  /// True when the header can become the pill.
  final bool floating;
  final double statusBar;
  final double restHeight;

  static _HeaderScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_HeaderScope>();

  @override
  bool updateShouldNotify(_HeaderScope old) =>
      level != old.level || floating != old.floating || pins != old.pins || statusBar != old.statusBar || restHeight != old.restHeight;
}

/// Header + scrollable body, as one unit: the header floats over the body,
/// turns into the pill on scroll and (setting) hides with direction.
///
/// ```dart
/// // before: SafeArea(child: Column(children: [AppHeader(...), Expanded(ListView(...))]))
/// HeaderPage(
///   header: AppHeader(title: 'More'),
///   body: ListView(children: [HeaderPage.gap(), ...]),
/// )
/// ```
/// The body fills the screen and keeps its own bottom padding; it starts with
/// [gap] (or [sliverGap]) so the first row sits under the header. Only the
/// header is sticky, or, with `scrollAway`, a [HeaderSearchBar].
class HeaderPage extends ConsumerStatefulWidget {
  const HeaderPage({
    required this.header,
    required this.body,
    this.floating = true,
    this.scrollAway = false,
    this.preview,
    super.key,
  });

  final AppHeader header;
  final Widget body;

  /// False: the header stays fixed at rest (no pill, never hides, never
  /// scrolls away). For pages whose main control sits under the header, and
  /// contextual (selection) headers.
  final bool floating;

  /// True: the header scrolls away with the content and a [HeaderSearchBar]
  /// below it becomes the pill instead (the Search tab).
  final bool scrollAway;

  /// Settings sheet previews only.
  final HeaderPreview? preview;

  /// The space the header takes: status bar plus the rest header.
  static double insetOf(BuildContext context) {
    final _HeaderScope? s = context.getInheritedWidgetOfExactType<_HeaderScope>();
    return s == null ? 0 : s.statusBar + s.restHeight;
  }

  /// The first child of the body's list.
  static Widget gap() => Builder(builder: (BuildContext c) => SizedBox(height: insetOf(c)));

  /// The first sliver of a `CustomScrollView`.
  static Widget sliverGap() => Builder(
    builder: (BuildContext c) => SliverToBoxAdapter(child: SizedBox(height: insetOf(c))),
  );

  @override
  ConsumerState<HeaderPage> createState() => _HeaderPageState();
}

class _HeaderPageState extends ConsumerState<HeaderPage> with TickerProviderStateMixin {
  /// 0 header, 1 pill (unbounded: springs overshoot).
  late final AnimationController _p = AnimationController.unbounded(vsync: this);

  /// Subtle: rest and pill layer alphas.
  late final AnimationController _a0 = AnimationController(vsync: this, value: 1);
  late final AnimationController _a1 = AnimationController(vsync: this);

  /// Subtle: the 4dp settle into the pill.
  late final AnimationController _shift = AnimationController.unbounded(vsync: this);

  /// 0 shown, 1 hidden (unbounded: springs overshoot).
  late final AnimationController _h = AnimationController.unbounded(vsync: this);

  /// The status-bar scrim.
  late final AnimationController _scrim = AnimationController(vsync: this);
  final ProxyAnimation _contentAlpha = ProxyAnimation(kAlwaysCompleteAnimation);

  /// Floating header off: how far the content has carried the header up.
  final ValueNotifier<double> _away = ValueNotifier<double>(0);
  final ValueNotifier<bool> _hiddenN = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _pillN = ValueNotifier<bool>(false);

  bool _pill = false;
  bool _scrolled = false;
  double _pixels = 0;
  double _down = 0, _up = 0, _moved = 0;
  Timer? _showTimer;
  MotionLevel _level = MotionLevel.expressive;
  bool _on = true;

  /// The Floating header setting itself ([_on] also needs `scrollAway` off).
  bool _setting = true;
  PillMode _mode = PillMode.always;
  double _headerExtent = 0;

  bool get _floats => _on && widget.floating;

  @override
  void didUpdateWidget(HeaderPage old) {
    super.didUpdateWidget(old);
    if (old.floating != widget.floating) {
      // Selection started or ended: back to rest, or to the pill if scrolled.
      _setHidden(false);
      _setPill(_floats && _pixels >= Motion.pillAt);
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    for (final AnimationController c in <AnimationController>[_p, _a0, _a1, _shift, _h, _scrim]) {
      c.dispose();
    }
    _away.dispose();
    _hiddenN.dispose();
    _pillN.dispose();
    super.dispose();
  }

  // ---- State changes (only on thresholds or direction) ----

  void _setPill(bool pill) {
    if (pill == _pill) return;
    _pill = pill;
    _pillN.value = pill;
    final double t = pill ? 1.0 : 0.0;
    switch (_level) {
      case MotionLevel.expressive:
        _p.springTo(t, pill ? Motion.springDefault : Motion.springStandard);
      case MotionLevel.subtle:
        // Two layers at their exact bounds: the outgoing one fades out
        // quickly, the incoming one fades in (settling 4dp down into the
        // pill). No bounds morph.
        _p.value = t;
        _a0.animateTo(1 - t, duration: pill ? Motion.fxInstant : Motion.fxFast, curve: Motion.curveEffects);
        _a1.animateTo(t, duration: pill ? Motion.fxFast : Motion.fxInstant, curve: Motion.curveEffects);
        _contentAlpha.parent = pill ? _a1 : _a0;
        if (pill) {
          _shift.value = 4;
          _shift.springTo(0, Motion.springSubtle);
        } else {
          _shift.value = 0;
        }
        _scrim.animateTo(t, duration: pill ? Motion.fxDefault : Motion.fxFast, curve: Motion.curveEffects);
      case MotionLevel.off:
        _p.value = t;
        _scrim.value = t;
    }
  }

  void _setHidden(bool hidden) {
    if (hidden == _hiddenN.value) return;
    _hiddenN.value = hidden;
    final double t = hidden ? 1.0 : 0.0;
    switch (_level) {
      case MotionLevel.expressive:
        _h.springTo(t, hidden ? Motion.springStandard : Motion.springDefault);
      case MotionLevel.subtle:
        _h.animateTo(t, duration: Motion.fxFast, curve: Motion.curveEffects);
      case MotionLevel.off:
        _h.animateTo(t, duration: Motion.fxInstant);
    }
  }

  void _setScrolled(bool scrolled) {
    if (scrolled == _scrolled) return;
    _scrolled = scrolled;
    if (_level == MotionLevel.off) {
      _scrim.value = scrolled ? 1 : 0;
    } else {
      _scrim.animateTo(scrolled ? 1 : 0, duration: Motion.fxDefault, curve: Motion.curveEffects);
    }
  }

  /// Jump every value to the exact state for the current offset (first build,
  /// a setting or level change).
  void _snap() {
    _showTimer?.cancel();
    _down = _up = _moved = 0;
    _pill = _floats && _pixels >= Motion.pillAt;
    _pillN.value = _pill;
    final double t = _pill ? 1.0 : 0.0;
    _p.value = t;
    _a0.value = 1 - t;
    _a1.value = t;
    _shift.value = 0;
    _contentAlpha.parent = _level == MotionLevel.subtle ? (_pill ? _a1 : _a0) : kAlwaysCompleteAnimation;
    _hiddenN.value = false;
    _h.value = 0;
    _scrolled = _pixels > 0;
    final bool carried = !_on && widget.floating;
    _scrim.value = !_on ? (_scrolled ? 1 : 0) : t;
    _away.value = carried ? _pixels.clamp(0, _headerExtent) : 0;
  }

  bool _keyboardOpen() => View.of(context).viewInsets.bottom > 0;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    final double px = n.metrics.pixels - n.metrics.minScrollExtent;
    _pixels = px;
    if (!_on && widget.floating) {
      final double a = px.clamp(0.0, _headerExtent);
      if (a != _away.value) _away.value = a;
      _setScrolled(px > 0);
      // A search pill takes over once the header has gone, and follows the
      // same "Show the pill" setting.
      if (widget.scrollAway && _setting) {
        if (px > _headerExtent + Motion.headerAt) {
          _hideByMode(n);
        } else {
          _setHidden(false);
          _showTimer?.cancel();
          _down = _up = _moved = 0;
        }
      }
      return false;
    }
    if (!_floats) return false;
    if (!_pill && px >= Motion.pillAt) {
      _setPill(true);
    } else if (_pill && px <= Motion.headerAt) {
      _setPill(false);
      _setHidden(false);
      _showTimer?.cancel();
      _down = _up = _moved = 0;
    }
    if (_pill) _hideByMode(n);
    return false;
  }

  /// "Show the pill": hides and shows whatever is the pill as the list moves.
  void _hideByMode(ScrollNotification n) {
    final double delta = n is ScrollUpdateNotification ? (n.scrollDelta ?? 0) : 0.0;
    switch (_mode) {
      case PillMode.scrollUp:
        if (delta > 0) {
          _down += delta;
          _up = 0;
          if (_down > Motion.pillHideAfter && !_keyboardOpen()) _setHidden(true);
        } else if (delta < 0) {
          _up -= delta;
          _down = 0;
          if (_up > Motion.pillShowAfter) _setHidden(false);
        }
      case PillMode.scrollStop:
        if (delta != 0) {
          _showTimer?.cancel();
          _moved += delta.abs();
          if (_moved > Motion.pillHideAfter && !_keyboardOpen()) _setHidden(true);
        } else if (n is ScrollEndNotification) {
          _moved = 0;
          _showTimer?.cancel();
          _showTimer = Timer(Motion.pillStopDelay, () {
            if (mounted) _setHidden(false);
          });
        }
      case PillMode.always:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final HeaderPreview? preview = widget.preview;
    final bool setting = preview?.floating ?? ref.watch(settingsProvider.select((AppSettings s) => s.floatingHeader));
    _setting = setting;
    final bool on = !widget.scrollAway && setting;
    final PillMode mode = preview?.pill ?? ref.watch(settingsProvider.select((AppSettings s) => s.pillMode));
    final MotionLevel level = Motion.levelOf(context);
    final double sb = MediaQuery.paddingOf(context).top;
    final double restH = widget.header.restHeight(context);
    final bool first = _headerExtent == 0;
    _headerExtent = sb + restH;
    if (first || on != _on || mode != _mode || level != _level) {
      _on = on;
      _mode = mode;
      _level = level;
      _snap();
    }
    final bool scrollsAway = !on && widget.floating;

    final Widget scrim = Positioned(
      key: const ValueKey<String>('header-scrim'),
      top: 0,
      left: 0,
      right: 0,
      height: sb + 16,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: on && level == MotionLevel.expressive ? _ClampedAnimation(_p) : _scrim,
          child: HeaderScrim(statusBar: sb),
        ),
      ),
    );

    Widget header = SizedBox(height: sb + restH, child: widget.header);
    header = ValueListenableBuilder<bool>(
      valueListenable: _hiddenN,
      child: header,
      // A hidden pill is not focusable and takes no taps.
      builder: (BuildContext _, bool hidden, Widget? child) => IgnorePointer(
        ignoring: hidden,
        child: ExcludeSemantics(excluding: hidden, child: child),
      ),
    );
    header = _HideTransform(
      hide: _h,
      shift: _shift,
      away: scrollsAway ? _away : null,
      awayMax: sb + restH,
      level: level,
      child: header,
    );

    return _HeaderScope(
      hide: _h,
      hidden: _hiddenN,
      pins: setting,
      progress: _p,
      restAlpha: _a0,
      pillAlpha: _a1,
      contentAlpha: _contentAlpha,
      pilled: _pillN,
      level: level,
      floating: _floats,
      statusBar: sb,
      restHeight: restH,
      child: Stack(
        children: <Widget>[
          NotificationListener<ScrollNotification>(
            key: const ValueKey<String>('header-body'),
            onNotification: _onScroll,
            child: MediaQuery.removePadding(context: context, removeTop: true, child: widget.body),
          ),
          if (_floats) scrim,
          Positioned(
            key: const ValueKey<String>('header-top'),
            top: 0,
            left: 0,
            right: 0,
            child: RepaintBoundary(child: Semantics(container: true, explicitChildNodes: true, child: header)),
          ),
          if (!_floats && scrollsAway) scrim,
        ],
      ),
    );
  }
}

/// The pill leaving (up and fading) and the header being carried off by the
/// content (Floating header off).
class _HideTransform extends StatelessWidget {
  const _HideTransform({
    required this.hide,
    required this.shift,
    required this.away,
    required this.awayMax,
    required this.level,
    required this.child,
  });

  final Animation<double> hide;
  final Animation<double> shift;
  final ValueListenable<double>? away;
  final double awayMax;
  final MotionLevel level;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ValueListenable<double>? a = away;
    if (a != null) {
      return ValueListenableBuilder<double>(
        valueListenable: a,
        child: child,
        builder: (BuildContext _, double v, Widget? c) =>
            Transform.translate(offset: Offset(0, -math.min(v, awayMax)), child: c),
      );
    }
    final double dist = switch (level) {
      MotionLevel.expressive => HeaderSpec.hideDistance,
      MotionLevel.subtle => 4.0,
      MotionLevel.off => 0.0,
    };
    final double fade = level == MotionLevel.expressive ? 1.25 : 1.0;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[hide, shift]),
      child: child,
      builder: (BuildContext _, Widget? c) {
        final double h = hide.value;
        final double o = (1 - h * fade).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, shift.value - h * dist),
          // Hidden is excluded above; this keeps the node while it fades.
          child: Opacity(opacity: o, alwaysIncludeSemantics: true, child: c),
        );
      },
    );
  }
}

/// Fill and hairline of the header: the full-width rest surface and the pill
/// are one rounded rect morphing between two sets of bounds. Repaints from
/// the animations only.
class _SurfacePainter extends CustomPainter {
  _SurfacePainter({
    required this.progress,
    required this.restAlpha,
    required this.pillAlpha,
    required this.subtle,
    required this.restBottom,
    required this.pillTop,
    required this.pillBottom,
    required this.rest,
    required this.pill,
    required this.border,
  }) : super(repaint: Listenable.merge(<Listenable>[progress, restAlpha, pillAlpha]));

  final Animation<double> progress;
  final Animation<double> restAlpha;
  final Animation<double> pillAlpha;
  final bool subtle;
  final double restBottom, pillTop, pillBottom;
  final Color rest, pill, border;

  RRect rrectAt(Size size, double p) {
    final double pp = math.max(0.0, p);
    final double cq = p.clamp(0.0, 1.0);
    final double m = HeaderSpec.margin * pp;
    final double top = pillTop * pp;
    final double bottom = restBottom + (pillBottom - restBottom) * p;
    return RRect.fromLTRBR(m, top, size.width - m, math.max(top, bottom), Radius.circular(HeaderSpec.radius * cq));
  }

  void _paintAt(Canvas canvas, Size size, double p, double alpha) {
    if (alpha <= 0) return;
    final double cq = p.clamp(0.0, 1.0);
    final RRect r = rrectAt(size, p);
    final double a = cq * alpha;
    final Color fill = Color.lerp(rest, pill, cq)!;
    canvas.drawRRect(r, Paint()..color = fill.withValues(alpha: fill.a * alpha));
    if (a > 0) {
      canvas.drawRRect(
        r.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = border.withValues(alpha: border.a * a),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _lastSize = size;
    if (subtle) {
      _paintAt(canvas, size, 0, restAlpha.value);
      _paintAt(canvas, size, 1, pillAlpha.value);
    } else {
      _paintAt(canvas, size, progress.value, 1);
    }
  }

  Size _lastSize = Size.zero;

  /// Only the drawn shape takes touches: beside the pill the body is reached.
  @override
  bool? hitTest(Offset position) => rrectAt(_lastSize, subtle ? 0 : progress.value).contains(position);

  @override
  bool shouldRepaint(_SurfacePainter old) =>
      old.rest != rest ||
      old.pill != pill ||
      old.border != border ||
      old.subtle != subtle ||
      old.restBottom != restBottom ||
      old.pillTop != pillTop ||
      old.pillBottom != pillBottom ||
      old.progress != progress;
}

class _FloatingSurface extends StatelessWidget {
  const _FloatingSurface({required this.scope, required this.child});

  final _HeaderScope scope;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final double sb = scope.statusBar;
    return CustomPaint(
      painter: _SurfacePainter(
        progress: scope.progress,
        restAlpha: scope.restAlpha,
        pillAlpha: scope.pillAlpha,
        subtle: scope.level == MotionLevel.subtle,
        restBottom: sb + scope.restHeight,
        pillTop: sb + HeaderSpec.top,
        pillBottom: sb + HeaderSpec.top + HeaderSpec.pillHeight,
        rest: c.surface,
        pill: c.surfaceContainer,
        border: c.outline,
      ),
      child: Padding(
        padding: EdgeInsets.only(top: sb),
        child: FadeTransition(
          opacity: scope.contentAlpha,
          child: AnimatedBuilder(
            animation: scope.progress,
            child: child,
            // Buttons keep x; they move 2dp up (y 14 to 12) into the pill.
            builder: (BuildContext _, Widget? ch) =>
                Transform.translate(offset: Offset(0, -2 * scope.progress.value.clamp(0.0, 1.0)), child: ch),
          ),
        ),
      ),
    );
  }
}

/// The title (and optional subtitle): 22 at rest, 16 in the pill; the
/// subtitle fades out first; a different pill title cross-fades in.
class _TitleSlot extends StatelessWidget {
  const _TitleSlot({
    required this.title,
    required this.pillTitle,
    required this.subtitle,
    required this.titleHeight,
    required this.subtitleHeight,
    required this.progress,
    required this.pilled,
    required this.leadShift,
    required this.trailShift,
    required this.dropBelow,
  });

  final String title;
  final String? pillTitle;
  final String? subtitle;
  final double titleHeight;
  final double subtitleHeight;
  final Animation<double> progress;
  final ValueListenable<bool> pilled;
  final double leadShift;
  final double trailShift;
  final double dropBelow;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final TextStyle style = MullType.headerTitle.copyWith(color: c.onSurface);
    Text text(String s) => Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    final String? swap = pillTitle;

    return LayoutBuilder(
      builder: (BuildContext _, BoxConstraints box) => AnimatedBuilder(
        animation: progress,
        builder: (BuildContext _, Widget? _) {
          final double cq = progress.value.clamp(0.0, 1.0);
          final double s = 1 - (1 - HeaderSpec.titleScale) * cq;
          final double lead = leadShift * cq;
          final double visual = math.max(0.0, box.maxWidth - lead - trailShift * cq);
          final bool drop = visual < dropBelow;

          Widget titleLayer = swap == null
              ? text(title)
              : Stack(
                  children: <Widget>[
                    Opacity(opacity: (1 - cq / 0.5).clamp(0.0, 1.0), child: text(title)),
                    Opacity(opacity: ((cq - 0.5) / 0.5).clamp(0.0, 1.0), child: text(swap)),
                  ],
                );
          if (swap != null) {
            titleLayer = ExcludeSemantics(child: titleLayer);
            titleLayer = ValueListenableBuilder<bool>(
              valueListenable: pilled,
              child: titleLayer,
              builder: (BuildContext _, bool p, Widget? ch) =>
                  Semantics(header: true, label: p ? swap : title, child: ch),
            );
          }
          // Laid out wider by 1/s, then scaled down to fit [visual].
          titleLayer = SizedBox(
            height: titleHeight,
            child: OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              minWidth: 0,
              maxWidth: visual / s,
              child: titleLayer,
            ),
          );
          // With a subtitle the pair is centred; once it fades the title
          // drops half its height to stay centred.
          titleLayer = Transform(
            alignment: AlignmentDirectional.centerStart,
            transform: Matrix4.translationValues(lead, subtitleHeight / 2 * cq, 0)..scaleByDouble(s, s, 1, 1),
            child: titleLayer,
          );
          // Always present (opacity 1 costs nothing) so the element never
          // remounts mid-morph.
          titleLayer = Opacity(
            opacity: drop ? (1 - cq / HeaderSpec.titleDropEnd).clamp(0.0, 1.0) : 1,
            alwaysIncludeSemantics: true,
            child: titleLayer,
          );

          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                titleLayer,
                if (subtitle != null)
                  Opacity(
                    opacity: (1 - cq / HeaderSpec.subtitleFadeEnd).clamp(0.0, 1.0),
                    alwaysIncludeSemantics: true,
                    child: Text(subtitle!, style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A search field that is a screen's sticky header (the Search tab): a bar
/// under the title at rest, and the same floating pill as every other header
/// once it reaches the top (margins, height, radius, fill, hairline, scrim and
/// "Show the pill" included). Floating header off: it scrolls away.
///
/// A sliver, inside a [HeaderPage] with `scrollAway: true`. [child] is the
/// bare field; it keeps its element (and focus) through the morph.
class HeaderSearchBar extends StatelessWidget {
  const HeaderSearchBar({required this.child, super.key});

  final Widget child;

  /// The field's height at rest.
  static const double restHeight = 48;

  @override
  Widget build(BuildContext context) {
    final _HeaderScope scope = _HeaderScope.maybeOf(context)!;
    return SliverPersistentHeader(
      pinned: scope.pins,
      delegate: _SearchBarDelegate(
        extent: scope.statusBar + HeaderSpec.top + restHeight + Space.md,
        pins: scope.pins,
        child: child,
      ),
    );
  }
}

class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  const _SearchBarDelegate({required this.extent, required this.pins, required this.child});

  final double extent;
  final bool pins;
  final Widget child;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      _SearchPill(under: pins ? shrinkOffset : 0, child: child);
  @override
  bool shouldRebuild(_SearchBarDelegate old) => extent != old.extent || pins != old.pins || child != old.child;
}

class _SearchPill extends StatefulWidget {
  const _SearchPill({required this.under, required this.child});

  /// How far the content has gone under the bar.
  final double under;
  final Widget child;

  @override
  State<_SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<_SearchPill> with SingleTickerProviderStateMixin {
  late final AnimationController _p = AnimationController.unbounded(vsync: this, value: _pill ? 1 : 0);
  late bool _pill = widget.under >= Motion.headerAt;

  @override
  void didUpdateWidget(_SearchPill old) {
    super.didUpdateWidget(old);
    // A gap between on and off, so it never flickers.
    final bool pill = _pill ? widget.under > 1 : widget.under >= Motion.headerAt;
    if (pill == _pill) return;
    _pill = pill;
    final double to = pill ? 1 : 0;
    switch (Motion.levelOf(context)) {
      case MotionLevel.expressive:
        _p.springTo(to, pill ? Motion.springDefault : Motion.springStandard);
      case MotionLevel.subtle:
        _p.animateTo(to, duration: Motion.fxFast, curve: Motion.curveEffects);
      case MotionLevel.off:
        _p.value = to;
    }
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final _HeaderScope scope = _HeaderScope.maybeOf(context)!;
    final double sb = scope.statusBar;
    final Widget bar = AnimatedBuilder(
      animation: _p,
      child: widget.child,
      builder: (BuildContext _, Widget? child) {
        final double p = _p.value;
        final double q = p.clamp(0.0, 1.0);
        final double side = Space.screen + (HeaderSpec.margin - Space.screen) * p;
        final double height = HeaderSearchBar.restHeight + (HeaderSpec.pillHeight - HeaderSearchBar.restHeight) * q;
        return Padding(
          padding: EdgeInsets.fromLTRB(side, sb + HeaderSpec.top, side, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.lerp(c.surfaceContainerHigh, c.surfaceContainer, q),
                borderRadius: BorderRadius.circular(height / 2),
              ),
              // In front, so the hairline takes no room from the field.
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                border: Border.all(color: c.outline.withValues(alpha: c.outline.a * q)),
              ),
              child: child,
            ),
          ),
        );
      },
    );
    return Stack(
      children: <Widget>[
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: sb + 16,
          child: IgnorePointer(
            child: FadeTransition(opacity: _ClampedAnimation(_p), child: HeaderScrim(statusBar: sb)),
          ),
        ),
        Positioned.fill(
          child: ValueListenableBuilder<bool>(
            valueListenable: scope.hidden,
            builder: (BuildContext _, bool hidden, Widget? child) => IgnorePointer(
              ignoring: hidden,
              child: ExcludeSemantics(excluding: hidden, child: child),
            ),
            child: _HideTransform(
              hide: scope.hide,
              shift: kAlwaysDismissedAnimation,
              away: null,
              awayMax: 0,
              level: scope.level,
              child: bar,
            ),
          ),
        ),
      ],
    );
  }
}

/// The status bar's fade, behind a pill.
class HeaderScrim extends StatelessWidget {
  const HeaderScrim({required this.statusBar, super.key});

  final double statusBar;

  @override
  Widget build(BuildContext context) {
    final Color surface = context.colors.surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: <double>[0, statusBar * 0.5 / (statusBar + 16), 1],
          colors: <Color>[
            surface.withValues(alpha: 0.94),
            surface.withValues(alpha: 0.94),
            surface.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _ClampedAnimation extends Animation<double> with AnimationWithParentMixin<double> {
  _ClampedAnimation(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.value.clamp(0.0, 1.0);
}

/// Deprecated: replaced by [HeaderPage]. Kept so the screens not yet
/// converted (Home, Shelves) keep building; delete once they have moved.
///
/// Reports whether a scroll view has moved past its first 24px, so the
/// header above it can collapse.
class CollapseOnScroll extends StatefulWidget {
  const CollapseOnScroll({required this.builder, super.key});

  final Widget Function(BuildContext context, bool collapsed) builder;

  @override
  State<CollapseOnScroll> createState() => _CollapseOnScrollState();
}

class _CollapseOnScrollState extends State<CollapseOnScroll> {
  bool _collapsed = false;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    final bool next = n.metrics.pixels > 24;
    if (next != _collapsed) setState(() => _collapsed = next);
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.builder(context, _collapsed));
}
