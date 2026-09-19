import 'package:drift/drift.dart';

import 'dictionary_db.dart';
import 'user_db.dart';

/// Collections (bookmarks, reading, user lists), notes, seen state, lookups
/// and app state. Owns the user connection and nothing else (rule D3); every
/// word is a `word_key` string (rule D4).
class UserRepository {
  UserRepository(this._db);

  final UserDatabase _db;

  // ---------------------------------------------------------------- collections

  /// The two system collections. Auto-populated, never deleted.
  static const String bookmarksSlug = 'bookmarks';
  static const String readingSlug = 'reading';
  static const String readingListName = 'From my reading';

  static const Map<String, String> _systemNames = <String, String>{
    bookmarksSlug: 'Bookmarks',
    readingSlug: readingListName,
  };

  /// Creates the system rows if they are missing. Called once the user
  /// database is open, and again after a reset.
  Future<void> ensureSystemCollections() async {
    for (final String slug in _systemNames.keys) {
      await _idOf(slug);
    }
  }

  /// The row id behind a slug. A missing system row is created on demand so
  /// The row id behind a slug. A missing system row is created on demand so
  /// a bookmark can never land nowhere. Any collection (even built-in) gets an
  /// on-demand row so words can be added to it.
  Future<int?> _idOf(String slug) async {
    final UserCollection? row = await (_db.select(_db.userCollections)
          ..where((UserCollections c) => c.slug.equals(slug)))
        .getSingleOrNull();
    if (row != null) return row.id;
    final String? name = _systemNames[slug];
    return _db
        .into(_db.userCollections)
        .insert(
          UserCollectionsCompanion.insert(
            slug: slug,
            kind: name != null ? 'system' : 'builtin',
            name: name ?? slug,
            createdAt: DateTime.now(),
          ),
        );
  }

  /// System rows first (Bookmarks, then From my reading), then user
  /// collections in creation order. Builtin extension rows are excluded.
  Stream<List<UserCollection>> watchCollections() => (_db.select(_db.userCollections)
        ..where((UserCollections c) => c.kind.isNotIn(const <String>['builtin']))
        ..orderBy(<OrderingTerm Function(UserCollections)>[
          (UserCollections c) => OrderingTerm.desc(c.kind.equals('system')),
          (UserCollections c) => OrderingTerm.asc(c.slug.equals(readingSlug)),
          (UserCollections c) => OrderingTerm.asc(c.createdAt),
        ]))
      .watch();

  Future<List<UserCollection>> collections() => watchCollections().first;

  Future<UserCollection?> collection(String slug) => (_db.select(_db.userCollections)
        ..where((UserCollections c) => c.slug.equals(slug)))
      .getSingleOrNull();

  /// Returns the new collection's slug.
  Future<String> createCollection(String name, {int? color, DateTime? now}) async {
    final DateTime at = now ?? DateTime.now();
    final String slug = 'u${at.microsecondsSinceEpoch}';
    await _db
        .into(_db.userCollections)
        .insert(
          UserCollectionsCompanion.insert(
            slug: slug,
            kind: 'user',
            name: name,
            color: Value<int?>(color),
            createdAt: at,
          ),
        );
    return slug;
  }

  Future<void> renameCollection(String slug, String name) =>
      (_db.update(_db.userCollections)..where((UserCollections c) => c.slug.equals(slug)))
          .write(UserCollectionsCompanion(name: Value<String>(name)));

  Future<void> setCollectionColor(String slug, int? color) =>
      (_db.update(_db.userCollections)..where((UserCollections c) => c.slug.equals(slug)))
          .write(UserCollectionsCompanion(color: Value<int?>(color)));

  /// System collections cannot be deleted; the call is a no-op for them.
  Future<void> deleteCollection(String slug) => (_db.delete(_db.userCollections)
        ..where((UserCollections c) => c.slug.equals(slug) & c.kind.equals('user')))
      .go();

