import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/nav_bar.dart';
import '../../core/database/dictionary_db.dart';
import '../../core/database/user_db.dart';
import '../../core/motion/motion.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_menu.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/how_to_use_sheet.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/two_column_grid.dart';
import 'collection_cards.dart';
import 'shelf_edit_screen.dart';

enum _Filter { all, words, phrases, bands, topics, yours, inProgress }

enum _Sort { kind, progress, size, az }

/// HANDOFF 12, the browse screen. The user's own shelves come first (My
/// Shelf), then bands, a ladder (easiest first, fixed order), and topics, a
/// grid (unordered, overlapping). Nobody should have to wonder
/// whether Professional Words is harder than Well Read, and a list created
/// here appears here.
class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  final TextEditingController _search = TextEditingController();
  _Filter _filter = _Filter.all;
  _Sort _sort = _Sort.kind;

  /// True for the first moments after the tab opens or a filter or sort
  /// changes: the first six topic cards that appear stagger in then, and only
  /// then (`StaggeredEntrance` reads it once, when a card first builds). Cards
  /// are keyed by shelf, so one that stays put does not move or blink, and a
  /// card built by scrolling never animates. Read at build, so it needs no
  /// setState.
  /// False too when the tab was built ahead of its first visit ([WarmTab]):
  /// it is complete the moment it shows. The notifier, not `valuesOf`: a
  /// dependency here rebuilt the whole tab on its first visit.
  late bool _intro = TickerMode.getValuesNotifier(context).value.enabled;
  Timer? _introTimer;

  /// True once the open has taken longer than [Delayed.threshold] with the
  /// shelf data still settling: from then on the skeletons are showing.
  bool _slow = false;
  Timer? _slowTimer;

  // `select`, not the AsyncValue: watching the whole seen stream here
  // rebuilt the Shelves tab (offstage or not) on every swipe of the Mull tab.
  bool _settling({required bool watch}) => watch
      ? ref.watch(userCollectionsProvider.select((AsyncValue<List<UserCollection>> v) => v.isLoading)) ||
          ref.watch(collectionKeysSettlingProvider) ||
          ref.watch(seenMapProvider.select((AsyncValue<Map<String, SeenWord>> v) => v.isLoading))
      : ref.read(userCollectionsProvider).isLoading ||
          ref.read(collectionKeysSettlingProvider) ||
          ref.read(seenMapProvider).isLoading;

  void _armIntro() {
    _introTimer?.cancel();
    _introTimer = Timer(Motion.staggerDelay(6) + Motion.fxDefault, () => _intro = false);
  }

  /// A filter or sort from the user: what it brings in eases in.
  void _swap(VoidCallback change) {
    _intro = true;
    _armIntro();
    setState(change);
  }

  @override
  void initState() {
    super.initState();
    _armIntro();
    _slowTimer = Timer(Delayed.threshold, () {
      if (mounted && _settling(watch: false)) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _slowTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final List<Collection> all = ref.watch(collectionsProvider);
    // The in-progress set changes when a shelf starts or finishes; the
    // numbers change on every seen write and only the sort needs them. Each
    // card watches its own progress.
    final SlugSet inProgress = ref.watch(inProgressSlugsProvider);
    final Map<String, Progress> progress =
        _sort == _Sort.progress ? ref.watch(collectionProgressProvider) : const <String, Progress>{};
    // The dictionary's shelves are here at once; their word keys come off
    // the worker isolate, and the user's own and the seen progress a frame
    // later from the user database. Until then the sections hold their shape
    // with placeholders rather than jumping.
    final bool settling = _settling(watch: true);
    final ({Set<String> withWords, Set<String> withPhrases}) kinds = ref.watch(shelfKindsProvider);
    final String q = _search.text.trim().toLowerCase();
    final Widget newShelf = SectionHeaderAction(
      label: '+ New shelf',
      semanticLabel: 'New shelf',
      onTap: () => openShelfEditor(context),
    );

    Progress of(Collection x) => progress[x.slug] ?? const Progress(0, 0);
    // A placeholder that flashes is worse than none: while the counts settle
    // the real card is shown (its count is the dictionary's own, its bar
    // simply empty), and the skeleton only takes over if the read is still
    // out after the threshold. A fast open never renders one.
    // Once the threshold has passed with the data still out, the skeletons
    // are on screen and the swap to the real cards is a cross-fade, never a
    // cut. Before that (and always on a fast open) the real card stands in
    // and nothing fades, so a quick open draws no loader at all.
    Widget settle(Widget skeleton, Widget real) => _slow
        ? SkeletonCrossFade(loading: settling, placeholder: skeleton, child: real)
        : settling
            ? Delayed(placeholder: real, child: skeleton)
            : real;
    bool visibleFor(Collection x, _Filter f) {
      if (q.isNotEmpty && !x.title.toLowerCase().contains(q) && !x.description.toLowerCase().contains(q)) return false;
      return switch (f) {
        _Filter.all => true,
        _Filter.words => kinds.withWords.contains(x.slug),
        _Filter.phrases => kinds.withPhrases.contains(x.slug),
        _Filter.bands => x.kind == 'band',
        _Filter.topics => x.kind != 'band' && !x.isUsers,
        _Filter.yours => x.isUsers,
        _Filter.inProgress => inProgress.contains(x.slug),
      };
    }
    int compare(Collection a, Collection b) => switch (_sort) {
      _Sort.kind => a.sortOrder.compareTo(b.sortOrder),
      _Sort.progress => of(b).fraction.compareTo(of(a).fraction),
      _Sort.size => b.wordCount.compareTo(a.wordCount),
      _Sort.az => a.title.compareTo(b.title),
    };

    bool visible(Collection x) => visibleFor(x, _filter);
    final List<Collection> bands = all.where((Collection x) => x.kind == 'band' && visible(x)).toList()..sort(compare);
    final List<Collection> topics = all.where((Collection x) => x.kind != 'band' && !x.isUsers && visible(x)).toList()..sort(compare);
    final List<Collection> yours = all.where((Collection x) => x.isUsers && visible(x)).toList()..sort(compare);
    final bool yoursSettling = settling && yours.isEmpty && _filter == _Filter.all && q.isEmpty;

    return Scaffold(
      body: HeaderPage(
        header: AppHeader(
                title: 'Shelves',
                onBack: Navigator.of(context).canPop() ? () => Navigator.of(context).pop() : null,
                actions: <Widget>[
                  Builder(
                    builder: (BuildContext anchor) => AppIconButton(
                      icon: Icons.add_rounded,
                      semanticLabel: 'Add shelf',
                      onPressed: () async {
                        final String? action = await showAppMenu<String>(
                          context: context,
                          anchorContext: anchor,
                          minWidth: 220,
                          entries: <AppMenuEntry<String>>[
                            const AppMenuEntry<String>(
                              value: 'new',
                              label: 'New shelf',
                              icon: Icons.add_rounded,
                            ),
                            const AppMenuEntry<String>(
                              value: 'import',
                              label: 'Import words',
                              subtitle: 'paste a table or pick a CSV',
                              icon: Icons.file_upload_outlined,
                            ),
                          ],
                        );
                        if (action == 'new' && context.mounted) {
                          await openShelfEditor(context);
                        } else if (action == 'import' && context.mounted) {
                          await context.push(Routes.importWords);
                        }
                      },
                    ),
                  ),
                  Builder(
                    builder: (BuildContext anchor) => AppIconButton(
                      icon: Icons.more_horiz_rounded,
                      semanticLabel: 'More',
                      onPressed: () async {
                        final String? action = await showAppMenu<String>(
                          context: context,
                          anchorContext: anchor,
                          minWidth: 200,
                          entries: <AppMenuEntry<String>>[
                            const AppMenuEntry<String>(
                              value: 'how_to_use',
                              label: 'How to use',
                              icon: Icons.help_outline_rounded,
                            ),
                            const AppMenuEntry<String>.divider(),
                            for (final (_Sort v, String l) in const <(_Sort, String)>[
                              (_Sort.kind, 'Sort: Kind'),
                              (_Sort.progress, 'Sort: Progress'),
                              (_Sort.size, 'Sort: Size'),
                              (_Sort.az, 'Sort: A to Z'),
                            ])
                              AppMenuEntry<String>(
                                value: 'sort_${v.name}',
                                label: l,
                                icon: switch (v) {
                                  _Sort.kind => Icons.category_outlined,
                                  _Sort.progress => Icons.trending_up_rounded,
                                  _Sort.size => Icons.format_list_numbered_rounded,
                                  _Sort.az => Icons.sort_by_alpha_rounded,
                                },
                                selected: _sort == v,
                              ),
                          ],
                        );
                        if (action == null || !context.mounted) return;
                        if (action == 'how_to_use') {
                          await showHowToUseShelvesSheet(context);
                        } else {
                          final String key = action.replaceFirst('sort_', '');
                          final _Sort? s = _Sort.values.where((_Sort x) => x.name == key).firstOrNull;
                          if (s != null) _swap(() => _sort = s);
                        }
                      },
                    ),
                  ),
                ],
              ),
        // Lazy: 22 topic cards built up front was 39 ms of the Shelves tab's
        // first frame once the queries came off it, and only four of them
        // are ever on screen.
        body: CustomScrollView(
                  slivers: <Widget>[
                    HeaderPage.sliverGap(),
                    SliverList.list(children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.md),
                      // The shared search bar (Kuber's pill), the same as the Search tab's.
                      child: SearchField(
                        controller: _search,
                        hint: 'Search shelves',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                      child: Row(
                        spacing: Space.sm,
                        children: <Widget>[
                          for (final (_Filter f, String l) in const <(_Filter, String)>[
                            (_Filter.all, 'All'),
                            (_Filter.words, 'Words'),
                            (_Filter.phrases, 'Phrases'),
                            (_Filter.bands, 'Bands'),
                            (_Filter.topics, 'Topics'),
                            (_Filter.yours, 'My Shelf'),
                            (_Filter.inProgress, 'In progress'),
                          ])
                            PillChip(
                              label: l,
                              count: all.where((Collection x) => visibleFor(x, f)).length,
                              showCountWhenSelectedOnly: true,
                              selected: _filter == f,
                              onTap: () => _swap(() => _filter = f),
                            ),
                        ],
                      ),
                    ),
                    // My Shelf's action is a 48dp target: half the gap is already in it.
                    SizedBox(height: yours.isNotEmpty || yoursSettling ? Space.section / 2 : Space.section),
                    ]),
                    SliverList.list(key: const ValueKey<String>('yours'), children: <Widget>[
                    if (yoursSettling)
                      // Bookmarks and From my reading always exist, so two
                      // rows is the least the section will be. Nothing is
                      // drawn until the read has actually taken a moment.
                      Delayed(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            SectionHeader(label: 'My Shelf', trailing: newShelf),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                              child: Container(
                                decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: Radii.cardR, border: Border.all(color: c.outline)),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: <Widget>[
                                    const SkeletonRow(),
                                    Divider(color: c.divider, height: 1),
                                    const SkeletonRow(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (yours.isNotEmpty) ...<Widget>[
                      SectionHeader(label: 'My Shelf', trailing: newShelf),
                      YourLists(collections: yours, onOpen: (Collection x) => context.push(Routes.collection(x.slug))),
                    ],
                    if (yours.isNotEmpty) const SizedBox(height: Space.section),
                    ]),
                    if (bands.isNotEmpty)
                      SliverList.list(key: const ValueKey<String>('bands'), children: <Widget>[
                      const SectionHeader(label: 'Bands', trailing: SectionNote('easiest first')),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                        child: Container(
                          decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: Radii.cardR, border: Border.all(color: c.outline)),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: <Widget>[
                              for (int i = 0; i < bands.length; i++) ...<Widget>[
                                if (i > 0) Divider(color: c.divider, height: 1),
                                settle(
                                  const SkeletonRow(),
                                  Consumer(
                                    // Per shelf: a reused bar would ease from
                                    // the old shelf's progress to this one's.
                                    key: ValueKey<String>(bands[i].slug),
                                    builder: (BuildContext context, WidgetRef ref, Widget? _) => BandRow(
                                      collection: bands[i],
                                      progress: ref.watch(progressOfProvider(bands[i].slug)),
                                      onTap: () => context.push(Routes.collection(bands[i].slug)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.section),
                      ]),
                    if (topics.isNotEmpty) ...<Widget>[
                      SliverToBoxAdapter(
                        key: const ValueKey<String>('topics-label'),
                        child: SectionHeader(label: 'Topics · ${topics.length}', trailing: const SectionNote('pick by interest')),
                      ),
                      SliverPadding(
                        key: const ValueKey<String>('topics'),
                        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                        sliver: SliverList.separated(
                          itemCount: TwoColumnGrid.rowsFor(topics.length),
                          separatorBuilder: (BuildContext _, int _) => const SizedBox(height: Space.row),
                          itemBuilder: (BuildContext context, int r) {
                            final int i = r * 2;
                            Widget card(int n) => StaggeredEntrance(
                              key: ValueKey<String>(topics[n].slug),
                              index: n,
                              animate: _intro && n < 6,
                              child: settle(
                                const SkeletonCard(),
                                Consumer(
                                  builder: (BuildContext context, WidgetRef ref, Widget? _) => TopicCard(
                                    collection: topics[n],
                                    progress: ref.watch(progressOfProvider(topics[n].slug)),
                                    onTap: () => context.push(Routes.collection(topics[n].slug)),
                                  ),
                                ),
                              ),
                            );
                            return TwoColumnGrid.row(
                              card(i),
                              i + 1 < topics.length ? card(i + 1) : null,
                            );
                          },
                        ),
                      ),
                      const SliverToBoxAdapter(key: ValueKey<String>('topics-gap'), child: SizedBox(height: Space.section)),
                    ],
                    SliverList.list(key: const ValueKey<String>('end'), children: <Widget>[
                    if (!settling && bands.isEmpty && topics.isEmpty && yours.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(Space.xl),
                        child: Center(
                          child: Text('No shelves match', style: MullType.body.copyWith(color: c.onSurfaceMuted)),
                        ),
                      ),
                    SizedBox(height: Space.bottomSafe + MullNavPill.liftOf(context)),
                    ]),
                  ],
                ),
      ),
    );
  }
}
