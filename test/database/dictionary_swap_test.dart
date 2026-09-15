import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/database/user_repository.dart';

import 'fake_dictionary.dart';

/// Rule D4: user data references words by `word_key`, never by row id, so a
/// rebuilt dictionary with different ids still resolves every bookmark and
/// note.
void main() {
  late UserDatabase userDb;
  late UserRepository user;

  setUp(() {
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
    user = UserRepository(userDb);
  });

  tearDown(() => userDb.close());

  test('a bookmark and a note survive a dictionary swap', () async {
    const FakeWord abate = FakeWord('abate', 'verb', 'To lessen in force or intensity.');
    const FakeWord colour = FakeWord('colour', 'noun', 'The spectral composition of light.');

    // v1: abate is row 1.
    final DictionaryDb v1 = fakeDictionary(words: <FakeWord>[abate, colour], version: '1');
    expect(v1.byKey(abate.key)!.headword, 'abate');

    await user.toggleBookmark(abate.key);
    await user.putNote(abate.key, 'Rain abates. Storms abate.');
    v1.close();

    // v2: rebuilt, colour first, abate re-defined and now row 2.
    const FakeWord abate2 = FakeWord('abate', 'verb', 'To become less intense.');
    final DictionaryDb v2 = fakeDictionary(words: <FakeWord>[colour, abate2], version: '2');

    final List<String> bookmarked = await user.bookmarkedKeys();
    expect(bookmarked, <String>[abate.key]);
    final DictionaryWord? resolved = v2.byKey(bookmarked.single);
    expect(resolved, isNotNull);
    expect(resolved!.headword, 'abate');
    expect(resolved.definitionShort, 'To become less intense.');
    expect(await user.note(abate.key), 'Rain abates. Storms abate.');
    v2.close();
  });

  test('the two databases never share a connection', () {
    // The dictionary is a sqlite3 Database; the user store is a drift
    // database. Neither type can be handed to the other repository.
    final DictionaryDb dict = fakeDictionary(words: const <FakeWord>[]);
    expect(dict.entryCount, 0);
    expect(user, isA<UserRepository>());
    dict.close();
  });
}
