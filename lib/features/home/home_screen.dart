import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/user_db.dart';
import '../../core/database/user_repository.dart';
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
import '../../shared/widgets/two_column_grid.dart';
import '../collections/collection_cards.dart';
import '../dictionary/word_sheet.dart';
import '../collections/create_list_sheet.dart';

/// HANDOFF 3.1. Greeting, word of the day, Continue, Recently looked up,
/// Collections (a shortlist: last opened, in progress, then built-ins), Your
/// lists. Both collection sections read the one unified query, so a list
/// made here is here. On scroll the greeting collapses to "Home".
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
    final List<Collection> collections = ref.watch(collectionsProvider);
    final Map<String, Progress> progress = ref.watch(collectionProgressProvider);
    final List<String> recent = ref.watch(recentLookupsProvider).value ?? const <String>[];
    final List<Collection> grid = ref.watch(homeCollectionsProvider);
    final List<Collection> yours = collections.where((Collection x) => x.isUsers).toList();
    final DictionaryDb dict = ref.watch(dictProvider);

    // Continue: the most recently started, unfinished collection.
    final Map<String, SeenWord> seen = ref.watch(seenMapProvider).value ?? const <String, SeenWord>{};
    final Map<String, List<String>> keys = ref.watch(collectionKeysProvider);
    Collection? cont;
    DateTime? latest;
    for (final Collection col in collections) {
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
                      // A row, not a fixed-height list: the chips are as
                      // tall as their text.
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                        child: Row(
                          spacing: Space.sm,
                          children: <Widget>[
                            for (final String key in recent)
                              if (dict.byKey(key) case final DictionaryWord w) _RecentChip(word: w),
                          ],
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
                      child: TwoColumnGrid(
                        children: <Widget>[
                          for (final Collection x in grid)
                            TopicCard(
                              collection: x,
                              progress: progress[x.slug] ?? const Progress(0, 0),
                              compact: true,
                              onTap: () => context.push(Routes.collection(x.slug)),
                            ),
                          _NewListCard(onTap: () => showCreateListSheet(context)),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.section),
                    SectionHeader(
                      label: 'Your lists',
                      trailing: InkWell(
                        onTap: () => context.push(Routes.collections),
                        child: Text('See all', style: MullType.monoLabel.copyWith(color: c.accent)),
                      ),
                    ),
                    YourLists(collections: yours, onOpen: (Collection x) => context.push(Routes.collection(x.slug))),
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
              // 42 at most, stepping down by grapheme count like the card,
              // and never scaled: a headword is never broken mid-word.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  word.headword,
                  style: MullType.headwordAt(math.max(1, MullType.headwordStep(word.headword))).copyWith(fontSize: MullType.headwordStep(word.headword) <= 1 ? 42 : null, color: c.onSurface),
                  textScaler: TextScaler.noScaling,
                  softWrap: false,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: Space.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
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

  final Collection collection;
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
              // Bounded, or the one-line definition would never ellipsise
              // inside a horizontal scroll.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(word.headword, style: MullType.titleSmall.copyWith(color: c.onSurface)),
                    Text('${posLabel(word.pos)} · ${word.definitionShort}', style: MullType.monoLabel.copyWith(fontSize: 10, color: c.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Add ${word.headword} to From my reading',
                child: InkWell(
                  onTap: () => ref.read(userRepositoryProvider).addToCollection(UserRepository.readingSlug, word.wordKey),
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
