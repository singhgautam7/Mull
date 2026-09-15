import 'package:drift/drift.dart';

import 'user_db.dart';

/// Bookmarks, notes, lists, seen state, lookups and app state. Owns the user
/// connection and nothing else (rule D3); every word is a `word_key` string
/// (rule D4).
class UserRepository {
  UserRepository(this._db);

  final UserDatabase _db;

  /// The name of the list search results land in.
  static const String readingListName = 'From my reading';

  // ---------------------------------------------------------------- bookmarks

  Future<bool> isBookmarked(String wordKey) async =>
      (await (_db.select(_db.bookmarks)
                ..where((Bookmarks b) => b.wordKey.equals(wordKey)))
              .getSingleOrNull()) !=
      null;

  /// Returns the new state.
  Future<bool> toggleBookmark(String wordKey, {DateTime? now}) async {
    if (await isBookmarked(wordKey)) {
      await removeBookmark(wordKey);
      return false;
    }
    await addBookmark(wordKey, now: now);
    return true;
  }

  Future<void> addBookmark(String wordKey, {DateTime? now}) => _db
      .into(_db.bookmarks)
      .insert(
        BookmarksCompanion.insert(
          wordKey: wordKey,
          createdAt: now ?? DateTime.now(),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  Future<void> removeBookmark(String wordKey) =>
      (_db.delete(_db.bookmarks)
            ..where((Bookmarks b) => b.wordKey.equals(wordKey)))
          .go();

  Future<List<String>> bookmarkedKeys() async =>
      (await (_db.select(_db.bookmarks)
                ..orderBy(<OrderingTerm Function(Bookmarks)>[
                  (Bookmarks b) => OrderingTerm.desc(b.createdAt),
                ]))
              .get())
          .map((Bookmark b) => b.wordKey)
          .toList();

  Stream<Set<String>> watchBookmarkedKeys() => _db
      .select(_db.bookmarks)
      .watch()
      .map((List<Bookmark> rows) => rows.map((Bookmark b) => b.wordKey).toSet());

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

  // ---------------------------------------------------------------- lists

  Stream<List<WordList>> watchLists() => (_db.select(_db.wordLists)
        ..orderBy(<OrderingTerm Function(WordLists)>[
          (WordLists l) => OrderingTerm.desc(l.isReading),
          (WordLists l) => OrderingTerm.asc(l.createdAt),
        ]))
      .watch();

  Future<List<WordList>> lists() => (_db.select(_db.wordLists)
        ..orderBy(<OrderingTerm Function(WordLists)>[
          (WordLists l) => OrderingTerm.desc(l.isReading),
          (WordLists l) => OrderingTerm.asc(l.createdAt),
        ]))
      .get();

  Future<WordList?> list(int id) => (_db.select(_db.wordLists)
        ..where((WordLists l) => l.id.equals(id)))
      .getSingleOrNull();

  /// "From my reading" exists from first run; search results land in it.
  Future<WordList> readingList() async {
    final WordList? existing = await (_db.select(_db.wordLists)
          ..where((WordLists l) => l.isReading.equals(true)))
        .getSingleOrNull();
    if (existing != null) return existing;
    final int id = await _db
        .into(_db.wordLists)
        .insert(
          WordListsCompanion.insert(
            name: readingListName,
            isReading: const Value<bool>(true),
            createdAt: DateTime.now(),
          ),
        );
    return (await list(id))!;
  }

  Future<int> createList(String name, {int? color, DateTime? now}) => _db
      .into(_db.wordLists)
      .insert(
        WordListsCompanion.insert(
          name: name,
          color: Value<int?>(color),
          createdAt: now ?? DateTime.now(),
        ),
      );

  Future<void> renameList(int id, String name) =>
      (_db.update(_db.wordLists)..where((WordLists l) => l.id.equals(id)))
          .write(WordListsCompanion(name: Value<String>(name)));

  Future<void> setListColor(int id, int? color) =>
      (_db.update(_db.wordLists)..where((WordLists l) => l.id.equals(id)))
          .write(WordListsCompanion(color: Value<int?>(color)));

  Future<void> deleteList(int id) =>
      (_db.delete(_db.wordLists)..where((WordLists l) => l.id.equals(id))).go();

  Future<void> addToList(int listId, String wordKey, {DateTime? now}) => _db
      .into(_db.listWords)
      .insert(
        ListWordsCompanion.insert(
          listId: listId,
          wordKey: wordKey,
          addedAt: now ?? DateTime.now(),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  Future<void> removeFromList(int listId, String wordKey) =>
      (_db.delete(_db.listWords)
            ..where(
              (ListWords l) =>
                  l.listId.equals(listId) & l.wordKey.equals(wordKey),
            ))
          .go();

  Future<List<String>> listWordKeys(int listId) async =>
      (await (_db.select(_db.listWords)
                ..where((ListWords l) => l.listId.equals(listId))
                ..orderBy(<OrderingTerm Function(ListWords)>[
                  (ListWords l) => OrderingTerm.asc(l.position),
                  (ListWords l) => OrderingTerm.desc(l.addedAt),
                ]))
              .get())
          .map((ListWord l) => l.wordKey)
          .toList();

  Stream<List<String>> watchListWordKeys(int listId) => (_db.select(_db.listWords)
        ..where((ListWords l) => l.listId.equals(listId))
        ..orderBy(<OrderingTerm Function(ListWords)>[
          (ListWords l) => OrderingTerm.asc(l.position),
          (ListWords l) => OrderingTerm.desc(l.addedAt),
        ]))
      .watch()
      .map((List<ListWord> rows) => rows.map((ListWord l) => l.wordKey).toList());

  /// Which lists hold a word.
  Future<Set<int>> listsContaining(String wordKey) async =>
      (await (_db.select(_db.listWords)
                ..where((ListWords l) => l.wordKey.equals(wordKey)))
              .get())
          .map((ListWord l) => l.listId)
          .toSet();

  /// Word count per list id.
  Stream<Map<int, int>> watchListCounts() =>
      _db.select(_db.listWords).watch().map((List<ListWord> rows) {
        final Map<int, int> m = <int, int>{};
        for (final ListWord r in rows) {
          m[r.listId] = (m[r.listId] ?? 0) + 1;
        }
        return m;
      });

  Future<void> reorderList(int listId, List<String> orderedKeys) =>
      _db.batch((Batch b) {
        for (int i = 0; i < orderedKeys.length; i++) {
          b.update(
            _db.listWords,
            ListWordsCompanion(position: Value<int>(i)),
            where: (ListWords l) =>
                l.listId.equals(listId) & l.wordKey.equals(orderedKeys[i]),
          );
        }
      });

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
  }

  // ---------------------------------------------------------------- app state

  Future<String?> appState(String key) async =>
      (await (_db.select(_db.appState)
                ..where((AppState a) => a.key.equals(key)))
              .getSingleOrNull())
          ?.value;

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
}
