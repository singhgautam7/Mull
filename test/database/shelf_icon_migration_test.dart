import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/database/user_repository.dart';
import 'package:sqlite3/sqlite3.dart';

/// Schema 5 gives user shelves a nullable `icon` and `note`. A schema 4 shelf
/// keeps its colour and members, reads both as null, and can take them.
void main() {
  test('schema 4 shelf survives the move to 5 and can take an icon and note', () async {
    final Directory dir = await Directory.systemTemp.createTemp('mull_s5_');
    addTearDown(() => dir.delete(recursive: true));
    final File file = File('${dir.path}/mull_user.db');

    final Database raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE user_collections(id INTEGER PRIMARY KEY AUTOINCREMENT, slug TEXT NOT NULL UNIQUE,
        kind TEXT NOT NULL, name TEXT NOT NULL, color INTEGER, created_at INTEGER NOT NULL);
      CREATE TABLE user_collection_words(collection_id INTEGER NOT NULL REFERENCES user_collections(id) ON DELETE CASCADE,
        word_key TEXT NOT NULL, position INTEGER NOT NULL DEFAULT 0, added_at INTEGER NOT NULL,
        PRIMARY KEY(collection_id, word_key));
      INSERT INTO user_collections VALUES (1, 'u1', 'user', 'Viva', 3, 20);
      INSERT INTO user_collection_words VALUES (1, 'abate|verb|1', 0, 30), (1, 'egress|noun|1', 1, 40);
      PRAGMA user_version = 4;
    ''');
    raw.close();

    final UserDatabase db = UserDatabase.forTesting(NativeDatabase(file));
    final UserRepository user = UserRepository(db);
    final UserCollection before = (await user.collection('u1'))!;
    expect((before.name, before.color, before.icon, before.note), ('Viva', 3, null, null));
    expect(await user.collectionWordKeys('u1'), <String>['abate|verb|1', 'egress|noun|1']);

    await user.updateCollection('u1', name: 'Viva 2', color: 3, icon: 'school', note: 'Oral exam');
    final UserCollection after = (await user.collection('u1'))!;
    expect((after.name, after.color, after.icon, after.note), ('Viva 2', 3, 'school', 'Oral exam'));

    final String made = await user.createCollection('New', icon: 'book', note: 'n');
    expect((await user.collection(made))!.icon, 'book');
    await db.close();
  });
}
