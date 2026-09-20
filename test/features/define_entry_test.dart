import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/providers.dart';
import 'package:mull/core/utils/platform_surfaces.dart';
import 'package:mull/define_main.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

/// The "Define in Mull" entry point: a see-through host that draws its first
/// frame at once, opens the sheet for the arrival, and finishes the activity
/// the moment the last sheet is gone. It must never keep the caller waiting:
/// the launch transition holds the whole display until the first frame.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryDb dict;
  late UserDatabase userDb;
  late List<String> calls;
  Map<String, String?>? arrival;

  setUp(() async {
    dict = fakeDictionary(
      words: const <FakeWord>[
        FakeWord('abate', 'verb', 'To lessen in force or intensity.'),
        FakeWord('serendipity', 'noun', 'A happy accident.'),
        // Everyday words, not in the learning set: the kind a short
        // selection is usually made of.
        FakeWord('command', 'noun', 'An order.', inLearningSet: false),
        FakeWord('line', 'noun', 'A long mark.', inLearningSet: false),
        FakeWord('command-line', 'noun', 'A text interface.', band: 'uncommon', inLearningSet: false),
      ],
    );
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues(<String, Object>{});
    calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      PlatformSurfaces.channel,
      (MethodCall call) async {
        calls.add(call.method);
        if (call.method == 'openInApp') calls.add('openInApp:${(call.arguments as Map<Object?, Object?>)['route']}');
        if (call.method == 'incomingText') {
          final Map<String, String?>? a = arrival;
          arrival = null;
          return a;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(PlatformSurfaces.channel, null);
    await userDb.close();
    dict.close();
  });

  /// Fixed pumps, never pumpAndSettle: the install state and the sheet's
  /// hairline animate, so settle would wait forever.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Unmounts the tree and lets the user database's stream timers fire, so
  /// nothing is pending when the test ends.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> pumpDefine(WidgetTester tester) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          prefsProvider.overrideWithValue(prefs),
          userDatabaseProvider.overrideWithValue(userDb),
          dictionaryProvider.overrideWith((Ref ref) async => dict),
        ],
        child: const DefineApp(),
      ),
    );
  }

  testWidgets('draws a first frame at once and opens the sheet for a word', (WidgetTester tester) async {
    arrival = <String, String?>{'text': 'serendipity', 'wordKey': null, 'sourceHint': 'com.example.reader'};
    await pumpDefine(tester);
    // One frame, before the dictionary future resolves: never blank for the caller.
    expect(find.byType(Scaffold), findsOneWidget, reason: 'first frame drawn');

    await settle(tester);
    expect(calls, contains('incomingText'));
    expect(find.text('serendipity'), findsWidgets, reason: 'the word sheet is open');
    expect(find.text('Back to Reader'), findsOneWidget, reason: 'opened from outside');
    expect(calls, isNot(contains('finish')));

    // Dismissing the sheet finishes the activity: the user is back in Reader.
    await tester.tap(find.text('Back to Reader'));
    await settle(tester);
    expect(calls, contains('finish'));
    await unmount(tester);
  });

  testWidgets('an empty selection finishes without showing anything', (WidgetTester tester) async {
    arrival = <String, String?>{'text': '   ', 'wordKey': null, 'sourceHint': null};
    await pumpDefine(tester);
    await settle(tester);
    expect(calls, contains('finish'));
    expect(find.byType(BottomSheet), findsNothing);
    await unmount(tester);
  });

  testWidgets('a word Mull does not have opens the unknown-word sheet, then finishes', (WidgetTester tester) async {
    arrival = <String, String?>{'text': 'xylophonist', 'wordKey': null, 'sourceHint': null};
    await pumpDefine(tester);
    await settle(tester);
    expect(find.textContaining('xylophonist'), findsWidgets);
    expect(calls, isNot(contains('finish')));
    await tester.tap(find.bySemanticsLabel('Not now'));
    await settle(tester);
    expect(calls, contains('finish'));
    await unmount(tester);
  });

  testWidgets('a multi-word selection offers the picker', (WidgetTester tester) async {
    arrival = <String, String?>{'text': 'The storm will abate, they said, with serendipity.', 'wordKey': null, 'sourceHint': null};
    await pumpDefine(tester);
    await settle(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(calls, isNot(contains('finish')));
    await unmount(tester);
  });

  testWidgets('a short selection of everyday words offers each word, or the phrase itself', (WidgetTester tester) async {
    // "Command Line" is a headword (`command-line`), so the whole selection opens.
    arrival = <String, String?>{'text': 'Command Line', 'wordKey': null, 'sourceHint': null};
    await pumpDefine(tester);
    await settle(tester);
    expect(find.text('command-line'), findsWidgets, reason: 'the phrase is an entry');
    await unmount(tester);

    // Two everyday words with no entry for the pair: both are offered.
    arrival = <String, String?>{'text': 'line command', 'wordKey': null, 'sourceHint': null};
    await pumpDefine(tester);
    await settle(tester);
    expect(find.text('DID YOU MEAN ONE OF THESE'), findsOneWidget);
    expect(find.text('command'), findsOneWidget);
    expect(find.text('line'), findsOneWidget);
    // Picking one opens its entry over the caller.
    await tester.tap(find.text('command'));
    await settle(tester);
    expect(find.text('An order.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('an unknown word gets "Did you mean" and a one-row search / not-now', (WidgetTester tester) async {
    arrival = <String, String?>{'text': 'serendipty', 'wordKey': null, 'sourceHint': null};
    await pumpDefine(tester);
    await settle(tester);
    expect(find.text('DID YOU MEAN'), findsOneWidget);
    expect(find.textContaining('serendipity'), findsWidgets);
    expect(find.bySemanticsLabel('Not now'), findsOneWidget);
    await tester.tap(find.text('Search Mull for it'));
    await settle(tester);
    expect(calls, contains('openInApp:/search?q=serendipty'));
    await unmount(tester);
  });
}
