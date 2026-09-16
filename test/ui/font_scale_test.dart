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
import 'package:mull/features/collections/collection_cards.dart';
import 'package:mull/features/collections/collection_screen.dart';
import 'package:mull/features/collections/collections_screen.dart';
import 'package:mull/features/collections/create_list_sheet.dart';
import 'package:mull/features/dictionary/add_to_list_sheet.dart';
import 'package:mull/features/dictionary/note_sheet.dart';
import 'package:mull/features/dictionary/search_screen.dart';
import 'package:mull/features/dictionary/word_sheet.dart';
import 'package:mull/features/home/home_screen.dart';
import 'package:mull/core/database/mix_repository.dart';
import 'package:mull/features/linger/linger_rules.dart';
import 'package:mull/features/linger/linger_screen.dart';
import 'package:mull/features/linger/mix_sheet.dart';
import 'package:mull/features/linger/saved_mixes_screen.dart';
import 'package:mull/features/linger/word_card.dart';
import 'package:mull/features/settings/export_screen.dart';
import 'package:mull/features/settings/info_screens.dart';
import 'package:mull/features/settings/more_screen.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:mull/features/settings/settings_screen.dart';
import 'package:mull/features/settings/theme_screen.dart';
import 'package:mull/features/settings/welcome_screen.dart';
import 'package:mull/features/stats/stats_screen.dart';
import 'package:mull/shared/widgets/two_column_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

