// Perf harness, pass 2. Rerun recipe: specs/app-polish-2/performance.md.
//
// Frame numbers come from the engine's FrameTiming (build and raster per
// frame), windowed by Timeline.now (both are CLOCK_MONOTONIC on Android).
// Rebuild counts come from timeline build events with
// debugProfileBuildsEnabled on, counted by the driver.
//
// Finders depend only on: MullApp, MullNavPill + kDestinations labels,
// HomeScreen, CollectionsScreen, CollectionScreen, SearchScreen, MoreScreen,
// SearchResultCard, AppBottomSheet, AppIconButton, SelectableText.
import 'dart:async';
import 'dart:developer' show Timeline;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mull/app.dart';
import 'package:mull/app/nav_bar.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/dictionary_installer.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/database/user_repository.dart';
import 'package:mull/core/providers.dart';
import 'package:mull/core/router/router.dart';
import 'package:mull/features/collections/collection_screen.dart';
import 'package:mull/features/collections/collections_screen.dart';
import 'package:mull/features/dictionary/search_screen.dart';
import 'package:mull/features/home/home_screen.dart';
import 'package:mull/features/linger/word_card.dart';
import 'package:mull/features/settings/more_screen.dart';
import 'package:mull/features/settings/settings_controller.dart' show prefsProvider;
import 'package:mull/shared/widgets/app_bottom_sheet.dart';
import 'package:mull/shared/widgets/app_icon_button.dart';
import 'package:mull/shared/widgets/fields.dart' show SearchField;
import 'package:shared_preferences/shared_preferences.dart';

final Map<String, dynamic> results = <String, dynamic>{};

const String kSeedVersion = 'perf-seed-v2';
const int kShelfWords = 1500;

double pct(List<num> v, double p) {
  if (v.isEmpty) return double.nan;
  final List<num> s = List<num>.of(v)..sort();
  return s[((s.length - 1) * p).round()].toDouble();
}

double r1(double v) => (v * 10).roundToDouble() / 10;

/// Collects every FrameTiming the engine reports.
class Frames {
  final List<FrameTiming> all = <FrameTiming>[];
  void start() => SchedulerBinding.instance.addTimingsCallback(all.addAll);

  /// Frame stats for frames whose build started in [t0, t1] (Timeline.now µs).
  Map<String, dynamic> stats(int t0, int t1) {
    final List<FrameTiming> f = all.where((FrameTiming t) {
      final int b = t.timestampInMicroseconds(FramePhase.buildStart);
      return b >= t0 && b <= t1;
    }).toList();
    final List<double> build = f.map((FrameTiming t) => t.buildDuration.inMicroseconds / 1000).toList();
    final List<double> raster = f.map((FrameTiming t) => t.rasterDuration.inMicroseconds / 1000).toList();
    return <String, dynamic>{
      'frames': f.length,
      'build_p50': r1(pct(build, .5)),
      'build_p90': r1(pct(build, .9)),
      'build_worst': r1(pct(build, 1)),
      'raster_p50': r1(pct(raster, .5)),
      'raster_p90': r1(pct(raster, .9)),
      'raster_worst': r1(pct(raster, 1)),
      'over16': f.where((FrameTiming t) => t.buildDuration.inMicroseconds > 16000 || t.rasterDuration.inMicroseconds > 16000).length,
      'build_over16': build.where((double b) => b > 16).length,
    };
  }
}

/// Pumps 1 ms at a time until [f] matches; returns wall ms, or -1 on timeout.
Future<int> pumpUntil(WidgetTester t, Finder f, {int timeoutMs = 20000}) async {
  final Stopwatch sw = Stopwatch()..start();
  while (f.evaluate().isEmpty) {
    if (sw.elapsedMilliseconds > timeoutMs) return -1;
    await t.pump(const Duration(milliseconds: 1));
  }
  return sw.elapsedMilliseconds;
}

