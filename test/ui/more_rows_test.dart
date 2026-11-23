import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/motion/pressable.dart';
import 'package:mull/core/providers.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/features/settings/more_screen.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryDb dict;
  late UserDatabase userDb;

  setUpAll(() async {
    final ByteData font = ByteData.sublistView(
      File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync(),
    );
    await (FontLoader('Instrument Sans')..addFont(Future<ByteData>.value(font))).load();
  });

  setUp(() {
    dict = fakeDictionary(words: const <FakeWord>[FakeWord('ephemera', 'noun', 'Short-lived things.', band: 'core')]);
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await userDb.close();
    dict.close();
  });

  testWidgets('every More row is disc, title, subtitle under the title, and Pressable', (WidgetTester tester) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{'onboarded': true});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            prefsProvider.overrideWithValue(prefs),
            dictProvider.overrideWithValue(dict),
            userDatabaseProvider.overrideWithValue(userDb),
          ],
          child: MaterialApp(
            theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
            home: const MoreScreen(),
          ),
        ),
      );
      await tester.pump();

      final Finder rows = find.byType(MoreEntryRow);
      expect(rows, findsNWidgets(8));
      expect(tester.getTopLeft(find.text('Notes')).dy, lessThan(tester.getTopLeft(find.text('Stats')).dy), reason: 'Notes sits above Stats');
      expect(find.text('TOOLS'), findsOneWidget);
      expect(find.text('MANAGE'), findsOneWidget);
      expect(find.text('ABOUT'), findsOneWidget);
      expect(find.text('Shelves'), findsNothing);
      expect(find.text('Mixes'), findsNothing);

      for (final MoreEntryRow row in tester.widgetList<MoreEntryRow>(rows)) {
        final Finder one = find.byWidget(row);
        expect(find.descendant(of: one, matching: find.byType(MoreIconDisc)), findsOneWidget);
        expect(find.descendant(of: one, matching: find.byType(Pressable)), findsOneWidget);
        expect(row.subtitle, isNotEmpty);
        final Offset title = tester.getTopLeft(find.descendant(of: one, matching: find.text(row.title)));
        final Offset sub = tester.getTopLeft(find.descendant(of: one, matching: find.text(row.subtitle)));
        expect(sub.dx, title.dx, reason: '${row.title}: subtitle aligned with title');
        expect(sub.dy, greaterThan(title.dy), reason: '${row.title}: subtitle under title');
        expect(tester.getSize(find.descendant(of: one, matching: find.byType(MoreIconDisc))), const Size(40, 40));
        expect(tester.getSize(one).height, greaterThanOrEqualTo(72));
      }

      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(Duration.zero);
      await tester.pump();
    });
  });
}
