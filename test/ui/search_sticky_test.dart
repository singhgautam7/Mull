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
    testWidgets('search row sticky with floating header $floating', (WidgetTester tester) async {
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
        expect(find.text('Search'), findsNothing);
        await tester.enterText(find.byType(TextField), 'rose');
        for (int i = 0; i < 5; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          await tester.pump();
        }
        expect(find.byType(SearchResultCard), findsWidgets);
        expect(find.byType(SegmentedToggle<SearchSegment>), findsOneWidget);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);

        expect(find.byType(SegmentedToggle<SearchSegment>), findsNothing, reason: 'toggle scrolled away');
        if (floating) {
          expect(find.byType(SearchField), findsOneWidget);
          final Rect r = tester.getRect(find.byType(SearchField));
          expect(r.top, lessThan(80));
          expect(find.byType(SearchField).hitTestable(), findsOneWidget);
        } else {
          expect(find.byType(SearchField).hitTestable(), findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
