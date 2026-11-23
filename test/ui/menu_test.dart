import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/providers.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:mull/shared/widgets/app_menu.dart';
import 'package:mull/shared/widgets/definable_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

/// One menu look: showAppMenu and the long-press menu render AppMenuRow.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('every row of showAppMenu shows an icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext c) => TextButton(
              onPressed: () => showAppMenu<String>(
                context: c,
                anchorContext: c,
                entries: const <AppMenuEntry<String>>[
                  AppMenuEntry<String>(value: 'a', label: 'One', icon: Icons.edit_outlined),
                  AppMenuEntry<String>(value: 'b', label: 'Two', icon: Icons.check_rounded, selected: true),
                  AppMenuEntry<String>.divider(),
                  AppMenuEntry<String>(value: 'c', label: 'Three', icon: Icons.delete_outline_rounded, danger: true),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.byType(AppMenuRow), findsNWidgets(3));
    for (final Element e in find.byType(AppMenuRow).evaluate()) {
      expect(find.descendant(of: find.byWidget(e.widget), matching: find.byType(Icon)), findsWidgets);
    }
    // The selected row carries a second icon, the trailing check.
    expect(find.descendant(of: find.widgetWithText(AppMenuRow, 'Two'), matching: find.byType(Icon)), findsNWidgets(2));
  });

  testWidgets('a menu fades as one panel, returns the value, ignores a disabled row, scrolls when tall', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: Builder(
              builder: (BuildContext c) => TextButton(
                onPressed: () async => picked = await showAppMenu<String>(
                  context: c,
                  anchorContext: c,
                  entries: <AppMenuEntry<String>>[
                    const AppMenuEntry<String>(value: 'off', label: 'Off row', icon: Icons.block_rounded, enabled: false),
                    for (int i = 0; i < 17; i++) AppMenuEntry<String>(value: '$i', label: 'Row $i', icon: Icons.edit_outlined),
                  ],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    // One fade for the panel, none per row (17 rows were 17 layers a frame).
    expect(find.descendant(of: find.byType(AppMenuPanel), matching: find.byType(FadeTransition)), findsNothing);
    final Rect panel = tester.getRect(find.byType(AppMenuPanel));
    expect(panel.bottom, lessThanOrEqualTo(600));
    expect(panel.right, lessThanOrEqualTo(400));
    await tester.tap(find.text('Off row'));
    await settle(tester);
    expect(find.byType(AppMenuPanel), findsOneWidget);
    await tester.ensureVisible(find.text('Row 16'));
    await settle(tester);
    await tester.tap(find.text('Row 16'));
    await settle(tester);
    expect(picked, '16');
    expect(find.byType(AppMenuPanel), findsNothing);
    // A tap outside closes with nothing.
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.tapAt(const Offset(10, 300));
    await settle(tester);
    expect(find.byType(AppMenuPanel), findsNothing);
    expect(picked, isNull);
  });

  testWidgets('the long-press menu renders AppMenuRows with icons', (WidgetTester tester) async {
    final DictionaryDb dict = fakeDictionary(words: const <FakeWord>[
      FakeWord('petulant', 'adjective', 'Silent and sulky.'),
      FakeWord('sulky', 'adjective', 'Silent and moody.', inLearningSet: false),
    ]);
    final UserDatabase userDb = UserDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await userDb.close();
      dict.close();
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          prefsProvider.overrideWithValue(prefs),
          userDatabaseProvider.overrideWithValue(userDb),
          dictProvider.overrideWithValue(dict),
        ],
        child: MaterialApp(
          theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
          home: const Scaffold(body: Padding(padding: EdgeInsets.all(24), child: DefinableText('Silent and sulky.', style: TextStyle(fontSize: 18)))),
        ),
      ),
    );
    await settle(tester);
    final EditableTextState state = tester.state<EditableTextState>(find.byType(EditableText).first);
    final int at = state.textEditingValue.text.indexOf('sulky');
    final RenderEditable r = state.renderEditable;
    final List<TextBox> boxes = r.getBoxesForSelection(TextSelection(baseOffset: at, extentOffset: at + 5));
    await tester.longPressAt(r.localToGlobal(boxes.first.toRect().center));
    await settle(tester);
    expect(find.byType(AppMenuPanel), findsOneWidget);
    expect(find.byType(AppMenuRow), findsNWidgets(2));
    expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
    expect(find.text('Define "sulky"'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
