import 'dart:io';

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
import 'package:mull/features/settings/info_screens.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

/// The About page reads its attribution from the dictionary's `meta` table
/// (read once), links to no website, and opens Flutter's licence page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String attribution = 'Wiktionary via Kaikki.org, CC BY-SA 4.0. Open English WordNet 2024, CC BY 4.0.';

  late UserDatabase userDb;

  setUp(() => userDb = UserDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => userDb.close());

  /// The shipped schema, with or without a `source_attribution` row
  /// (`fakeDictionary` writes only `dict_version`).
  DictionaryDb dictionary({required bool withAttribution}) {
    final Database db = sqlite3.openInMemory();
    db.execute(File('tools/build_dictionary/schema.sql').readAsStringSync());
    db.execute("INSERT INTO meta(key, value) VALUES ('dict_version', 'test')");
    if (withAttribution) db.execute('INSERT INTO meta(key, value) VALUES (?, ?)', <Object>['source_attribution', attribution]);
    return DictionaryDb.forTesting(db);
  }

  Future<void> pump(WidgetTester tester, DictionaryDb dict) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(360, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          prefsProvider.overrideWithValue(prefs),
          userDatabaseProvider.overrideWithValue(userDb),
          dictProvider.overrideWithValue(dict),
          appVersionProvider.overrideWith((Ref ref) async => '1.2.3'),
        ],
        child: MaterialApp(theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light), home: const AboutScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the attribution stored in the dictionary and no website', (WidgetTester tester) async {
    final DictionaryDb dict = dictionary(withAttribution: true);
    addTearDown(dict.close);
    await pump(tester, dict);
    expect(find.text(attribution), findsOneWidget);
    expect(find.textContaining('singhgautam'), findsNothing);
    expect(find.textContaining('http'), findsNothing);
    expect(find.textContaining('.com'), findsNothing);
  });

  testWidgets('shows no sources block when the dictionary holds none', (WidgetTester tester) async {
    final DictionaryDb dict = dictionary(withAttribution: false);
    addTearDown(dict.close);
    await pump(tester, dict);
    expect(find.text('SOURCES AND CREDITS'), findsNothing);
  });

  testWidgets('Open-source licences opens the licence page', (WidgetTester tester) async {
    final DictionaryDb dict = dictionary(withAttribution: true);
    addTearDown(dict.close);
    await pump(tester, dict);
    await tester.tap(find.text('Open-source licences'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
