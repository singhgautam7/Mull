import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/user_db.dart';
import '../../core/database/user_repository.dart';
import '../../core/providers.dart';

@immutable
class MullStats {
  const MullStats({
    required this.wordsSeen,
    required this.bookmarked,
    required this.notes,
    required this.perDay,
    required this.heatmap,
    required this.mostRevisited,
    required this.longestRun,
    required this.daysIn,
  });

  final int wordsSeen;
  final int bookmarked;
  final int notes;

  /// Thirty buckets, oldest first; today is last.
  final List<int> perDay;

  /// 7 weekdays (Monday first) x 12 two-hour blocks.
  final List<List<int>> heatmap;
  final List<SeenWord> mostRevisited;
  final int longestRun;

  /// Days since the first seen event; drives the first-week copy.
  final int daysIn;

  int get heatmapMax => heatmap.fold(0, (int m, List<int> row) => row.fold(m, (int a, int b) => a > b ? a : b));
}

/// Stats is a mirror, not a scoreboard. No level, no estimate of words
/// known, no goal ring.
final FutureProvider<MullStats> statsProvider = FutureProvider<MullStats>((Ref ref) async {
  final UserRepository user = ref.watch(userRepositoryProvider);
  // Recomputed whenever seen state changes.
  ref.watch(seenMapProvider);
  final int wordsSeen = (await user.allSeen()).length;
  final int bookmarked = (await user.bookmarkedKeys()).length;
  final int notes = await user.noteCount();
  final List<SeenEvent> events = await user.allSeenEvents();

  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final List<int> perDay = List<int>.filled(30, 0);
  final List<List<int>> heat = List<List<int>>.generate(7, (_) => List<int>.filled(12, 0));
  final Set<DateTime> days = <DateTime>{};
  for (final SeenEvent e in events) {
    final DateTime d = DateTime(e.at.year, e.at.month, e.at.day);
    days.add(d);
    final int ago = today.difference(d).inDays;
    if (ago >= 0 && ago < 30) perDay[29 - ago]++;
    heat[e.at.weekday - 1][e.at.hour ~/ 2]++;
  }
  // Longest run of consecutive days with at least one word seen.
  final List<DateTime> sorted = days.toList()..sort();
  int longest = 0;
  int run = 0;
  DateTime? prev;
  for (final DateTime d in sorted) {
    run = prev != null && d.difference(prev).inDays == 1 ? run + 1 : 1;
    if (run > longest) longest = run;
    prev = d;
  }
  final int daysIn = sorted.isEmpty ? 0 : today.difference(sorted.first).inDays + 1;
  return MullStats(
    wordsSeen: wordsSeen,
    bookmarked: bookmarked,
    notes: notes,
    perDay: perDay,
    heatmap: heat,
    mostRevisited: await user.mostRevisited(),
    longestRun: longest,
    daysIn: daysIn,
  );
});
