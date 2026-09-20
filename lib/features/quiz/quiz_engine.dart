import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/database/dictionary_db.dart';

enum QuizQuestionType { wordToDefinition, definitionToWord, cloze }

class QuizQuestion {
  const QuizQuestion({
    required this.answer,
    required this.type,
    required this.options,
    this.cloze,
  });
  final DictionaryWord answer;
  final QuizQuestionType type;
  final List<DictionaryWord> options;
  final String? cloze;
}

/// Builds a session's questions from a shelf. Distractors keep the answer's
/// part of speech and a neighbouring band, come from the shelf before the
/// wider learning set, never sit on either side of a synonym link, and are
/// chosen for a similar definition length so no option stands out.
class QuizEngine {
  QuizEngine(this._dictionary);
  final DictionaryDb _dictionary;

  /// [build] for a shelf of [keys], packaged for `DictionaryDb.compute`. Made
  /// here, in a synchronous function, so the closure carries only the keys:
  /// one made inside an async method drags that method's completer along and
  /// cannot be sent to the worker.
  static List<QuizQuestion> Function(DictionaryDb db) generator(
    List<String> keys, {
    required Set<String> seenKeys,
    required int minimumWords,
  }) => (DictionaryDb db) {
    final List<DictionaryWord> words = db.byKeys(keys);
    return words.length < minimumWords
        ? const <QuizQuestion>[]
        : QuizEngine(db).build(words, seenKeys: seenKeys);
  };

  static const String blank = '______';

  /// Seen words first, then unseen, up to [limit] questions.
  List<QuizQuestion> build(
    List<DictionaryWord> shelf, {
    int limit = 10,
    Set<String> seenKeys = const <String>{},
    Random? random,
  }) {
    final Random rng = random ?? Random();
    final List<DictionaryWord> seen = shelf
        .where((DictionaryWord w) => seenKeys.contains(w.wordKey))
        .toList()
      ..shuffle(rng);
    final List<DictionaryWord> unseen = shelf
        .where((DictionaryWord w) => !seenKeys.contains(w.wordKey))
        .toList()
      ..shuffle(rng);

    final Set<String> shelfKeys = <String>{
      for (final DictionaryWord w in shelf) w.wordKey,
    };
    final List<DictionaryWord> candidates = <DictionaryWord>[
      ...shelf,
      ..._dictionary.quizCandidates().where(
        (DictionaryWord w) => !shelfKeys.contains(w.wordKey),
      ),
    ];

    final List<QuizQuestion> questions = <QuizQuestion>[];
    for (final DictionaryWord answer in <DictionaryWord>[...seen, ...unseen]) {
      final List<DictionaryWord> distractors = _distractors(
        answer,
        candidates,
        shelfKeys,
        rng,
      );
      if (distractors.length < 3) continue;
      final String? cloze = clozeFor(answer);
      // Cloze is the strongest question, so it takes two thirds of the
      // draws whenever the example allows it.
      final QuizQuestionType type = cloze != null && rng.nextInt(3) < 2
          ? QuizQuestionType.cloze
          : QuizQuestionType.values[rng.nextInt(2)];
      questions.add(
        QuizQuestion(
          answer: answer,
          type: type,
          options: <DictionaryWord>[answer, ...distractors]..shuffle(rng),
          cloze: cloze,
        ),
      );
      if (questions.length == limit) break;
    }
    return questions;
  }

  List<DictionaryWord> _distractors(
    DictionaryWord answer,
    List<DictionaryWord> candidates,
    Set<String> shelfKeys,
    Random random,
  ) {
    final Set<String> blocked = <String>{
      answer.headwordNorm,
      ..._dictionary.synonyms(answer.wordKey).map(DictionaryDb.normalise),
    };
    final int band = _bandIndex(answer.band);
    final int targetLength = answer.definitionShort.length;

    final List<DictionaryWord> valid = candidates
        .where(
          (DictionaryWord w) =>
              w.pos == answer.pos &&
              (_bandIndex(w.band) - band).abs() <= 1 &&
              !blocked.contains(w.headwordNorm),
        )
        .toList()
      // Shelf words first, then by how closely the definition length matches.
      ..sort((DictionaryWord a, DictionaryWord b) {
        final int shelfOrder = (shelfKeys.contains(a.wordKey) ? 0 : 1)
            .compareTo(shelfKeys.contains(b.wordKey) ? 0 : 1);
        if (shelfOrder != 0) return shelfOrder;
        return (a.definitionShort.length - targetLength).abs().compareTo(
          (b.definitionShort.length - targetLength).abs(),
        );
      });

    // The reverse synonym check costs a query per word, so it runs on the
    // short list only.
    final List<DictionaryWord> pool = valid
        .take(12)
        .where(
          (DictionaryWord w) => !_dictionary
              .synonyms(w.wordKey)
              .map(DictionaryDb.normalise)
              .contains(answer.headwordNorm),
        )
        .toList()
      ..shuffle(random);
    return pool.take(3).toList();
  }

  /// The word's example with the headword, or an inflection of it, blanked.
  /// Null when no example contains the word, which skips the cloze type.
  @visibleForTesting
  String? clozeFor(DictionaryWord word) {
    final RegExp pattern = inflectionPattern(<String>{
      word.headword,
      ..._dictionary.inflections(word.wordKey),
    });
    for (final String example in _dictionary.examples(word.wordKey)) {
      if (pattern.hasMatch(example)) {
        return example.replaceFirst(pattern, blank);
      }
    }
    return null;
  }

  /// Matches any of [forms] as a whole word, plus the regular English
  /// inflections of each: `abate` also matches `abated`, `abating`, `abates`;
  /// `carry` matches `carries` and `carried`; `hop` matches `hopped`.
  @visibleForTesting
  static RegExp inflectionPattern(Iterable<String> forms) {
    final Set<String> stems = <String>{};
    for (final String form in forms) {
      final String f = form.trim().toLowerCase();
      if (f.isEmpty) continue;
      stems.add(f);
      if (f.length < 3) continue; // too short to alter without false hits
      if (f.endsWith('e')) stems.add(f.substring(0, f.length - 1));
      if (f.endsWith('y')) stems.add('${f.substring(0, f.length - 1)}i');
      if (!'aeiou'.contains(f[f.length - 1])) stems.add(f + f[f.length - 1]);
    }
    final String alternatives = (stems.toList()
          ..sort((String a, String b) => b.length.compareTo(a.length)))
        .map(RegExp.escape)
        .join('|');
    return RegExp(
      '\\b(?:$alternatives)(?:s|es|ed|d|ing|ly|er|est|ness|ment)?\\b',
      caseSensitive: false,
    );
  }

  static int _bandIndex(String band) => switch (band) {
    'core' => 0,
    'everyday' => 1,
    'well_read' => 2,
    _ => 3,
  };
}
