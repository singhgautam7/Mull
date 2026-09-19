import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/data_transfer_repository.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/database/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_dictionary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const FakeWord abate = FakeWord(
    'abate',
    'verb',
    'To lessen in force or intensity.',
  );
  const FakeWord dither = FakeWord(
    'dither',
    'verb',
    'To be indecisive.',
  );

  late DictionaryDb dict;
  late UserDatabase userDb;
  late UserRepository userRepo;
  late SharedPreferences prefs;
  late DataTransferRepository transferRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();

    dict = fakeDictionary(
      words: <FakeWord>[abate, dither],
      collections: <String, List<String>>{
        'everyday': <String>[abate.key, dither.key],
      },
    );

    userDb = UserDatabase.forTesting(NativeDatabase.memory());
    userRepo = UserRepository(userDb);
    transferRepo = DataTransferRepository(userDb, dict, prefs);
  });

  tearDown(() async {
    await userDb.close();
    dict.close();
  });

  test('exportJson produces valid Mull export format with all user data', () async {
    // 1. Add user shelf
    final String shelfSlug = await userRepo.createCollection('Test Shelf');
    await userRepo.addToCollection(shelfSlug, abate.key);

    // 2. Add bookmark
    await userRepo.toggleBookmark(abate.key);

    // 3. Add note
    await userRepo.putNote(abate.key, 'My important note on abate');

    // 4. Add context
    await userRepo.addContext(
      abate.key,
      'The storm began to abate towards evening.',
      sourceHint: 'com.android.chrome',
    );

    // 5. Add seen progress
    await userRepo.markSeen(abate.key);

    // 6. Add quiz session
    final int sessionId = await userRepo.beginQuiz(shelfSlug, 10);
    await userRepo.answerQuiz(
      sessionId,
      wordKey: abate.key,
      type: 'meaning',
      correct: true,
      chosenKey: abate.key,
    );
    await userRepo.finishQuiz(sessionId, correctCount: 1, abandoned: false);

    // Export
    final String jsonStr = await transferRepo.exportJson();
    expect(jsonStr, isNotEmpty);

    final ImportPreview preview = transferRepo.parse(
      jsonStr,
      fileName: 'test-backup.json',
    );
    expect(preview.data['format'], equals('mull.export'));
    expect(preview.data['format_version'], equals(1));
    expect(preview.count('collections'), greaterThanOrEqualTo(1));
    expect(preview.count('notes'), equals(1));
    expect(preview.count('contexts'), equals(1));
  });

  Map<String, Object?> payload(Map<String, Object?> sections) =>
      <String, Object?>{
        'format': DataTransferRepository.format,
        'format_version': DataTransferRepository.formatVersion,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        ...sections,
      };

  test('merge never overwrites a note: both are kept, imported one marked', () async {
    await userRepo.putNote(abate.key, 'Mine, written on the phone');

    await transferRepo.apply(
      ImportPreview(
        payload(<String, Object?>{
          'notes': <Object?>[
            <String, Object?>{
              'word_key': abate.key,
              'body': 'Theirs, from the file',
              'updated_at': DateTime(2026, 6).toIso8601String(),
            },
            <String, Object?>{
              'word_key': dither.key,
              'body': 'Dither note from import',
              'updated_at': DateTime(2026).toIso8601String(),
            },
          ],
        }),
        'merge.json',
      ),
      mode: ImportMode.merge,
    );

    final String? merged = await userRepo.note(abate.key);
    expect(merged, startsWith('Mine, written on the phone'));
    expect(merged, contains(DataTransferRepository.importedNoteMarker));
    expect(merged, contains('2026-06-01'));
    expect(merged, endsWith('Theirs, from the file'));
    expect(await userRepo.note(dither.key), 'Dither note from import');

    // Importing the same file again does not append a second copy.
    await transferRepo.apply(
      transferRepo.parse(await transferRepo.exportJson(), fileName: 'again.json'),
      mode: ImportMode.merge,
    );
    expect(await userRepo.note(abate.key), merged);
  });

  test('a failure halfway through an import leaves the database untouched', () async {
    final ImportPreview broken = ImportPreview(
      payload(<String, Object?>{
        'collections': <Object?>[
          <String, Object?>{
            'slug': 'u1',
            'name': 'Imported shelf',
            'kind': 'user',
            'members': <Object?>[
              <String, Object?>{'word_key': abate.key},
            ],
          },
        ],
        'notes': <Object?>[
          <String, Object?>{'word_key': abate.key, 'body': 'A note'},
        ],
        // Written after collections and notes; the bad type throws mid-way.
        'mixes': <Object?>[
          <String, Object?>{
            'name': 'Broken mix',
            'settings': <String, Object?>{'seen_policy': 5},
          },
        ],
      }),
      'broken.json',
    );

    await expectLater(
      transferRepo.apply(broken, mode: ImportMode.merge),
      throwsA(isA<TypeError>()),
    );

    expect(await userRepo.note(abate.key), isNull);
    expect(
      (await userRepo.collections()).where((c) => c.name == 'Imported shelf'),
      isEmpty,
    );
  });

  test('an export round-trips across a dictionary rebuild (rule D4)', () async {
    final String shelf = await userRepo.createCollection('Storms');
    await userRepo.addToCollection(shelf, abate.key);
    await userRepo.toggleBookmark(dither.key);
    await userRepo.putNote(abate.key, 'note');
    final String json = await transferRepo.exportJson();
    expect(transferRepo.parse(json, fileName: 'a.json').data['dict_version'], 'test');

    // v2: same words, different insertion order, so every row id changes.
    final DictionaryDb v2 = fakeDictionary(
      words: <FakeWord>[dither, abate],
      version: 'v2',
    );
    final UserDatabase fresh = UserDatabase.forTesting(NativeDatabase.memory());
    final UserRepository freshRepo = UserRepository(fresh);
    final ImportResult result = await DataTransferRepository(fresh, v2, prefs)
        .apply(
          DataTransferRepository(fresh, v2, prefs).parse(json, fileName: 'a.json'),
          mode: ImportMode.replace,
        );
    expect(result.unresolvedCount, 0);

    final UserCollection storms = (await freshRepo.collections()).singleWhere(
      (UserCollection c) => c.name == 'Storms',
    );
    final List<String> keys = await freshRepo.collectionWordKeys(storms.slug);
    expect(keys, <String>[abate.key]);
    expect(v2.byKey(keys.single)?.headword, 'abate');
    expect(await freshRepo.bookmarkedKeys(), <String>[dither.key]);
    expect(await freshRepo.note(abate.key), 'note');

    await fresh.close();
    v2.close();
  });

  test('a word key missing from the dictionary is kept and counted', () async {
    final ImportResult result = await transferRepo.apply(
      ImportPreview(
        payload(<String, Object?>{
          'collections': <Object?>[
            <String, Object?>{
              'slug': 'u1',
              'name': 'Old words',
              'kind': 'user',
              'members': <Object?>[
                <String, Object?>{'word_key': 'gone|noun|1'},
                <String, Object?>{'word_key': abate.key},
              ],
            },
          ],
        }),
        'old.json',
      ),
      mode: ImportMode.merge,
    );
    expect(result.unresolvedCount, 1);
    final UserCollection old = (await userRepo.collections()).singleWhere(
      (UserCollection c) => c.name == 'Old words',
    );
    expect(await userRepo.collectionWordKeys(old.slug), containsAll(<String>['gone|noun|1', abate.key]));
  });

  test('contexts are exported, cleared, and imported correctly', () async {
    await userRepo.addContext(
      abate.key,
      'The storm began to abate towards morning.',
      sourceHint: 'org.mozilla.firefox',
    );

    final List<WordContext> beforeExport = await userRepo.contexts(abate.key);
    expect(beforeExport.length, equals(1));
    expect(beforeExport.first.sourceHint, equals('org.mozilla.firefox'));

    final String jsonStr = await transferRepo.exportJson();

    // Clear contexts
    await userRepo.clearContexts();
    final List<WordContext> afterClear = await userRepo.contexts(abate.key);
    expect(afterClear, isEmpty);

    // Restore via replace
    final ImportPreview preview = transferRepo.parse(
      jsonStr,
      fileName: 'backup.json',
    );
    await transferRepo.apply(preview, mode: ImportMode.replace);

    final List<WordContext> restored = await userRepo.contexts(abate.key);
    expect(restored.length, equals(1));
    expect(restored.first.contextText, contains('abate towards morning'));
    expect(restored.first.sourceHint, equals('org.mozilla.firefox'));
  });
}
