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
import 'package:mull/features/collections/add_to_shelf_screen.dart';
import 'package:mull/features/collections/collection_screen.dart';
import 'package:mull/shared/widgets/app_icon_button.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const FakeWord abate = FakeWord('abate', 'verb', 'To lessen in force or intensity.');

  late DictionaryDb dict;
  late UserDatabase userDb;

  setUpAll(() async {
    final ByteData font = ByteData.sublistView(File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync());
    await (FontLoader('Instrument Sans')..addFont(Future<ByteData>.value(font))).load();
  });

  setUp(() {
    dict = fakeDictionary(
      words: const <FakeWord>[abate],
      collections: <String, List<String>>{'everyday': <String>[abate.key]},
      details: <String, (String, String, String)>{'everyday': ('band', 'Everyday', 'Words for this week.')},
    );
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
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

  Future<void> pump(WidgetTester tester, Widget screen) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'onboarded': true});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          prefsProvider.overrideWithValue(prefs),
          userDatabaseProvider.overrideWithValue(userDb),
          dictProvider.overrideWithValue(dict),
        ],
        child: MaterialApp(theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light), home: screen),
      ),
    );
    await settle(tester);
  }

  AppIconButton button(WidgetTester tester, String label) => tester.widget<AppIconButton>(
    find.byWidgetPredicate((Widget w) => w is AppIconButton && w.semanticLabel == label),
  );

  Future<void> openOverflow(WidgetTester tester) async {
    await tester.tap(find.byWidgetPredicate((Widget w) => w is AppIconButton && w.semanticLabel == 'More'));
    await settle(tester);
  }

  testWidgets('a pre-made shelf cannot be added to', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await pump(tester, const CollectionScreen(slug: 'everyday'));
      expect(find.byWidgetPredicate((Widget w) => w is AppIconButton && w.semanticLabel == 'Add'), findsNothing);
      await openOverflow(tester);
      expect(find.text('Export this shelf'), findsOneWidget);
      expect(find.text('Add words'), findsNothing);
      expect(find.text('Add phrases'), findsNothing);
      expect(find.text('Import words'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('your own shelf keeps every way to add', (WidgetTester tester) async {
    await tester.runAsync(() async {
      final String slug = await UserRepository(userDb).createCollection('Mine');
      await pump(tester, CollectionScreen(slug: slug));
      expect(button(tester, 'Add').onPressed, isNotNull);
      await openOverflow(tester);
      expect(find.text('Add words'), findsOneWidget);
      expect(find.text('Add phrases'), findsOneWidget);
      expect(find.text('Import words'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('the add screen on a pre-made slug shows no picker', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await pump(tester, const AddToShelfScreen(slug: 'everyday', phrases: false));
      expect(find.text('This shelf is not yours to change'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
