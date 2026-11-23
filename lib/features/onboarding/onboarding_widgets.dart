import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/onboarding_spec.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_button.dart';

/// Kuber's `OnboardingEntrance`: fade with a fractional slide, an optional
/// rise and scale. Subtle: no delay, half the distance. Off: a 90 ms fade.
/// One controller carries the delay as the head of its timeline, so no timer
/// is left pending.
class OnboardingEntrance extends StatefulWidget {
  const OnboardingEntrance({
    required this.child,
    this.delay = Duration.zero,
    this.beginOffset = OnboardingSpec.entranceSlide,
    this.duration = OnboardingSpec.entrance,
    this.rise = 0,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final Offset beginOffset;
  final Duration duration;
  final double rise;

  @override
  State<OnboardingEntrance> createState() => _OnboardingEntranceState();
}

class _OnboardingEntranceState extends State<OnboardingEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late Animation<double> _value;
  MotionLevel _level = MotionLevel.expressive;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _level = Motion.levelOf(context);
    final Duration delay = _level == MotionLevel.expressive ? widget.delay : Duration.zero;
    final Duration run = switch (_level) {
      MotionLevel.off => Motion.fxInstant,
      MotionLevel.subtle => Motion.fxDefault,
      MotionLevel.expressive => widget.duration,
    };
    final double total = (delay + run).inMilliseconds.toDouble();
    _controller.duration = delay + run;
    _value = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay.inMilliseconds / total, 1, curve: OnboardingSpec.entranceCurve),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double k = switch (_level) {
      MotionLevel.expressive => 1,
      MotionLevel.subtle => 0.5,
      MotionLevel.off => 0,
    };
    return FadeTransition(
      opacity: _value,
      child: AnimatedBuilder(
        animation: _value,
        child: widget.child,
        builder: (BuildContext context, Widget? child) => FractionalTranslation(
          translation: widget.beginOffset * k * (1 - _value.value),
          child: Transform.translate(offset: Offset(0, widget.rise * k * (1 - _value.value)), child: child),
        ),
      ),
    );
  }
}

/// Kuber's `OnboardingFit`: content is laid out 280 to 520 wide and scaled
/// down when it does not fit, so the largest OS font never overflows.
class OnboardingFit extends StatelessWidget {
  const OnboardingFit({required this.child, this.alignment = Alignment.topCenter, super.key});

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints box) {
      final double width = box.maxWidth - Space.xl * 2;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        child: Align(
          alignment: alignment,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: SizedBox(width: width.clamp(OnboardingSpec.fitMin, OnboardingSpec.fitMax), child: child),
          ),
        ),
      );
    },
  );
}

/// Dots: the active one is a 24 wide pill in `primary`.
class OnboardingDots extends StatelessWidget {
  const OnboardingDots({required this.current, required this.count, super.key});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final bool off = Motion.levelOf(context) == MotionLevel.off;
    return Semantics(
      label: 'Step ${current + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < count; i++)
            AnimatedContainer(
              duration: off ? Duration.zero : OnboardingSpec.dotDuration,
              curve: OnboardingSpec.dotCurve,
              width: i == current ? OnboardingSpec.dotActive : OnboardingSpec.dotInactive,
              height: OnboardingSpec.dotHeight,
              margin: const EdgeInsets.symmetric(horizontal: OnboardingSpec.dotMargin),
              decoration: BoxDecoration(
                color: i == current ? c.primary : c.outline,
                borderRadius: BorderRadius.circular(Radii.full),
              ),
            ),
        ],
      ),
    );
  }
}

/// Top right, 56 tall.
class OnboardingSkip extends StatelessWidget {
  const OnboardingSkip({required this.onSkip, super.key});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      child: SizedBox(
        height: OnboardingSpec.skipHeight,
        child: Align(
          alignment: Alignment.centerRight,
          widthFactor: 1,
          child: AppButton(label: 'Skip', type: AppButtonType.muted, compact: true, onPressed: onSkip),
        ),
      ),
    ),
  );
}

/// Kuber's bottom bar: dots, then Back (outlined, 112 wide) and a 56 tall
/// primary that swaps its label with a fade and a short slide.
class OnboardingNavBar extends StatelessWidget {
  const OnboardingNavBar({
    required this.page,
    required this.count,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onBack,
    super.key,
  });

  final int page;
  final int count;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final bool off = Motion.levelOf(context) == MotionLevel.off;
    final Duration resize = off ? Duration.zero : OnboardingSpec.barResize;
    final bool showBack = page > 0;
    return OnboardingEntrance(
      delay: OnboardingSpec.barEntranceDelay,
      duration: OnboardingSpec.barEntrance,
      beginOffset: Offset.zero,
      rise: OnboardingSpec.barRise,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              OnboardingDots(current: page, count: count),
              const SizedBox(height: Space.lg),
              Row(
                children: <Widget>[
                  AnimatedContainer(
                    duration: resize,
                    curve: OnboardingSpec.barCurve,
                    width: showBack ? OnboardingSpec.backWidth : 0,
                    height: OnboardingSpec.buttonHeight,
                    margin: EdgeInsets.only(right: showBack ? Space.md : 0),
                    child: ClipRect(
                      child: ExcludeSemantics(
                        excluding: !showBack,
                        child: OverflowBox(
                          maxWidth: OnboardingSpec.backWidth,
                          alignment: Alignment.centerLeft,
                          child: AppButton(
                            label: 'Back',
                            icon: Icons.arrow_back_rounded,
                            type: AppButtonType.outlined,
                            fullWidth: true,
                            padding: const EdgeInsets.symmetric(horizontal: Space.md),
                            onPressed: showBack ? onBack : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: OnboardingSpec.buttonHeight,
                      child: AnimatedSwitcher(
                        duration: off ? Motion.fxInstant : OnboardingSpec.labelSwap,
                        transitionBuilder: (Widget child, Animation<double> a) => FadeTransition(
                          opacity: a,
                          child: off
                              ? child
                              : SlideTransition(
                                  position: Tween<Offset>(begin: OnboardingSpec.labelSlide, end: Offset.zero).animate(a),
                                  child: child,
                                ),
                        ),
                        child: AppButton(
                          key: ValueKey<String>(primaryLabel),
                          label: primaryLabel,
                          fullWidth: true,
                          onPressed: onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
