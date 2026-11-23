import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/database/user_repository.dart';
import 'package:mull/core/providers.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/features/dictionary/add_to_list_sheet.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

/// The add-to-list sheet: nothing is ticked for a word in no list (even from
/// search), lists that hold the word stay ticked, and Done names what was
/// added while the sheet was open.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const FakeWord rose = FakeWord('rose', 'noun', 'A prickly shrub with fragrant flowers.');
  late DictionaryDb dict;
  late UserDatabase userDb;
  late UserRepository repo;

  setUpAll(() async {
    final ByteData font = ByteData.sublistView(File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync());
    await (FontLoader('Instrument Sans')..addFont(Future<ByteData>.value(font))).load();
  });

  setUp(() async {
    dict = fakeDictionary(words: <FakeWord>[rose]);
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
    repo = UserRepository(userDb);
    await repo.ensureSystemCollections();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    await userDb.close();
    dict.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openSheet(WidgetTester tester, {bool fromSearch = false}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          prefsProvider.overrideWithValue(prefs),
          userDatabaseProvider.overrideWithValue(userDb),
          dictProvider.overrideWithValue(dict),
        ],
        child: MaterialApp(
          theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      showAddToListSheet(context, wordKey: rose.key, headword: 'rose', fromSearch: fromSearch),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  bool ticked(WidgetTester tester, String label) {
    final Semantics s = tester.widget<Semantics>(find.widgetWithText(Semantics, label).first);
    return s.properties.toggled ?? false;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('a word in no list opens with nothing ticked, even from search, and nothing is written', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await openSheet(tester, fromSearch: true);
      expect(ticked(tester, 'Bookmarks'), isFalse);
      expect(ticked(tester, UserRepository.readingListName), isFalse);
      expect(await repo.collectionsContaining(rose.key), isEmpty);
      await finish(tester);
    });
  });

  testWidgets('a list that already holds the word opens ticked', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await repo.addToCollection(UserRepository.bookmarksSlug, rose.key);
      await openSheet(tester);
      expect(ticked(tester, 'Bookmarks'), isTrue);
      expect(ticked(tester, UserRepository.readingListName), isFalse);
      await finish(tester);
    });
  });

  testWidgets('Done after one list says "Added to <list>"', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await openSheet(tester);
      await tester.tap(find.text(UserRepository.readingListName));
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(find.text('Added to ${UserRepository.readingListName}'), findsOneWidget);
      expect(await repo.collectionsContaining(rose.key), <String>{UserRepository.readingSlug});
      await finish(tester);
    });
  });

  testWidgets('Done after several lists says "Added to 2 lists"', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await openSheet(tester);
      await tester.tap(find.text('Bookmarks'));
      await settle(tester);
      await tester.tap(find.text(UserRepository.readingListName));
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(find.text('Added to 2 lists'), findsOneWidget);
      await finish(tester);
    });
  });

  testWidgets('nothing added, or a tick then untick, shows no toast; an existing list does not count', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await repo.addToCollection(UserRepository.bookmarksSlug, rose.key);
      await openSheet(tester);
      await tester.tap(find.text(UserRepository.readingListName));
      await settle(tester);
      await tester.tap(find.text(UserRepository.readingListName));
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(find.textContaining('Added to'), findsNothing);
      await finish(tester);
    });
  });
}
