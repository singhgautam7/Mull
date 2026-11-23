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
import 'package:mull/features/notes/notes_screen.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const FakeWord abate = FakeWord('abate', 'verb', 'To lessen in force or intensity.');
  const FakePhrase phrase = FakePhrase('break the ice', 'idiom', 'Start a conversation.');

  late DictionaryDb dict;
  late UserDatabase userDb;
  late UserRepository user;

  setUpAll(() async {
    final ByteData font = ByteData.sublistView(File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync());
    await (FontLoader('Instrument Sans')..addFont(Future<ByteData>.value(font))).load();
  });

  setUp(() {
    dict = fakeDictionary(words: const <FakeWord>[abate], phrases: const <FakePhrase>[phrase]);
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
    user = UserRepository(userDb);
  });

  tearDown(() async {
    await userDb.close();
    dict.close();
  });

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'onboarded': true});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          prefsProvider.overrideWithValue(prefs),
          userDatabaseProvider.overrideWithValue(userDb),
          dictProvider.overrideWithValue(dict),
        ],
        child: MaterialApp(theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light), home: const NotesScreen()),
      ),
    );
    for (int i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('lists notes newest first and opens the word sheet', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await user.putNote(abate.key, 'Old note on a word.', now: DateTime(2020, 1, 5));
      await user.putNote(phrase.key, 'Newer note on a phrase.', now: DateTime(2021, 3, 9));
      await pump(tester);

      expect(find.text('2 notes'), findsOneWidget);
      expect(find.textContaining('break the ice'), findsOneWidget);
      expect(find.textContaining('abate'), findsOneWidget);
      expect(find.text('9 Mar 2021'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Newer note on a phrase.')).dy,
        lessThan(tester.getTopLeft(find.text('Old note on a word.')).dy),
      );

      await tester.tap(find.text('Old note on a word.'));
      for (int i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('a key the dictionary no longer has still shows and opens the note sheet', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await user.putNote('gone|noun|1', 'Kept after an import.');
      await pump(tester);

      expect(find.text('1 note'), findsOneWidget);
      expect(find.text('gone'), findsOneWidget);
      await tester.tap(find.text('Kept after an import.'));
      for (int i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('no notes shows the empty state', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await pump(tester);
      expect(find.text('No notes yet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
