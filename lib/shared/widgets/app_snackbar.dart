import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'app_icon_button.dart';

/// The toast message specification.
class SnackMessage {
  const SnackMessage({
    required this.text,
    this.actionLabel,
    this.onAction,
    this.isError = false,
    this.duration,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;
  final Duration? duration;

  Duration get effectiveDuration =>
      duration ??
      (actionLabel != null || isError
          ? const Duration(seconds: 5)
          : const Duration(seconds: 4));
}

/// A top-positioned, timed snackbar with a countdown progress indicator,
/// circular card radius, dismiss close button, and swipe-to-dismiss gestures.
abstract final class AppSnackbar {
  static OverlayEntry? _currentEntry;
  static _AppSnackBarController? _currentController;
  static Timer? _currentTimer;

  static void dismiss() {
    _currentTimer?.cancel();
    _currentTimer = null;

    final _AppSnackBarController? controller = _currentController;
    final OverlayEntry? entry = _currentEntry;
    _currentController = null;
    _currentEntry = null;

    if (controller != null && entry != null) {
      controller.animateOut().then((_) {
        if (entry.mounted) entry.remove();
      });
    } else {
      entry?.remove();
    }
  }

  static void show(BuildContext context, SnackMessage message) {
    dismiss();

    final OverlayState? overlay =
        Overlay.maybeOf(context, rootOverlay: true) ??
        Navigator.maybeOf(context, rootNavigator: true)?.overlay;
    if (overlay == null) return;

    final _AppSnackBarController controller = _AppSnackBarController();
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext _) => _TimedSnackBarWidget(
        controller: controller,
        message: message,
        onRequestClose: dismiss,
      ),
    );

    _currentController = controller;
    _currentEntry = entry;
    overlay.insert(entry);

    _currentTimer = Timer(message.effectiveDuration, dismiss);
  }

  static void info(BuildContext context, String text) =>
      show(context, SnackMessage(text: text));

  static void error(BuildContext context, String text) =>
      show(context, SnackMessage(text: text, isError: true));

  static void undo(BuildContext context, String text, VoidCallback onUndo) =>
      show(
        context,
        SnackMessage(
          text: text,
          actionLabel: 'Undo',
          onAction: onUndo,
        ),
      );
}

class _AppSnackBarController {
  _TimedSnackBarWidgetState? _state;

  void _attach(_TimedSnackBarWidgetState state) => _state = state;

  Future<void> animateOut() async {
    final _TimedSnackBarWidgetState? state = _state;
    if (state == null) return;
    await state._animateOut();
  }
}

class _TimedSnackBarWidget extends StatefulWidget {
  const _TimedSnackBarWidget({
    required this.controller,
    required this.message,
    required this.onRequestClose,
  });

  final _AppSnackBarController controller;
  final SnackMessage message;
  final VoidCallback onRequestClose;

  @override
  State<_TimedSnackBarWidget> createState() => _TimedSnackBarWidgetState();
}