  Future<void> addToCollection(String slug, String wordKey, {DateTime? now}) async {
    final int? id = await _idOf(slug);
    if (id == null) return;
    await _db
        .into(_db.userCollectionWords)
        .insert(
          UserCollectionWordsCompanion.insert(
            collectionId: id,
            wordKey: wordKey,
            addedAt: now ?? DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> removeFromCollection(String slug, String wordKey) async {
    final int? id = await _idOf(slug);
    if (id == null) return;
    await (_db.delete(_db.userCollectionWords)
          ..where(
            (UserCollectionWords w) => w.collectionId.equals(id) & w.wordKey.equals(wordKey),
          ))
        .go();
  }

  JoinedSelectStatement<HasResultSet, dynamic> _wordsJoin() =>
      _db.select(_db.userCollectionWords).join(<Join<HasResultSet, dynamic>>[
        innerJoin(
          _db.userCollections,
          _db.userCollections.id.equalsExp(_db.userCollectionWords.collectionId),
        ),
      ])
        ..orderBy(<OrderingTerm>[
          OrderingTerm.asc(_db.userCollectionWords.position),
          OrderingTerm.desc(_db.userCollectionWords.addedAt),
        ]);

  /// Word keys of one collection: by position, then newest first.
  Future<List<String>> collectionWordKeys(String slug) => collectionWordKeysFor(<String>[slug]);

  /// Word keys of every collection in [slugs], deduplicated. Slugs that name
  /// a dictionary collection are simply not here; the queue builder unions
  /// the two.
  Future<List<String>> collectionWordKeysFor(Iterable<String> slugs) async {
    final List<String> list = slugs.toList();
    if (list.isEmpty) return const <String>[];
    final List<TypedResult> rows = await (_wordsJoin()
          ..where(_db.userCollections.slug.isIn(list)))
        .get();
    return <String>{
      for (final TypedResult r in rows) r.readTable(_db.userCollectionWords).wordKey,
    }.toList();
  }

  /// Every collection's word keys, live, by slug.
  Stream<Map<String, List<String>>> watchCollectionWordKeys() =>
      _wordsJoin().watch().map((List<TypedResult> rows) {
        final Map<String, List<String>> m = <String, List<String>>{};
        for (final TypedResult r in rows) {
          m
              .putIfAbsent(r.readTable(_db.userCollections).slug, () => <String>[])
              .add(r.readTable(_db.userCollectionWords).wordKey);
        }
        return m;
      });

  /// Slugs of the collections holding a word.
  Future<Set<String>> collectionsContaining(String wordKey) async {
    final List<TypedResult> rows = await (_wordsJoin()
          ..where(_db.userCollectionWords.wordKey.equals(wordKey)))
        .get();
    return <String>{for (final TypedResult r in rows) r.readTable(_db.userCollections).slug};
  }

  /// For list reorder by drag (HANDOFF 3.7), when it lands.
  Future<void> reorderCollection(String slug, List<String> orderedKeys) async {
    final int? id = await _idOf(slug);
    if (id == null) return;
    await _db.batch((Batch b) {
      for (int i = 0; i < orderedKeys.length; i++) {
        b.update(
          _db.userCollectionWords,
          UserCollectionWordsCompanion(position: Value<int>(i)),
          where: (UserCollectionWords w) =>
              w.collectionId.equals(id) & w.wordKey.equals(orderedKeys[i]),
        );
      }
    });
  }

  // ---------------------------------------------------------------- bookmarks

  /// Bookmarks are the `bookmarks` system collection; these are its verbs.

  Future<bool> isBookmarked(String wordKey) async =>
      (await collectionsContaining(wordKey)).contains(bookmarksSlug);

  /// Returns the new state.
  Future<bool> toggleBookmark(String wordKey, {DateTime? now}) async {
    if (await isBookmarked(wordKey)) {
      await removeBookmark(wordKey);
      return false;
    }
    await addBookmark(wordKey, now: now);
    return true;
  }

  Future<void> addBookmark(String wordKey, {DateTime? now}) =>
      addToCollection(bookmarksSlug, wordKey, now: now);

  Future<void> removeBookmark(String wordKey) => removeFromCollection(bookmarksSlug, wordKey);

  /// Newest first.
  Future<List<String>> bookmarkedKeys() => collectionWordKeys(bookmarksSlug);

  Stream<Set<String>> watchBookmarkedKeys() => (_wordsJoin()
        ..where(_db.userCollections.slug.equals(bookmarksSlug)))
      .watch()
      .map(
        (List<TypedResult> rows) => <String>{
          for (final TypedResult r in rows) r.readTable(_db.userCollectionWords).wordKey,
        },
      );

  // ---------------------------------------------------------------- notes

  Future<String?> note(String wordKey) async =>
      (await (_db.select(_db.notes)
                ..where((Notes n) => n.wordKey.equals(wordKey)))
              .getSingleOrNull())
          ?.body;

  Stream<String?> watchNote(String wordKey) => (_db.select(_db.notes)
        ..where((Notes n) => n.wordKey.equals(wordKey)))
      .watchSingleOrNull()
      .map((Note? n) => n?.body);

  /// Empty text deletes the note; there is no such thing as an empty note.
  Future<void> putNote(String wordKey, String body, {DateTime? now}) async {
    if (body.trim().isEmpty) {
      await (_db.delete(_db.notes)
            ..where((Notes n) => n.wordKey.equals(wordKey)))
          .go();
      return;
    }
    await _db
        .into(_db.notes)
        .insertOnConflictUpdate(
          NotesCompanion.insert(
            wordKey: wordKey,
            body: body,
            updatedAt: now ?? DateTime.now(),
          ),
        );
  }

  Future<Map<String, String>> allNotes() async {
    final List<Note> rows = await _db.select(_db.notes).get();
    return <String, String>{for (final Note n in rows) n.wordKey: n.body};
  }

  Future<int> noteCount() async {
    final Expression<int> n = _db.notes.wordKey.count();
    final TypedResult r = await (_db.selectOnly(_db.notes)
          ..addColumns(<Expression<Object>>[n]))
        .getSingle();
    return r.read(n) ?? 0;
  }

  Future<void> clearNotes() => _db.delete(_db.notes).go();

  // ---------------------------------------------------------------- seen

  /// Written on card exit after the dwell threshold, never on entry.
  Future<void> markSeen(String wordKey, {DateTime? now}) async {
    final DateTime at = now ?? DateTime.now();
    await _db.transaction(() async {
      final SeenWord? row = await (_db.select(_db.seen)
            ..where((Seen s) => s.wordKey.equals(wordKey)))
          .getSingleOrNull();
      await _db
          .into(_db.seen)
          .insertOnConflictUpdate(
            SeenCompanion.insert(
              wordKey: wordKey,
              seenCount: Value<int>((row?.seenCount ?? 0) + 1),
              firstSeenAt: row?.firstSeenAt ?? at,
              lastSeenAt: at,
            ),
          );
      await _db
          .into(_db.seenEvents)
          .insert(SeenEventsCompanion.insert(wordKey: wordKey, at: at));
    });
  }

  /// Seen state for every word in [keys]; a key with no row is unseen.
  Future<Map<String, SeenWord>> seenStates(Iterable<String> keys) async {
    final List<String> list = keys.toList();
    if (list.isEmpty) return const <String, SeenWord>{};
    final List<SeenWord> rows = await (_db.select(_db.seen)
          ..where((Seen s) => s.wordKey.isIn(list)))
        .get();
    return <String, SeenWord>{for (final SeenWord r in rows) r.wordKey: r};
  }

  Future<Map<String, SeenWord>> allSeen() async {
    final List<SeenWord> rows = await _db.select(_db.seen).get();
    return <String, SeenWord>{for (final SeenWord r in rows) r.wordKey: r};
  }

  Stream<Map<String, SeenWord>> watchAllSeen() =>
      _db.select(_db.seen).watch().map(
            (List<SeenWord> rows) =>
                <String, SeenWord>{for (final SeenWord r in rows) r.wordKey: r},
          );

  Future<List<SeenEvent>> seenEventsSince(DateTime since) =>
      (_db.select(_db.seenEvents)
            ..where((SeenEvents e) => e.at.isBiggerOrEqualValue(since))
            ..orderBy(<OrderingTerm Function(SeenEvents)>[
              (SeenEvents e) => OrderingTerm.asc(e.at),
            ]))
          .get();

  Future<List<SeenEvent>> allSeenEvents() => (_db.select(_db.seenEvents)
        ..orderBy(<OrderingTerm Function(SeenEvents)>[
          (SeenEvents e) => OrderingTerm.asc(e.at),
        ]))
      .get();

  Future<List<SeenWord>> mostRevisited({int limit = 8}) =>
      (_db.select(_db.seen)
            ..where((Seen s) => s.seenCount.isBiggerThanValue(1))
            ..orderBy(<OrderingTerm Function(Seen)>[
              (Seen s) => OrderingTerm.desc(s.seenCount),
              (Seen s) => OrderingTerm.desc(s.lastSeenAt),
            ])
            ..limit(limit))
          .get();

  Future<void> clearSeen() async {
    await _db.delete(_db.seen).go();
    await _db.delete(_db.seenEvents).go();
  }

  /// Reset everything: every table. The dictionary is untouched (rule D3).
  Future<void> resetAll() async {
    await _db.transaction(() async {
      for (final TableInfo<Table, Object?> t in _db.allTables) {
        await _db.delete(t).go();
      }
    });
    await ensureSystemCollections();
  }

  // ---------------------------------------------------------------- app state

  /// The slug of the collection opened most recently.
  static const String kLastOpened = 'last_opened_collection';

  Future<String?> appState(String key) async =>
      (await (_db.select(_db.appState)
                ..where((AppState a) => a.key.equals(key)))
              .getSingleOrNull())
          ?.value;

  Stream<String?> watchAppState(String key) => (_db.select(_db.appState)
        ..where((AppState a) => a.key.equals(key)))
      .watchSingleOrNull()
      .map((AppStateRow? r) => r?.value);

  Future<void> setAppState(String key, String? value) async {
    if (value == null) {
      await (_db.delete(_db.appState)
            ..where((AppState a) => a.key.equals(key)))
          .go();
      return;
    }
    await _db
        .into(_db.appState)
        .insertOnConflictUpdate(
          AppStateCompanion.insert(key: key, value: value),
        );
  }

  // ---------------------------------------------------------------- searches

  Future<void> recordSearch(String query, {DateTime? now}) => _db
      .into(_db.recentSearches)
      .insertOnConflictUpdate(
        RecentSearchesCompanion.insert(
          query: query,
          at: now ?? DateTime.now(),
        ),
      );

  Future<List<String>> recentSearches({int limit = 12}) async =>
      (await (_db.select(_db.recentSearches)
                ..orderBy(<OrderingTerm Function(RecentSearches)>[
                  (RecentSearches r) => OrderingTerm.desc(r.at),
                ])
                ..limit(limit))
              .get())
          .map((RecentSearch r) => r.query)
          .toList();

  Future<void> recordLookup(String wordKey, {DateTime? now}) => _db
      .into(_db.recentLookups)
      .insertOnConflictUpdate(
        RecentLookupsCompanion.insert(
          wordKey: wordKey,
          at: now ?? DateTime.now(),
        ),
      );

  Stream<List<String>> watchRecentLookups({int limit = 12}) =>
      (_db.select(_db.recentLookups)
            ..orderBy(<OrderingTerm Function(RecentLookups)>[
              (RecentLookups r) => OrderingTerm.desc(r.at),
            ])
            ..limit(limit))
          .watch()
          .map((List<RecentLookup> rows) => rows.map((RecentLookup r) => r.wordKey).toList());

  /// Rule D4 forward migration: remapped phrase types.
  /// If a user saved a legacy `{phrase_norm}|idiom|1` key and the phrase was
  /// reclassified (e.g. to proverb or binomial), updates all user tables
  /// to the new canonical `phrase_key`.
  Future<int> migrateLegacyPhraseKeys(DictionaryDb dict) async {
    int count = 0;
    final List<QueryRow> rows = await _db.customSelect(
      "SELECT DISTINCT word_key FROM user_collection_words WHERE word_key LIKE '%|idiom|1' "
      "UNION SELECT DISTINCT word_key FROM notes WHERE word_key LIKE '%|idiom|1' "
      "UNION SELECT DISTINCT word_key FROM seen WHERE word_key LIKE '%|idiom|1' "
      "UNION SELECT DISTINCT word_key FROM recent_lookups WHERE word_key LIKE '%|idiom|1'",
    ).get();

    for (final QueryRow r in rows) {
      final String oldKey = r.read<String>('word_key');
      final Phrase? phrase = dict.phraseByKey(oldKey);
      if (phrase != null && phrase.phraseKey != oldKey) {
        final String newKey = phrase.phraseKey;
        await _db.customUpdate(
          'UPDATE OR REPLACE user_collection_words SET word_key = ? WHERE word_key = ?',
          variables: <Variable<Object>>[Variable<String>(newKey), Variable<String>(oldKey)],
          updates: <TableInfo<Table, Object?>>{_db.userCollectionWords},
        );
        await _db.customUpdate(
          'UPDATE OR REPLACE notes SET word_key = ? WHERE word_key = ?',
          variables: <Variable<Object>>[Variable<String>(newKey), Variable<String>(oldKey)],
          updates: <TableInfo<Table, Object?>>{_db.notes},
        );
        await _db.customUpdate(
          'UPDATE OR REPLACE seen SET word_key = ? WHERE word_key = ?',
          variables: <Variable<Object>>[Variable<String>(newKey), Variable<String>(oldKey)],
          updates: <TableInfo<Table, Object?>>{_db.seen},
        );
        await _db.customUpdate(
          'UPDATE recent_lookups SET word_key = ? WHERE word_key = ?',
          variables: <Variable<Object>>[Variable<String>(newKey), Variable<String>(oldKey)],
          updates: <TableInfo<Table, Object?>>{_db.recentLookups},
        );
        await _db.customUpdate(
          'UPDATE seen_events SET word_key = ? WHERE word_key = ?',
          variables: <Variable<Object>>[Variable<String>(newKey), Variable<String>(oldKey)],
          updates: <TableInfo<Table, Object?>>{_db.seenEvents},
        );
        count++;
      }
    }
    return count;
  }
}
