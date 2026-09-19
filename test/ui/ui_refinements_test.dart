import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/app/nav_bar.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/database/user_repository.dart';
import 'package:mull/core/providers.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/features/collections/collection_cards.dart';
import 'package:mull/features/collections/collection_screen.dart';
import 'package:mull/features/collections/collections_screen.dart';
import 'package:mull/features/dictionary/search_screen.dart';
import 'package:mull/features/linger/saved_mixes_screen.dart';
import 'package:mull/features/linger/word_card.dart';
import 'package:mull/features/settings/data_screen.dart';
import 'package:mull/features/settings/more_screen.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:mull/features/settings/settings_screen.dart';
import 'package:mull/features/settings/settings_widgets.dart';
import 'package:mull/shared/widgets/app_button.dart';
import 'package:mull/shared/widgets/app_icon_button.dart';
import 'package:mull/shared/widgets/app_snackbar.dart';
import 'package:mull/shared/widgets/chips.dart';
import 'package:mull/shared/widgets/mull_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const FakeWord ephemera = FakeWord(
    'ephemera',
    'noun',
    'Things that exist or are used or enjoyed for only a short time.',
    band: 'core',
  );

  late DictionaryDb dict;
  late UserDatabase userDb;

  setUpAll(() async {
    final ByteData font = ByteData.sublistView(
      File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync(),
    );
    await (FontLoader('Instrument Sans')..addFont(Future<ByteData>.value(font))).load();
  });

  setUp(() {
    dict = fakeDictionary(words: <FakeWord>[ephemera]);
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await userDb.close();
    dict.close();
  });

  testWidgets('AppIconButton displays AppTooltip on long press', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
        home: Scaffold(
          body: Center(
            child: AppIconButton(
              icon: Icons.bookmark_rounded,
              semanticLabel: 'Bookmark',
              tooltip: 'Save to bookmarks',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    // Long press on button
    await tester.longPress(find.byType(AppIconButton));
    await tester.pump();

    // Tooltip should be visible
    expect(find.text('Save to bookmarks'), findsOneWidget);
  });

  testWidgets('AppSnackbar shows timed top snackbar with linear progress indicator and close button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: ElevatedButton(
                onPressed: () => AppSnackbar.info(context, 'Test snackbar message'),
                child: const Text('Show snackbar'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show snackbar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Test snackbar message'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Dismiss by tapping close
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Test snackbar message'), findsNothing);
  });

  testWidgets('WordCard action row contains Open full entry, Bookmark, Add note, and More', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
        home: Scaffold(
          body: WordCard(
            word: dict.byKey(ephemera.key)!,
            examples: const <String>['Collecting bus tickets and other ephemera.'],
            synonyms: const <String>['transience'],
            seenBefore: false,
            bookmarked: false,
            hasNote: false,
            onOpenEntry: () {},
            onBookmark: () {},
            onNote: () {},
            onOverflow: (_) {},
            onSpeak: () {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Open full entry'), findsOneWidget);
    expect(find.bySemanticsLabel('Bookmark'), findsOneWidget);
    expect(find.bySemanticsLabel('Add note'), findsOneWidget);
    expect(find.bySemanticsLabel('More'), findsOneWidget);
  });

  testWidgets('SearchScreen shows duplicate feedback when word already exists in shelf', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final UserRepository userRepo = UserRepository(userDb);
    await userRepo.ensureSystemCollections();
    await userRepo.addToCollection('from-my-reading', ephemera.key);

    await tester.runAsync(() async {
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
            home: const SearchScreen(
              addToCollectionSlug: 'from-my-reading',
              initialSegment: SearchSegment.words,
            ),
          ),
        ),
      );

      // Search for ephemera
      await tester.enterText(find.byType(TextField), 'ephem');
      for (int i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }

      // Tap on result
      expect(find.text('ephemera'), findsOneWidget);
      await tester.tap(find.text('ephemera'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();

      // Duplicate message should appear
      expect(find.text('Word already exists in the shelf'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('AppButton of type outlined has surface background and accent border', (
    WidgetTester tester,
  ) async {
    final ThemeData theme = AppTheme.of(ThemeFamily.byId('mull'), Tone.light);
    final MullColors colors = ThemeFamily.byId('mull').colors(Tone.light);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: AppButton(
              label: 'Add words',
              type: AppButtonType.outlined,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    final Material material = tester.widget<Material>(
      find.descendant(of: find.byType(AppButton), matching: find.byType(Material)).first,
    );
    expect(material.color, colors.surface);
    final StadiumBorder shape = material.shape! as StadiumBorder;
    expect(shape.side.color, colors.accent);
  });

  test('kDestinations includes 5 tabs: Home, Mull, Shelves, Search, More', () {
    expect(kDestinations.length, 5);
    expect(kDestinations[0].label, 'Home');
    expect(kDestinations[0].glyph, MullGlyph.home);
    expect(kDestinations[1].label, 'Mull');
    expect(kDestinations[1].glyph, MullGlyph.mull);
    expect(kDestinations[2].label, 'Shelves');
    expect(kDestinations[2].glyph, MullGlyph.collections);
    expect(kDestinations[3].label, 'Search');
    expect(kDestinations[3].glyph, MullGlyph.search);
    expect(kDestinations[4].label, 'More');
    expect(kDestinations[4].glyph, MullGlyph.more);
  });

  testWidgets('SettingsScreen pronunciation speed row opens bottom sheet with slider', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'onboarded': true});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          prefsProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
          home: const SettingsScreen(),
        ),
      ),
    );

    // Verify OTHER group does not exist
    expect(find.text('OTHER'), findsNothing);

    // Find and tap Pronunciation speed row
    final Finder rowFinder = find.text('Pronunciation speed');
    expect(rowFinder, findsOneWidget);
    await tester.tap(rowFinder);
    await tester.pumpAndSettle();

    // Verify bottom sheet title and slider are displayed
    expect(find.text('Pronunciation speed'), findsNWidgets(2)); // row + sheet title
    expect(find.text('Speed'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Tap Done to close sheet
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  });

  testWidgets('MoreScreen shows Data row under Your data below Permissions without Export', (
    WidgetTester tester,
  ) async {
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

      // Under Your data: Stats, Permissions, Data should be present; Export should not be under Your data
      expect(find.text('YOUR DATA'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('Permissions'), findsOneWidget);
      expect(find.text('Data'), findsOneWidget);
      expect(find.text('Export'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(Duration.zero);
      await tester.pump();
    });
  });

  testWidgets('DataScreen shows Export section with Export notes and shelves', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          userDatabaseProvider.overrideWithValue(userDb),
        ],
        child: MaterialApp(
          theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
          home: const DataScreen(),
        ),
      ),
    );

    expect(find.text('EXPORT'), findsOneWidget);
    expect(find.text('Export notes and shelves'), findsOneWidget);
    expect(find.text('Markdown · CSV'), findsOneWidget);
    expect(find.text('DATA MANAGEMENT'), findsOneWidget);
    expect(find.text('Clear notes'), findsOneWidget);
  });

  testWidgets('TopicCard formats metrics as "187 · 3 seen" with accent color', (
    WidgetTester tester,
  ) async {
    const Collection topic = Collection(
      id: 1,
      slug: 'nature',
      title: 'Nature',
      description: 'The natural world.',
      kind: 'topic',
      band: 'core',
      icon: 'leaf',
      sortOrder: 1,
      wordCount: 187,
    );
    final MullColors colors = ThemeFamily.byId('mull').colors(Tone.light);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
        home: Scaffold(
          body: TopicCard(
            collection: topic,
            progress: const Progress(3, 187),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byType(TopicCard), findsOneWidget);
    final RichText richText = tester.widget<RichText>(
      find.byWidgetPredicate((Widget w) => w is RichText && w.text.toPlainText().contains('187')),
    );
    expect(richText.text.toPlainText(), '187 · 3 seen');
    TextSpan? seenSpan;
    richText.text.visitChildren((InlineSpan span) {
      if (span is TextSpan && span.text == '3 seen') {
        seenSpan = span;
        return false;
      }
      return true;
    });
    expect(seenSpan, isNotNull);
    expect(seenSpan!.style?.color, colors.accent);
  });

  testWidgets('PillChip displays badge count only when selected with showCountWhenSelectedOnly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
        home: const Scaffold(
          body: Column(
            children: <Widget>[
              PillChip(
                label: 'Words',
                count: 42,
                selected: false,
                showCountWhenSelectedOnly: true,
              ),
              PillChip(
                label: 'Phrases',
                count: 15,
                selected: true,
                showCountWhenSelectedOnly: true,
              ),
            ],
          ),
        ),
      ),
    );

    // Unselected 'Words' has count 42 but badge should not be shown
    expect(find.text('Words'), findsOneWidget);
    expect(find.text('42'), findsNothing);

    // Selected 'Phrases' has count 15 and badge is shown
    expect(find.text('Phrases'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
  });

  testWidgets('CollectionsScreen shows Shelves title and Words/Phrases filters', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'onboarded': true});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            prefsProvider.overrideWithValue(prefs),
            userDatabaseProvider.overrideWithValue(userDb),
            dictProvider.overrideWithValue(dict),
          ],
          child: MaterialApp(
            theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
            home: const CollectionsScreen(),
          ),
        ),
      );

      expect(find.text('Shelves'), findsOneWidget);
      expect(find.text('Search shelves'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Words'), findsOneWidget);
      expect(find.text('Phrases'), findsOneWidget);
      expect(find.text('Bands'), findsOneWidget);
      expect(find.text('Topics'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('CollectionScreen header has + button opening Add words/phrases menu', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'onboarded': true});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final UserRepository userRepo = UserRepository(userDb);
    await userRepo.ensureSystemCollections();

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            prefsProvider.overrideWithValue(prefs),
            userDatabaseProvider.overrideWithValue(userDb),
            dictProvider.overrideWithValue(dict),
          ],
          child: MaterialApp(
            theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
            home: const CollectionScreen(slug: 'from-my-reading'),
          ),
        ),
      );

      // Verify '+' button is in the header
      final Finder addBtn = find.bySemanticsLabel('Add');
      expect(addBtn, findsOneWidget);

      // Tap '+' button
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Dropdown menu options
      expect(find.text('Add words'), findsOneWidget);
      expect(find.text('Add phrases'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('CollectionScreen shows floating Mull button and 6-segment overflow menu', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'onboarded': true});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final UserRepository userRepo = UserRepository(userDb);
    await userRepo.ensureSystemCollections();
    await userRepo.addToCollection('from-my-reading', ephemera.key);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            prefsProvider.overrideWithValue(prefs),
            userDatabaseProvider.overrideWithValue(userDb),
            dictProvider.overrideWithValue(dict),
          ],
          child: MaterialApp(
            theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
            home: const CollectionScreen(slug: 'from-my-reading'),
          ),
        ),
      );

      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Verify floating primary Mull button is present and normal width
      final Finder mullButton = find.widgetWithText(AppButton, 'Mull');
      expect(mullButton, findsOneWidget);
      final AppButton btnWidget = tester.widget<AppButton>(mullButton);
      expect(btnWidget.type, AppButtonType.primary);
      expect(btnWidget.fullWidth, false);

      // Verify top search bar is present without AZ sort button
      expect(find.text('Search shelf'), findsOneWidget);
      expect(find.text('AZ'), findsNothing);

      // Open overflow menu
      final Finder moreBtn = find.bySemanticsLabel('More');
      expect(moreBtn, findsOneWidget);
      await tester.tap(moreBtn);
      await tester.pumpAndSettle();

      // Verify segments and their icons
      // Segment 1: Mull these
      expect(find.text('Mull these'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
      // Segment 2: Add words, Add phrases
      expect(find.text('Add words'), findsOneWidget);
      expect(find.text('Add phrases'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsWidgets);
      // Segment 3: Sorts
      expect(find.text('Sort: Name'), findsOneWidget);
      expect(find.byIcon(Icons.sort_by_alpha_rounded), findsOneWidget);
      expect(find.text('Sort: Frequency'), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
      expect(find.text('Sort: Bookmark first'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      // Segment 4: Orders
      expect(find.text('Order: ASCENDING'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.text('Order: DESCENDING'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
      // Segment 5: View modes
      expect(find.text('View mode: Cards'), findsOneWidget);
      expect(find.byIcon(Icons.view_agenda_outlined), findsOneWidget);
      expect(find.text('View mode: Table'), findsOneWidget);
      expect(find.byIcon(Icons.table_rows_outlined), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('CollectionScreen on user shelf shows Delete in red in overflow menu', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'onboarded': true});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final UserRepository userRepo = UserRepository(userDb);
    final String userSlug = await userRepo.createCollection('My Custom Shelf');
    await userRepo.addToCollection(userSlug, ephemera.key);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            prefsProvider.overrideWithValue(prefs),
            userDatabaseProvider.overrideWithValue(userDb),
            dictProvider.overrideWithValue(dict),
          ],
          child: MaterialApp(
            theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
            home: CollectionScreen(slug: userSlug),
          ),
        ),
      );

      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Open overflow menu
      final Finder moreBtn = find.bySemanticsLabel('More');
      expect(moreBtn, findsOneWidget);
      await tester.tap(moreBtn);
      await tester.pumpAndSettle();

      // Segment 6: Rename and Delete should appear for user-created shelf
      expect(find.text('Rename'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('MoreScreen General section order is Shelves, Mixes, Settings', (
    WidgetTester tester,
  ) async {
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

      // Check General section rows
      expect(find.text('GENERAL'), findsOneWidget);
      final List<SettingsRow> rows = tester
          .widgetList<SettingsRow>(find.byType(SettingsRow))
          .take(3)
          .toList();
      expect(rows.length, 3);
      expect(rows[0].label, 'Shelves');
      expect(rows[1].label, 'Mixes');
      expect(rows[2].label, 'Settings');

      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(Duration.zero);
      await tester.pump();
    });
  });

  testWidgets('CollectionsScreen overflow menu has How to use and opens sheet', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'onboarded': true});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            prefsProvider.overrideWithValue(prefs),
            userDatabaseProvider.overrideWithValue(userDb),
            dictProvider.overrideWithValue(dict),
          ],
          child: MaterialApp(
            theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
            home: const CollectionsScreen(),
          ),
        ),
      );

      // Open overflow menu
      final Finder moreBtn = find.bySemanticsLabel('More');
      expect(moreBtn, findsOneWidget);
      await tester.tap(moreBtn);
      await tester.pumpAndSettle();

      // Verify 'How to use' option exists
      final Finder howToUseFinder = find.text('How to use');
      expect(howToUseFinder, findsOneWidget);
      await tester.tap(howToUseFinder);
      await tester.pumpAndSettle();

      // Verify bottom sheet opened
      expect(find.text('How to use shelves'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('SavedMixesScreen overflow menu has How to use and opens sheet', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'onboarded': true});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            prefsProvider.overrideWithValue(prefs),
            userDatabaseProvider.overrideWithValue(userDb),
            dictProvider.overrideWithValue(dict),
          ],
          child: MaterialApp(
            theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
            home: const SavedMixesScreen(),
          ),
        ),
      );

      // Open overflow menu
      final Finder moreBtn = find.bySemanticsLabel('More');
      expect(moreBtn, findsOneWidget);
      await tester.tap(moreBtn);
      await tester.pumpAndSettle();

      // Verify 'How to use' option exists
      final Finder howToUseFinder = find.text('How to use');
      expect(howToUseFinder, findsOneWidget);
      await tester.tap(howToUseFinder);
      await tester.pumpAndSettle();

      // Verify bottom sheet opened
      expect(find.text('How to use mixes'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
    });
  });
}
