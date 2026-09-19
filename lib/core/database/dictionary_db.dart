import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

/// One sense of one word: a row of `words` in dictionary.db.
@immutable
class DictionaryWord {
  const DictionaryWord({
    required this.wordKey,
    required this.headword,
    required this.headwordNorm,
    required this.pos,
    required this.senseIndex,
    required this.definitionShort,
    required this.definitionFull,
    required this.ipa,
    required this.freqRank,
    required this.band,
  });

  /// `{headword_norm}|{pos}|{sense_index}`. The only thing user data stores.
  final String wordKey;
  final String headword;
  final String headwordNorm;
  final String pos;
  final int senseIndex;
  final String definitionShort;
  final String definitionFull;
  final String? ipa;
  final int freqRank;
  final String band;

  factory DictionaryWord._from(Row r) => DictionaryWord(
    wordKey: r['word_key'] as String,
    headword: r['headword'] as String,
    headwordNorm: r['headword_norm'] as String,
    pos: r['pos'] as String,
    senseIndex: r['sense_index'] as int,
    // The pipeline stores '' when the short form would repeat the full one.
    definitionShort: (r['definition_short'] as String).isEmpty ? r['definition_full'] as String : r['definition_short'] as String,
    definitionFull: r['definition_full'] as String,
    ipa: r['ipa'] as String?,
    freqRank: r['freq_rank'] as int,
    band: r['band'] as String,
  );
}

/// One collection, whichever database it lives in. Bands, topics, idioms
/// and pairs come from the dictionary; `system` (Bookmarks, From my reading)
/// and `user` rows come from the user database. Screens read them through
/// one provider and never ask which is which.
@immutable
class Collection {
  const Collection({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.kind,
    required this.band,
    required this.icon,
    required this.sortOrder,
    required this.wordCount,
    this.color,
  });

  /// The row id in whichever database owns it. Never stored in user data.
  final int id;

  /// The stable id: a dictionary slug, `bookmarks`, `reading`, or `u{n}`.
  final String slug;
  final String title;
  final String description;

  /// band | topic | idiom | pairs | system | user
  final String kind;
  final String? band;
  final String? icon;
  final int sortOrder;
  final int wordCount;

  /// User collections only: an index into `MullColors.tagHues`.
  final int? color;

  /// Lives in the user database: a system or user collection.
  bool get isUsers => kind == 'user' || kind == 'system';

  /// Can be a source in a mix.
  bool get isMixable => kind != 'idiom' && kind != 'pairs';
}

@immutable
class Phrase {
  const Phrase({
    required this.phraseKey,
    required this.phrase,
    required this.phraseNorm,
    required this.type,
    required this.meaning,
    this.usageNote,
    this.example,
    required this.register,
    this.origin,
    this.attribution,
    this.sourceLanguage,
    this.slotPattern,
    required this.freqRank,
    required this.inLearningSet,
  });

  /// `{phrase_norm}|{type}|1`
  final String phraseKey;
  final String phrase;
  final String phraseNorm;
  final String type;
  final String meaning;
  final String? usageNote;
  final String? example;
  final String register;
  final String? origin;
  final String? attribution;
  final String? sourceLanguage;
  final String? slotPattern;
  final int freqRank;
  final bool inLearningSet;

  factory Phrase._from(Row r) => Phrase(
    phraseKey: r['phrase_key'] as String,
    phrase: r['phrase'] as String,
    phraseNorm: r['phrase_norm'] as String,
    type: r['type'] as String,
    meaning: r['meaning'] as String,
    usageNote: r['usage_note'] as String?,
    example: r['example'] as String?,
    register: r['register'] as String,
    origin: r['origin'] as String?,
    attribution: r['attribution'] as String?,
    sourceLanguage: r['source_language'] as String?,
    slotPattern: r['slot_pattern'] as String?,
    freqRank: r['freq_rank'] as int,
    inLearningSet: (r['in_learning_set'] as int) == 1,
  );
}

@immutable
class Idiom {
  const Idiom({
    required this.idiomKey,
    required this.phrase,
    required this.meaning,
    required this.example,
    required this.register,
  });

