import 'dart:math';

import '../../core/database/dictionary_db.dart';
import '../../core/database/mix_repository.dart';
import '../../core/database/user_db.dart';
import '../../core/database/user_repository.dart';
import 'linger_rules.dart';

/// Builds the word queue the Mull tab plays from a [MixSpec].
///
/// The queue is not persisted; the mix is. Reopening the tab rebuilds from
/// current state, which naturally excludes words seen in the last session.
class QueueBuilder {
  QueueBuilder(this._dict, this._user);

  final DictionaryDb _dict;
  final UserRepository _user;

  /// Every word key the mix can draw from, deduplicated. A word in three
  /// source collections is here once. A source slug names either a
  /// dictionary collection or one of the user's own; each database answers
  /// for the slugs it knows.
  Future<List<String>> pool(MixSpec mix) async {
    if (mix.includeBookmarkedOnly) return _user.bookmarkedKeys();
    return poolFor(mix.effectiveSources);
  }

  Future<List<String>> poolFor(List<String> sources) async => <String>{
    ..._dict.collectionWordKeys(sources),
    ...await _user.collectionWordKeysFor(sources),
  }.toList();

  /// One batch of [size] keys. [exclude] is what the session has already
  /// served, so extending the queue never repeats a card.
  ///
  /// The split is deterministic: `round(size * unseenRatio)` unseen, the
  /// rest due-for-review, most overdue first. When one side runs short the
  /// other fills in. Only `reviewOnly` falls back to seen-but-not-due words;
  /// every other policy lets the pool run dry so the end card is honest.
  Future<List<String>> build(
    MixSpec mix, {
    int size = kQueueBatchSize,
    Set<String> exclude = const <String>{},
    DateTime? now,
    Random? random,
  }) async {
    final DateTime at = now ?? DateTime.now();
    final Random rng = random ?? Random();
    final List<String> candidates = (await pool(mix))
        .where((String k) => !exclude.contains(k))
        .toList();
    if (candidates.isEmpty) return const <String>[];

    final Map<String, SeenWord> seen = await _user.seenStates(candidates);
    final List<String> unseen = <String>[];
    final List<SeenWord> due = <SeenWord>[];
    final List<SeenWord> rest = <SeenWord>[];
    for (final String k in candidates) {
      final SeenWord? s = seen[k];
      if (s == null) {
        unseen.add(k);
      } else if (isDue(s, at)) {
        due.add(s);
      } else {
        rest.add(s);
      }
    }
    if (mix.shuffle) unseen.shuffle(rng);
    due.sort((SeenWord a, SeenWord b) => a.lastSeenAt.compareTo(b.lastSeenAt));
    rest.sort((SeenWord a, SeenWord b) => a.lastSeenAt.compareTo(b.lastSeenAt));

    final int wantUnseen = (size * mix.seenPolicy.unseenRatio).round();
    final int wantDue = size - wantUnseen;
    final List<String> fromUnseen = unseen.take(wantUnseen).toList();
    final List<String> fromDue = due.take(wantDue).map((SeenWord s) => s.wordKey).toList();

    final List<String> out = <String>[...fromUnseen, ...fromDue];
    // Backfill from the other side, within the policy's spirit.
    if (out.length < size && mix.seenPolicy != SeenPolicy.reviewOnly) {
      out.addAll(unseen.skip(wantUnseen).take(size - out.length));
    }
    if (out.length < size && mix.seenPolicy != SeenPolicy.unseenOnly) {
      out.addAll(due.skip(wantDue).take(size - out.length).map((SeenWord s) => s.wordKey));
    }
    if (out.length < size && mix.seenPolicy == SeenPolicy.reviewOnly) {
      out.addAll(rest.take(size - out.length).map((SeenWord s) => s.wordKey));
    }
    if (mix.shuffle) out.shuffle(rng);
    return out;
  }
}
