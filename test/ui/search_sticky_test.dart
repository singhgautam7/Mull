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

/// Search: the title scrolls away and the search bar becomes the pill every
/// other header becomes. Floating header off, it scrolls away with the rest.
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

        // The title and the pills have scrolled away.
        expect(find.byType(PillChip).hitTestable(), findsNothing, reason: 'filters scrolled away');
        if (floating) {
          // The header pill's geometry: 12 in from each side, 8 under the
          // status bar (none here), 56 tall, the hairline on.
          for (int i = 0; i < 60; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          final Rect r = tester.getRect(find.ancestor(of: find.byType(SearchField), matching: find.byType(Container)).first);
          expect(r, rectMoreOrLessEquals(const Rect.fromLTWH(12, 8, 336, 56), epsilon: 0.5));
          expect(find.byType(SearchField).hitTestable(), findsOneWidget);
          // Back at the top it is the resting bar again.
          await tester.drag(find.byType(CustomScrollView), const Offset(0, 4000));
          for (int i = 0; i < 60; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          final Rect rest = tester.getRect(find.ancestor(of: find.byType(SearchField), matching: find.byType(Container)).first);
          expect(rest.left, closeTo(20, 0.5));
          expect(rest.height, closeTo(48, 0.5));
        } else {
          expect(find.byType(SearchField).hitTestable(), findsNothing, reason: 'nothing is sticky with Floating header off');
        }
        await tester.pumpWidget(const SizedBox());
      });
    });
  }

  // The field once sat under the title header: the inset was read above
  // HeaderPage and came back 0, and every test here ran with no status bar,
  // where "under the header" and "at the top" are the same place. A phone has
  // a status bar, so pump one and look at the field at rest, not only pinned.
  testWidgets('Search: at rest the field sits below the title, in view and tappable; pinned it clears the status bar', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.runAsync(() async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 28);
      tester.view.viewPadding = const FakeViewPadding(top: 28);
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
      final Rect title = tester.getRect(find.text('Search'));
      final Rect field = tester.getRect(find.byType(SearchField));
      expect(field.top, greaterThanOrEqualTo(title.bottom), reason: 'the field is under the title, not behind it');
      expect(field.left, 20);
      expect(field.right, 360 - 20);
      expect(find.byType(SearchField).hitTestable(), findsOneWidget);
      expect(tester.getRect(find.byType(PillChip).first).top, greaterThanOrEqualTo(field.bottom));

      await tester.enterText(find.byType(TextField), 'rose');
      for (int i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await tester.pump();
      }
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // The pill clears the status bar; the 48dp field is centred in its 56.
      expect(tester.getRect(find.byType(SearchField)).top, closeTo(28 + 8 + 4, 0.5));
      await tester.pumpWidget(const SizedBox());
    });
  });
}
