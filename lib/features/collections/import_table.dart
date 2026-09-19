import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';

/// What a column of a pasted table is for.
enum ColumnRole { word, definition, example, ignore }

/// A pasted or picked table, parsed and ready for column mapping.
/// Pure: no dictionary, no widgets, so it is testable on its own.
@immutable
class ImportTable {
  const ImportTable({required this.rows, required this.columnCount});

  static const ImportTable empty = ImportTable(
    rows: <List<String>>[],
    columnCount: 0,
  );

  final List<List<String>> rows;
  final int columnCount;

  bool get isEmpty => rows.isEmpty;

  /// Word first, then definition, then example, ignoring anything beyond.
  Map<int, ColumnRole> get defaultRoles => <int, ColumnRole>{
    for (int i = 0; i < columnCount; i++)
      i: switch (i) {
        0 => ColumnRole.word,
        1 => ColumnRole.definition,
        2 => ColumnRole.example,
        _ => ColumnRole.ignore,
      },
  };

  /// One record per row with a non-empty word cell, under [roles]. The
  /// example column is labelled for the user's sake but not carried: Mull's
  /// own entry supplies examples.
  List<({String word, String? definition})> records(
    Map<int, ColumnRole> roles,
  ) {
    int? column(ColumnRole role) => roles.entries
        .where((MapEntry<int, ColumnRole> e) => e.value == role)
        .map((MapEntry<int, ColumnRole> e) => e.key)
        .firstOrNull;
    final int? wordCol = column(ColumnRole.word);
    if (wordCol == null) return const <({String word, String? definition})>[];
    final int? defCol = column(ColumnRole.definition);
    String? cell(List<String> row, int? col) =>
        col != null && col < row.length && row[col].isNotEmpty ? row[col] : null;
    return <({String word, String? definition})>[
      for (final List<String> row in rows)
        if (cell(row, wordCol) case final String word)
          (word: word, definition: cell(row, defCol)),
    ];
  }

  /// Header cells that mark a first row as a header rather than data.
  static const Set<String> _headerWords = <String>{
    'word',
    'headword',
    'term',
    'definition',
    'meaning',
    'example',
    'pos',
    'part of speech',
  };

  /// Parses TSV or CSV (delimiter detected), quoted fields, ragged rows and
  /// blank lines, and a bare one-word-per-line list. A recognised header row
  /// is dropped.
  static ImportTable parse(String raw) {
    final String text = raw.replaceAll('\r\n', '\n').trim();
    if (text.isEmpty) return empty;

    final int tabs = '\t'.allMatches(text).length;
    final int commas = ','.allMatches(text).length;
    final String delimiter = tabs >= commas && tabs > 0 ? '\t' : ',';

    List<List<Object?>> parsed;
    try {
      parsed = CsvToListConverter(
        fieldDelimiter: delimiter,
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(text);
    } on FormatException {
      // ponytail: a malformed quote falls back to one word per line.
      parsed = <List<Object?>>[
        for (final String line in text.split('\n')) <Object?>[line],
      ];
    }

    final List<List<String>> rows = <List<String>>[];
    int columnCount = 0;
    for (final List<Object?> row in parsed) {
      final List<String> cells = row
          .map((Object? c) => (c?.toString() ?? '').trim())
          .toList();
      if (cells.every((String c) => c.isEmpty)) continue;
      rows.add(cells);
      if (cells.length > columnCount) columnCount = cells.length;
    }
    if (rows.isNotEmpty &&
        rows.first.any((String c) => _headerWords.contains(c.toLowerCase()))) {
      rows.removeAt(0);
    }
    return ImportTable(rows: rows, columnCount: rows.isEmpty ? 0 : columnCount);
  }
}
