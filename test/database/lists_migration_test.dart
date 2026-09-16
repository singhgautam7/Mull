import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/database/user_repository.dart';
import 'package:sqlite3/sqlite3.dart';

/// Schema 2 kept bookmarks in their own table and lists in `word_lists` /
/// `list_words`. Schema 3 folds them into the unified collections model, by
/// `word_key`, and leaves the old tables in place until the migration has
/// proven itself. Losing someone's bookmarks to a refactor is not
/// recoverable.
void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('mull_migrate_'));
  tearDown(() => dir.delete(recursive: true));

  test('lists and bookmarks from schema 2 become collections; old tables stay', () async {
    final File file = File('${dir.path}/mull_user.db');

    // A schema 2 database as drift would have written it.
    final Database raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE bookmarks(word_key TEXT NOT NULL PRIMARY KEY, created_at INTEGER NOT NULL);
      CREATE TABLE word_lists(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, color INTEGER,
        is_reading INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL);
      CREATE TABLE list_words(list_id INTEGER NOT NULL REFERENCES word_lists(id) ON DELETE CASCADE,
        word_key TEXT NOT NULL, position INTEGER NOT NULL DEFAULT 0, added_at INTEGER NOT NULL,
        PRIMARY KEY(list_id, word_key));
      INSERT INTO bookmarks VALUES ('abate|verb|1', 100), ('colour|noun|1', 200);
      INSERT INTO word_lists(id, name, color, is_reading, created_at) VALUES
        (1, 'From my reading', NULL, 1, 10), (2, 'Viva', 3, 0, 20);
      INSERT INTO list_words VALUES (1, 'dither|verb|1', 0, 30), (2, 'abate|verb|1', 0, 40), (2, 'egress|noun|1', 1, 50);
      PRAGMA user_version = 2;
    ''');
    raw.close();

    final UserDatabase db = UserDatabase.forTesting(NativeDatabase(file));
    final UserRepository user = UserRepository(db);
    await user.ensureSystemCollections();

    expect(
      (await user.collections()).map((UserCollection c) => '${c.slug}:${c.kind}:${c.name}'),
      <String>['bookmarks:system:Bookmarks', 'reading:system:From my reading', 'u2:user:Viva'],
    );
    expect((await user.collection('u2'))!.color, 3);
    expect((await user.bookmarkedKeys()).toSet(), <String>{'abate|verb|1', 'colour|noun|1'});
    expect(await user.collectionWordKeys('reading'), <String>['dither|verb|1']);
    expect(await user.collectionWordKeys('u2'), <String>['abate|verb|1', 'egress|noun|1']);
    await db.close();

    // The old tables are still there, untouched.
    final Database after = sqlite3.open(file.path);
    expect(after.select('SELECT count(*) AS n FROM bookmarks').first['n'], 2);
    expect(after.select('SELECT count(*) AS n FROM list_words').first['n'], 3);
    expect(after.select('PRAGMA user_version').first.values.first, 3);
    after.close();
  });
}
