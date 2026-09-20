import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/providers.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:mull/features/settings/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

/// The three cards on the first welcome page arrive staggered on first load
/// and only then: back on page 01 from page 02 they are already settled.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryDb dict;
  late UserDatabase userDb;

  setUp(() {
    dict = fakeDictionary(
      words: const <FakeWord>[FakeWord('abate', 'verb', 'To lessen.')],
      collections: const <String, List<String>>{'everyday': <String>['abate|verb|1']},
      details: const <String, (String, String, String)>{'everyday': ('band', 'Everyday', '')},
    );
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    await userDb.close();
    dict.close();
  });

  double opacityOf(WidgetTester tester, String word) {
    final Finder card = find.ancestor(of: find.text(word), matching: find.byType(Opacity)).first;
    return tester.widget<Opacity>(card).opacity;
  }

  testWidgets('cards animate in once, back to front, and stay put afterwards', (WidgetTester tester) async {
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
          home: const WelcomeScreen(),
        ),
      ),
    );
    // First frame: nothing has landed yet.
    expect(opacityOf(tester, 'sonder'), 0);
    expect(opacityOf(tester, 'mull'), 0);
    // Half way through the first card's 240 ms: the back card is on its way,
    // the front card (last in the stagger) has not started.
    await tester.pump(const Duration(milliseconds: 120));
    expect(opacityOf(tester, 'sonder'), greaterThan(0));
    expect(opacityOf(tester, 'sonder'), lessThan(1));
    expect(opacityOf(tester, 'mull'), 0);
    await tester.pump(const Duration(milliseconds: 600));
    expect(opacityOf(tester, 'sonder'), 1);
    expect(opacityOf(tester, 'petrichor'), 1);
    expect(opacityOf(tester, 'mull'), 1);

    // A rebuild of the page (here the OS text scale changing, as a font
    // setting or a rotation would) does not replay the entrance.
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pump();
    expect(opacityOf(tester, 'mull'), 1, reason: 'the entrance plays once');
    await tester.pump(const Duration(milliseconds: 16));
    expect(opacityOf(tester, 'sonder'), 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