  final String idiomKey;
  final String phrase;
  final String meaning;
  final String? example;
  final String register;
}

/// The shipped dictionary, opened read-only (rule D3). Never written to by
/// the app; replaced wholesale on update. Nothing here touches user data and
/// nothing here shares a connection with [UserDatabase].
///
/// ponytail: queries run synchronously on the calling isolate. The full
/// dataset answers a search in well under a frame; move to a worker isolate
/// via `Isolate.run` only if profiling on a device shows otherwise.
class DictionaryDb {
  DictionaryDb._(this._db);

  final Database _db;

  static DictionaryDb open(String path) =>
      DictionaryDb._(sqlite3.open(path, mode: OpenMode.readOnly));

  /// Test constructor over an in-memory database the test has populated.
  @visibleForTesting
  DictionaryDb.forTesting(this._db);

  void close() => _db.close();

  String? meta(String key) {
    final ResultSet rs = _db.select(
      'SELECT value FROM meta WHERE key = ?',
      <Object>[key],
    );
    return rs.isEmpty ? null : rs.first['value'] as String;
  }

  String get version => meta('dict_version') ?? 'unknown';

  int get entryCount =>
      _db.select('SELECT count(*) AS n FROM words').first['n'] as int;

  int get headwordCount =>
      _db
              .select('SELECT count(DISTINCT headword_norm) AS n FROM words')
              .first['n']
          as int;

  int get phraseCount =>
      _db.select('SELECT count(*) AS n FROM phrases').first['n'] as int;

  int get idiomCount => phraseCount;

  static const String _cols =
      'word_key, headword, headword_norm, pos, sense_index, definition_short, '
      'definition_full, ipa, freq_rank, band';

  DictionaryWord? byKey(String wordKey) {
    final ResultSet rs = _db.select(
      'SELECT $_cols FROM words WHERE word_key = ?',
      <Object>[wordKey],
    );
    return rs.isEmpty ? null : DictionaryWord._from(rs.first);
  }

  List<DictionaryWord> byKeys(Iterable<String> keys) {
    final List<String> list = keys.toList();
    if (list.isEmpty) return const <DictionaryWord>[];
    final String marks = List<String>.filled(list.length, '?').join(',');
    return _db
        .select('SELECT $_cols FROM words WHERE word_key IN ($marks)', list)
        .map(DictionaryWord._from)
        .toList();
  }

  List<Phrase> phrasesByKeys(Iterable<String> keys) {
    final List<String> list = keys.toList();
    if (list.isEmpty) return const <Phrase>[];
    final String marks = List<String>.filled(list.length, '?').join(',');
    return _db
        .select('SELECT $_phraseCols FROM phrases WHERE phrase_key IN ($marks)', list)
        .map(Phrase._from)
        .toList();
  }

  /// Every sense of a headword, grouped by part of speech in dictionary order.
  List<DictionaryWord> senses(String headwordNorm) => _db
      .select(
        'SELECT $_cols FROM words WHERE headword_norm = ? ORDER BY id',
        <Object>[headwordNorm],
      )
      .map(DictionaryWord._from)
      .toList();

  List<String> examples(String wordKey) => _db
      .select('SELECT text FROM examples WHERE word_key = ? ORDER BY id', <Object>[
        wordKey,
      ])
      .map((Row r) => r['text'] as String)
      .toList();

  List<String> synonyms(String wordKey) => _db
      .select(
        'SELECT synonym FROM synonyms WHERE word_key = ? ORDER BY id',
        <Object>[wordKey],
      )
      .map((Row r) => r['synonym'] as String)
      .toList();

  /// The US spelling of a headword, if the dictionary carries one.
  String? usSpelling(String wordKey) {
    final ResultSet rs = _db.select(
      "SELECT alias_norm FROM aliases WHERE word_key = ? AND kind = 'us_spelling'",
      <Object>[wordKey],
    );
    return rs.isEmpty ? null : rs.first['alias_norm'] as String;
  }

