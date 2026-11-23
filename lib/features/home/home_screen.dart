import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/motion/motion.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_menu.dart';
import '../../shared/widgets/app_tooltip.dart';
import '../../shared/widgets/dashed_border.dart';
import '../../shared/widgets/progress.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/two_column_grid.dart';
import '../collections/collection_cards.dart';
import '../collections/shelf_edit_screen.dart';
import '../dictionary/add_to_list_sheet.dart';
import '../dictionary/word_sheet.dart';

/// The word of the day's first example, read once per word and off the
/// build that shows it (a provider computes on first watch, so the read sits
/// behind an await).
final _wotdExampleProvider = FutureProvider.autoDispose.family<String?, String>((Ref ref, String wordKey) async {
  final DictionaryDb dict = ref.watch(dictProvider);
  await Future<void>.value();
  return dict.examples(wordKey).firstOrNull;
});

/// The words behind "Recently searched", resolved once per change of the
/// recent keys; the chips hold their last list while a new one resolves.
final FutureProvider<List<DictionaryWord>> _recentWordsProvider = FutureProvider.autoDispose<List<DictionaryWord>>((
  Ref ref,
) async {
  final List<String> keys = ref.watch(recentLookupsProvider).value ?? const <String>[];
  final DictionaryDb dict = ref.watch(dictProvider);
  await Future<void>.value();
  return <DictionaryWord>[
    for (final String k in keys.take(10))
      if (dict.byKey(k) case final DictionaryWord w) w,
  ];
});

/// HANDOFF 3.1. Greeting, word of the day, Continue, Recently looked up,
/// Collections (a shortlist: last opened, in progress, then built-ins), Your
/// lists. Both collection sections read the one unified query, so a list
/// made here is here. On scroll the greeting collapses to "Home".
///
/// The screen watches nothing but the shelf count. Each section is its own
/// consumer and each progress number its own select, so a seen write (every
/// swipe on the Mull tab, while Home sits offstage) rebuilds only the ring
/// whose number moved, never the screen.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Home lists at most this many of the user's shelves; "See all" opens
  /// the Shelves tab, which lists every one lazily.
  static const int yourShelvesShown = 6;

  static String greeting() {
    final int h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int shelfCount = ref.watch(collectionsProvider.select((List<Collection> l) => l.length));
    Widget seeAll(String label) => SectionHeaderAction(label: label, onTap: () => context.push(Routes.collections));

    return Scaffold(
      body: HeaderPage(
        header: AppHeader(
          title: greeting(),
          pillTitle: 'Home',
          actions: <Widget>[
            Builder(
              builder: (BuildContext anchor) => AppIconButton(
                icon: Icons.more_horiz_rounded,
                semanticLabel: 'More',
                onPressed: () async {
                  final String? a = await showAppMenu<String>(
                    context: context,
                    anchorContext: anchor,
                    entries: const <AppMenuEntry<String>>[
                      AppMenuEntry<String>(value: 'collections', label: 'All shelves', icon: Icons.grid_view_rounded),
                      AppMenuEntry<String>(value: 'stats', label: 'Stats', icon: Icons.bar_chart_rounded),
                    ],
                  );
                  if (!context.mounted || a == null) return;
                  unawaited(context.push<void>(a == 'collections' ? Routes.collections : Routes.stats));
                },
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: Space.bottomSafe),
          children: <Widget>[
            HeaderPage.gap(),
            const _WotdSection(),
            const _ContinueSection(),
            const SizedBox(height: Space.section),
            const SectionHeader(label: 'Recently searched'),
            const _RecentSection(),
            const SizedBox(height: Space.section),
            SectionHeader(label: 'Shelves', trailing: seeAll('See all $shelfCount')),
            const _ShelfGrid(),
            const SizedBox(height: Space.section),
            SectionHeader(label: 'My Shelf', trailing: seeAll('See all')),
            const _YourShelves(),
          ],
        ),
      ),
    );
  }
}

/// The word of the day comes off the worker; until it lands the card's
/// frame and label hold the top of the screen and the rest fades in, so
/// nothing below jumps by a whole card.
class _WotdSection extends ConsumerWidget {
  const _WotdSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DictionaryWord?> wotd = ref.watch(wordOfTheDayProvider);
    final DictionaryWord? word = wotd.value;
    if (wotd.hasValue && word == null) return const SizedBox.shrink();
    return _WordOfTheDay(
      word: word,
      example: word == null ? null : ref.watch(_wotdExampleProvider(word.wordKey)).value,
    );
  }
}

