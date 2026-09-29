import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_installer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

/// `shelfKindsProvider` reads a dictionary shelf's kind instead of asking
/// the database what is on it: `band` and `topic` hold words, `idiom` holds
/// phrases. That turned 44 queries in the Shelves tab's first build into
/// none. If the pipeline ever mixes the two, the Words / Phrases filters go
/// wrong silently, so the shipped dictionary is held to it here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every dictionary shelf holds only what its kind says it holds', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final Directory dir = await Directory.systemTemp.createTemp('mull_kinds_');
    addTearDown(() => dir.delete(recursive: true));
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String path = await DictionaryInstaller(prefs: prefs, directory: dir).ensureInstalled();
    final Database db = sqlite3.open(path, mode: OpenMode.readOnly);
    addTearDown(db.close);

    final ResultSet rows = db.select('''
      SELECT c.kind AS kind,
             sum(CASE WHEN w.word_key IS NOT NULL THEN 1 ELSE 0 END) AS words,
             sum(CASE WHEN p.phrase_key IS NOT NULL THEN 1 ELSE 0 END) AS phrases,
             count(*) AS n
      FROM collection_words cw
      JOIN collections c ON c.id = cw.collection_id
      LEFT JOIN words w ON w.word_key = cw.word_key
      LEFT JOIN phrases p ON p.phrase_key = cw.word_key
      WHERE c.kind != 'pairs'
      GROUP BY c.kind''');
    expect(rows, isNotEmpty, reason: 'the shipped dictionary has collections');

    for (final Row r in rows) {
      final String kind = r['kind'] as String;
      final int words = r['words'] as int;
      final int phrases = r['phrases'] as int;
      final int n = r['n'] as int;
      if (kind == 'idiom') {
        expect(words, 0, reason: 'an idiom shelf must hold no words');
        expect(phrases, n, reason: 'every idiom shelf member is a phrase');
      } else {
        expect(phrases, 0, reason: 'a $kind shelf must hold no phrases');
        expect(words, n, reason: 'every $kind shelf member is a word');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
