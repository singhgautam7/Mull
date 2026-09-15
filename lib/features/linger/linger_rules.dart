import '../../core/database/user_db.dart';

/// The whole spaced repetition system: a seen-policy ratio and an interval
/// ladder. There is no ease factor, no grading scale and no lapse counter,
/// and none will be added.

/// Governs the unseen / due-for-review serve ratio in the queue builder.
enum SeenPolicy {
  unseenOnly('unseen_only', 1.0),
  light('light', 0.85),
  mixed('mixed', 0.70),
  reviewOnly('review_only', 0.0);

  const SeenPolicy(this.dbValue, this.unseenRatio);

  /// The string stored in `mix_settings.seen_policy`.
  final String dbValue;

  /// Share of a queue that is unseen; the rest is due-for-review.
  final double unseenRatio;

  static SeenPolicy fromDb(String value) => values.firstWhere(
    (SeenPolicy p) => p.dbValue == value,
    orElse: () => SeenPolicy.light,
  );
}

/// A word is due when `lastSeenAt` is older than this many days, indexed by
/// `seenCount`, clamped at the last value.
const List<int> kReviewLadderDays = <int>[1, 3, 7, 21, 60];

bool isDue(SeenWord seen, DateTime now) {
  final int step = (seen.seenCount - 1).clamp(0, kReviewLadderDays.length - 1);
  return now.difference(seen.lastSeenAt).inDays >= kReviewLadderDays[step];
}

/// Seen is written on card exit, and only once the card has been on screen
/// this long, so a fast scroll past a word does not count as having met it.
const Duration kSeenDwellThreshold = Duration(milliseconds: 1200);

/// Words per queue batch; the queue extends as the user nears its end.
const int kQueueBatchSize = 30;
