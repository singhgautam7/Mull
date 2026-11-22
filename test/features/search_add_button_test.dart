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
import 'package:mull/features/dictionary/search_screen.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

/// M3: every word result carries an add-to-list button (card and table
/// style), not the history rows; it opens the add-to-list sheet and the row
/// tap still opens the word sheet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryDb dict;
  late UserDatabase userDb;

  setUpAll(() async {
    final ByteData font = ByteData.sublistView(File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync());
    await (FontLoader('Instrument Sans')..addFont(Future<ByteData>.value(font))).load();
  });

  setUp(() async {
    dict = fakeDictionary(words: <FakeWord>[const FakeWord('rose', 'noun', 'A prickly shrub with fragrant flowers.')]);
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
    await UserRepository(userDb).ensureSystemCollections();
    await UserRepository(userDb).recordSearch('history term');
  });

  tearDown(() async {
    await userDb.close();
    dict.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpSearch(WidgetTester tester, SearchStyle style) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'search.style': style.name});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          prefsProvider.overrideWithValue(prefs),
          userDatabaseProvider.overrideWithValue(userDb),
          dictProvider.overrideWithValue(dict),
        ],
        child: MaterialApp(theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light), home: const SearchScreen()),
      ),
    );
    await settle(tester);
  }

  Finder addButton() => find.bySemanticsLabel('Add rose to a list');

  for (final SearchStyle style in SearchStyle.values) {
    testWidgets('${style.name} results: button opens the sheet in table mode, card mode omits button', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpSearch(tester, style);
        expect(addButton(), findsNothing, reason: 'history rows carry no add button');
        expect(find.text('history term'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'rose');
        await settle(tester);
        final Finder result = find.byType(style == SearchStyle.table ? SearchResultRow : SearchResultCard);
        expect(result, findsOneWidget);

        if (style == SearchStyle.table) {
          expect(addButton(), findsOneWidget);
          expect(tester.getSize(addButton()).shortestSide, greaterThanOrEqualTo(48));

          await tester.tap(addButton());
          await settle(tester);
          expect(find.text('Add rose to'), findsOneWidget);
          await tester.tap(find.text('Done'));
          await settle(tester);
          expect(find.text('Add rose to'), findsNothing);
        } else {
          expect(addButton(), findsNothing, reason: 'card mode omits add to list button');
        }

        await tester.tap(result);
        await settle(tester);
        expect(find.text('Add rose to'), findsNothing);
        expect(find.byType(BottomSheet), findsOneWidget, reason: 'the word sheet');
        handle.dispose();
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
