// Perf harness. Run (see README in perf_baseline.md):
//   flutter drive --profile --target-platform android-arm64 \
//     --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart -d <id>
// Depends only on: MullApp, providers, repositories, nav pill, WordCard,
// SearchResultCard, AppBottomSheet, AppHeader.debugBuildCount.
import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:mull/features/collections/collection_cards.dart';
import 'package:mull/features/collections/collection_screen.dart';
import 'package:mull/features/collections/collections_screen.dart';
import 'package:mull/features/dictionary/search_screen.dart';
import 'package:mull/features/home/home_screen.dart';
import 'package:mull/features/linger/word_card.dart';
import 'package:mull/features/settings/settings_controller.dart' show prefsProvider;
import 'package:mull/shared/widgets/app_bottom_sheet.dart';
import 'package:mull/shared/widgets/app_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Map<String, dynamic> results = <String, dynamic>{};

double median(List<num> v) {
  final List<num> s = List<num>.of(v)..sort();
  if (s.isEmpty) return double.nan;
  final int m = s.length ~/ 2;
  return s.length.isOdd ? s[m].toDouble() : (s[m - 1] + s[m]) / 2;
}

double pct(List<num> v, double p) {
  final List<num> s = List<num>.of(v)..sort();
  return s[((s.length - 1) * p).round()].toDouble();
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

Finder navItem(int i) =>
    find.descendant(of: find.byType(MullNavPill), matching: find.byType(InkWell)).at(i);

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.reportData = <String, dynamic>{'results': results};

  testWidgets('perf baseline', (WidgetTester tester) async {
    // ---- boot like lib/main.dart, seed before the UI exists
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app.onboarded', true);
    final DictionaryInstaller installer = await DictionaryInstaller.forApp();
    final UserDatabase userDb = UserDatabase();

    final Stopwatch inst = Stopwatch()..start();
    final String dbPath = await installer.ensureInstalled();
    results['dictionary_ensure_installed_ms'] = inst.elapsedMilliseconds;

    final DictionaryDb seedDict = DictionaryDb.open(dbPath);
    final List<String> keys = (seedDict.quizCandidates().map((DictionaryWord w) => w.wordKey).toList()..sort())
        .take(2000)
        .toList();
    final List<String> headwords = seedDict
        .quizCandidates()
        .map((DictionaryWord w) => w.headword)
        .toSet()
        .toList()
      ..sort();
    seedDict.close();
    expect(keys.length, 2000);

    final UserRepository repo = UserRepository(userDb);
    for (final UserCollection c in await repo.collections()) {
      if (c.name == 'Perf shelf') await repo.deleteCollection(c.slug);
    }
    final String slug = await repo.createCollection('Perf shelf');
    await repo.addAllToCollection(slug, keys);
    final DateTime base = DateTime.now().subtract(const Duration(days: 1));
    for (int i = 0; i < 200; i++) {
      await repo.recordSearch(headwords[(i * 13) % headwords.length], now: base.add(Duration(seconds: i)));
    }
    results['seed'] = <String, dynamic>{'shelf_slug': slug, 'shelf_words': keys.length, 'recent_searches': 200};

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
    final int homeMs = await pumpUntil(tester, find.byType(MullNavPill), timeoutMs: 90000);
    expect(homeMs, greaterThanOrEqualTo(0), reason: 'app never reached the nav shell');
    results['boot_to_nav_shell_ms'] = homeMs;
    await settle(tester, ms: 2000);

    // ---- 6: Home trace (already shown; trace a settle plus return to Home later)
    // ---- a: Mull tab first card x3
    final List<int> mullMs = <int>[];
    for (int i = 0; i < 3; i++) {
      await binding.traceAction(() async {
        await tester.tap(navItem(1));
        final int ms = await pumpUntil(tester, find.byType(WordCard));
        mullMs.add(ms);
        await settle(tester, ms: 800);
      }, reportKey: 'mull_open_${i + 1}');
      await tester.tap(navItem(0));
      await settle(tester, ms: 800);
    }
    results['mull_first_card_ms'] = <String, dynamic>{'runs': mullMs, 'median': median(mullMs)};

    // ---- b: Shelves first open x3
    final List<int> shelvesMs = <int>[];
    for (int i = 0; i < 3; i++) {
      await binding.traceAction(() async {
        await tester.tap(navItem(2));
        final int ms = await pumpUntil(
          tester,
          find.descendant(
            of: find.byType(CollectionsScreen),
            matching: find.byWidgetPredicate((Widget w) => w is TopicCard || w is BandRow),
          ),
        );
        shelvesMs.add(ms);
        await settle(tester, ms: 800);
      }, reportKey: 'shelves_open_${i + 1}');
      await tester.tap(navItem(0));
      await settle(tester, ms: 800);
    }
    results['shelves_first_card_ms'] = <String, dynamic>{'runs': shelvesMs, 'median': median(shelvesMs)};

    // ---- 6: Home, Search, More worst frames
    await tester.tap(navItem(1));
    await settle(tester, ms: 800);
    await binding.traceAction(() async {
      await tester.tap(navItem(0));
      await settle(tester, ms: 1200);
    }, reportKey: 'home_open');
    await binding.traceAction(() async {
      await tester.tap(navItem(3));
      await settle(tester, ms: 1200);
    }, reportKey: 'search_open');
    await binding.traceAction(() async {
      await tester.tap(navItem(4));
      await settle(tester, ms: 1200);
    }, reportKey: 'more_open');
    await tester.tap(navItem(0));
    await settle(tester, ms: 800);

    // ---- f (Home half): header builds while flinging Home
    final Finder homeList = find.descendant(of: find.byType(HomeScreen), matching: find.byType(ListView));
    AppHeader.debugBuildCount = 0;
    for (int i = 0; i < 6; i++) {
      await tester.fling(homeList.first, const Offset(0, -500), 2500);
      await settle(tester, ms: 700);
    }
    for (int i = 0; i < 6; i++) {
      await tester.fling(homeList.first, const Offset(0, 500), 2500);
      await settle(tester, ms: 700);
    }
    results['header_builds_home_12_flings'] = AppHeader.debugBuildCount;

    // ---- c: scroll the Perf shelf
    unawaited(GoRouter.of(tester.element(find.byType(MullNavPill))).push(Routes.collection(slug)));
    final int shelfMs = await pumpUntil(tester, find.byType(SearchResultCard), timeoutMs: 30000);
    results['perf_shelf_open_to_first_card_ms'] = shelfMs;
    expect(shelfMs, greaterThanOrEqualTo(0));
    await settle(tester, ms: 1000);
    final Finder shelfScroll =
        find.descendant(of: find.byType(CollectionScreen), matching: find.byType(CustomScrollView)).first;
    AppHeader.debugBuildCount = 0;
    await binding.traceAction(() async {
      for (int i = 0; i < 6; i++) {
        await tester.fling(shelfScroll, const Offset(0, -700), 3000);
        await settle(tester, ms: 900);
      }
      for (int i = 0; i < 6; i++) {
        await tester.fling(shelfScroll, const Offset(0, 700), 3000);
        await settle(tester, ms: 900);
      }
    }, reportKey: 'shelf_scroll');
    results['header_builds_shelf_12_flings'] = AppHeader.debugBuildCount;

    // ---- d: open and close the word sheet 5 times (from the top of the shelf)
    for (int i = 0; i < 4; i++) {
      await tester.fling(shelfScroll, const Offset(0, 1500), 6000);
      await settle(tester, ms: 800);
    }
    await binding.traceAction(() async {
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byType(SearchResultCard).hitTestable().first);
        await pumpUntil(tester, find.byType(AppBottomSheet));
        await settle(tester, ms: 700);
        rootNavigatorKey.currentState!.pop();
        await settle(tester, ms: 600);
      }
    }, reportKey: 'word_sheet_5x');

    // ---- e: search latency through DictionaryDb.searchAll
    final ProviderContainer container = ProviderScope.containerOf(tester.element(find.byType(CollectionScreen).first));
    final DictionaryDb dict = container.read(dictionaryProvider).requireValue;
    final Stopwatch w = Stopwatch()..start();
    await dict.searchAll('pro');
    results['search_first_query_ms'] = w.elapsedMicroseconds / 1000;
    final List<String> queries = <String>[];
    for (int i = 0; queries.length < 200; i++) {
      final String h = headwords[(i * 37 + 5) % headwords.length].toLowerCase();
      if (h.length < 4) continue;
      final int kind = queries.length % 4;
      queries.add(switch (kind) {
        0 => h.substring(0, 1 + (queries.length ~/ 4) % 6 > h.length ? h.length : 1 + (queries.length ~/ 4) % 6),
        1 => h.substring(0, h.length < 3 ? h.length : 3),
        2 => h,
        _ => '${h.substring(0, 1)}${h.substring(2, 3)}${h.substring(1, 2)}${h.substring(3)}', // typo: swap 2 letters
      });
    }
    final List<double> lat = <double>[];
    for (final String q in queries) {
      final Stopwatch s = Stopwatch()..start();
      await dict.searchAll(q);
      lat.add(s.elapsedMicroseconds / 1000);
    }
    results['search_ms'] = <String, dynamic>{
      'n': lat.length,
      'p50': pct(lat, 0.5),
      'p95': pct(lat, 0.95),
      'max': pct(lat, 1),
    };

    // ---- g: leave the app open for a host-side meminfo read
    results['done_at'] = DateTime.now().toIso8601String();
    await settle(tester, ms: 25000);
  });
}
