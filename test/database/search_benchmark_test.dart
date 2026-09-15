import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:sqlite3/sqlite3.dart';

/// Rule D5: exact, prefix, FTS, trigram; each under 50 ms on the shipped
/// data. Runs against the committed asset, decompressed to a temp file.
void main() {
  late Directory dir;
  late DictionaryDb dict;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('mull_search_');
    final File out = File('${dir.path}/dictionary.db');
    await File('assets/db/dictionary.db.gz').openRead().transform(gzip.decoder).pipe(out.openWrite());
    dict = DictionaryDb.open(out.path);
  });

  tearDownAll(() async {
    dict.close();
    await dir.delete(recursive: true);
  });

  test('the search ladder resolves exact, alias, prefix, fts and typos', () {
    // Pick real words from the data so the test tracks whatever was built.
    final Database raw = sqlite3.open('${dir.path}/dictionary.db', mode: OpenMode.readOnly);
    final String head = raw.select('SELECT headword FROM words WHERE band = ? ORDER BY freq_rank LIMIT 1', <Object>['everyday']).first['headword'] as String;
    final ResultSet alias = raw.select("SELECT a.alias_norm, w.headword FROM aliases a JOIN words w ON w.word_key = a.word_key WHERE a.kind = 'us_spelling' LIMIT 1");
    raw.close();

    expect(dict.search(head).first.headword, head, reason: 'exact match first');
    expect(dict.search(head.toUpperCase()).first.headword, head, reason: 'normalised');
    expect(dict.search(head.substring(0, 3)).map((DictionaryWord w) => w.headword), contains(head), reason: 'prefix');
    if (alias.isNotEmpty) {
      expect(
        dict.search(alias.first['alias_norm'] as String).map((DictionaryWord w) => w.headword),
        contains(alias.first['headword']),
        reason: 'US spelling resolves to the British headword',
      );
    }
    // A typo: swap two inner letters and expect the trigram rung to recover it.
    if (head.length >= 5) {
      final String typo = head.substring(0, 1) + head[2] + head[1] + head.substring(3);
      expect(dict.search(typo).map((DictionaryWord w) => w.headword), contains(head), reason: 'typo "$typo"');
      expect(dict.suggest(typo), isNotNull);
    }
    expect(dict.search('zzzzqqq'), isEmpty);
    expect(dict.search(''), isEmpty);
  });

  test('every rung of the ladder answers in under 50 ms', () {
    final List<String> queries = <String>['a', 'ab', 'abo', 'colour', 'color', 'the', 'wistfl', 'mitigate', 'q', 'strength'];
    // Warm the page cache once, as a real session would within a keystroke.
    for (final String q in queries) {
      dict.search(q);
    }
    for (final String q in queries) {
      final Stopwatch sw = Stopwatch()..start();
      dict.search(q);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(50), reason: 'search("$q") took ${sw.elapsedMicroseconds} us');
    }
  });
}