class _TimedSnackBarWidgetState extends State<_TimedSnackBarWidget>
    with TickerProviderStateMixin {
  // Enter / exit position: 0 hidden, 1 shown (unbounded: the spring may pass 1).
  late final AnimationController _pos = AnimationController.unbounded(vsync: this);
  late final AnimationController _fade = AnimationController(vsync: this);
  late final AnimationController _progressCtrl;
  late MotionLevel _level;
  bool _started = false;
  bool _actionFired = false;

  Offset _dragOffset = Offset.zero;

  static const double _kSwipeDistanceThreshold = 80.0;
  static const double _kSwipeVelocityThreshold = 600.0;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: widget.message.effectiveDuration,
    );
    widget.controller._attach(this);
    _progressCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _level = Motion.levelOf(context);
    if (_started) return;
    _started = true;
    // Enter: slide on springDefault (Subtle: springSubtle over 4 dp; Off: no
    // slide) and fade on curveEffects.
    _fade.animateTo(
      1,
      duration: _level == MotionLevel.off ? Motion.fxInstant : Motion.snackEnter,
      curve: Motion.curveEffects,
    );
    if (_level == MotionLevel.off) {
      _pos.value = 1;
    } else {
      _pos.springTo(1, Motion.spatial(_level, Motion.springDefault));
    }
  }

  Future<void> _animateOut() async {
    if (!mounted) return;
    _progressCtrl.stop();
    final Duration d = _level == MotionLevel.off ? Motion.fxInstant : Motion.snackExit;
    if (_level != MotionLevel.off) _pos.animateTo(0, duration: d, curve: Motion.curveEffects);
    await _fade.animateTo(0, duration: d, curve: Motion.curveEffects);
  }

  @override
  void dispose() {
    _pos.dispose();
    _fade.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  void _handleAction(VoidCallback? cb) {
    if (_actionFired) return;
    _actionFired = true;
    widget.onRequestClose();
    cb?.call();
  }

  void _onDragStart(DragStartDetails _) {
    _progressCtrl.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      final double dx = _dragOffset.dx + details.delta.dx;
      final double dy = (_dragOffset.dy + details.delta.dy).clamp(-200.0, 0.0);
      _dragOffset = Offset(dx, dy);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final Offset v = details.velocity.pixelsPerSecond;
    final bool distanceMet =
        _dragOffset.dx.abs() >= _kSwipeDistanceThreshold ||
        _dragOffset.dy <= -_kSwipeDistanceThreshold;
    final bool velocityMet =
        v.dx.abs() >= _kSwipeVelocityThreshold ||
        v.dy <= -_kSwipeVelocityThreshold;

    if (distanceMet || velocityMet) {
      widget.onRequestClose();
      return;
    }

    setState(() => _dragOffset = Offset.zero);
    _progressCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final SnackMessage m = widget.message;
    // Kuber: an error is its container, anything else the raised surface.
    final Color bg = m.isError ? c.dangerContainer : c.surfaceContainerHigh;
    final Color fg = m.isError ? c.onDangerContainer : c.onSurface;
    final Color accent = m.isError ? c.danger : c.primary;
    final double topPadding = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: topPadding + Space.sm,
      left: Space.screen,
      right: Space.screen,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_pos, _fade]),
        builder: (BuildContext context, Widget? child) {
          final double p = _pos.value;
          final double dragDistance = _dragOffset.distance;
          final double dragFade = (dragDistance / 200).clamp(0.0, 0.5);
          Widget w = Opacity(
            opacity: (_fade.value * (1 - dragFade)).clamp(0.0, 1.0),
            child: child,
          );
          w = switch (_level) {
            MotionLevel.expressive => FractionalTranslation(translation: Offset(0, p - 1), child: w),
            MotionLevel.subtle => Transform.translate(offset: Offset(0, -4 * (1 - p)), child: w),
            MotionLevel.off => w,
          };
          return Transform.translate(offset: _dragOffset, child: w);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          // Kuber's body: an icon in the accent, the message, the action, close,
          // and the timer along the bottom. The shape clips everything in it.
          child: Semantics(
            liveRegion: true,
            child: Material(
              color: bg,
              shape: RoundedRectangleBorder(
                borderRadius: Radii.cardR,
                side: BorderSide(color: c.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.xs, Space.xs),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            m.isError ? Icons.error_rounded : Icons.check_circle_rounded,
                            color: accent,
                            size: 20,
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(m.text, style: MullType.label.copyWith(color: fg)),
                            ),
                          ),
                          if (m.actionLabel != null)
                            Semantics(
                              button: true,
                              label: m.actionLabel,
                              excludeSemantics: true,
                              child: Pressable(
                                kind: PressKind.chip,
                                morphCorners: false,
                                onTap: () => _handleAction(m.onAction),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: Space.md),
                                    child: Align(
                                      widthFactor: 1,
                                      heightFactor: 1,
                                      child: Text(
                                        m.actionLabel!.toUpperCase(),
                                        style: MullType.label.copyWith(color: accent, letterSpacing: 0.24).weight(700),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          AppIconButton(
                            icon: Icons.close_rounded,
                            filled: false,
                            tint: fg,
                            semanticLabel: 'Dismiss',
                            onPressed: widget.onRequestClose,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 10),
                    child: SizedBox(
                      height: 4,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _TimerPainter(_progressCtrl, indicator: accent, track: fg.withValues(alpha: 0.16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kuber's snackbar timer: a flat 4dp indicator and track with a 4dp gap and
/// round ends, running down.
class _TimerPainter extends CustomPainter {
  _TimerPainter(this.elapsed, {required this.indicator, required this.track}) : super(repaint: elapsed);

  final Animation<double> elapsed;
  final Color indicator;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final double h = size.height;
    final Radius r = Radius.circular(h / 2);
    final double v = (1 - elapsed.value).clamp(0.0, 1.0);
    final double w = v * size.width - (v < 1 ? 2 : 0);
    void bar(double from, double to, Color color) {
      if (to > from) canvas.drawRRect(RRect.fromLTRBR(from, 0, to, h, r), Paint()..color = color);
    }

    bar(0, w, indicator);
    bar(w > 0 ? w + 4 : 0, size.width, track);
  }

  @override
  bool shouldRepaint(_TimerPainter old) => old.indicator != indicator || old.track != track || old.elapsed != elapsed;
}
