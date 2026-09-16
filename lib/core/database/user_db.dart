import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'user_db.g.dart';

/// Rule D4: user data references a word by its stable string key,
/// `{headword_norm}|{pos}|{sense_index}`, never by a dictionary row id.

@DataClassName('Bookmark')
class Bookmarks extends Table {
  TextColumn get wordKey => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{wordKey};
}

@DataClassName('Note')
class Notes extends Table {
  TextColumn get wordKey => text()();
  TextColumn get body => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{wordKey};
}

/// The lists model before schema 3, with [Bookmarks]. Retained, unread,
/// until the migration into [UserCollections] has proven itself on real
/// installs; dropped a release later.
@DataClassName('WordList')
class WordLists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();

  /// An index into `MullColors.tagHues`, or null for the theme accent.
  IntColumn get color => integer().nullable()();
  BoolColumn get isReading => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('ListWord')
class ListWords extends Table {
  IntColumn get listId =>
      integer().references(WordLists, #id, onDelete: KeyAction.cascade)();
  TextColumn get wordKey => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{listId, wordKey};
}

/// Every collection the user owns, as one model. `system` rows (Bookmarks,
/// From my reading) are auto-populated and cannot be deleted; `user` rows are
/// created by the user. Built-in bands and topics live in the dictionary and
/// are joined to these by the provider layer, never here (rule D3).
@DataClassName('UserCollection')
class UserCollections extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The stable id every screen and every mix source uses: `bookmarks`,
  /// `reading`, or `u{n}` for a user collection.
  TextColumn get slug => text().unique()();

  /// system | user
  TextColumn get kind => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();

  /// An index into `MullColors.tagHues`, or null for the theme accent.
  IntColumn get color => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('UserCollectionWord')
class UserCollectionWords extends Table {
  IntColumn get collectionId =>
      integer().references(UserCollections, #id, onDelete: KeyAction.cascade)();
  TextColumn get wordKey => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{collectionId, wordKey};
}

/// One row per word the user has dwelt on. The whole spaced repetition
/// state: a count and a last-seen time, nothing more.
@DataClassName('SeenWord')
class Seen extends Table {
  TextColumn get wordKey => text()();
  IntColumn get seenCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get firstSeenAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{wordKey};
}

/// Append-only log behind Stats: words seen per day, time-of-day heatmap.
@DataClassName('SeenEvent')
class SeenEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get wordKey => text()();
  DateTimeColumn get at => dateTime()();
}

@DataClassName('RecentSearch')
class RecentSearches extends Table {
  TextColumn get query => text()();
  DateTimeColumn get at => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{query};
}

/// Words opened from a search result: Home's "Recently looked up".
@DataClassName('RecentLookup')
class RecentLookups extends Table {
  TextColumn get wordKey => text()();
  DateTimeColumn get at => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{wordKey};
}

/// A mix is a query over collections plus a rule about seen words. It is
/// what the Mull tab plays; it never plays a collection directly.
@DataClassName('Mix')
class Mixes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  BoolColumn get isPreset => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('MixSource')
class MixSources extends Table {
  IntColumn get mixId =>
      integer().references(Mixes, #id, onDelete: KeyAction.cascade)();
  TextColumn get collectionSlug => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{mixId, collectionSlug};
}

@DataClassName('MixSetting')
class MixSettings extends Table {
  IntColumn get mixId =>
      integer().references(Mixes, #id, onDelete: KeyAction.cascade)();

  /// unseen_only | light | mixed | review_only
  TextColumn get seenPolicy => text()();
  BoolColumn get shuffle => boolean().withDefault(const Constant(true))();
  BoolColumn get includeBookmarkedOnly =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{mixId};
}

/// Key/value app state: `active_mix_id`, `last_scoped_collection`.
@DataClassName('AppStateRow')
class AppState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

/// Everything the user makes. One SQLite file, separate from the dictionary
/// (rule D3). A dictionary replacement cannot touch this; a migration here
/// cannot touch the dictionary.
@DriftDatabase(
  tables: <Type>[
    Bookmarks,
    Notes,
    WordLists,
    ListWords,
    UserCollections,
    UserCollectionWords,
    Seen,
    SeenEvents,
    RecentSearches,
    RecentLookups,
    Mixes,
    MixSources,
    MixSettings,
    AppState,
  ],
)
class UserDatabase extends _$UserDatabase {
  UserDatabase() : super(driftDatabase(name: 'mull_user'));

  /// Test constructor: an in-memory database with the same schema.
  UserDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 3) {
        await m.createTable(userCollections);
        await m.createTable(userCollectionWords);
        await _migrateListsToCollections();
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Schema 3: bookmarks, "From my reading" and every user list become rows
  /// of [UserCollections], keyed by `word_key` (rule D4). The old tables are
  /// copied from, never dropped, so a bug here loses nothing.
  Future<void> _migrateListsToCollections() async {
    await customStatement('''
      INSERT OR IGNORE INTO user_collections(slug, kind, name, color, created_at)
      SELECT CASE WHEN is_reading THEN 'reading' ELSE 'u' || id END,
             CASE WHEN is_reading THEN 'system' ELSE 'user' END,
             name, color, created_at
      FROM word_lists
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO user_collection_words(collection_id, word_key, position, added_at)
      SELECT uc.id, lw.word_key, lw.position, lw.added_at
      FROM list_words lw
      JOIN word_lists wl ON wl.id = lw.list_id
      JOIN user_collections uc
        ON uc.slug = CASE WHEN wl.is_reading THEN 'reading' ELSE 'u' || wl.id END
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO user_collections(slug, kind, name, color, created_at)
      VALUES ('bookmarks', 'system', 'Bookmarks', NULL, strftime('%s', 'now'))
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO user_collection_words(collection_id, word_key, position, added_at)
      SELECT (SELECT id FROM user_collections WHERE slug = 'bookmarks'), word_key, 0, created_at
      FROM bookmarks
    ''');
  }
}
