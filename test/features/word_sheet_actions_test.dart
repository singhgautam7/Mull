import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/database/user_repository.dart';
import 'package:mull/core/providers.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/features/dictionary/word_sheet.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryDb dict;
  late UserDatabase userDb;
  late UserRepository repo;
  const FakeWord rose = FakeWord('rose', 'noun', 'A flower.');

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    dict = fakeDictionary(words: <FakeWord>[rose]);
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
    repo = UserRepository(userDb);
    await repo.ensureSystemCollections();
  });

  tearDown(() async {
    await userDb.close();
    dict.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
              body: TextButton(onPressed: () => showWordSheet(context, wordKey: rose.key), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  testWidgets('the action row is Add to shelf, note and share; no See in Mull, no bookmark', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await open(tester);
      expect(find.text('See in Mull'), findsNothing);
      expect(find.bySemanticsLabel('Bookmark'), findsNothing);
      expect(find.bySemanticsLabel('Remove bookmark'), findsNothing);
      expect(find.text('Add to shelf'), findsOneWidget);
      expect(find.bySemanticsLabel('Add or edit a note'), findsOneWidget);
      expect(find.bySemanticsLabel('Share'), findsOneWidget);
      expect(find.byIcon(Icons.library_add_outlined), findsOneWidget);
      expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
      expect(Icons.sticky_note_2_outlined, isNot(Icons.library_add_outlined));
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('Add to shelf opens a switch per shelf; a tap flips it once and writes the membership', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await open(tester);
      await tester.tap(find.text('Add to shelf'));
      await settle(tester);
      final Finder switches = find.byType(Switch);
      expect(switches, findsWidgets);
      expect(find.byType(Checkbox), findsNothing);
      final Finder row = find.text('Bookmarks');
      expect(tester.widget<Switch>(switches.first).value, isFalse);
      await tester.tap(row);
      await settle(tester);
      expect(tester.widget<Switch>(switches.first).value, isTrue, reason: 'one tap, one toggle');
      expect(await repo.collectionsContaining(rose.key), contains(UserRepository.bookmarksSlug));
      await tester.tap(row);
      await settle(tester);
      expect(tester.widget<Switch>(switches.first).value, isFalse);
      expect(await repo.collectionsContaining(rose.key), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