/// Nothing overflows at the largest OS font scale on a 360dp phone, with the
/// longest headword and definition the dataset carries. A RenderFlex
/// overflow is an exception in a widget test, so every pump here is an
/// assertion.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Android's largest font scale.
  const double maxScale = 2.0;

  // The longest entries in the shipped learning set, as of this build.
  const FakeWord longest = FakeWord(
    'institutionalisation',
    'noun',
    'Pertaining to the universal Church, representing the entire Christian world; interdenominational; sometimes by extension, interreligious.',
    ipa: '/ˌɪnstɪˌtjuːʃənəlaɪˈzeɪʃən/',
    examples: <String>[
      'The institutionalisation of the practice, which had once been informal and ad hoc, took the better part of a decade and left almost nobody satisfied with the result.',
    ],
    synonyms: <String>['formalisation', 'systematisation', 'regularisation', 'standardisation'],
  );
  const FakeWord abate = FakeWord('abate', 'verb', 'To lessen in force or intensity.', examples: <String>['The storm abated by morning.']);
  const FakeWord colour = FakeWord('colour', 'noun', 'The spectral composition of light.');

  late DictionaryDb dict;
  late UserDatabase userDb;

  setUpAll(() async {
    // Real metrics: the bundled typeface, not the test font.
    final ByteData font = ByteData.sublistView(File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync());
    await (FontLoader('Instrument Sans')..addFont(Future<ByteData>.value(font))).load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{'onboarded': true});
    dict = fakeDictionary(
      words: <FakeWord>[longest, abate, colour],
      collections: <String, List<String>>{
        'core': <String>[abate.key, colour.key],
        'everyday': <String>[longest.key, abate.key],
        'old_and_worth_reviving': <String>[longest.key],
      },
      details: <String, (String, String, String)>{
        'core': ('band', 'Easy Words', 'The common core, worth being sure of.'),
        'everyday': ('band', 'Everyday', 'Words you will use this week.'),
        'old_and_worth_reviving': ('topic', 'Old and Worth Reviving', 'Out of fashion, not out of use.'),
      },
    );
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await userDb.close();
    dict.close();
  });

  Future<void> pumpAt(WidgetTester tester, Widget screen, {double scale = maxScale}) async {
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
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    // Let the user database's streams deliver, then settle.
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Widget card(FakeWord w, {bool bookmarked = false}) => Scaffold(
    body: Padding(
      // The Mull tab's insets: 96 from the top, 104 from the bottom.
      padding: const EdgeInsets.fromLTRB(14, 96, 14, 104),
      child: WordCard(
        word: dict.byKey(w.key)!,
        examples: w.examples,
        synonyms: w.synonyms,
        seenBefore: true,
        bookmarked: bookmarked,
        hasNote: true,
        onNote: () {},
        onBookmark: () {},
        onShare: () {},
        onOverflow: (_) {},
        onSpeak: () {},
      ),
    ),
  );

  testWidgets('the word card never overflows: longest entries, max scale, 360dp', (WidgetTester tester) async {
    await pumpAt(tester, card(longest));
    expect(find.textContaining('institutionalisation', findRichText: true), findsOneWidget);
    // The action row is pinned inside the card and fully visible.
    final Rect share = tester.getRect(find.bySemanticsLabel('Share'));
    expect(share.bottom, lessThanOrEqualTo(640 - 104));
    expect(share.height, 52);
  });

  testWidgets('the word card at every scale, with and without an example', (WidgetTester tester) async {
    for (final double scale in <double>[1.0, 1.3, 1.6, maxScale]) {
      await pumpAt(tester, card(longest, bookmarked: true), scale: scale);
      await pumpAt(tester, card(colour), scale: scale);
    }
  });

  testWidgets('collection cards grow with their text', (WidgetTester tester) async {
    final List<Collection> all = dict.collections();
    final Collection topic = all.singleWhere((Collection c) => c.slug == 'old_and_worth_reviving');
    final Collection band = all.singleWhere((Collection c) => c.slug == 'core');
    await pumpAt(
      tester,
      Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            TwoColumnGrid(
              children: <Widget>[
                TopicCard(collection: topic, progress: const Progress(1, 1), onTap: () {}),
                TopicCard(collection: topic, progress: const Progress(0, 1), compact: true, onTap: () {}),
              ],
            ),
            BandRow(collection: band, progress: const Progress(1, 2), onTap: () {}),
          ],
        ),
      ),
    );
    expect(find.text('Old and Worth Reviving'), findsNWidgets(2));
  });

  testWidgets('every screen at max scale', (WidgetTester tester) async {
    await tester.runAsync(() async {
      final UserRepository user = UserRepository(userDb);
      await user.ensureSystemCollections();
      final String slug = await user.createCollection('A list with a fairly long name');
      await user.addToCollection(slug, longest.key);
      await user.addBookmark(longest.key);
      await user.recordLookup(longest.key);
      await user.markSeen(abate.key);

      for (final Widget screen in <Widget>[
        const HomeScreen(),
        const CollectionsScreen(),
        const CollectionScreen(slug: 'everyday'),
        CollectionScreen(slug: slug),
        const CollectionScreen(slug: UserRepository.bookmarksSlug),
        const MoreScreen(),
        const SettingsScreen(),
        const ThemeScreen(),
        const StatsScreen(),
        const WelcomeScreen(),
        const SearchScreen(),
        const ExportScreen(),
        const AboutScreen(),
        const PrivacyScreen(),
        const DictionaryInfoScreen(),
        const PermissionsScreen(),
        const SavedMixesScreen(),
        const LingerScreen(scope: 'everyday'),
      ]) {
        await pumpAt(tester, screen);
        for (int i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
        // Lists lay out lazily: scroll to the bottom so every row is built.
        final Finder vertical = find.byWidgetPredicate((Widget w) => w is Scrollable && w.axis == Axis.vertical && w is! PageView);
        if (screen is! LingerScreen && vertical.evaluate().isNotEmpty) {
          for (int i = 0; i < 8; i++) {
            await tester.drag(vertical.first, const Offset(0, -500), warnIfMissed: false);
            await tester.pump();
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(Duration.zero);
      await tester.pump();
    });
  });

  testWidgets('every sheet at max scale', (WidgetTester tester) async {
    await tester.runAsync(() async {
      final UserRepository user = UserRepository(userDb);
      await user.ensureSystemCollections();
      await user.putNote(longest.key, 'A note that runs on for a while so the sheet has something to show at the top.');
      const MixSpec active = MixSpec(id: 1, name: 'Anything', isPreset: true, sources: <String>['core', 'everyday'], seenPolicy: SeenPolicy.light);
      for (final Future<void> Function(BuildContext) open in <Future<void> Function(BuildContext)>[
        (BuildContext c) => showWordSheet(c, wordKey: longest.key, fromSearch: true),
        (BuildContext c) => showNoteSheet(c, wordKey: longest.key, headword: longest.headword),
        (BuildContext c) => showAddToListSheet(c, wordKey: longest.key, headword: longest.headword),
        (BuildContext c) => showCreateListSheet(c),
        (BuildContext c) => showMixSheet(c, active: active),
      ]) {
        await pumpAt(
          tester,
          Scaffold(body: Builder(builder: (BuildContext c) => TextButton(onPressed: () => open(c), child: const Text('open')))),
        );
        await tester.tap(find.text('open'));
        for (int i = 0; i < 12; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          await tester.pump();
        }
        final Finder vertical = find.byWidgetPredicate((Widget w) => w is Scrollable && w.axis == Axis.vertical);
        if (vertical.evaluate().isNotEmpty) {
          for (int i = 0; i < 6; i++) {
            await tester.drag(vertical.last, const Offset(0, -500), warnIfMissed: false);
            await tester.pump();
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(Duration.zero);
      await tester.pump();
    });
  });
}
