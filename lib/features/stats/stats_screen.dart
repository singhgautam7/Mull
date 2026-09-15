import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/user_db.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/progress.dart';
import '../settings/settings_widgets.dart';
import 'stats_providers.dart';

/// HANDOFF 3.8. Three quiet figures, words seen per day (30 bars), the
/// time-of-day heatmap, per-collection rings, most-revisited words, and the
/// longest run of days as one text row at the bottom.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    final MullStats? s = ref.watch(statsProvider).value;
    final List<DictionaryCollection> collections = ref.watch(collectionsProvider).where((DictionaryCollection x) => x.kind == 'band').toList();
    final Map<String, Progress> progress = ref.watch(collectionProgressProvider);
    final DictionaryDb dict = ref.watch(dictProvider);
    if (s == null) return const SettingsScaffold(title: 'Stats', children: <Widget>[]);
    final bool firstWeek = s.daysIn < 14;

    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: Space.section, bottom: Space.row),
      child: Text(t, style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant)),
    );

    return SettingsScaffold(
      title: 'Stats',
      children: <Widget>[
        if (firstWeek)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xl),
            child: Text(
              s.daysIn == 0
                  ? 'Nothing here yet. Open Mull and it starts.'
                  : '${_dayWord(s.daysIn)} in. There is not much here yet, which is the expected amount.',
              style: MullType.body.copyWith(color: c.onSurfaceVariant),
            ),
          ),
        Row(
          children: <Widget>[
            _Figure(value: s.wordsSeen, label: 'words seen'),
            _Figure(value: s.bookmarked, label: 'bookmarked'),
            _Figure(value: s.notes, label: 'notes'),
          ],
        ),
        label(firstWeek ? 'WORDS SEEN PER DAY' : 'WORDS SEEN PER DAY · LAST 30'),
        _Bars(values: s.perDay, daysIn: s.daysIn),
        if (firstWeek)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Text('the rest of the month fills in as it happens', style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
          ),
        label('WHEN YOU ACTUALLY OPEN MULL'),
        if (firstWeek) ...<Widget>[
          Text('Not enough days yet to show a pattern.', style: MullType.body.copyWith(color: c.onSurface)),
          const SizedBox(height: 4),
          Text('The heatmap appears after a fortnight of use.', style: MullType.note.copyWith(color: c.onSurfaceVariant)),
        ] else
          _Heatmap(stats: s),
        label('COLLECTIONS'),
        Row(
          children: <Widget>[
            for (final DictionaryCollection col in collections)
              Expanded(
                child: Column(
                  children: <Widget>[
                    ProgressRing(fraction: (progress[col.slug] ?? const Progress(0, 0)).fraction),
                    const SizedBox(height: Space.sm),
                    Text(col.title, textAlign: TextAlign.center, style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
              ),
          ],
        ),
        if (s.mostRevisited.isNotEmpty) ...<Widget>[
          label('MOST REVISITED'),
          for (final SeenWord w in s.mostRevisited)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(dict.byKey(w.wordKey)?.headword ?? w.wordKey, style: MullType.titleMedium.copyWith(color: c.onSurface))),
                  Text('${w.seenCount}', style: MullType.monoTabular.copyWith(color: c.onSurfaceVariant)),
                ],
              ),
            ),
        ],
        const SizedBox(height: Space.section),
        Row(
          children: <Widget>[
            Expanded(child: Text('Longest run of days', style: MullType.note.copyWith(color: c.onSurfaceVariant))),
            Text('${s.longestRun}', style: MullType.monoTabular.copyWith(color: c.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }

  static String _dayWord(int n) => switch (n) {
    1 => 'One day',
    2 => 'Two days',
    3 => 'Three days',
    4 => 'Four days',
    5 => 'Five days',
    6 => 'Six days',
    _ => '$n days',
  };
}

/// Mono tabular, not a hero number.
class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(grouped(value), style: MullType.monoTabular.copyWith(fontSize: 26, color: c.onSurface)),
          Text(label, style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Thirty bars, the last two in `primary`, the rest `primaryContainer`, zero
/// days a flat `surfaceContainerHigh` stub. Only the days that exist paint
/// in the first week.
class _Bars extends StatelessWidget {
  const _Bars({required this.values, required this.daysIn});

  final List<int> values;
  final int daysIn;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final int max = values.fold(1, (int m, int v) => v > m ? v : m);
    final int shown = daysIn < 30 ? daysIn.clamp(1, 30) : 30;
    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 3,
        children: <Widget>[
          for (int i = 0; i < 30; i++)
            Expanded(
              child: i < 30 - shown
                  ? const SizedBox.shrink()
                  : Container(
                      height: values[i] == 0 ? 3 : 8 + 64 * values[i] / max,
                      decoration: BoxDecoration(
                        color: values[i] == 0 ? c.surfaceContainerHigh : (i >= 28 ? c.primary : c.primaryContainer),
                        borderRadius: const BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

/// 7 x 12 two-hour cells, four intensity steps from `surfaceContainerHigh`
/// to `primary`.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.stats});

  final MullStats stats;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final int max = stats.heatmapMax;
    Color cell(int v) {
      if (v == 0 || max == 0) return c.surfaceContainerHigh;
      final double t = v / max;
      return t < 0.34 ? Color.lerp(c.surfaceContainerHigh, c.primary, 0.33)! : t < 0.67 ? Color.lerp(c.surfaceContainerHigh, c.primary, 0.66)! : c.primary;
    }
    const List<String> days = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            const SizedBox(width: 18),
            for (final String h in const <String>['2am', '8am', '2pm', '8pm'])
              Expanded(child: Text(h, style: MullType.monoLabel.copyWith(fontSize: 9, color: c.onSurfaceMuted))),
          ],
        ),
        const SizedBox(height: 4),
        for (int d = 0; d < 7; d++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              spacing: 3,
              children: <Widget>[
                SizedBox(width: 15, child: Text(days[d], style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant))),
                for (int h = 0; h < 12; h++)
                  Expanded(
                    child: Container(height: 14, decoration: BoxDecoration(color: cell(stats.heatmap[d][h]), borderRadius: BorderRadius.circular(3))),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
