import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:mull/features/linger/word_card.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:mull/shared/widgets/definable_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

/// Long press in a definition: select a word, then Define or Copy. The menu
/// resolves exact, alias, phrase and lemma (never fuzzy), opens the entry's
/// sheet over the current one, and leaves the Mull tab's paging alone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const List<FakeWord> words = <FakeWord>[
    FakeWord('petulant', 'adjective', 'Childishly sulky or bad-tempered when angered.'),
    FakeWord('whimsical', 'adjective', 'Playfully quaint and fanciful, full of whim.'),
    FakeWord('adamant', 'adjective', 'Refusing to be persuaded; unwilling to change one\'s mind.'),
    FakeWord('sulky', 'adjective', 'Silent and moody.', inLearningSet: false),
    FakeWord('anger', 'noun', 'A strong feeling of displeasure.', inLearningSet: false),
    FakeWord('quaint', 'adjective', 'Attractively old-fashioned.', inLearningSet: false),
    FakeWord('persuade', 'verb', 'To win someone over.', inLearningSet: false),
  ];
  const FakePhrase mind = FakePhrase('change one\'s mind', 'idiom', 'To decide differently.');

  late DictionaryDb dict;
  late UserDatabase userDb;
  Map<String, Object?>? clipboard;
  int? sdk;

  setUpAll(() async {
    final ByteData font = ByteData.sublistView(File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync());
    await (FontLoader('Instrument Sans')..addFont(Future<ByteData>.value(font))).load();
  });

  setUp(() {
    dict = fakeDictionary(words: words, phrases: <FakePhrase>[mind]);
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues(<String, Object>{});
    clipboard = null;
    sdk = null;
    final TestDefaultBinaryMessengerBinding b = TestDefaultBinaryMessengerBinding.instance;
    b.defaultBinaryMessenger.setMockMethodCallHandler(PlatformSurfaces.channel, (MethodCall call) async {
      if (call.method == 'sdkInt') return sdk;
      return null;
    });
    b.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map<Object?, Object?>).cast<String, Object?>();
      return null;
    });
  });

  tearDown(() async {
    final TestDefaultBinaryMessengerBinding b = TestDefaultBinaryMessengerBinding.instance;
    b.defaultBinaryMessenger.setMockMethodCallHandler(PlatformSurfaces.channel, null);
    b.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    await userDb.close();
    dict.close();
  });

  /// Fixed pumps, never pumpAndSettle: streams and the hairline animate.
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
        child: MaterialApp(theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light), home: home),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  }

  Widget definition(FakeWord w) => Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(w.headword, key: const Key('headword'), style: const TextStyle(fontSize: 32)),
          DefinableText(w.definition, style: const TextStyle(fontSize: 18)),
        ],
      ),
    ),
  );

  /// The global centre of [word] inside the (single) selectable text.
  Offset centreOf(WidgetTester tester, String word) {
    final EditableTextState state = tester.state<EditableTextState>(find.byType(EditableText).first);
    final int at = state.textEditingValue.text.indexOf(word);
    expect(at, isNonNegative, reason: '$word is in the text');
    final RenderEditable r = state.renderEditable;
    final List<TextBox> boxes = r.getBoxesForSelection(TextSelection(baseOffset: at, extentOffset: at + word.length));
    return r.localToGlobal(boxes.first.toRect().center);
  }

  Future<void> pressWord(WidgetTester tester, String word) async {
    await tester.longPressAt(centreOf(tester, word));
    await settle(tester);
  }

  /// Selects [from, to) as a drag of the handles would.
  Future<void> selectRange(WidgetTester tester, String from, String to) async {
    final EditableTextState state = tester.state<EditableTextState>(find.byType(EditableText).first);
    final String text = state.textEditingValue.text;
    final int start = text.indexOf(from);
    final int end = text.indexOf(to) + to.length;
    state.userUpdateTextEditingValue(
      state.textEditingValue.copyWith(selection: TextSelection(baseOffset: start, extentOffset: end)),
      SelectionChangedCause.drag,
    );
    state.showToolbar();
    await settle(tester);
  }

  testWidgets('a long press selects the word and offers Define and Copy', (WidgetTester tester) async {
    await pumpApp(tester, definition(words.first));
    expect(find.text('Copy'), findsNothing, reason: 'no menu at rest');
    await pressWord(tester, 'sulky');
    expect(find.text('Define "sulky"'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    // Nothing else is offered.
    expect(find.text('Share'), findsNothing);
    expect(find.text('Select all'), findsNothing);
    expect(find.bySemanticsLabel('Define "sulky"'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('petulant, whimsical and adamant each define a word in their definition', (WidgetTester tester) async {
    const Map<String, String> inside = <String, String>{'petulant': 'sulky', 'whimsical': 'quaint', 'adamant': 'persuaded'};
    for (final FakeWord w in words.take(3)) {
      await pumpApp(tester, definition(w));
      final String target = inside[w.headword]!;
      await pressWord(tester, target);
      expect(find.text('Define "$target"'), findsOneWidget, reason: '${w.headword}: $target');
      await unmount(tester);
    }
  });

  testWidgets('Define opens the entry, and an inflected form opens its lemma', (WidgetTester tester) async {
    await pumpApp(tester, definition(words.first));
    await pressWord(tester, 'angered');
    expect(find.text('Define "angered"'), findsOneWidget, reason: 'angered resolves to anger');
    await tester.tap(find.text('Define "angered"'));
    await settle(tester);
    expect(find.text('anger'), findsOneWidget, reason: 'the sheet for the lemma');
    expect(find.text('A strong feeling of displeasure.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a sheet opens over the sheet and back returns to the first word', (WidgetTester tester) async {
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
    expect(find.text('petulant'), findsWidgets);

    await pressWord(tester, 'sulky');
    await tester.tap(find.text('Define "sulky"'));
    await settle(tester);
    expect(find.text('Silent and moody.'), findsOneWidget, reason: 'sulky is open');
    expect(find.text('Childishly sulky or bad-tempered when angered.'), findsOneWidget, reason: 'petulant is still under it');

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Silent and moody.'), findsNothing);
    expect(find.text('Childishly sulky or bad-tempered when angered.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a selection of several words is Copy only unless the phrase is an entry', (WidgetTester tester) async {
    await pumpApp(tester, definition(words.first));
    await selectRange(tester, 'Childishly', 'sulky');
    expect(find.text('Copy'), findsOneWidget);
    expect(find.textContaining('Define'), findsNothing, reason: '"Childishly sulky" is not an entry');
    await unmount(tester);

    await pumpApp(tester, definition(words[2]));
    await selectRange(tester, 'change', 'mind');
    expect(find.text('Define "change one\'s mind"'), findsOneWidget, reason: 'a phrase entry');
    await tester.tap(find.text('Define "change one\'s mind"'));
    await settle(tester);
    expect(find.text('IDIOM'), findsOneWidget);
    expect(find.text('To decide differently.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a typo never defines a different word', (WidgetTester tester) async {
    expect(dict.resolveSelection('sulkey', phrases: true, lemma: true), (word: null, idiom: null));
    expect(dict.resolveSelection('angered', lemma: true).word?.headword, 'anger');
    expect(dict.resolveSelection('angered').word, isNull, reason: 'lemma is opt-in');
  });

  testWidgets('a long press outside the definition shows no menu', (WidgetTester tester) async {
    await pumpApp(tester, definition(words.first));
    await tester.longPress(find.byKey(const Key('headword')));
    await settle(tester);
    expect(find.text('Copy'), findsNothing);
    expect(find.textContaining('Define'), findsNothing);
    await unmount(tester);
  });

  testWidgets('Copy copies, and confirms below Android 13 only', (WidgetTester tester) async {
    for (final (int? level, bool toast) in <(int?, bool)>[(30, true), (null, true), (34, false)]) {
      sdk = level;
      clipboard = null;
      await pumpApp(tester, definition(words.first));
      await pressWord(tester, 'sulky');
      await tester.tap(find.text('Copy'));
      await settle(tester);
      expect(clipboard?['text'], 'sulky', reason: 'sdk $level');
      expect(find.text('Copied'), toast ? findsOneWidget : findsNothing, reason: 'sdk $level');
      await unmount(tester);
      await tester.pump(const Duration(seconds: 5));
    }
  });

  testWidgets('the word card still pages on a vertical drag', (WidgetTester tester) async {
    final PageController pager = PageController();
    addTearDown(pager.dispose);
    Widget card(FakeWord w) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 34, 14, 104),
      child: WordCard(
        word: dict.byKey(w.key)!,
        examples: const <String>[],
        synonyms: const <String>[],
        seenBefore: false,
        bookmarked: false,
        hasNote: false,
        onOpenEntry: () {},
        onNote: () {},
        onBookmark: () {},
        onOverflow: (_) {},
        onSpeak: () {},
      ),
    );
    await pumpApp(
      tester,
      Scaffold(
        body: PageView(
          controller: pager,
          scrollDirection: Axis.vertical,
          children: <Widget>[card(words[0]), card(words[1])],
        ),
      ),
    );
    // A drag that begins on the definition text pages.
    final TestGesture g = await tester.startGesture(tester.getCenter(find.byType(EditableText).first));
    for (int i = 0; i < 30; i++) {
      await g.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await settle(tester);
    expect(pager.page, closeTo(1.0, 0.01));
    expect(find.textContaining('Playfully quaint'), findsOneWidget);

    // And a long press on the definition still selects a word, in place.
    await pressWord(tester, 'quaint');
    expect(pager.page, closeTo(1.0, 0.01));
    expect(find.text('Define "quaint"'), findsOneWidget);
    await unmount(tester);
  });
}