Future<void> settle(WidgetTester t, {int ms = 1500}) async {
  final Stopwatch sw = Stopwatch()..start();
  while (sw.elapsedMilliseconds < ms) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

Finder navItem(int i) => find.descendant(
  of: find.byType(MullNavPill),
  matching: find.byWidgetPredicate(
    (Widget w) => w is Semantics && w.properties.label == kDestinations[i].label,
  ),
);

const List<Type> kTabScreens = <Type>[HomeScreen, Object, CollectionsScreen, SearchScreen, MoreScreen];
const List<String> kTabNames = <String>['home', 'mull', 'shelves', 'search', 'more'];

Future<void> seed(UserDatabase db, UserRepository repo, DictionaryDb dict) async {
  if (await repo.appState('perf.seed') == kSeedVersion) return;
  await repo.resetAll();
  final List<DictionaryWord> pool = dict.quizCandidates().toList()
    ..sort((DictionaryWord a, DictionaryWord b) => a.wordKey.compareTo(b.wordKey));
  final List<String> keys = pool.map((DictionaryWord w) => w.wordKey).toList();
  // Shelves: one of 1,500, four smaller ones.
  final String big = await repo.createCollection('Perf shelf', color: 2);
  await repo.addAllToCollection(big, keys.take(kShelfWords));
  const List<(String, int)> small = <(String, int)>[('Reading list', 60), ('Exam words', 180), ('Work', 40), ('Favourites', 120)];
  for (int s = 0; s < small.length; s++) {
    final String slug = await repo.createCollection(small[s].$1, color: s);
    await repo.addAllToCollection(slug, keys.skip(2000 + s * 300).take(small[s].$2));
  }
  // 300 bookmarks, 300 notes.
  await repo.addAllToCollection(UserRepository.bookmarksSlug, keys.skip(100).where((_) => true).take(300));
  final DateTime now = DateTime.now();
  await db.batch((b) {
    b.insertAll(
      db.notes,
      <NotesCompanion>[
        for (int i = 0; i < 300; i++)
          NotesCompanion.insert(
            wordKey: keys[(i * 7) % keys.length],
            body: 'Note $i: met this in a book, means roughly what the card says.',
            updatedAt: now.subtract(Duration(hours: i)),
          ),
      ],
      mode: InsertMode.insertOrReplace,
    );
    // Seen: 3,000 words, about 9,000 events over 180 days.
    final List<SeenCompanion> seen = <SeenCompanion>[];
    final List<SeenEventsCompanion> events = <SeenEventsCompanion>[];
    for (int i = 0; i < 3000; i++) {
      final String k = keys[(i * 3 + 1) % keys.length];
      final int count = 1 + i % 5;
      final DateTime first = now.subtract(Duration(days: 180 - (i % 170), minutes: i));
      DateTime last = first;
      for (int e = 0; e < count; e++) {
        last = first.add(Duration(days: e * (1 + i % 9), minutes: e * 17));
        if (last.isAfter(now)) last = now.subtract(Duration(minutes: i + e));
        events.add(SeenEventsCompanion.insert(wordKey: k, at: last));
      }
      seen.add(SeenCompanion.insert(wordKey: k, seenCount: Value<int>(count), firstSeenAt: first, lastSeenAt: last));
    }
    b.insertAll(db.seen, seen, mode: InsertMode.insertOrReplace);
    b.insertAll(db.seenEvents, events);
  });
  final List<String> heads = pool.map((DictionaryWord w) => w.headword).toSet().toList()..sort();
  for (int i = 0; i < 200; i++) {
    await repo.recordSearch(heads[(i * 13) % heads.length], now: now.subtract(Duration(minutes: 400 - i)));
  }
  for (int i = 0; i < 60; i++) {
    await repo.recordLookup(keys[(i * 11) % keys.length], now: now.subtract(Duration(minutes: 200 - i)));
  }
  await repo.setAppState('perf.seed', kSeedVersion);
}

void main() {
  final IntegrationTestWidgetsFlutterBinding binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.reportData = <String, dynamic>{'results': results};

  testWidgets('perf', (WidgetTester tester) async {
    final Frames frames = Frames()..start();
    Future<Map<String, dynamic>> window(Future<void> Function() body) async {
      final int t0 = Timeline.now;
      await body();
      final int t1 = Timeline.now;
      await settle(tester, ms: 1200); // let the timing batch arrive
      return frames.stats(t0, t1);
    }

    // ---- boot like lib/main.dart, seed before the UI exists
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app.onboarded', true);
    final DictionaryInstaller installer = await DictionaryInstaller.forApp();
    final UserDatabase userDb = UserDatabase();
    final String dbPath = await installer.ensureInstalled();
    final DictionaryDb seedDict = DictionaryDb.open(dbPath);
    final UserRepository repo = UserRepository(userDb);
    final Stopwatch seedSw = Stopwatch()..start();
    await seed(userDb, repo, seedDict);
    results['seed_ms'] = seedSw.elapsedMilliseconds;
    final List<String> heads = seedDict.quizCandidates().map((DictionaryWord w) => w.headword).toSet().toList()..sort();
    seedDict.close();
    final String bigSlug = (await repo.collections()).firstWhere((UserCollection c) => c.name == 'Perf shelf').slug;
    results['seed'] = <String, dynamic>{
      'shelf_words': kShelfWords,
      'user_shelves': 5,
      'bookmarks': 300,
      'notes': await repo.noteCount(),
      'seen_words': (await repo.allSeen()).length,
      'seen_events': (await repo.allSeenEvents()).length,
      'recent_searches': 200,
    };

    // ---- first frame of Home: boot to nav shell
    final Map<String, dynamic> first = <String, dynamic>{};
    int bootMs = -1;
    first['home'] = await window(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            prefsProvider.overrideWithValue(prefs),
            installerProvider.overrideWithValue(installer),
            userDatabaseProvider.overrideWithValue(userDb),
          ],
          child: const MullApp(),
        ),
      );
      bootMs = await pumpUntil(tester, find.byType(HomeScreen), timeoutMs: 90000);
      await settle(tester, ms: 1500);
    });
    expect(bootMs, greaterThanOrEqualTo(0), reason: 'app never reached Home');
    (first['home'] as Map<String, dynamic>)['ms_to_screen'] = bootMs;
    await settle(tester, ms: 1500);

    // ---- first open of Shelves, Search, More (cold in this session)
    for (final int i in <int>[2, 3, 4]) {
      int ms = -1;
      final Map<String, dynamic> s = await window(() async {
        await tester.tap(navItem(i));
        ms = await pumpUntil(tester, find.byType(kTabScreens[i]).hitTestable());
        await settle(tester, ms: 600);
      });
      s['ms_to_screen'] = ms;
      first[kTabNames[i]] = s;
      await tester.tap(navItem(0));
      await settle(tester, ms: 800);
    }
    results['first_open'] = first;

    // ---- every ordered pair of tabs, warm
    final Map<String, dynamic> pairs = <String, dynamic>{};
    final List<int> allFrom = <int>[];
    final int tAll0 = Timeline.now;
    for (int a = 0; a < 5; a++) {
      for (int b = 0; b < 5; b++) {
        if (a == b) continue;
        await tester.tap(navItem(a));
        await settle(tester, ms: 700);
        pairs['${kTabNames[a]}>${kTabNames[b]}'] = await window(() async {
          await tester.tap(navItem(b));
          await settle(tester, ms: 500);
        });
        allFrom.add(a);
      }
    }
    final int tAll1 = Timeline.now;
    final Map<String, dynamic> pairFrames = frames.stats(tAll0, tAll1);
    results['tab_switch_pairs'] = pairs;
    results['tab_switch_all'] = pairFrames;

    // ---- scroll Home, Shelves
    Future<Map<String, dynamic>> flingAll(Finder f, {int n = 6, double d = 600}) => window(() async {
      for (int i = 0; i < n; i++) {
        await tester.fling(f, Offset(0, -d), 3000);
        await settle(tester, ms: 700);
      }
      for (int i = 0; i < n; i++) {
        await tester.fling(f, Offset(0, d), 3000);
        await settle(tester, ms: 700);
      }
    });
    Finder scrollIn(Type screen) => find
        .descendant(of: find.byType(screen), matching: find.byWidgetPredicate((Widget w) => w is Scrollable && w.axisDirection == AxisDirection.down))
        .first;

    await tester.tap(navItem(0));
    await settle(tester, ms: 800);
    final Map<String, dynamic> scroll = <String, dynamic>{};
    scroll['home'] = await flingAll(scrollIn(HomeScreen));
    await tester.tap(navItem(2));
    await settle(tester, ms: 800);
    scroll['shelves'] = await flingAll(scrollIn(CollectionsScreen));

    // ---- Shelves overflow menu: open and close x5
    final Map<String, dynamic> menus = <String, dynamic>{};
    final Finder shelvesAction = find.descendant(of: find.byType(CollectionsScreen), matching: find.byType(AppIconButton)).hitTestable().last;
    menus['shelves_overflow_5x'] = await window(() async {
      for (int i = 0; i < 5; i++) {
        await tester.tap(shelvesAction);
        await settle(tester, ms: 600);
        await tester.tapAt(const Offset(8, 300));
        await settle(tester, ms: 500);
      }
    });

    // ---- the 1,500-word shelf: open, scroll
    unawaited(GoRouter.of(tester.element(find.byType(MullNavPill))).push(Routes.collection(bigSlug)));
    final int shelfMs = await pumpUntil(tester, find.byType(SearchResultCard), timeoutMs: 30000);
    results['big_shelf_open_to_first_card_ms'] = shelfMs;
    await settle(tester, ms: 1000);
    scroll['shelf_1500'] = await flingAll(scrollIn(CollectionScreen), d: 800);
    for (int i = 0; i < 4; i++) {
      await tester.fling(scrollIn(CollectionScreen), const Offset(0, 1500), 6000);
      await settle(tester, ms: 600);
    }

    // ---- word sheet open and close x5, then the long-press menu x3
    menus['word_sheet_5x'] = await window(() async {
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byType(SearchResultCard).hitTestable().first);
        await pumpUntil(tester, find.byType(AppBottomSheet));
        await settle(tester, ms: 700);
        rootNavigatorKey.currentState!.pop();
        await settle(tester, ms: 600);
      }
    });
    await tester.tap(find.byType(SearchResultCard).hitTestable().first);
    await pumpUntil(tester, find.byType(AppBottomSheet));
    await settle(tester, ms: 800);
    final Finder defText = find.descendant(of: find.byType(AppBottomSheet), matching: find.byType(SelectableText)).hitTestable().first;
    bool menuShown = false;
    menus['long_press_3x'] = await window(() async {
      for (int i = 0; i < 3; i++) {
        await tester.longPressAt(tester.getTopLeft(defText) + const Offset(24, 10));
        await settle(tester, ms: 700);
        menuShown = menuShown || find.text('Copy').evaluate().isNotEmpty;
        // A tap on the text clears the selection and closes the menu.
        await tester.tapAt(tester.getTopLeft(defText) + const Offset(4, 4));
        await settle(tester, ms: 500);
      }
    });
    menus['long_press_menu_shown'] = menuShown;
    while (find.byType(AppBottomSheet).evaluate().isNotEmpty) {
      rootNavigatorKey.currentState!.pop();
      await settle(tester, ms: 600);
    }
    rootNavigatorKey.currentState!.pop(); // the shelf
    await settle(tester, ms: 800);

    // ---- Search: type, scroll results
    await tester.tap(navItem(3));
    await settle(tester, ms: 800);
    await tester.enterText(find.descendant(of: find.byType(SearchField), matching: find.byType(TextField)), 'pro');
    await settle(tester, ms: 1500);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, ms: 600);
    scroll['search_results'] = await flingAll(scrollIn(SearchScreen), n: 4);
    results['scroll'] = scroll;
    results['menus'] = menus;

    // ---- rebuild counts (timeline build events, counted by the driver)
    await tester.tap(navItem(0));
    await settle(tester, ms: 800);
    widgets.debugProfileBuildsEnabled = true;
    await binding.traceAction(() async {
      for (final int i in <int>[2, 3, 4, 1, 0]) {
        await tester.tap(navItem(i));
        await settle(tester, ms: 600);
      }
    }, reportKey: 'rebuilds_tab_switch');
    await binding.traceAction(() async {
      for (int i = 0; i < 3; i++) {
        await tester.fling(scrollIn(HomeScreen), const Offset(0, -600), 3000);
        await settle(tester, ms: 600);
      }
      for (int i = 0; i < 3; i++) {
        await tester.fling(scrollIn(HomeScreen), const Offset(0, 600), 3000);
        await settle(tester, ms: 600);
      }
    }, reportKey: 'rebuilds_home_scroll');
    // Swipes on the Mull tab write seen (after the 1.2 s dwell) while Home
    // and Shelves sit offstage: count what rebuilds there.
    await tester.tap(navItem(1));
    await settle(tester, ms: 1500);
    await binding.traceAction(() async {
      for (int i = 0; i < 4; i++) {
        await tester.fling(find.byType(WordCard).hitTestable().first, const Offset(0, -500), 2500);
        await settle(tester, ms: 1700);
      }
    }, reportKey: 'rebuilds_mull_swipes');
    widgets.debugProfileBuildsEnabled = false;
    await tester.tap(navItem(0));
    await settle(tester, ms: 800);

    // ---- search latency through DictionaryDb.searchAll (as pass 1)
    final ProviderContainer container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    final DictionaryDb dict = container.read(dictionaryProvider).requireValue;
    final List<double> lat = <double>[];
    for (int i = 0; i < 120; i++) {
      final String h = heads[(i * 37 + 5) % heads.length].toLowerCase();
      final String q = h.length < 3 ? h : h.substring(0, 1 + i % h.length.clamp(1, 6));
      final Stopwatch s = Stopwatch()..start();
      await dict.searchAll(q);
      lat.add(s.elapsedMicroseconds / 1000);
    }
    results['search_ms'] = <String, dynamic>{'n': lat.length, 'p50': r1(pct(lat, .5)), 'p95': r1(pct(lat, .95)), 'max': r1(pct(lat, 1))};
    results['done_at'] = DateTime.now().toIso8601String();
    await settle(tester, ms: 6000);
  });
}