  /// Rule D5. Exact, then prefix, then FTS, then trigram for typos. Results
  /// are deduplicated by headword so a word with four senses is one row.
  List<DictionaryWord> search(String query, {int limit = 30}) {
    final String q = normalise(query);
    if (q.isEmpty) return const <DictionaryWord>[];
    final Map<String, DictionaryWord> out = <String, DictionaryWord>{};

    void take(ResultSet rs) {
      for (final Row r in rs) {
        if (out.length >= limit) return;
        out.putIfAbsent(r['headword_norm'] as String, () => DictionaryWord._from(r));
      }
    }

    // Exact headword, then an alias (US spelling, inflection) that resolves.
    take(
      _db.select(
        'SELECT $_cols FROM words WHERE headword_norm = ? AND sense_index = 1 '
        'ORDER BY id',
        <Object>[q],
      ),
    );
    take(
      _db.select(
        'SELECT w.$_colsW FROM aliases a JOIN words w ON w.word_key = a.word_key '
        'WHERE a.alias_norm = ? ORDER BY w.freq_rank',
        <Object>[q],
      ),
    );
    if (out.length < limit) {
      // A headword with several parts of speech is several sense-1 rows, so
      // fetch headroom for the dedupe: a common prefix must fill the page
      // here, or the FTS rung below scans every definition containing it.
      take(
        _db.select(
          'SELECT $_cols FROM words WHERE headword_norm > ? AND headword_norm < ? '
          'AND sense_index = 1 ORDER BY freq_rank LIMIT ?',
          <Object>[q, '$q￿', limit * 3],
        ),
      );
    }
    if (out.length < limit && q.length >= 3) {
      take(
        _db.select(
          'SELECT w.$_colsW FROM words_fts f JOIN words w ON w.id = f.rowid '
          'WHERE words_fts MATCH ? ORDER BY bm25(words_fts), w.freq_rank LIMIT ?',
          <Object>[_ftsQuery(q), limit],
        ),
      );
    }
    if (out.length < limit && q.length >= 3) {
      for (final DictionaryWord w in _fuzzy(q, limit - out.length)) {
        out.putIfAbsent(w.headwordNorm, () => w);
      }
    }
    return out.values.toList();
  }

  static const String _colsW =
      'word_key, w.headword, w.headword_norm, w.pos, w.sense_index, '
      'w.definition_short, w.definition_full, w.ipa, w.freq_rank, w.band';

  /// A safe FTS5 query: every token quoted, prefix-matched, AND-ed.
  static String _ftsQuery(String q) =>
      q.split(' ').where((String t) => t.isNotEmpty).map((String t) => '"$t"*').join(' ');

  /// The single-word "Did you mean" candidate for a query with no results.
  String? suggest(String query) {
    final String q = normalise(query);
    final List<DictionaryWord> hits = _fuzzy(q, 1);
    return hits.isEmpty ? null : hits.first.headword;
  }

  /// The typo rung. Any trigram of the query pulls a candidate from the
  /// trigram index; candidates are then ranked by Damerau-Levenshtein
  /// distance to the query, then frequency, and only near misses survive.
  List<DictionaryWord> _fuzzy(String q, int limit) {
    if (q.length < 3 || limit <= 0) return const <DictionaryWord>[];
    final Set<String> grams = <String>{
      for (int i = 0; i + 3 <= q.length; i++) q.substring(i, i + 3),
    };
    final String match = grams.map((String g) => '"$g"').join(' OR ');
    final ResultSet rs = _db.select(
      'SELECT w.$_colsW FROM words_trigram t JOIN words w ON w.id = t.rowid '
      'WHERE words_trigram MATCH ? AND w.sense_index = 1 '
      'ORDER BY bm25(words_trigram), w.freq_rank LIMIT 300',
      <Object>[match],
    );
    final int tolerance = q.length <= 5 ? 1 : 2;
    final List<(int, DictionaryWord)> scored = <(int, DictionaryWord)>[];
    for (final Row r in rs) {
      final DictionaryWord w = DictionaryWord._from(r);
      final int d = _editDistance(q, w.headwordNorm);
      if (d <= tolerance) scored.add((d, w));
    }
    scored.sort(
      ((int, DictionaryWord) a, (int, DictionaryWord) b) =>
          a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.freqRank.compareTo(b.$2.freqRank),
    );
    return scored.take(limit).map(((int, DictionaryWord) e) => e.$2).toList();
  }

