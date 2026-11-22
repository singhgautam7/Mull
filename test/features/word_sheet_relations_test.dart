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
import 'package:mull/core/utils/platform_surfaces.dart';
import 'package:mull/features/dictionary/word_sheet.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:mull/shared/widgets/chips.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const List<FakeWord> words = <FakeWord>[
    FakeWord(
      'cognitive',
      'adj',
      'Relating to mental processes such as thinking and reasoning.',
      synonyms: <String>['mental', 'intellectual', 'cerebral', 'rational'],
      antonyms: <String>['emotional', 'physical'],
      wordFamily: <WordFamilyMember>[
        WordFamilyMember('cognition', 'noun'),
        WordFamilyMember('cognitively', 'adv'),
        WordFamilyMember('cognizant', 'adj'),
      ],
    ),
    FakeWord(
      'cognition',
      'noun',
      'The mental action or process of acquiring knowledge.',
      inLearningSet: false,
    ),
  ];

  late DictionaryDb dict;
  late UserDatabase userDb;

  setUpAll(() async {
    final ByteData font = ByteData.sublistView(File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync());
    await (FontLoader('Instrument Sans')..addFont(Future<ByteData>.value(font))).load();
  });

  setUp(() {
    dict = fakeDictionary(words: words);
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final TestDefaultBinaryMessengerBinding b = TestDefaultBinaryMessengerBinding.instance;
    b.defaultBinaryMessenger.setMockMethodCallHandler(PlatformSurfaces.channel, (MethodCall call) async => null);
  });

  tearDown(() async {
    final TestDefaultBinaryMessengerBinding b = TestDefaultBinaryMessengerBinding.instance;
    b.defaultBinaryMessenger.setMockMethodCallHandler(PlatformSurfaces.channel, null);
    await userDb.close();
    dict.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(400, 800);
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
          home: home,
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('renders SYNONYMS, ANTONYMS, and WORD FAMILY sections without PillChip', (WidgetTester tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (BuildContext c) => TextButton(
            onPressed: () => showWordSheet(c, wordKey: words.first.key),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await settle(tester);

    // Section headers
    expect(find.text('ADJECTIVE'), findsOneWidget);
    expect(find.text('SYNONYMS'), findsOneWidget);
    expect(find.text('ANTONYMS'), findsOneWidget);
    expect(find.text('WORD FAMILY'), findsOneWidget);

    // No PillChip should exist in the sheet
    expect(find.byType(PillChip), findsNothing);

    // Synonyms and Antonyms content
    expect(find.text('mental'), findsOneWidget);
    expect(find.text('intellectual'), findsOneWidget);
    expect(find.text('cerebral'), findsOneWidget);
    expect(find.text('rational'), findsOneWidget);
    expect(find.text('emotional'), findsOneWidget);
    expect(find.text('physical'), findsOneWidget);

    // Word family member with pos label
    expect(find.textContaining('cognition'), findsOneWidget);
    expect(find.textContaining('(noun)'), findsOneWidget);
    expect(find.textContaining('cognitively'), findsOneWidget);
    expect(find.textContaining('(adverb)'), findsOneWidget);
    expect(find.textContaining('cognizant'), findsOneWidget);
    expect(find.textContaining('(adjective)'), findsOneWidget);

    // Tapping a word family member opens its sheet
    await tester.tap(find.textContaining('cognition'));
    await settle(tester);

    expect(find.text('The mental action or process of acquiring knowledge.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
