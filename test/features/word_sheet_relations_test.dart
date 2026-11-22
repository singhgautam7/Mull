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
import 'package:mull/features/dictionary/word_sheet.dart';
import 'package:mull/shared/widgets/chips.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryDb dict;
  late UserDatabase userDb;

  final List<String> many = <String>['m1', 'm2', 'm3', 'm4', 'm5', 'm6', 'm7', 'm8', 'm9', 'm10'];
  final FakeWord big = FakeWord(
    'big',
    'adjective',
    'Of great size.',
    synonyms: <String>['large', 'gargantuan'],
    antonyms: many,
    wordFamily: const <WordFamilyMember>[WordFamilyMember('bigness', 'noun')],
  );
  const FakeWord large = FakeWord('large', 'adjective', 'Of considerable size.');
  const FakeWord bigness = FakeWord('bigness', 'noun', 'The state of being big.');

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    dict = fakeDictionary(words: <FakeWord>[big, large, bigness]);
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await userDb.close();
    dict.close();
  });

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
              body: TextButton(onPressed: () => showWordSheet(context, wordKey: big.key), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('an existing related word is a chip that opens its sheet; a missing one is plain text', (WidgetTester tester) async {
    await open(tester);
    expect(find.widgetWithText(PillChip, 'large'), findsOneWidget);
    expect(find.text('gargantuan'), findsOneWidget);
    expect(find.widgetWithText(PillChip, 'gargantuan'), findsNothing);
    expect(find.widgetWithText(PillChip, 'bigness'), findsOneWidget);

    await tester.tap(find.widgetWithText(PillChip, 'large'));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Of considerable size.', skipOffstage: false), findsOneWidget);
    expect(find.text('Of great size.', skipOffstage: false), findsOneWidget, reason: 'the first sheet is still under it');
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(Duration.zero);
      await tester.pump();
    });
  });

  testWidgets('a long list shows eight chips and Show all expands the rest', (WidgetTester tester) async {
    await open(tester);
    expect(find.text('Show all (10)'), findsOneWidget);
    expect(find.text('m9'), findsNothing);
    await tester.tap(find.text('Show all (10)'));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('m9'), findsOneWidget);
    expect(find.text('m10'), findsOneWidget);
    expect(find.text('Show less'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(Duration.zero);
      await tester.pump();
    });
  });
}