  /// Damerau-Levenshtein (optimal string alignment): a transposition costs 1.
  static int _editDistance(String a, String b) {
    final List<List<int>> d = List<List<int>>.generate(
      a.length + 1,
      (int i) => List<int>.filled(b.length + 1, 0),
    );
    for (int i = 0; i <= a.length; i++) {
      d[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      d[0][j] = j;
    }
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final int cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        int v = d[i - 1][j - 1] + cost;
        if (d[i - 1][j] + 1 < v) v = d[i - 1][j] + 1;
        if (d[i][j - 1] + 1 < v) v = d[i][j - 1] + 1;
        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1) &&
            d[i - 2][j - 2] + 1 < v) {
          v = d[i - 2][j - 2] + 1;
        }
        d[i][j] = v;
      }
    }
    return d[a.length][b.length];
  }

  static const String _phraseCols =
      'phrase_key, phrase, phrase_norm, type, meaning, usage_note, example, '
      'register, origin, attribution, source_language, slot_pattern, freq_rank, in_learning_set';

  List<Phrase> searchPhrases(String query, {int limit = 30}) {
    final String q = normalise(query);
    if (q.isEmpty) return const <Phrase>[];
    return _db
        .select(
          'SELECT $_phraseCols FROM phrases '
          "WHERE phrase_norm LIKE '%' || ? || '%' ORDER BY length(phrase_norm) LIMIT ?",
          <Object>[q, limit],
        )
        .map(Phrase._from)
        .toList();
  }

  List<Idiom> searchIdioms(String query, {int limit = 30}) {
    final String q = normalise(query);
    if (q.isEmpty) return const <Idiom>[];
    return _db
        .select(
          'SELECT phrase_key AS idiom_key, phrase, meaning, example, register FROM phrases '
          "WHERE phrase_norm LIKE '%' || ? || '%' ORDER BY length(phrase_norm) LIMIT ?",
          <Object>[q, limit],
        )
        .map(_idiomFrom)
        .toList();
  }

  List<Collection> collections() => _db
      .select(
        'SELECT c.id, c.slug, c.title, c.description, c.kind, c.band, c.icon, '
        'c.sort_order, (SELECT count(*) FROM collection_words cw WHERE cw.collection_id = c.id) AS n '
        // The pairs kind needs a two-word card the app does not have yet.
        "FROM collections c WHERE c.kind != 'pairs' ORDER BY c.sort_order",
      )
      .map(
        (Row r) => Collection(
          id: r['id'] as int,
          slug: r['slug'] as String,
          title: r['title'] as String,
          description: r['description'] as String,
          kind: r['kind'] as String,
          band: r['band'] as String?,
          icon: r['icon'] as String?,
          sortOrder: r['sort_order'] as int,
          wordCount: r['n'] as int,
        ),
      )
      .toList();

  /// Word keys of every collection in [slugs], deduplicated, in position order.
  List<String> collectionWordKeys(Iterable<String> slugs) {
    final List<String> list = slugs.toList();
    if (list.isEmpty) return const <String>[];
    final String marks = List<String>.filled(list.length, '?').join(',');
    return _db
        .select(
          'SELECT DISTINCT cw.word_key FROM collection_words cw '
          'JOIN collections c ON c.id = cw.collection_id '
          'WHERE c.slug IN ($marks) ORDER BY cw.position',
          list,
        )
        .map((Row r) => r['word_key'] as String)
        .toList();
  }

  /// Slugs of the collections a word belongs to.
  List<String> collectionsOf(String wordKey) => _db
      .select(
        'SELECT c.slug FROM collection_words cw JOIN collections c ON c.id = cw.collection_id '
        'WHERE cw.word_key = ? ORDER BY c.sort_order',
        <Object>[wordKey],
      )
      .map((Row r) => r['slug'] as String)
      .toList();

  /// The inflections the dictionary knows for a word (plural, past...).
  List<String> inflections(String wordKey) => _db
      .select(
        "SELECT alias_norm FROM aliases WHERE word_key = ? AND kind = 'inflection' ORDER BY rowid",
        <Object>[wordKey],
      )
      .map((Row r) => r['alias_norm'] as String)
      .toList();

  /// Members of a phrase collection, in position order.
  List<Phrase> collectionPhrases(String slug) => _db
      .select(
        'SELECT p.$_phraseCols FROM collection_words cw '
        'JOIN collections c ON c.id = cw.collection_id '
        'JOIN phrases p ON p.phrase_key = cw.word_key '
        'WHERE c.slug = ? ORDER BY cw.position',
        <Object>[slug],
      )
      .map(Phrase._from)
      .toList();

  /// Members of an idiom collection, in position order. For kind = idiom,
  /// `collection_words.word_key` holds an `idiom_key` / `phrase_key`.
  List<Idiom> collectionIdioms(String slug) => _db
      .select(
        'SELECT p.phrase_key AS idiom_key, p.phrase, p.meaning, p.example, p.register FROM collection_words cw '
        'JOIN collections c ON c.id = cw.collection_id '
        'JOIN phrases p ON p.phrase_key = cw.word_key '
        'WHERE c.slug = ? ORDER BY cw.position',
        <Object>[slug],
      )
      .map(_idiomFrom)
      .toList();

  /// Look up a phrase by key. If [key] matches a legacy idiom key
  /// `{phrase_norm}|idiom|1`, it resolves by phrase_norm to the canonical phrase.
  Phrase? phraseByKey(String key) {
    final ResultSet rs = _db.select(
      'SELECT $_phraseCols FROM phrases WHERE phrase_key = ?',
      <Object>[key],
    );
    if (rs.isNotEmpty) return Phrase._from(rs.first);
    if (key.contains('|')) {
      final String norm = key.split('|').first;
      final ResultSet byNorm = _db.select(
        'SELECT $_phraseCols FROM phrases WHERE phrase_norm = ? LIMIT 1',
        <Object>[norm],
      );
      if (byNorm.isNotEmpty) return Phrase._from(byNorm.first);
    }
    return null;
  }

  Idiom? idiomByKey(String key) {
    final Phrase? p = phraseByKey(key);
    if (p == null) return null;
    return Idiom(
      idiomKey: p.phraseKey,
      phrase: p.phrase,
      meaning: p.meaning,
      example: p.example,
      register: p.register,
    );
  }

  static Idiom _idiomFrom(Row r) => Idiom(
    idiomKey: r['idiom_key'] as String,
    phrase: r['phrase'] as String,
    meaning: r['meaning'] as String,
    example: r['example'] as String?,
    register: r['register'] as String,
  );

  /// Members of one collection, in position order.
  List<DictionaryWord> collectionWords(String slug) => _db
      .select(
        'SELECT w.$_colsW FROM collection_words cw '
        'JOIN collections c ON c.id = cw.collection_id '
        'JOIN words w ON w.word_key = cw.word_key '
        'WHERE c.slug = ? ORDER BY cw.position',
        <Object>[slug],
      )
      .map(DictionaryWord._from)
      .toList();

  /// The same normalisation the build pipeline applies to `headword_norm`:
  /// lowercase, diacritics stripped, punctuation removed, whitespace collapsed.
  static String normalise(String s) {
    final StringBuffer b = StringBuffer();
    for (final int cu in s.toLowerCase().runes) {
      final String ch = String.fromCharCode(cu);
      final String? plain = _diacritics[ch];
      if (plain != null) {
        b.write(plain);
      } else if (ch == '-') {
        b.write(' ');
      } else if ((cu >= 0x61 && cu <= 0x7a) || (cu >= 0x30 && cu <= 0x39) || cu == 0x20) {
        b.write(ch);
      }
    }
    return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const Map<String, String> _diacritics = <String, String>{
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'æ': 'ae',
    'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ì': 'i', 'í': 'i',
    'î': 'i', 'ï': 'i', 'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o',
    'ö': 'o', 'ø': 'o', 'œ': 'oe', 'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y', 'ß': 'ss',
  };
}
