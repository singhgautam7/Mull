import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/mix_repository.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/database/user_repository.dart';
import 'package:mull/features/linger/linger_rules.dart';
import 'package:mull/features/linger/queue_builder.dart';

import '../database/fake_dictionary.dart';

void main() {
  late UserDatabase userDb;
  late UserRepository user;
  late MixRepository mixes;
  late DictionaryDb dict;
  late QueueBuilder queue;
  final DateTime now = DateTime(2026, 9, 14, 12);

  // 300 words in one collection, 100 more that sit in three collections.
  final List<FakeWord> words = <FakeWord>[
    for (int i = 0; i < 400; i++) FakeWord('word$i', 'noun', 'Definition $i.', rank: i + 1),
  ];

  setUp(() async {
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
    user = UserRepository(userDb);
    mixes = MixRepository(userDb);
    dict = fakeDictionary(
      words: words,
      collections: <String, List<String>>{
        'alpha': <String>[for (int i = 0; i < 300; i++) words[i].key],
        'beta': <String>[for (int i = 300; i < 400; i++) words[i].key],
        'gamma': <String>[for (int i = 300; i < 400; i++) words[i].key],
        'delta': <String>[for (int i = 300; i < 400; i++) words[i].key],
      },
    );
    queue = QueueBuilder(dict, user);
    await mixes.ensurePresets(
      bandSlugs: <String>['alpha'],
      topicSlugs: <String>['beta', 'gamma', 'delta'],
    );
  });

  tearDown(() async {
    dict.close();
    await userDb.close();
  });

  /// Marks the first [n] words seen [count] times, last seen [daysAgo].
  Future<void> seenSome(int from, int n, {int count = 1, int daysAgo = 30}) async {
    for (int i = from; i < from + n; i++) {
      for (int c = 0; c < count; c++) {
        await user.markSeen(words[i].key, now: now.subtract(Duration(days: daysAgo)));
      }
    }
  }

  test('four presets exist after first run and Anything is active', () async {
    final List<MixSpec> all = await mixes.all();
    expect(all.map((MixSpec m) => m.name), <String>['Anything', 'Quick wins', 'Stretch me', 'Review']);
    expect(all.every((MixSpec m) => m.isPreset), isTrue);
    expect((await mixes.active())!.name, 'Anything');
    expect((await mixes.active())!.sources, unorderedEquals(<String>['alpha', 'beta', 'gamma', 'delta']));
    expect(all.last.includeBookmarkedOnly, isTrue);
    expect(all.last.seenPolicy, SeenPolicy.reviewOnly);
    // Calling again neither duplicates nor changes the active mix.
    await mixes.ensurePresets(bandSlugs: <String>['alpha'], topicSlugs: <String>['beta']);
    expect((await mixes.all()).length, 4);
  });

  test('each seen policy produces the expected unseen/due ratio over 200 draws', () async {
    // 150 seen and due, 250 unseen: plenty on both sides.
    await seenSome(0, 150, daysAgo: 30);
    const int draws = 200;
    // (unseen, total): review_only never pads with unseen words, so with 150
    // seen words it serves 150 and stops.
    const Map<SeenPolicy, (int, int)> expected = <SeenPolicy, (int, int)>{
      SeenPolicy.unseenOnly: (200, 200),
      SeenPolicy.light: (170, 200),
      SeenPolicy.mixed: (140, 200),
      SeenPolicy.reviewOnly: (0, 150),
    };
    for (final MapEntry<SeenPolicy, (int, int)> e in expected.entries) {
      final MixSpec mix = MixSpec(
        id: 99,
        name: e.key.name,
        isPreset: false,
        sources: const <String>['alpha', 'beta'],
        seenPolicy: e.key,
      );
      final List<String> keys = await queue.build(mix, size: draws, now: now, random: Random(1));
      final Map<String, SeenWord> seen = await user.seenStates(keys);
      final int unseen = keys.where((String k) => !seen.containsKey(k)).length;
      expect(keys.length, e.value.$2, reason: e.key.name);
      expect(unseen, e.value.$1, reason: '${e.key.name}: $unseen unseen of ${keys.length}');
    }
  });

  test('a word in three source collections appears once per queue', () async {
    const MixSpec mix = MixSpec(
      id: 1,
      name: 'triple',
      isPreset: false,
      sources: <String>['beta', 'gamma', 'delta'],
      seenPolicy: SeenPolicy.unseenOnly,
    );
    expect((await queue.pool(mix)).length, 100);
    final List<String> keys = await queue.build(mix, size: 100, now: now);
    expect(keys.length, 100);
    expect(keys.toSet().length, 100);
    // Extending with what was served never repeats either.
    final List<String> more = await queue.build(mix, size: 30, exclude: keys.toSet(), now: now);
    expect(more, isEmpty);
  });

  test('scoped play does not mutate the active mix', () async {
    final MixSpec before = (await mixes.active())!;
    await mixes.setScoped('beta');
    final MixSpec scoped = MixSpec.scoped('beta', before.seenPolicy);
    expect(scoped.isScoped, isTrue);
    expect(scoped.effectiveSources, <String>['beta']);
    expect((await queue.pool(scoped)).length, 100);

    final MixSpec after = (await mixes.active())!;
    expect(after.id, before.id);
    expect(after.sources, before.sources);
    expect(after.seenPolicy, before.seenPolicy);
    expect(await mixes.scopedCollection(), 'beta');
    await mixes.clearScoped();
    expect(await mixes.scopedCollection(), isNull);
    expect((await mixes.active())!.sources, before.sources);
  });

  test('the interval ladder decides what is due', () async {
    await seenSome(0, 1, count: 1, daysAgo: 0); // seen today, once: due in 1 day
    await seenSome(1, 1, count: 2, daysAgo: 2); // seen twice, 2 days ago: due at 3
    await seenSome(2, 1, count: 3, daysAgo: 8); // seen 3 times, 8 days ago: due at 7
    await seenSome(3, 1, count: 9, daysAgo: 59); // clamped at 60
    final Map<String, SeenWord> s = await user.seenStates(<String>[for (int i = 0; i < 4; i++) words[i].key]);
    expect(isDue(s[words[0].key]!, now), isFalse);
    expect(isDue(s[words[1].key]!, now), isFalse);
    expect(isDue(s[words[2].key]!, now), isTrue);
    expect(isDue(s[words[3].key]!, now), isFalse);
    expect(isDue(s[words[3].key]!, now.add(const Duration(days: 1))), isTrue);
    expect(kSeenDwellThreshold, const Duration(milliseconds: 1200));
  });

  test('review_only serves due words first, then other seen words, never unseen', () async {
    await seenSome(0, 10, daysAgo: 30); // due
    await seenSome(10, 10, daysAgo: 0); // seen, not due
    const MixSpec mix = MixSpec(
      id: 2,
      name: 'r',
      isPreset: false,
      sources: <String>['alpha'],
      seenPolicy: SeenPolicy.reviewOnly,
      shuffle: false,
    );
    final List<String> keys = await queue.build(mix, size: 15, now: now);
    expect(keys.length, 15);
    expect(keys.take(10).toSet(), <String>{for (int i = 0; i < 10; i++) words[i].key});
    expect(keys.skip(10).every((String k) => int.parse(k.replaceAll(RegExp(r'\D'), '')) >= 10), isTrue);
  });

  test('bookmarked-only mixes draw from bookmarks', () async {
    await user.toggleBookmark(words[5].key);
    await user.toggleBookmark(words[6].key);
    await seenSome(5, 2, daysAgo: 30);
    final MixSpec review = (await mixes.all()).last;
    expect(await queue.build(review, now: now), unorderedEquals(<String>[words[5].key, words[6].key]));
  });
}
