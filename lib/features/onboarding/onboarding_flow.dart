import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/motion.dart';
import '../../core/router/router.dart';
import '../../core/theme/onboarding_spec.dart';
import '../../core/theme/tokens.dart';
import '../settings/settings_controller.dart';
import 'onboarding_intro_page.dart';
import 'onboarding_setup_page.dart';
import 'onboarding_widgets.dart';

/// First run: four intro pages and a setup page in one PageView. Skip jumps
/// to setup, which is not swipeable past and ends with Get started.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final PageController _pages = PageController();
  int _page = 0;

  static final int _setup = OnboardingIntroPage.count;
  static final int _count = _setup + 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (Motion.levelOf(context) == MotionLevel.off) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(page, duration: OnboardingSpec.pageChange, curve: OnboardingSpec.pageCurve);
    }
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).setOnboarded(value: true);
    if (!mounted) return;
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final bool setup = _page == _setup;
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _goTo(_page - 1);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              // Same height on every page, so nothing jumps when Skip leaves.
              SizedBox(
                height: OnboardingSpec.skipHeight,
                child: setup ? null : OnboardingSkip(onSkip: () => _pages.jumpToPage(_setup)),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: setup ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                  onPageChanged: (int p) => setState(() => _page = p),
                  children: <Widget>[
                    for (int i = 0; i < _setup; i++) OnboardingIntroPage(index: i),
                    const OnboardingSetupPage(),
                  ],
                ),
              ),
              OnboardingNavBar(
                page: _page,
                count: _count,
                primaryLabel: setup ? 'Get started' : 'Next',
                onPrimary: setup ? _finish : () => _goTo(_page + 1),
                onBack: () => _goTo(_page - 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
