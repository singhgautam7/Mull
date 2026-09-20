import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/family_card.dart';
import '../../shared/widgets/two_column_grid.dart';
import 'settings_controller.dart';

/// HANDOFF 3.14. Three screens, Skip present from the first. 01 what Mull
/// is, over stacked word cards; 02 pick a starting collection; 03 word of
/// the day time.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  int _step = 0;

  /// The card illustration animates in once, on the first load; coming back
  /// to page 01 from 02 shows it settled.
  bool _cardsIntroduced = false;
  bool _wotd = false;
  int _minutes = 8 * 60 + 30;

  Future<void> _finish({bool skipped = false}) async {
    final SettingsController ctl = ref.read(settingsProvider.notifier);
    // Asking to be notified asks the OS too; declined, the setting stays off.
    if (!skipped) await ctl.setWotd(enabled: _wotd, minutes: _minutes);
    await ctl.setOnboarded(value: true);
    if (!mounted) return;
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    // The 40px display line at the largest OS scale would break words on a
    // narrow phone; it grows to 1.5x and no further.
    final TextScaler display = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5);
    final AppSettings s = ref.watch(settingsProvider);
    final SettingsController ctl = ref.read(settingsProvider.notifier);
    final Tone tone = s.toneFor(MediaQuery.platformBrightnessOf(context));
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.fast),
                child: Text(
                  '0${_step + 1} / 03',
                  key: ValueKey<int>(_step),
                  style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant),
                ),
              ),
              // Centred while it fits; scrolls at a large font scale. The
              // buttons below stay put.
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints box) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const SizedBox(height: Space.xl),
                          // `page.push`: the next screen arrives from the
                          // right on the spring, the last one fades under it.
                          // The old page is out in the first 40% and the new
                          // one arrives over the last 70%, so two pages of
                          // text never sit half-visible on each other.
                          AnimatedSwitcher(
                            duration: Motion.of(context, Motion.containerTransform),
                            switchInCurve: Interval(0.3, 1, curve: Motion.curveOf(context, Motion.spring)),
                            switchOutCurve: Interval(0.6, 1, curve: Motion.curveOf(context, Motion.decelerate)),
                            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
                              alignment: Alignment.topCenter,
                              children: <Widget>[...previous, ?current],
                            ),
                            transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(
                              opacity: animation,
                              child: Motion.reduced(context)
                                  ? child
                                  : SlideTransition(
                                      position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation),
                                      child: child,
                                    ),
                            ),
                            child: KeyedSubtree(
                              key: ValueKey<int>(_step),
                              child: switch (_step) {
                0 => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // An illustration: it does not scale with text.
                    MediaQuery.withNoTextScaling(
                      child: _CardStack(
                        introduce: !_cardsIntroduced,
                        onIntroduced: () => _cardsIntroduced = true,
                      ),
                    ),
                    const SizedBox(height: Space.xxl),
                    Text('A dictionary, and somewhere to put it when you are idle.', style: MullType.display.copyWith(color: c.onSurface), textScaler: display),
                    const SizedBox(height: Space.lg),
                    Text('Look a word up in Search. Or open Mull and swipe through a few.', style: MullType.body.copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
                1 => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text('Pick a look.', style: MullType.display.copyWith(color: c.onSurface), textScaler: display),
                    const SizedBox(height: Space.sm),
                    Text('Light or dark, and a colour. Change it any time under More.', style: MullType.body.copyWith(color: c.onSurfaceVariant)),
                    const SizedBox(height: Space.xl),
                    SegmentedToggle<ThemeMode>(
                      options: const <(ThemeMode, String)>[(ThemeMode.light, 'Light'), (ThemeMode.dark, 'Dark'), (ThemeMode.system, 'System')],
                      selected: s.themeMode,
                      onChanged: ctl.setThemeMode,
                    ),
                    const SizedBox(height: Space.lg),
                    TwoColumnGrid(
                      children: <Widget>[
                        for (final ThemeFamily f in ThemeFamily.all)
                          FamilyCard(
                            family: f,
                            colors: f.colors(f.hasAmoled ? tone : (tone == Tone.amoled ? Tone.dark : tone)),
                            selected: !s.dynamicColor && s.familyId == f.id,
                            onTap: () async {
                              await ctl.setDynamicColor(value: false);
                              await ctl.setFamily(f.id);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
                _ => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('One word a day, if you want it.', style: MullType.display.copyWith(color: c.onSurface), textScaler: display),
                    const SizedBox(height: Space.sm),
                    Text('A single quiet notification. Nothing else will ever notify you.', style: MullType.body.copyWith(color: c.onSurfaceVariant)),
                    const SizedBox(height: Space.xl),
                    Row(
                      children: <Widget>[
                        Expanded(child: Text('Word of the day', style: MullType.titleMedium.copyWith(color: c.onSurface))),
                        Switch.adaptive(value: _wotd, onChanged: (bool v) => setState(() => _wotd = v)),
                      ],
                    ),
                    const SizedBox(height: Space.lg),
                    Text('ARRIVES AT', style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant)),
                    const SizedBox(height: Space.sm),
                    Text(clock(_minutes), style: MullType.display.copyWith(color: c.onSurface), textScaler: display),
                    const SizedBox(height: Space.md),
                    Wrap(
                      spacing: Space.sm,
                      children: <Widget>[
                        for (final (String l, int m) in const <(String, int)>[('Morning', 510), ('Lunch', 750), ('Evening', 1140)])
                          PillChip(label: l, selected: _minutes == m, onTap: () => setState(() => _minutes = m)),
                      ],
                    ),
                  ],
                ),
              },
                            ),
                          ),
                          const SizedBox(height: Space.xl),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                spacing: Space.md,
                children: <Widget>[
                  Expanded(
                    child: AppButton(
                      label: switch (_step) { 0 => 'Start', 1 => 'Continue', _ => 'Done' },
                      fullWidth: true,
                      onPressed: () => _step < 2 ? setState(() => _step++) : _finish(),
                    ),
                  ),
                  AppButton(
                    label: _step == 2 ? 'Not now' : 'Skip',
                    type: AppButtonType.outlined,
                    onPressed: () => _step == 2 ? _finish() : _finish(skipped: true),
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

/// A soft accent-tinted illustration of word cards. Not the app's own UI.
/// On first load the three cards arrive one after another: a rise of 16dp
/// and a fade on `cardBackground` (decelerate, the system brought them), 90 ms
/// apart, back to front. Calm, no overshoot. Under reduced motion they
/// cross-fade at 90 ms.
class _CardStack extends StatefulWidget {
  const _CardStack({required this.introduce, required this.onIntroduced});

  /// False once the entrance has played: the cards then sit still.
  final bool introduce;
  final VoidCallback onIntroduced;

  @override
  State<_CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<_CardStack> with SingleTickerProviderStateMixin {
  static const int _cards = 3;
  static const Duration _stagger = Duration(milliseconds: 90);

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: Motion.cardBackground + _stagger * (_cards - 1),
    value: widget.introduce ? 0 : 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.introduce || _intro.isAnimating || _intro.isCompleted) return;
    if (Motion.reduced(context)) _intro.duration = Motion.reducedFade;
    _intro.forward().whenComplete(widget.onIntroduced);
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  /// The slice of the controller card [i] animates over.
  Animation<double> _entrance(int i) {
    final double total = _intro.duration!.inMilliseconds.toDouble();
    final double from = Motion.reduced(context) ? 0 : (_stagger.inMilliseconds * i) / total;
    final double to = Motion.reduced(context) ? 1 : from + Motion.cardBackground.inMilliseconds / total;
    return CurvedAnimation(
      parent: _intro,
      curve: Interval(from, to, curve: Motion.reduced(context) ? Curves.linear : Motion.decelerate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final bool reduced = Motion.reduced(context);
    Widget card(int i, String word, String ipa, String def, double dx, double dy, double angle, {bool tint = false}) {
      final Animation<double> t = _entrance(i);
      return Positioned(
        left: dx,
        top: dy,
        child: AnimatedBuilder(
          animation: t,
          builder: (BuildContext context, Widget? child) => Opacity(
            opacity: t.value,
            child: Transform.translate(
              offset: Offset(0, reduced ? 0 : 16 * (1 - t.value)),
              child: child,
            ),
          ),
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(Space.lg),
              decoration: BoxDecoration(
                color: tint ? c.primaryContainer : c.surfaceContainer,
                borderRadius: Radii.cardR,
                border: Border.all(color: c.outline),
              ),
              // The cards behind sit in muted ink, so the tinted one reads as
              // the front of the stack.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(word, style: MullType.title.copyWith(color: tint ? c.onPrimaryContainer : c.onSurfaceVariant)),
                  Text(ipa, style: MullType.monoLabel.copyWith(color: tint ? c.onPrimaryContainer : c.onSurfaceMuted)),
                  const SizedBox(height: 6),
                  Text(def, style: MullType.bodySmall.copyWith(color: tint ? c.onPrimaryContainer : c.onSurfaceMuted)),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          card(0, 'sonder', '/ˈsɒndə/', 'The sense that every passer-by has a life as full as yours.', 40, 0, -0.06),
          card(1, 'petrichor', '/ˈpɛtrɪkɔː/', 'The smell of rain falling on dry earth.', 0, 50, 0.03),
          // The app's own word is the one in colour, and the last to land.
          card(2, 'mull', '/mʌl/', 'To think about something at length, without hurry.', 70, 100, -0.02, tint: true),
        ],
      ),
    );
  }
}
