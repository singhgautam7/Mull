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
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/two_column_grid.dart';
import 'collection_cards.dart';
import 'create_list_sheet.dart';

enum _Filter { all, bands, topics, yours, inProgress }

enum _Sort { kind, progress, size, az }

/// HANDOFF 12, the browse screen. Bands are a ladder (one axis, fixed
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
    final String q = _search.text.trim().toLowerCase();

    Progress of(Collection x) => progress[x.slug] ?? const Progress(0, 0);
    bool visible(Collection x) {
      if (q.isNotEmpty && !x.title.toLowerCase().contains(q) && !x.description.toLowerCase().contains(q)) return false;
      return switch (_filter) {
        _Filter.all => true,
        _Filter.bands => x.kind == 'band',
        _Filter.topics => x.kind != 'band' && !x.isUsers,
        _Filter.yours => x.isUsers,
        _Filter.inProgress => of(x).started && !of(x).complete,
      };
    }

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
                title: 'Collections',
                collapsed: collapsed,
                onBack: () => context.pop(),
                actions: <Widget>[
                  AppIconButton(icon: Icons.add_rounded, semanticLabel: 'New list', onPressed: () => showCreateListSheet(context)),
                  Builder(
                    builder: (BuildContext anchor) => AppIconButton(
                      icon: Icons.swap_vert_rounded,
                      semanticLabel: 'Sort',
                      onPressed: () async {
                        final _Sort? s = await showAppMenu<_Sort>(
                          context: context,
                          anchorContext: anchor,
                          entries: <AppMenuEntry<_Sort>>[
                            for (final (_Sort v, String l) in const <(_Sort, String)>[
                              (_Sort.kind, 'Kind'),
                              (_Sort.progress, 'Progress'),
                              (_Sort.size, 'Size'),
                              (_Sort.az, 'A–Z'),
                            ])
                              AppMenuEntry<_Sort>(value: v, label: l, radio: true, selected: _sort == v),
                          ],
                        );
                        if (s != null) setState(() => _sort = s);
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
                                  hintText: 'Search collections',
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
                          for (final (_Filter f, String l) in <(_Filter, String)>[
                            (_Filter.all, 'All ${all.length}'),
                            (_Filter.bands, 'Bands'),
                            (_Filter.topics, 'Topics'),
                            (_Filter.yours, 'Yours'),
                            (_Filter.inProgress, 'In progress'),
                          ])
                            PillChip(label: l, selected: _filter == f, onTap: () => setState(() => _filter = f)),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.section),
                    if (bands.isNotEmpty) ...<Widget>[
                      const SectionHeader(label: 'Bands · easiest first', trailing: SectionNote('one axis')),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                        child: Container(
                          decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: Radii.cardR, border: Border.all(color: c.outline)),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: <Widget>[
                              for (int i = 0; i < bands.length; i++) ...<Widget>[
                                if (i > 0) Divider(color: c.divider, height: 1),
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
                              TopicCard(collection: t, progress: of(t), onTap: () => context.push(Routes.collection(t.slug))),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.section),
                    ],
                    if (yours.isNotEmpty) ...<Widget>[
                      const SectionHeader(label: 'Your lists', trailing: SectionNote('yours to fill')),
                      YourLists(collections: yours, onOpen: (Collection x) => context.push(Routes.collection(x.slug))),
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
