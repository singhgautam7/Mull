import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/mix_repository.dart';
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
import '../../shared/widgets/progress.dart';
import '../../shared/widgets/section_header.dart';
import '../linger/saved_mixes_screen.dart';
import 'create_list_sheet.dart';

/// HANDOFF 3.7. User lists in one filled container (Bookmarks first, then
/// "From my reading", then created lists); saved mixes under MIXES; curated
/// collections outlined below. That difference is the only signal needed.
class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    final List<WordList> lists = ref.watch(listsProvider).value ?? const <WordList>[];
    final Map<int, int> counts = ref.watch(listCountsProvider).value ?? const <int, int>{};
    final int bookmarks = ref.watch(bookmarksProvider).value?.length ?? 0;
    final List<MixSpec> mixes = (ref.watch(mixesProvider).value ?? const <MixSpec>[]).where((MixSpec m) => !m.isPreset).toList();
    final List<DictionaryCollection> collections = ref.watch(collectionsProvider);
    final Map<String, Progress> progress = ref.watch(collectionProgressProvider);
    final MixSpec? review = (ref.watch(mixesProvider).value ?? const <MixSpec>[])
        .where((MixSpec m) => m.isPreset && m.name == MixRepository.presetReview)
        .firstOrNull;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppHeader(
              title: 'Lists',
              onBack: () => context.pop(),
              actions: <Widget>[
                AppIconButton(icon: Icons.add_rounded, semanticLabel: 'New list', onPressed: () => showCreateListSheet(context)),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Space.bottomSafe),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                    child: Container(
                      decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: Radii.cardR),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: <Widget>[
                          ListRow(
                            title: 'Bookmarks',
                            subtitle: '${plural(bookmarks, 'word')} · default',
                            swatch: c.primary,
                            onTap: review == null ? null : () => context.go(Routes.playMix(review.id!)),
                          ),
                          for (final WordList l in lists) ...<Widget>[
                            Divider(color: c.divider, height: 1),
                            ListRow(
                              title: l.name,
                              subtitle: l.isReading
                                  ? '${plural(counts[l.id] ?? 0, 'word')} · added from search'
                                  : plural(counts[l.id] ?? 0, 'word'),
                              swatch: c.tagColor(l.color),
                              onTap: () => context.push(Routes.list(l.id)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (mixes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Space.section),
                    SectionHeader(
                      label: 'Mixes',
                      trailing: InkWell(
                        onTap: () => context.push(Routes.mixes),
                        child: Text('Your mixes', style: MullType.monoLabel.copyWith(color: c.accent)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                      child: Column(
                        spacing: Space.row,
                        children: <Widget>[for (final MixSpec m in mixes) MixRow(mix: m)],
                      ),
                    ),
                  ],
                  const SizedBox(height: Space.section),
                  const SectionHeader(label: 'Curated collections'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                    child: Column(
                      spacing: Space.row,
                      children: <Widget>[
                        for (final DictionaryCollection col in collections)
                          _CuratedRow(collection: col, progress: progress[col.slug] ?? const Progress(0, 0)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row in the filled container: a 30dp rounded swatch, title, `{n} words`.
class ListRow extends StatelessWidget {
  const ListRow({required this.title, required this.subtitle, required this.swatch, required this.onTap, super.key});

  final String title;
  final String subtitle;
  final Color swatch;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            spacing: 13,
            children: <Widget>[
              Container(width: 30, height: 30, decoration: BoxDecoration(color: swatch, borderRadius: BorderRadius.circular(9))),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: MullType.titleMedium.copyWith(color: c.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: c.onSurfaceMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CuratedRow extends StatelessWidget {
  const _CuratedRow({required this.collection, required this.progress});

  final DictionaryCollection collection;
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return InkWell(
      onTap: () => context.push(Routes.collection(collection.slug)),
      borderRadius: Radii.cardR,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(borderRadius: Radii.cardR, border: Border.all(color: c.outline)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(collection.title, style: MullType.titleMedium.copyWith(color: c.onSurface))),
                Text('${grouped(progress.seen)} / ${grouped(collection.wordCount)}', style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: Space.sm),
            ProgressTrack(fraction: progress.fraction),
          ],
        ),
      ),
    );
  }
}
