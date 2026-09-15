import 'dart:io';

import 'package:mull/core/database/dictionary_db.dart';
import 'package:sqlite3/sqlite3.dart';

/// One word to put in a fake dictionary.
class FakeWord {
  const FakeWord(this.headword, this.pos, this.definition, {this.rank = 100, this.band = 'core'});

  final String headword;
  final String pos;
  final String definition;
  final int rank;
  final String band;

  String get key => '${DictionaryDb.normalise(headword)}|$pos|1';
}

/// Builds an in-memory dictionary from the real `schema.sql`, so the tests
/// exercise the schema the pipeline ships rather than a copy of it.
///
/// Row ids follow insertion order, which is how a rebuilt dictionary comes
/// to have different ids for the same words (rule D4).
DictionaryDb fakeDictionary({
  required List<FakeWord> words,
  Map<String, List<String>> collections = const <String, List<String>>{},
  String version = 'test',
}) {
  final Database db = sqlite3.openInMemory();
  db.execute(File('tools/build_dictionary/schema.sql').readAsStringSync());
  db.execute("INSERT INTO meta(key, value) VALUES ('dict_version', ?)", <Object>[version]);
  for (final FakeWord w in words) {
    db.execute(
      'INSERT INTO words(word_key, headword, headword_norm, pos, sense_index, definition_short, '
      'definition_full, ipa, freq_rank, band) VALUES (?,?,?,?,1,?,?,NULL,?,?)',
      <Object>[w.key, w.headword, DictionaryDb.normalise(w.headword), w.pos, w.definition, w.definition, w.rank, w.band],
    );
  }
  int cid = 0;
  for (final MapEntry<String, List<String>> c in collections.entries) {
    cid++;
    db.execute(
      "INSERT INTO collections(id, slug, title, description, kind, band, icon, sort_order) VALUES (?,?,?,?,'topic',NULL,NULL,?)",
      <Object>[cid, c.key, c.key, '', cid],
    );
    for (int i = 0; i < c.value.length; i++) {
      db.execute(
        "INSERT INTO collection_words(collection_id, word_key, position, source) VALUES (?,?,?,'manual')",
        <Object>[cid, c.value[i], i],
      );
    }
  }
  db.execute("INSERT INTO words_fts(words_fts) VALUES ('rebuild')");
  db.execute("INSERT INTO words_trigram(words_trigram) VALUES ('rebuild')");
  return DictionaryDb.forTesting(db);
}
