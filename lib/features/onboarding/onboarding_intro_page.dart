import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/onboarding_spec.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/progress.dart';
import 'onboarding_widgets.dart';

/// One feature per page: an illustration built from Mull's own pieces, a
/// headline and a line or two.
class OnboardingIntroPage extends StatelessWidget {
  const OnboardingIntroPage({required this.index, super.key});

  static const List<(String, String)> copy = <(String, String)>[
    ('Define words anywhere', 'Select a word in any app, then tap Define in Mull. The meaning shows up right there.'),
    ('Learn with ready-made shelves', 'Pick a shelf of everyday words, old favourites or a topic you like. Learn at your own pace.'),
    ('Make shelves of your own', 'Save the words you meet while reading. Keep them on a shelf and add a note to each.'),
    ('Swipe through words', 'Open the Mull tab to see one word at a time. Then take a quiz on any shelf.'),
  ];

  static int get count => copy.length;

  final int index;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final (String title, String body) = copy[index];
    return OnboardingFit(
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          OnboardingEntrance(
            delay: OnboardingSpec.delayArt,
            child: Center(
              child: SizedBox(
                width: OnboardingSpec.artWidth,
                height: OnboardingSpec.artHeight,
                // An illustration: it does not scale with text.
                child: MediaQuery.withNoTextScaling(
                  child: ExcludeSemantics(
                    child: switch (index) {
                      0 => const _DefineArt(),
                      1 => const _ShelvesArt(),
                      2 => const _OwnShelvesArt(),
                      _ => const _MullArt(),
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.xxl),
          OnboardingEntrance(
            delay: OnboardingSpec.delayTitle,
            child: Text(title, style: MullType.display.copyWith(color: c.onSurface)),
          ),
          const SizedBox(height: Space.md),
          OnboardingEntrance(
            delay: OnboardingSpec.delayBody,
            child: Text(body, style: MullType.body.copyWith(color: c.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

/// A card on the page ground, as the app draws one.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.radius = Radii.cardR, this.padding = Space.lg});

  final Widget child;
  final BorderRadius radius;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: radius,
        border: Border.all(color: c.outline),
      ),
      child: child,
    );
  }
}

class _DefineArt extends StatelessWidget {
  const _DefineArt();

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _Panel(
          child: Text.rich(
            TextSpan(
              style: MullType.body.copyWith(color: c.onSurfaceVariant),
              children: <InlineSpan>[
                const TextSpan(text: 'She spoke of a '),
                TextSpan(
                  text: 'wistful',
                  style: TextStyle(backgroundColor: c.primaryContainer, color: c.onPrimaryContainer),
                ),
                const TextSpan(text: ' summer, long ago.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
          decoration: BoxDecoration(color: c.inverseSurface, borderRadius: BorderRadius.circular(Radii.full)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: Space.sm,
            children: <Widget>[
              Icon(Icons.menu_book_rounded, size: 18, color: c.onInverseSurface),
              Text('Define in Mull', style: MullType.titleSmall.copyWith(color: c.onInverseSurface)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShelfRow extends StatelessWidget {
  const _ShelfRow({required this.title, required this.note, required this.icon, required this.disc, required this.onDisc});

  final String title;
  final String note;
  final IconData icon;
  final Color disc;
  final Color onDisc;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return _Panel(
      radius: Radii.mediumR,
      padding: Space.md,
      child: Row(
        spacing: Space.md,
        children: <Widget>[
          Container(
            width: OnboardingSpec.disc,
            height: OnboardingSpec.disc,
            decoration: BoxDecoration(color: disc, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: onDisc),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: MullType.titleSmall.copyWith(color: c.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(note, style: MullType.bodySmall.copyWith(color: c.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelvesArt extends StatelessWidget {
  const _ShelvesArt();

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: Space.sm,
      children: <Widget>[
        _ShelfRow(title: 'Everyday words', note: 'Words you will use', icon: Icons.wb_sunny_rounded, disc: c.primaryContainer, onDisc: c.onPrimaryContainer),
        _ShelfRow(title: 'Old and worth reviving', note: 'Gentle, forgotten words', icon: Icons.history_edu_rounded, disc: c.tagColor(3), onDisc: c.onPrimary),
        _ShelfRow(title: 'Food and cooking', note: 'A topic shelf', icon: Icons.restaurant_rounded, disc: c.tagColor(4), onDisc: c.onPrimary),
      ],
    );
  }
}

class _OwnShelvesArt extends StatelessWidget {
  const _OwnShelvesArt();

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: Space.sm,
      children: <Widget>[
        _ShelfRow(title: 'From my reading', note: '12 words', icon: Icons.bookmark_rounded, disc: c.tagColor(1), onDisc: c.onPrimary),
        _ShelfRow(title: 'Words for work', note: '5 words', icon: Icons.work_rounded, disc: c.tagColor(5), onDisc: c.onPrimary),
        IgnorePointer(
          child: AppButton(label: 'New shelf', icon: Icons.add_rounded, type: AppButtonType.dotted, fullWidth: true, onPressed: () {}),
        ),
      ],
    );
  }
}

class _MullArt extends StatelessWidget {
  const _MullArt();

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: Space.lg,
      children: <Widget>[
        Expanded(
          child: _Panel(
            radius: BorderRadius.circular(Radii.wordCard),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.sm,
              children: <Widget>[
                Text('abate', style: MullType.headwordS.copyWith(color: c.onSurface)),
                const BandChip('Everyday'),
                Text('To become less strong.', style: MullType.note.copyWith(color: c.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          spacing: Space.sm,
          children: <Widget>[
            const ProgressRing(fraction: 0.7, size: 64),
            Text('Quiz', style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}
