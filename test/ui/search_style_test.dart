import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/providers.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/features/dictionary/search_screen.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

/// Search results in both styles: the card never overflows at the largest OS
/// font scale on a 360dp phone with the longest phrase the dataset carries,
/// the setting switches the style and survives a restart, and it defaults to
/// Card when nothing is stored.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The longest phrase in the shipped dictionary, as of this build.
  const FakePhrase longest = FakePhrase(
    "What's in a name? That which we call a rose by any other name would smell as sweet",
    'aphorism',
    'Labels and titles are arbitrary; intrinsic nature and qualities matter far more.',
    register: 'literary',
  );
  const FakeWord rose = FakeWord('rose', 'noun', 'A prickly shrub with fragrant flowers.', band: 'core');

  late DictionaryDb dict;
  late UserDatabase userDb;

  setUpAll(() async {
    final ByteData font = ByteData.sublistView(File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync());
    await (FontLoader('Instrument Sans')..addFont(Future<ByteData>.value(font))).load();
  });

  setUp(() {
    dict = fakeDictionary(words: <FakeWord>[rose], phrases: <FakePhrase>[longest]);
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await userDb.close();
    dict.close();
  });

  Future<void> pumpSearch(WidgetTester tester, {double scale = 1.0}) async {
    tester.view.physicalSize = const Size(360, 640);
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
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'rose');
    for (int i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    }
  }

  testWidgets('card results never overflow: longest phrase, max scale, 360dp', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.runAsync(() async {
      await pumpSearch(tester, scale: 2.0);
      // A word and a phrase both match "rose"; the words segment shows first.
      expect(find.byType(SearchResultCard), findsOneWidget);
      await tester.tap(find.text('Phrases'));
      await tester.pump();
      expect(find.byType(SearchResultCard), findsOneWidget);
      expect(find.textContaining('smell as sweet', findRichText: true), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('the setting switches the style and survives a restart', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.runAsync(() async {
      await pumpSearch(tester);
      expect(find.byType(SearchResultCard), findsOneWidget);
      expect(find.byType(SearchResultRow), findsNothing);

      final ProviderContainer container = ProviderScope.containerOf(tester.element(find.byType(SearchScreen)));
      await container.read(settingsProvider.notifier).setSearchStyle(SearchStyle.table);
      await tester.pump();
      expect(find.byType(SearchResultRow), findsOneWidget);
      expect(find.byType(SearchResultCard), findsNothing);

      // Restart: a fresh ProviderScope reads the stored value back.
      await tester.pumpWidget(const SizedBox());
      await pumpSearch(tester);
      expect(find.byType(SearchResultRow), findsOneWidget);
      expect(find.byType(SearchResultCard), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('defaults to Card when nothing is stored', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'theme.family': 'mull'});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(AppSettings.read(prefs).searchStyle, SearchStyle.card);
  });
}
