import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/database/user_repository.dart';

import 'fake_dictionary.dart';

void main() {
  late UserDatabase userDb;
  late UserRepository user;

  setUp(() {
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
    user = UserRepository(userDb);
  });

  tearDown(() => userDb.close());

  test('legacy idiom keys resolve to newly typed phrases and migrate cleanly', () async {
    // Reclassified phrases in the new phrases schema:
    // 1. spill the beans stays an idiom
    const FakePhrase spill = FakePhrase(
      'spill the beans',
      'idiom',
      'To reveal a secret prematurely.',
      example: "Don't spill the beans before the party.",
      register: 'informal',
    );
    // 2. a stitch in time saves nine reclassified from idiom to proverb
    const FakePhrase stitch = FakePhrase(
      'a stitch in time saves nine',
      'proverb',
      'A timely effort will prevent much work later.',
      usageNote: 'Advisory proverb against procrastination.',
      example: 'Fix that leak now; a stitch in time saves nine.',
      register: 'everyday',
    );
    // 3. spick and span reclassified from idiom to binomial
    const FakePhrase spick = FakePhrase(
      'spick and span',
      'binomial',
      'Immaculately clean and tidy.',
      usageNote: 'Fixed irreversible order.',
      example: 'The kitchen was left spick and span.',
      register: 'everyday',
    );

    final DictionaryDb dict = fakeDictionary(
      words: const <FakeWord>[],
      phrases: <FakePhrase>[spill, stitch, spick],
    );

    // Old keys previously stored in user bookmarks / notes:
    const String oldSpillKey = 'spill the beans|idiom|1';
    const String oldStitchKey = 'a stitch in time saves nine|idiom|1';
    const String oldSpickKey = 'spick and span|idiom|1';

    // Step 1: Prove dict.phraseByKey resolves legacy keys to the new canonical Phrase
    final Phrase? pSpill = dict.phraseByKey(oldSpillKey);
    expect(pSpill, isNotNull);
    expect(pSpill!.phraseKey, 'spill the beans|idiom|1');
    expect(pSpill.type, 'idiom');

    final Phrase? pStitch = dict.phraseByKey(oldStitchKey);
    expect(pStitch, isNotNull);
    expect(pStitch!.phraseKey, 'a stitch in time saves nine|proverb|1');
    expect(pStitch.type, 'proverb');
    expect(pStitch.usageNote, isNotNull);

    final Phrase? pSpick = dict.phraseByKey(oldSpickKey);
    expect(pSpick, isNotNull);
    expect(pSpick!.phraseKey, 'spick and span|binomial|1');
    expect(pSpick.type, 'binomial');

    // Step 2: Prove dict.idiomByKey backward compatibility
    final Idiom? iStitch = dict.idiomByKey(oldStitchKey);
    expect(iStitch, isNotNull);
    expect(iStitch!.phrase, 'a stitch in time saves nine');
    expect(iStitch.meaning, 'A timely effort will prevent much work later.');

    // Step 3: Seed user DB with legacy bookmarks, note, and lookup
    await user.addBookmark(oldSpillKey);
    await user.addBookmark(oldStitchKey);
    await user.addBookmark(oldSpickKey);
    await user.putNote(oldStitchKey, "Remember grandma's sewing proverb.");
    await user.recordLookup(oldSpickKey);

    expect(await user.bookmarkedKeys(), containsAll(<String>[oldSpillKey, oldStitchKey, oldSpickKey]));
    expect(await user.note(oldStitchKey), "Remember grandma's sewing proverb.");

    // Step 4: Run forward migration
    final int migrated = await user.migrateLegacyPhraseKeys(dict);
    // stitch and spick were reclassified so their keys change; spill stays the same
    expect(migrated, 2);

    // Step 5: Verify user DB now holds canonical keys
    final List<String> bookmarked = await user.bookmarkedKeys();
    expect(bookmarked, containsAll(<String>[
      'spill the beans|idiom|1',
      'a stitch in time saves nine|proverb|1',
      'spick and span|binomial|1',
    ]));
    expect(bookmarked, isNot(contains(oldStitchKey)));
    expect(bookmarked, isNot(contains(oldSpickKey)));

    // Verify note migrated to new key
    expect(await user.note('a stitch in time saves nine|proverb|1'), "Remember grandma's sewing proverb.");

    dict.close();
  });
}
