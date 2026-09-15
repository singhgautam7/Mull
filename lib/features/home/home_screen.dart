import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/user_db.dart';
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
import '../../shared/widgets/dashed_border.dart';
import '../../shared/widgets/progress.dart';
import '../../shared/widgets/section_header.dart';
import '../collections/collection_cards.dart';
import '../dictionary/word_sheet.dart';
import '../lists/create_list_sheet.dart';
import '../lists/lists_screen.dart';

/// HANDOFF 3.1. Greeting, word of the day, Continue, Recently looked up,
/// Collections, Your lists. On scroll the greeting collapses to "Home".
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static String greeting() {
    final int h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    final DictionaryWord? wotd = ref.watch(wordOfTheDayProvider);
    final List<DictionaryCollection> collections = ref.watch(collectionsProvider);
    final Map<String, Progress> progress = ref.watch(collectionProgressProvider);
    final List<String> recent = ref.watch(recentLookupsProvider).value ?? const <String>[];
    final List<WordList> lists = ref.watch(listsProvider).value ?? const <WordList>[];
    final Map<int, int> counts = ref.watch(listCountsProvider).value ?? const <int, int>{};
    final int bookmarks = ref.watch(bookmarksProvider).value?.length ?? 0;
    final DictionaryDb dict = ref.watch(dictProvider);

    // Continue: the most recently started, unfinished collection.
    final Map<String, SeenWord> seen = ref.watch(seenMapProvider).value ?? const <String, SeenWord>{};
    final Map<String, List<String>> keys = ref.watch(collectionKeysProvider);
    DictionaryCollection? cont;
    DateTime? latest;
    for (final DictionaryCollection col in collections) {
      final Progress p = progress[col.slug] ?? const Progress(0, 0);
      if (!p.started || p.complete) continue;
      for (final String k in keys[col.slug] ?? const <String>[]) {
        final DateTime? at = seen[k]?.lastSeenAt;
        if (at != null && (latest == null || at.isAfter(latest))) {
          latest = at;
          cont = col;
        }
      }
    }
    final List<DictionaryCollection> grid = collections.where((DictionaryCollection x) => x.kind != 'band').take(5).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CollapseOnScroll(
          builder: (BuildContext context, bool collapsed) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppHeader(
                title: collapsed ? 'Home' : greeting(),
                collapsed: collapsed,
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
                            AppMenuEntry<String>(value: 'collections', label: 'All collections', icon: Icons.grid_view_rounded),
                            AppMenuEntry<String>(value: 'lists', label: 'Lists', icon: Icons.list_alt_rounded),
                            AppMenuEntry<String>(value: 'stats', label: 'Stats', icon: Icons.bar_chart_rounded),
                          ],
                        );
                        if (!context.mounted || a == null) return;
                        unawaited(context.push<void>(switch (a) { 'collections' => Routes.collections, 'lists' => Routes.lists, _ => Routes.stats }));
                      },
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: Space.bottomSafe),
                  children: <Widget>[
                    if (wotd != null) _WordOfTheDay(word: wotd, example: dict.examples(wotd.wordKey).firstOrNull),
                    if (cont != null) ...<Widget>[
                      const SizedBox(height: Space.section),
                      const SectionHeader(label: 'Continue'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                        child: _Continue(collection: cont, progress: progress[cont.slug]!),
                      ),
                    ],
                    const SizedBox(height: Space.section),
                    const SectionHeader(label: 'Recently looked up'),
                    if (recent.isEmpty)
                      Padding(
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
                      )
                    else
                      SizedBox(
                        height: 52,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                          itemCount: recent.length,
                          separatorBuilder: (BuildContext _, int _) => const SizedBox(width: Space.sm),
                          itemBuilder: (BuildContext context, int i) {
                            final DictionaryWord? w = dict.byKey(recent[i]);
                            if (w == null) return const SizedBox.shrink();
                            return _RecentChip(word: w);
                          },
                        ),
                      ),
                    const SizedBox(height: Space.section),
                    SectionHeader(
                      label: 'Collections',
                      trailing: InkWell(
                        onTap: () => context.push(Routes.collections),
                        child: Text('See all ${collections.length}', style: MullType.monoLabel.copyWith(color: c.accent)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: Space.row,
                          crossAxisSpacing: Space.row,
                          mainAxisExtent: 96,
                        ),
                        itemCount: grid.length + 1,
                        itemBuilder: (BuildContext context, int i) {
                          if (i == grid.length) return _NewListCard(onTap: () => showCreateListSheet(context));
                          return TopicCard(
                            collection: grid[i],
                            progress: progress[grid[i].slug] ?? const Progress(0, 0),
                            compact: true,
                            onTap: () => context.push(Routes.collection(grid[i].slug)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: Space.section),
                    SectionHeader(
                      label: 'Your lists',
                      trailing: InkWell(
                        onTap: () => context.push(Routes.lists),
                        child: Text('Lists', style: MullType.monoLabel.copyWith(color: c.accent)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                      child: Container(
                        decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: Radii.cardR),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: <Widget>[
                            ListRow(title: 'Bookmarks', subtitle: plural(bookmarks, 'word'), swatch: c.primary, onTap: () => context.push(Routes.lists)),
                            for (final WordList l in lists) ...<Widget>[
                              Divider(color: c.divider, height: 1),
                              ListRow(title: l.name, subtitle: plural(counts[l.id] ?? 0, 'word'), swatch: c.tagColor(l.color), onTap: () => context.push(Routes.list(l.id))),
                            ],
                          ],
                        ),
                      ),
                    ),
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

/// The most confident element on the screen: `surfaceContainer`, 20dp
/// radius, section label in `accent`, headword 42, IPA, POS, short
/// definition, example.
class _WordOfTheDay extends StatelessWidget {
  const _WordOfTheDay({required this.word, required this.example});

  final DictionaryWord word;
  final String? example;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
      child: InkWell(
        onTap: () => showWordSheet(context, wordKey: word.wordKey),
        borderRadius: Radii.cardR,
        child: Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: Radii.cardR, border: Border.all(color: c.outline)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionHeader(label: 'Word of the day', accent: true, inset: false),
              const SizedBox(height: Space.sm),
              Text(word.headword, style: MullType.headwordL.copyWith(fontSize: 42, color: c.onSurface)),
              const SizedBox(height: 4),
              Row(
                spacing: Space.sm,
                children: <Widget>[
                  if (word.ipa != null) Text(word.ipa!, style: MullType.monoTabular.copyWith(color: c.onSurfaceVariant)),
                  Text(posLabel(word.pos), style: MullType.label.copyWith(fontStyle: FontStyle.italic, color: c.onSurfaceMuted)),
                ],
              ),
              const SizedBox(height: Space.md),
              Text(word.definitionShort, style: MullType.body.copyWith(fontSize: 16, color: c.onSurface)),
              if (example != null) ...<Widget>[
                const SizedBox(height: Space.sm),
                Text(example!, style: MullType.note.copyWith(color: c.onSurfaceVariant, fontStyle: FontStyle.italic)),
              ],
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

  final DictionaryCollection collection;
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return InkWell(
      onTap: () => context.go(Routes.scoped(collection.slug)),
      borderRadius: Radii.cardR,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: Radii.cardR, border: Border.all(color: c.outline)),
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
                  Text('${grouped(progress.seen)} / ${grouped(progress.total)} seen', style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant)),
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
      child: InkWell(
        onTap: () => showWordSheet(context, wordKey: word.wordKey, fromSearch: true),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: Space.sm,
            children: <Widget>[
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(word.headword, style: MullType.titleSmall.copyWith(color: c.onSurface)),
                  Text('${posLabel(word.pos)} · ${word.definitionShort}', style: MullType.monoLabel.copyWith(fontSize: 10, color: c.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
              Semantics(
                button: true,
                label: 'Add ${word.headword} to From my reading',
                child: InkWell(
                  onTap: () async {
                    final WordList reading = await ref.read(userRepositoryProvider).readingList();
                    await ref.read(userRepositoryProvider).addToList(reading.id, word.wordKey);
                  },
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: c.surfaceContainerHigh, shape: BoxShape.circle),
                    child: Icon(Icons.add_rounded, size: 16, color: c.accent),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.cardR,
        child: Container(
          padding: const EdgeInsets.all(14),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.add_rounded, size: 20, color: c.accent),
              const SizedBox(height: 4),
              Text('New list', style: MullType.titleMedium.copyWith(color: c.accent)),
              Text('Your own words', style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
