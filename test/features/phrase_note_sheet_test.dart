import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/database/user_repository.dart';
import 'package:mull/core/providers.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/features/dictionary/idiom_sheet.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const Idiom idiom = Idiom(
    idiomKey: 'break the ice|idiom|1',
    phrase: 'break the ice',
    meaning: 'To start a conversation.',
    example: null,
    register: 'everyday',
  );
  late DictionaryDb dict;
  late UserDatabase userDb;
  late UserRepository user;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    dict = fakeDictionary(words: const <FakeWord>[]);
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
    user = UserRepository(userDb);
  });

  tearDown(() async {
    await userDb.close();
    dict.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('add, edit and delete a note on an idiom, keyed by the idiom key', (WidgetTester tester) async {
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
              body: TextButton(onPressed: () => showIdiomSheet(context, idiom: idiom), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);

    // Add.
    await tester.tap(find.text('Add a note'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'first thought');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.runAsync(() async => expect(await user.note(idiom.idiomKey), 'first thought'));
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('first thought'), findsOneWidget);

    // Edit.
    await tester.tap(find.bySemanticsLabel('Edit note'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'second thought');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('second thought'), findsOneWidget);
    await tester.runAsync(() async => expect(await user.note(idiom.idiomKey), 'second thought'));

    // Delete.
    await tester.tap(find.bySemanticsLabel('Edit note'));
    await settle(tester);
    await tester.tap(find.text('Clear all'));
    await settle(tester);
    await tester.runAsync(() async => expect(await user.note(idiom.idiomKey), isNull));

    // Undo brings it back, above what was typed since.
    await tester.enterText(find.byType(TextField), 'third thought');
    await tester.tap(find.bySemanticsLabel('Undo'));
    await settle(tester);
    await tester.runAsync(() async => expect(await user.note(idiom.idiomKey), 'second thought\nthird thought'));

    await tester.tap(find.text('Clear all'));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('second thought'), findsNothing);
    expect(find.text('Add a note'), findsOneWidget);
    await tester.runAsync(() async => expect(await user.note(idiom.idiomKey), isNull));
    await tester.pumpAndSettle(const Duration(seconds: 6));
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(Duration.zero);
      await tester.pump();
    });
  });
}
