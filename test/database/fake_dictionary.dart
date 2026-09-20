import 'dart:io';

import 'package:mull/core/database/dictionary_db.dart';
import 'package:sqlite3/sqlite3.dart';

/// One word to put in a fake dictionary.
class FakeWord {
  const FakeWord(
    this.headword,
    this.pos,
    this.definition, {
    this.rank = 100,
    this.band = 'core',
    this.ipa,
    this.examples = const <String>[],
    this.synonyms = const <String>[],
    this.inLearningSet = true,
  });

  final String headword;
  final String pos;
  final String definition;
  final int rank;
  final String band;
  final String? ipa;
  final List<String> examples;
  final List<String> synonyms;
  final bool inLearningSet;

  String get key => '${DictionaryDb.normalise(headword)}|$pos|1';
}

/// One phrase to put in a fake dictionary.
class FakePhrase {
  const FakePhrase(
    this.phrase,
    this.type,
    this.meaning, {
    this.usageNote,
    this.example,
    this.register = 'everyday',
    this.origin,
    this.attribution,
    this.sourceLanguage,
    this.slotPattern,
    this.rank = 100,
    this.inLearningSet = true,
  });

  final String phrase;
  final String type;
  final String meaning;
  final String? usageNote;
  final String? example;
  final String register;
  final String? origin;
  final String? attribution;
  final String? sourceLanguage;
  final String? slotPattern;
  final int rank;
  final bool inLearningSet;

  String get norm => DictionaryDb.normalise(phrase);
  String get key => '$norm|$type|1';
}

/// Builds an in-memory dictionary from the real `schema.sql`, so the tests
/// exercise the schema the pipeline ships rather than a copy of it.
///
/// Row ids follow insertion order, which is how a rebuilt dictionary comes
/// to have different ids for the same words (rule D4).
/// A collection's kind, title and description default to topic / the slug /
/// empty; [details] overrides them as `(kind, title, description)`.
DictionaryDb fakeDictionary({
  required List<FakeWord> words,
  List<FakePhrase> phrases = const <FakePhrase>[],
  Map<String, List<String>> collections = const <String, List<String>>{},
  Map<String, (String, String, String)> details = const <String, (String, String, String)>{},
  String version = 'test',
}) {
  final Database db = sqlite3.openInMemory();
  db.execute(File('tools/build_dictionary/schema.sql').readAsStringSync());
  db.execute("INSERT INTO meta(key, value) VALUES ('dict_version', ?)", <Object>[version]);
  for (final FakePhrase p in phrases) {
    db.execute(
      'INSERT INTO phrases(phrase_key, phrase, phrase_norm, type, meaning, usage_note, '
      'example, register, origin, attribution, source_language, slot_pattern, freq_rank, in_learning_set) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      <Object?>[
        p.key,
        p.phrase,
        p.norm,
        p.type,
        p.meaning,
        p.usageNote,
        p.example,
        p.register,
        p.origin,
        p.attribution,
        p.sourceLanguage,
        p.slotPattern,
        p.rank,
        p.inLearningSet ? 1 : 0,
      ],
    );
  }
  for (final FakeWord w in words) {
    db.execute(
      'INSERT INTO words(word_key, headword, headword_norm, pos, sense_index, definition_short, '
      'definition_full, ipa, freq_rank, band, in_learning_set) VALUES (?,?,?,?,1,?,?,?,?,?,?)',
      <Object?>[w.key, w.headword, DictionaryDb.normalise(w.headword), w.pos, w.definition, w.definition, w.ipa, w.rank, w.band, w.inLearningSet ? 1 : 0],
    );
    for (final String e in w.examples) {
      db.execute('INSERT INTO examples(word_key, text) VALUES (?,?)', <Object>[w.key, e]);
    }
    for (final String syn in w.synonyms) {
      db.execute('INSERT INTO synonyms(word_key, synonym) VALUES (?,?)', <Object>[w.key, syn]);
    }
  }
  int cid = 0;
  for (final MapEntry<String, List<String>> c in collections.entries) {
    cid++;
    final (String kind, String title, String description) = details[c.key] ?? ('topic', c.key, '');
    db.execute(
      'INSERT INTO collections(id, slug, title, description, kind, band, icon, sort_order) VALUES (?,?,?,?,?,NULL,NULL,?)',
      <Object>[cid, c.key, title, description, kind, cid],
    );
    for (int i = 0; i < c.value.length; i++) {
      db.execute(
        "INSERT INTO collection_words(collection_id, word_key, position, source) VALUES (?,?,?,'manual')",
        <Object>[cid, c.value[i], i],
      );
    }
  }
  db.execute("INSERT INTO words_fts(words_fts) VALUES ('rebuild')");
  // One row per headword, as the pipeline does.
  db.execute('INSERT INTO words_trigram(rowid, headword_norm) SELECT min(id), headword_norm FROM words GROUP BY headword_norm');
  db.execute("INSERT INTO phrases_fts(phrases_fts) VALUES ('rebuild')");
  return DictionaryDb.forTesting(db);
}
