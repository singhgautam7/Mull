import 'package:flutter/material.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/progress.dart';

/// The progress states, HANDOFF 12. Not started: empty track, "not
/// started". In progress: "{n} of {total} seen" in `accent`. Complete: the
/// card fills with `primaryContainer`, "all {total} seen", still tappable.
String progressLabel(Progress p) => !p.started
    ? 'not started'
    : p.complete
        ? 'all ${grouped(p.total)} seen'
        : '${grouped(p.seen)} of ${grouped(p.total)} seen';

/// The swatch of one of the user's own collections: Bookmarks takes
/// `primary`, everything else its stored hue or the accent.
Color swatchColor(MullColors c, Collection x) => x.slug == 'bookmarks' ? c.primary : c.tagColor(x.color);

/// A drawn glyph tile for a topic, from the icon name the pipeline wrote.
/// Never a photograph, never an emoji.
IconData topicIcon(String? name) => switch (name) {
  'sun' => Icons.wb_sunny_outlined,
  'briefcase' => Icons.work_outline_rounded,
  'people' => Icons.groups_outlined,
  'heart' => Icons.favorite_border_rounded,
  'person' => Icons.person_outline_rounded,
  'pan' => Icons.restaurant_outlined,
  'compass' => Icons.explore_outlined,
  'coins' => Icons.payments_outlined,
  'cloud' => Icons.cloud_outlined,
  'scales' => Icons.balance_outlined,
  'clock' => Icons.schedule_outlined,
  'pulse' => Icons.monitor_heart_outlined,
  'book' => Icons.menu_book_outlined,
  'house' => Icons.home_work_outlined,
  'quote' => Icons.format_quote_outlined,
  _ => Icons.style_outlined,
};

/// The 2-column topic card: 30dp `primaryContainer` glyph tile, title,
/// one-line description, count and a 3dp progress track. 96dp min. One of
/// the user's own collections here takes its colour swatch as the tile.
class TopicCard extends StatelessWidget {
  const TopicCard({required this.collection, required this.progress, required this.onTap, this.compact = false, super.key});

  final Collection collection;
  final Progress progress;
  final VoidCallback onTap;

  /// Home's grid: title and count only.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final bool done = progress.complete;
    final Color fg = done ? c.onPrimaryContainer : c.onSurface;
    final Color muted = done ? c.onPrimaryContainer : c.onSurfaceVariant;
    return Semantics(
      button: true,
      label: '${collection.title}, ${grouped(collection.wordCount)} words, ${progressLabel(progress)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.cardR,
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: done ? c.primaryContainer : c.surfaceContainer,
            borderRadius: Radii.cardR,
            border: Border.all(color: done ? c.primaryContainer : c.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!compact) ...<Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: collection.isUsers ? swatchColor(c, collection) : (done ? c.surface : c.primaryContainer),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: collection.isUsers ? null : Icon(topicIcon(collection.icon), size: 17, color: done ? c.primary : c.onPrimaryContainer),
                ),
                const SizedBox(height: Space.row),
              ],
              Row(
                spacing: Space.sm,
                children: <Widget>[
                  if (compact && collection.isUsers)
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: swatchColor(c, collection), shape: BoxShape.circle)),
                  Expanded(child: Text(collection.title, style: MullType.titleMedium.copyWith(color: fg), maxLines: 2, overflow: TextOverflow.ellipsis)),
                ],
              ),
              if (!compact) ...<Widget>[
                const SizedBox(height: 2),
                Text(collection.description, style: MullType.bodySmall.copyWith(fontSize: 11.5, color: muted), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: Space.sm),
              // Count left, progress right; at a large font scale the
              // progress label drops to its own line rather than clipping.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: Space.sm,
                children: <Widget>[
                  Text(
                    compact ? plural(collection.wordCount, collection.kind == 'idiom' ? 'phrase' : 'word') : grouped(collection.wordCount),
                    style: MullType.monoLabel.copyWith(color: muted),
                  ),
                  if (!compact)
                    Text(
                      progressLabel(progress),
                      style: MullType.monoLabel.copyWith(color: progress.started && !done ? c.accent : muted),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ProgressTrack(fraction: progress.fraction, onContainer: done),
            ],
          ),
        ),
      ),
    );
  }
}

/// One rung of the bands ladder: a state dot (filled = complete, ringed =
/// in progress, empty = not started), title, description, count, track.
class BandRow extends StatelessWidget {
  const BandRow({required this.collection, required this.progress, required this.onTap, super.key});

  final Collection collection;
  final Progress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final bool done = progress.complete;
    return Semantics(
      button: true,
      label: '${collection.title}, ${progressLabel(progress)}',
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          color: done ? c.primaryContainer : null,
          child: Row(
            spacing: Space.md,
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? c.onPrimaryContainer : (progress.started ? Colors.transparent : Colors.transparent),
                  border: Border.all(color: done ? c.onPrimaryContainer : (progress.started ? c.primary : c.outline), width: progress.started ? 2 : 1.5),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: Text(collection.title, style: MullType.titleMedium.copyWith(color: done ? c.onPrimaryContainer : c.onSurface))),
                        Text(grouped(collection.wordCount), style: MullType.monoLabel.copyWith(color: done ? c.onPrimaryContainer : c.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(collection.description, style: MullType.bodySmall.copyWith(fontSize: 11.5, color: done ? c.onPrimaryContainer : c.onSurfaceVariant)),
                    const SizedBox(height: Space.sm),
                    ProgressTrack(fraction: progress.fraction, onContainer: done),
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

/// One row of the YOUR LISTS container: a 30dp rounded swatch, title,
/// `{n} words`. User lists sit in a filled container; curated collections
/// are outlined. That difference is the only signal needed.
class ListRow extends StatelessWidget {
  const ListRow({required this.collection, required this.onTap, super.key});

  final Collection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final String subtitle = switch (collection.slug) {
      'bookmarks' => '${plural(collection.wordCount, 'word')} · default',
      'reading' => '${plural(collection.wordCount, 'word')} · added from search',
      _ => plural(collection.wordCount, 'word'),
    };
    return Semantics(
      button: true,
      label: '${collection.title}, $subtitle',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            spacing: 13,
            children: <Widget>[
              Container(width: 30, height: 30, decoration: BoxDecoration(color: swatchColor(c, collection), borderRadius: BorderRadius.circular(9))),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(collection.title, style: MullType.titleMedium.copyWith(color: c.onSurface)),
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

/// The filled container of the user's own collections.
class YourLists extends StatelessWidget {
  const YourLists({required this.collections, required this.onOpen, super.key});

  final List<Collection> collections;
  final ValueChanged<Collection> onOpen;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
      child: Container(
        decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: Radii.cardR),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            for (final (int i, Collection x) in collections.indexed) ...<Widget>[
              if (i > 0) Divider(color: c.divider, height: 1),
              ListRow(collection: x, onTap: () => onOpen(x)),
            ],
          ],
        ),
      ),
    );
  }
}