class _ContinueSection extends ConsumerWidget {
  const _ContinueSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? slug = ref.watch(continueSlugProvider);
    final Collection? cont = slug == null
        ? null
        : ref.watch(collectionBySlugProvider.select((Map<String, Collection> m) => m[slug]));
    if (cont == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: Space.section),
        const SectionHeader(label: 'Continue'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.screen),
          child: _Continue(collection: cont, progress: ref.watch(progressOfProvider(cont.slug))),
        ),
      ],
    );
  }
}

class _RecentSection extends ConsumerWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    final bool empty = ref.watch(recentLookupsProvider.select((AsyncValue<List<String>> v) => (v.value ?? const <String>[]).isEmpty));
    if (empty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
        child: CustomPaint(
          foregroundPainter: DashedBorderPainter(c.outline, radius: Radii.card),
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Nothing looked up yet', style: MullType.titleMedium.copyWith(color: c.onSurface)),
                const SizedBox(height: 4),
                Text(
                  'Words you search land here, so the ones you met in the wild stay in reach. Tap + on any of them to keep it.',
                  style: MullType.note.copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final List<DictionaryWord> recentWords = ref.watch(_recentWordsProvider).value ?? const <DictionaryWord>[];
    // A row, not a fixed-height list: the chips are as tall as their text.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
      child: Row(
        spacing: Space.sm,
        children: <Widget>[for (final DictionaryWord w in recentWords) _RecentChip(word: w)],
      ),
    );
  }
}

class _ShelfGrid extends ConsumerWidget {
  const _ShelfGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Collection> grid = ref.watch(homeCollectionsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
      child: TwoColumnGrid(
        children: <Widget>[
          for (final Collection x in grid)
            Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? _) => TopicCard(
                collection: x,
                progress: ref.watch(progressOfProvider(x.slug)),
                compact: true,
                onTap: () => context.push(Routes.collection(x.slug)),
              ),
            ),
          _NewListCard(onTap: () => openShelfEditor(context)),
        ],
      ),
    );
  }
}

class _YourShelves extends ConsumerWidget {
  const _YourShelves();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Collection> yours = ref
        .watch(collectionsProvider)
        .where((Collection x) => x.isUsers)
        .take(HomeScreen.yourShelvesShown)
        .toList();
    return YourLists(collections: yours, onOpen: (Collection x) => context.push(Routes.collection(x.slug)));
  }
}

/// The most confident element on the screen: `surfaceContainer`, 20dp
/// radius, section label in `accent`, headword 42, IPA, POS, short
/// definition, example.
class _WordOfTheDay extends StatelessWidget {
  const _WordOfTheDay({required this.word, required this.example});

