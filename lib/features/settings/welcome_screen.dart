import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/chips.dart';
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
  String? _start;
  bool _wotd = false;
  int _minutes = 8 * 60 + 30;

  Future<void> _finish({bool skipped = false}) async {
    final SettingsController ctl = ref.read(settingsProvider.notifier);
    if (!skipped) await ctl.setWotd(enabled: _wotd, minutes: _minutes);
    await ctl.setOnboarded(value: true);
    if (!mounted) return;
    context.go(_start == null || skipped ? Routes.home : Routes.scoped(_start!));
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    // The 40px display line at the largest OS scale would break words on a
    // narrow phone; it grows to 1.5x and no further.
    final TextScaler display = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5);
    final List<Collection> collections = ref.watch(collectionsProvider).where((Collection x) => x.kind == 'band').toList();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('0${_step + 1} / 03', style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant)),
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
                          switch (_step) {
                0 => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // An illustration: it does not scale with text.
                    MediaQuery.withNoTextScaling(child: const _CardStack()),
                    const SizedBox(height: Space.xxl),
                    Text('A dictionary, and somewhere to put it when you are idle.', style: MullType.display.copyWith(color: c.onSurface), textScaler: display),
                    const SizedBox(height: Space.lg),
                    Text('Look a word up in Search. Or open Mull and swipe through a few.', style: MullType.body.copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
                1 => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text('Where would you like to start?', style: MullType.display.copyWith(color: c.onSurface), textScaler: display),
                    const SizedBox(height: Space.sm),
                    Text('You can change this at any time.', style: MullType.body.copyWith(color: c.onSurfaceVariant)),
                    const SizedBox(height: Space.xl),
                    for (final Collection col in collections)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.row),
                        child: InkWell(
                          onTap: () => setState(() => _start = col.slug),
                          borderRadius: Radii.cardR,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _start == col.slug ? c.primaryContainer : c.surfaceContainer,
                              borderRadius: Radii.cardR,
                              border: Border.all(color: _start == col.slug ? c.primary : c.outline),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(col.title, style: MullType.titleMedium.copyWith(color: _start == col.slug ? c.onPrimaryContainer : c.onSurface)),
                                Text('${col.description} ${grouped(col.wordCount)} of them.', style: MullType.bodySmall.copyWith(color: _start == col.slug ? c.onPrimaryContainer : c.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ),
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
class _CardStack extends StatelessWidget {
  const _CardStack();

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    Widget card(String word, String ipa, String def, double dx, double dy, double angle, {bool tint = false}) => Positioned(
      left: dx,
      top: dy,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(word, style: MullType.title.copyWith(color: tint ? c.onPrimaryContainer : c.onSurface)),
              Text(ipa, style: MullType.monoLabel.copyWith(color: tint ? c.onPrimaryContainer : c.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text(def, style: MullType.bodySmall.copyWith(color: tint ? c.onPrimaryContainer : c.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
    return SizedBox(
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          card('sonder', '/ˈsɒndə/', 'The sense that every passer-by has a life as full as yours.', 40, 0, -0.06),
          card('petrichor', '/ˈpɛtrɪkɔː/', 'The smell of rain falling on dry earth.', 0, 50, 0.03, tint: true),
          card('mull', '/mʌl/', 'To think about something at length, without hurry.', 70, 100, -0.02),
        ],
      ),
    );
  }
}
