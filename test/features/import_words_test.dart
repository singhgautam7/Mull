import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/features/collections/import_table.dart';

import '../database/fake_dictionary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImportTable.parse', () {
    test('a bare single-column word list', () {
      final ImportTable t = ImportTable.parse('abate\n\nabound\n  acumen  \n');
      expect(t.columnCount, 1);
      expect(t.rows, <List<String>>[
        <String>['abate'],
        <String>['abound'],
        <String>['acumen'],
      ]);
      expect(t.defaultRoles, <int, ColumnRole>{0: ColumnRole.word});
    });

    test('TSV with a header row, as Sheets and Notion paste it', () {
      final ImportTable t = ImportTable.parse(
        'Word\tDefinition\tExample\r\nabate\tto lessen\tthe storm abated\r\nabound\tto be plentiful\t\r\n',
      );
      expect(t.columnCount, 3);
      expect(t.rows.length, 2);
      expect(t.rows.first, <String>['abate', 'to lessen', 'the storm abated']);
      final List<({String word, String? definition})> recs = t.records(
        t.defaultRoles,
      );
      expect(recs[1].word, 'abound');
      expect(recs[1].definition, 'to be plentiful');
    });

    test('CSV with quoted commas and ragged rows', () {
      final ImportTable t = ImportTable.parse(
        'abate,"to lessen, reduce"\nabound\nacumen,"keen insight",extra,cells\n',
      );
      expect(t.columnCount, 4);
      expect(t.rows[0][1], 'to lessen, reduce');
      expect(t.rows[1], <String>['abound']);
      expect(t.records(t.defaultRoles).map((r) => r.word), <String>[
        'abate',
        'abound',
        'acumen',
      ]);
    });

    test('empty input parses to nothing', () {
      expect(ImportTable.parse('  \n\n').isEmpty, isTrue);
    });
  });

  test('a 500-row paste resolves in under two seconds', () {
    final DictionaryDb dict = fakeDictionary(
      words: <FakeWord>[
        for (int i = 0; i < 500; i++)
          FakeWord('word$i', 'noun', 'Definition for word $i'),
      ],
    );
    final ImportTable table = ImportTable.parse(
      <String>[for (int i = 0; i < 500; i++) 'word$i'].join('\n'),
    );
    final Stopwatch clock = Stopwatch()..start();
    final List<WordMatch> matches = dict.batchMatchWords(
      table.records(table.defaultRoles),
    );
    clock.stop();
    expect(matches.length, 500);
    expect(matches.every((WordMatch m) => m.isMatched), isTrue);
    expect(clock.elapsedMilliseconds, lessThan(2000));
    dict.close();
  });

  test('a shelf CSV export re-imports cleanly', () {
    const FakeWord abate = FakeWord('abate', 'verb', 'To lessen.');
    const FakeWord dither = FakeWord('dither', 'verb', 'To be indecisive.');
    final DictionaryDb dict = fakeDictionary(words: <FakeWord>[abate, dither]);

    // The same shape shelf_export_sheet writes.
    final String csv = const ListToCsvConverter().convert(<List<Object?>>[
      <String>['word', 'pos', 'definition', 'example', 'date_added', 'note'],
      <String>['abate', 'verb', 'To lessen.', 'It abated.', '2026-01-01', 'a, note'],
      <String>['dither', 'verb', 'To be indecisive.', '', '2026-01-02', ''],
    ]);

    final ImportTable table = ImportTable.parse(csv);
    expect(table.rows.length, 2, reason: 'header row is dropped');
    final List<WordMatch> matches = dict.batchMatchWords(
      table.records(table.defaultRoles),
    );
    expect(matches.map((WordMatch m) => m.word?.wordKey), <String>[
      abate.key,
      dither.key,
    ]);
    expect(matches.every((WordMatch m) => m.isMatched), isTrue);
    dict.close();
  });

  test('inflections and typos come back as near matches, not misses', () {
    const FakeWord run = FakeWord('run', 'verb', 'To move fast.');
    const FakeWord persistent = FakeWord('persistent', 'adj', 'Lasting.');
    final DictionaryDb dict = fakeDictionary(
      words: <FakeWord>[run, persistent],
    );
    final List<WordMatch> matches = dict.batchMatchWords(
      ImportTable.parse('running\npersistence\npersistant\nzzzz').records(
        <int, ColumnRole>{0: ColumnRole.word},
      ),
    );
    expect(matches[0].isNearMatch, isTrue);
    expect(matches[0].word?.wordKey, run.key);
    expect(matches[1].isNearMatch, isTrue);
    expect(matches[1].word?.wordKey, persistent.key);
    expect(matches[2].isNearMatch, isTrue, reason: 'trigram fuzzy');
    expect(matches[3].isNotFound, isTrue);
    dict.close();
  });
}
