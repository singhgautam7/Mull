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
import 'package:mull/shared/widgets/chips.dart';
import 'package:mull/shared/widgets/fields.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

/// Search has no title header: the field is the header. Floating header on,
/// it stays pinned while the Words/Phrases toggle scrolls away with the
/// results; off, the whole row scrolls away like any other header.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryDb dict;
  late UserDatabase userDb;

  setUpAll(() async {
    final ByteData font = ByteData.sublistView(File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync());
    await (FontLoader('Instrument Sans')..addFont(Future<ByteData>.value(font))).load();
  });

  setUp(() {
    dict = fakeDictionary(
      words: <FakeWord>[
        for (int i = 0; i < 40; i++) FakeWord('rose${String.fromCharCode(97 + i % 26)}$i', 'noun', 'A flower number $i.'),
      ],
    );
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await userDb.close();
    dict.close();
  });

  for (final bool floating in <bool>[true, false]) {
    testWidgets('Search: title, pill filters, only the search bar sticks (floating header $floating)', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'header.floating': floating});
      await tester.runAsync(() async {
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
              home: const SearchScreen(),
            ),
          ),
        );
        await tester.pump();
        // The Shelves tab's header, and All / Words / Phrases pills with Words on.
        expect(find.text('Search'), findsOneWidget);
        expect(find.byType(PillChip), findsNWidgets(3));
        final PillChip words = tester.widget<PillChip>(find.widgetWithText(PillChip, 'Words'));
        expect(words.selected, isTrue);
        expect(tester.widget<PillChip>(find.widgetWithText(PillChip, 'All')).selected, isFalse);

        await tester.enterText(find.byType(TextField), 'rose');
        for (int i = 0; i < 5; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          await tester.pump();
        }
        expect(find.byType(SearchResultCard), findsWidgets);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);

        // Whatever the setting, the bar stays at the top; the title and the
        // pills have scrolled away.
        expect(find.byType(PillChip).hitTestable(), findsNothing, reason: 'filters scrolled away');
        final Rect r = tester.getRect(find.byType(SearchField));
        expect(r.top, lessThan(40));
        expect(r.top, greaterThanOrEqualTo(0));
        expect(find.byType(SearchField).hitTestable(), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
