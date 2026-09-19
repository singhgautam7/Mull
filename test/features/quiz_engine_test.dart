import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/database/user_repository.dart';
import 'package:mull/features/quiz/quiz_engine.dart';

import '../database/fake_dictionary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const List<String> bands = <String>['core', 'everyday', 'well_read', 'rare'];
  int bandIndex(String band) => bands.indexOf(band);

  /// 80 words over four parts of speech and four bands, where every word is
  /// a synonym of its neighbour so the synonym rule is exercised constantly.
  List<FakeWord> corpus() => <FakeWord>[
    for (final String pos in <String>['noun', 'verb', 'adj', 'adv'])
      for (int i = 0; i < 20; i++)
        FakeWord(
          '$pos$i',
          pos,
          'Definition ${'x' * (i % 7)} of $pos number $i.',
          band: bands[i % 4],
          synonyms: <String>['$pos${(i + 1) % 20}'],
          examples: <String>['She would $pos$i all day.'],
        ),
  ];

  test('over 200 questions every distractor matches POS and band and is never a synonym', () {
    final DictionaryDb dict = fakeDictionary(words: corpus());
    final QuizEngine engine = QuizEngine(dict);
    final List<DictionaryWord> shelf = dict.byKeys(<String>[
      for (final FakeWord w in corpus().take(30)) w.key,
    ]);

    int checked = 0;
    for (int seed = 0; checked < 200; seed++) {
      for (final QuizQuestion q in engine.build(shelf, random: Random(seed))) {
        expect(q.options.length, 4);
        expect(q.options.map((DictionaryWord w) => w.wordKey).toSet().length, 4);
        expect(q.options, contains(q.answer));
        final Set<String> answerSynonyms = dict
            .synonyms(q.answer.wordKey)
            .map(DictionaryDb.normalise)
            .toSet();
        for (final DictionaryWord d in q.options) {
          if (d.wordKey == q.answer.wordKey) continue;
          expect(d.pos, q.answer.pos, reason: '${d.headword} vs ${q.answer.headword}');
          expect((bandIndex(d.band) - bandIndex(q.answer.band)).abs(), lessThanOrEqualTo(1));
          expect(answerSynonyms, isNot(contains(d.headwordNorm)), reason: 'forward synonym');
          expect(
            dict.synonyms(d.wordKey).map(DictionaryDb.normalise),
            isNot(contains(q.answer.headwordNorm)),
            reason: 'reverse synonym',
          );
          expect(d.headwordNorm, isNot(q.answer.headwordNorm), reason: 'same word, other sense');
        }
        checked++;
      }
    }
    expect(checked, greaterThanOrEqualTo(200));
    dict.close();
  });

  test('a 10-word shelf gives a full session; the wider set fills in distractors', () {
    final DictionaryDb dict = fakeDictionary(words: corpus());
    final List<DictionaryWord> shelf = dict.byKeys(<String>[
      for (int i = 0; i < 10; i++) FakeWord('noun$i', 'noun', '').key,
    ]);
    final List<QuizQuestion> qs = QuizEngine(dict).build(shelf, random: Random(1));
    expect(qs.length, 10);
    expect(qs.map((QuizQuestion q) => q.answer.wordKey).toSet().length, 10);
    dict.close();
  });

  test('seen words are asked before unseen ones', () {
    final DictionaryDb dict = fakeDictionary(words: corpus());
    final List<DictionaryWord> shelf = dict.byKeys(<String>[
      for (int i = 0; i < 20; i++) FakeWord('verb$i', 'verb', '').key,
    ]);
    final Set<String> seen = <String>{shelf[3].wordKey, shelf[17].wordKey};
    final List<QuizQuestion> qs = QuizEngine(dict).build(shelf, seenKeys: seen, random: Random(2));
    expect(qs.take(2).map((QuizQuestion q) => q.answer.wordKey).toSet(), seen);
    dict.close();
  });

  group('cloze', () {
    test('blanks inflected forms, so the blank always covers the word', () {
      const FakeWord abate = FakeWord('abate', 'verb', 'To lessen', examples: <String>['The storm finally abated by sunrise.']);
      const FakeWord tenuous = FakeWord('tenuous', 'adj', 'Weak', examples: <String>['He clung on, tenuously, to the ledge.']);
      const FakeWord depose = FakeWord('depose', 'verb', 'To remove', examples: <String>['The king was deposed in spring.']);
      const FakeWord carry = FakeWord('carry', 'verb', 'To bear', examples: <String>['She carries it; he carried his.']);
      const FakeWord hop = FakeWord('hop', 'verb', 'To jump', examples: <String>['They hopped across.']);
      const FakeWord sober = FakeWord('sober', 'adj', 'Not drunk', examples: <String>['A sobering thought.']);
      const FakeWord miss = FakeWord('linger', 'verb', 'To stay', examples: <String>['Nothing of the word is here.']);
      final DictionaryDb dict = fakeDictionary(
        words: <FakeWord>[abate, tenuous, depose, carry, hop, sober, miss],
      );
      final QuizEngine engine = QuizEngine(dict);

      String? cloze(FakeWord w) => engine.clozeFor(dict.byKey(w.key)!);
      expect(cloze(abate), 'The storm finally ______ by sunrise.');
      expect(cloze(tenuous), 'He clung on, ______, to the ledge.');
      expect(cloze(depose), 'The king was ______ in spring.');
      expect(cloze(carry), 'She ______ it; he carried his.');
      expect(cloze(hop), 'They ______ across.');
      expect(cloze(sober), 'A ______ thought.');
      expect(cloze(miss), isNull, reason: 'no cloze when the example lacks the word');
      dict.close();
    });

    test('never blanks an unrelated word that merely starts the same', () {
      final RegExp p = QuizEngine.inflectionPattern(<String>['art']);
      expect(p.hasMatch('the artist arrived'), isFalse);
      expect(p.hasMatch('her art and arts'), isTrue);
    });
  });

  test('a quiz writes history but never the seen state', () async {
    final UserDatabase db = UserDatabase.forTesting(NativeDatabase.memory());
    final UserRepository user = UserRepository(db);
    const String key = 'abate|verb|1';
    await user.markSeen(key, now: DateTime(2026, 1, 1));
    await user.markSeen(key, now: DateTime(2026, 1, 5));
    final SeenWord before = (await user.seenStates(<String>[key]))[key]!;

    final int session = await user.beginQuiz('u1', 1);
    await user.answerQuiz(session, wordKey: key, type: 'cloze', correct: false, chosenKey: 'other|verb|1');
    await user.finishQuiz(session, correctCount: 0, abandoned: false);

    final SeenWord after = (await user.seenStates(<String>[key]))[key]!;
    expect(after.seenCount, before.seenCount);
    expect(after.lastSeenAt, before.lastSeenAt);
    expect(await user.wrongQuizKeys(), <String>[key]);
    await db.close();
  });

  test('an abandoned session is recorded, not dropped', () async {
    final UserDatabase db = UserDatabase.forTesting(NativeDatabase.memory());
    final UserRepository user = UserRepository(db);
    final int session = await user.beginQuiz('u1', 10);
    await user.answerQuiz(session, wordKey: 'a|noun|1', type: 'cloze', correct: true);
    await user.finishQuiz(session, correctCount: 1, abandoned: true);

    final List<QuizSession> rows = await db.select(db.quizSessions).get();
    expect(rows.single.wasAbandoned, isTrue);
    expect(rows.single.completedAt, isNotNull);
    expect(await user.completedQuizCount(), 0, reason: 'abandoned sessions do not count as taken');
    await db.close();
  });

  test('a word leaves "Words I got wrong" after two correct answers running', () async {
    final UserDatabase db = UserDatabase.forTesting(NativeDatabase.memory());
    final UserRepository user = UserRepository(db);
    const String key = 'abate|verb|1';
    DateTime t = DateTime(2026);
    Future<void> answer({required bool correct}) async {
      t = t.add(const Duration(minutes: 1));
      final int s = await user.beginQuiz('u1', 1, now: t);
      await user.answerQuiz(s, wordKey: key, type: 'cloze', correct: correct, now: t);
      await user.finishQuiz(s, correctCount: correct ? 1 : 0, abandoned: false, now: t);
    }

    await answer(correct: false);
    await answer(correct: true);
    expect(await user.wrongQuizKeys(), <String>[key]);
    await answer(correct: true);
    expect(await user.wrongQuizKeys(), isEmpty);
    await db.close();
  });
}
