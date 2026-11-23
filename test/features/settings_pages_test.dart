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
import 'package:mull/features/settings/settings_screen.dart';
import 'package:mull/features/settings/settings_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryDb dict;
  late UserDatabase userDb;

  setUp(() {
    dict = fakeDictionary(words: const <FakeWord>[FakeWord('abate', 'verb', 'To lessen.')]);
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await userDb.close();
    dict.close();
  });

  Future<SharedPreferences> pump(WidgetTester tester, Widget page, [Map<String, Object> initial = const <String, Object>{}]) async {
    SharedPreferences.setMockInitialValues(initial);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          prefsProvider.overrideWithValue(prefs),
          userDatabaseProvider.overrideWithValue(userDb),
          dictProvider.overrideWithValue(dict),
        ],
        child: MaterialApp(theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light), home: page),
      ),
    );
    await tester.pump();
    return prefs;
  }

  List<String> labels(WidgetTester tester) => <String>[
    for (final SettingsRow r in tester.widgetList<SettingsRow>(find.byType(SettingsRow))) r.label,
  ];

  testWidgets('every setting sits on exactly one page', (WidgetTester tester) async {
    final List<String> all = <String>[];
    for (final Widget page in const <Widget>[LookSettingsScreen(), WordsSettingsScreen(), RemindersSettingsScreen()]) {
      await pump(tester, page);
      all.addAll(labels(tester));
    }
    expect(all.toSet().length, all.length, reason: 'a label appears on two pages: $all');
    expect(
      all,
      containsAll(<String>[
        'Theme', 'Floating header', 'Text size', 'Search results', 'Haptics',
        'Show synonyms', 'Spelling', 'Pronunciation speed', 'Word of the day', 'Arrives at',
      ]),
    );
  });

  testWidgets('Floating header opens its sheet', (WidgetTester tester) async {
    await pump(tester, const LookSettingsScreen());
    expect(find.text('Always'), findsOneWidget);
    await tester.tap(find.text('Floating header'));
    // The sheet's previews loop forever: settle by time, not by idle.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('The header follows you as you scroll'), findsOneWidget);
  });

  testWidgets('the haptics switch persists', (WidgetTester tester) async {
    await pump(tester, const LookSettingsScreen());
    expect(AppSettings.read(await SharedPreferences.getInstance()).haptics, isTrue);
    await tester.tap(find.text('Haptics'));
    await tester.pumpAndSettle();
    expect(AppSettings.read(await SharedPreferences.getInstance()).haptics, isFalse);
  });
}
