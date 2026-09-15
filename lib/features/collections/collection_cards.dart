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
/// one-line description, count and a 3dp progress track. 96dp min.
class TopicCard extends StatelessWidget {
  const TopicCard({required this.collection, required this.progress, required this.onTap, this.compact = false, super.key});

  final DictionaryCollection collection;
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
                    color: done ? c.surface : c.primaryContainer,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(topicIcon(collection.icon), size: 17, color: done ? c.primary : c.onPrimaryContainer),
                ),
                const SizedBox(height: Space.row),
              ],
              Text(collection.title, style: MullType.titleMedium.copyWith(color: fg), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (!compact) ...<Widget>[
                const SizedBox(height: 2),
                Text(collection.description, style: MullType.bodySmall.copyWith(fontSize: 11.5, color: muted), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: Space.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      compact ? '${grouped(collection.wordCount)} ${collection.kind == 'idiom' ? 'phrases' : 'words'}' : grouped(collection.wordCount),
                      style: MullType.monoLabel.copyWith(color: muted),
                    ),
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

  final DictionaryCollection collection;
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
