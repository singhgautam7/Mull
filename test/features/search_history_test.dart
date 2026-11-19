import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

/// M5: a long press on a history row asks "Remove from history?"; Remove
/// forgets that entry only, Cancel keeps it, TalkBack gets the same action.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryDb dict;
  late UserDatabase userDb;
  late UserRepository repo;

  setUpAll(() async {
    final ByteData font = ByteData.sublistView(File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync());
    await (FontLoader('Instrument Sans')..addFont(Future<ByteData>.value(font))).load();
  });

  setUp(() async {
    dict = fakeDictionary(words: <FakeWord>[const FakeWord('rose', 'noun', 'A shrub.')]);
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
    repo = UserRepository(userDb);
    final DateTime t = DateTime(2026, 1, 1);
    await repo.recordSearch('alpha', now: t);
    await repo.recordSearch('beta', now: t.add(const Duration(minutes: 1)));
    SharedPreferences.setMockInitialValues(<String, Object>{});
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

  Future<void> pumpSearch(WidgetTester tester) async {
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

  Future<void> hold(WidgetTester tester, String text) async {
    final TestGesture g = await tester.startGesture(tester.getCenter(find.text(text)));
    // Inside runAsync the recogniser's timer is a real one.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await g.up();
    await settle(tester);
  }

  testWidgets('long press asks, Remove deletes only that entry (repository and rows)', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await pumpSearch(tester);
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);

      await hold(tester, 'alpha');
      await settle(tester);
      expect(find.text('Remove from history?'), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await settle(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('alpha'), findsNothing);
      expect(find.text('beta'), findsOneWidget);
      expect(await repo.recentSearches(), <String>['beta']);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('Cancel keeps the entry', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await pumpSearch(tester);
      await hold(tester, 'beta');
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Remove from history?'), findsNothing);
      expect(find.text('beta'), findsOneWidget);
      expect(await repo.recentSearches(), <String>['beta', 'alpha']);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('a tap still runs the search; TalkBack gets "Remove from history"', (WidgetTester tester) async {
    await tester.runAsync(() async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSearch(tester);
      final SemanticsNode node = tester.getSemantics(find.text('beta'));
      expect(node.getSemanticsData().customSemanticsActionIds, isNotEmpty);
      final int id = CustomSemanticsAction.getIdentifier(const CustomSemanticsAction(label: 'Remove from history'));
      tester.semantics.performAction(find.semantics.byLabel('beta'), SemanticsAction.customAction, args: id);
      await settle(tester);
      expect(find.text('Remove from history?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);

      await tester.tap(find.text('beta'));
      await settle(tester);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'beta');
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  });
}