  /// Null for the frames before the worker answers: the frame and the label
  /// show, the body fades in when it lands.
  final DictionaryWord? word;
  final String? example;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final DictionaryWord? word = this.word;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
      child: Pressable(
        onTap: word == null ? null : () => showWordSheet(context, wordKey: word.wordKey),
        child: Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: Radii.cardR,
            border: Border.all(color: c.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionHeader(label: 'Word of the day', accent: true, inset: false),
              AnimatedSize(
                duration: Motion.of(context, Motion.reflow),
                curve: Motion.curveOf(context, Motion.decelerate),
                alignment: Alignment.topLeft,
                child: word == null
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                    const SizedBox(height: Space.sm),
                    // 42 at most, stepping down by grapheme count like the card,
                    // and never scaled: a headword is never broken mid-word.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        word.headword,
                        style: MullType.headwordAt(math.max(1, MullType.headwordStep(word.headword)))
                            .copyWith(fontSize: MullType.headwordStep(word.headword) <= 1 ? 42 : null, color: c.onSurface),
                        textScaler: TextScaler.noScaling,
                        softWrap: false,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: Space.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        if (word.ipa != null)
                          Text(word.ipa!, style: MullType.monoTabular.copyWith(color: c.onSurfaceVariant)),
                        Text(
                          posLabel(word.pos),
                          style: MullType.label.copyWith(fontStyle: FontStyle.italic, color: c.onSurfaceMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                    Text(word.definitionShort, style: MullType.body.copyWith(fontSize: 16, color: c.onSurface)),
                    if (example != null) ...<Widget>[
                      const SizedBox(height: Space.sm),
                      Text(
                        example!,
                        style: MullType.note.copyWith(color: c.onSurfaceVariant, fontStyle: FontStyle.italic),
                      ),
                    ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Progress ring, title, "{seen} / {total} seen", a small launcher.
class _Continue extends StatelessWidget {
  const _Continue({required this.collection, required this.progress});

  final Collection collection;
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Pressable(
      onTap: () => context.go(Routes.scoped(collection.slug)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: Radii.cardR,
          border: Border.all(color: c.outline),
        ),
        child: Row(
          spacing: 14,
          children: <Widget>[
            ProgressRing(fraction: progress.fraction),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(collection.title, style: MullType.titleMedium.copyWith(color: c.onSurface)),
                  const SizedBox(height: 2),
                  Text(
                    '${grouped(progress.seen)} / ${grouped(progress.total)} seen',
                    style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
              child: Icon(Icons.arrow_forward_rounded, size: 18, color: c.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A recent chip with a 26dp + affordance that adds it to "From my reading".
class _RecentChip extends ConsumerWidget {
  const _RecentChip({required this.word});

  final DictionaryWord word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    return Material(
      color: c.surfaceContainer,
      shape: StadiumBorder(side: BorderSide(color: c.outline)),
      clipBehavior: Clip.antiAlias,
      child: Pressable(
        kind: PressKind.chip,
        morphCorners: false,
        onTap: () => showWordSheet(context, wordKey: word.wordKey, fromSearch: true),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: Space.sm,
            children: <Widget>[
              // Bounded, or the one-line definition would never ellipsise
              // inside a horizontal scroll. Reduced by 15% (220 * 0.85 = 187).
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 187),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(word.headword, style: MullType.titleSmall.copyWith(color: c.onSurface)),
                    Text(
                      '${posLabel(word.pos)} · ${word.definitionShort}',
                      style: MullType.monoLabel.copyWith(fontSize: 10, color: c.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AppTooltip(
                message: 'Add to shelf',
                child: Semantics(
                  button: true,
                  label: 'Add ${word.headword} to shelf',
                  child: Pressable(
                    kind: PressKind.iconButton,
                    onTap: () => showAddToListSheet(context, wordKey: word.wordKey, headword: word.headword),
                    // The glyph stays 26dp; the target is 48.
                    child: SizedBox(
                      width: IconSpec.tapTarget,
                      height: IconSpec.tapTarget,
                      child: Center(
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(color: c.surfaceContainerHigh, shape: BoxShape.circle),
                          child: Icon(Icons.add_rounded, size: 16, color: c.accent),
                        ),
                      ),
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

class _NewListCard extends StatelessWidget {
  const _NewListCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(c.outline, radius: Radii.card),
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.add_rounded, size: 20, color: c.accent),
              const SizedBox(height: 4),
              Text('New shelf', style: MullType.titleMedium.copyWith(color: c.accent)),
              Text('Your own words', style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
