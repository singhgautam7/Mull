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
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_menu.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/how_to_use_sheet.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/two_column_grid.dart';
import 'collection_cards.dart';
import 'create_list_sheet.dart';

enum _Filter { all, words, phrases, bands, topics, yours, inProgress }

enum _Sort { kind, progress, size, az }

/// HANDOFF 12, the browse screen. Bands are a ladder (easiest first, fixed
/// order), topics are a grid (unordered, overlapping), and the user's own
/// lists sit below in a filled container. Nobody should have to wonder
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final List<Collection> all = ref.watch(collectionsProvider);
    final Map<String, Progress> progress = ref.watch(collectionProgressProvider);
    // The dictionary's shelves are here at once; the user's own and the seen
    // progress arrive a frame later from the user database. Until then the
    // sections hold their shape with placeholders rather than jumping.
    final bool settling = ref.watch(userCollectionsProvider).isLoading ||
        ref.watch(seenMapProvider).isLoading;
    final ({Set<String> withWords, Set<String> withPhrases}) kinds = ref.watch(shelfKindsProvider);
    final String q = _search.text.trim().toLowerCase();

    Progress of(Collection x) => progress[x.slug] ?? const Progress(0, 0);
    bool visibleFor(Collection x, _Filter f) {
      if (q.isNotEmpty && !x.title.toLowerCase().contains(q) && !x.description.toLowerCase().contains(q)) return false;
      return switch (f) {
        _Filter.all => true,
        _Filter.words => kinds.withWords.contains(x.slug),
        _Filter.phrases => kinds.withPhrases.contains(x.slug),
        _Filter.bands => x.kind == 'band',
        _Filter.topics => x.kind != 'band' && !x.isUsers,
        _Filter.yours => x.isUsers,
        _Filter.inProgress => of(x).started && !of(x).complete,
      };
    }
    bool visible(Collection x) => visibleFor(x, _filter);

    int compare(Collection a, Collection b) => switch (_sort) {
      _Sort.kind => a.sortOrder.compareTo(b.sortOrder),
      _Sort.progress => of(b).fraction.compareTo(of(a).fraction),
      _Sort.size => b.wordCount.compareTo(a.wordCount),
      _Sort.az => a.title.compareTo(b.title),
    };

    final List<Collection> bands = all.where((Collection x) => x.kind == 'band' && visible(x)).toList()..sort(compare);
    final List<Collection> topics = all.where((Collection x) => x.kind != 'band' && !x.isUsers && visible(x)).toList()..sort(compare);
    final List<Collection> yours = all.where((Collection x) => x.isUsers && visible(x)).toList()..sort(compare);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CollapseOnScroll(
          builder: (BuildContext context, bool collapsed) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppHeader(
                title: 'Shelves',
                collapsed: collapsed,
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
                          await showCreateListSheet(context);
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
                          if (s != null) setState(() => _sort = s);
                        }
                      },
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: Space.bottomSafe),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.md),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: Radii.fullR, border: Border.all(color: c.outline)),
                        child: Row(
                          spacing: 11,
                          children: <Widget>[
                            Icon(Icons.search_rounded, size: 18, color: c.iconMuted),
                            Expanded(
                              child: TextField(
                                controller: _search,
                                onChanged: (_) => setState(() {}),
                                style: MullType.body.copyWith(fontSize: 14, color: c.onSurface),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                  hintText: 'Search shelves',
                                  hintStyle: MullType.body.copyWith(fontSize: 14, color: c.onSurfaceMuted),
                                ),
                              ),
                            ),
                          ],
                        ),
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
                            (_Filter.yours, 'Yours'),
                            (_Filter.inProgress, 'In progress'),
                          ])
                            PillChip(
                              label: l,
                              count: all.where((Collection x) => visibleFor(x, f)).length,
                              showCountWhenSelectedOnly: true,
                              selected: _filter == f,
                              onTap: () => setState(() => _filter = f),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.section),
                    if (bands.isNotEmpty) ...<Widget>[
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
                                if (settling)
                                  const SkeletonRow()
                                else
                                  BandRow(collection: bands[i], progress: of(bands[i]), onTap: () => context.push(Routes.collection(bands[i].slug))),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.section),
                    ],
                    if (topics.isNotEmpty) ...<Widget>[
                      SectionHeader(label: 'Topics · ${topics.length}', trailing: const SectionNote('pick by interest')),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                        child: TwoColumnGrid(
                          children: <Widget>[
                            for (final Collection t in topics)
                              if (settling)
                                const SkeletonCard()
                              else
                                TopicCard(collection: t, progress: of(t), onTap: () => context.push(Routes.collection(t.slug))),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.section),
                    ],
                    if (settling && _filter == _Filter.all && q.isEmpty) ...<Widget>[
                      // Bookmarks and From my reading always exist, so two
                      // rows is the least the section will be.
                      const SectionHeader(label: 'Your shelves', trailing: SectionNote('yours to fill')),
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
                    ] else if (yours.isNotEmpty) ...<Widget>[
                      const SectionHeader(label: 'Your shelves', trailing: SectionNote('yours to fill')),
                      YourLists(collections: yours, onOpen: (Collection x) => context.push(Routes.collection(x.slug))),
                    ],
                    if (!settling && bands.isEmpty && topics.isEmpty && yours.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(Space.xl),
                        child: Center(
                          child: Text('No shelves match', style: MullType.body.copyWith(color: c.onSurfaceMuted)),
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
