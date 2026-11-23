// The two paths users feel first: Shelves opened right after launch, and the
// overflow menu of a full shelf. Per-frame build and raster, vsync to raster.
import 'dart:async';
import 'dart:developer' show Timeline;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' as widgets;
import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mull/app.dart';
import 'package:mull/app/nav_bar.dart';
import 'package:mull/core/database/dictionary_installer.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/providers.dart';
import 'package:mull/core/router/router.dart';
import 'package:mull/features/collections/collection_screen.dart';
import 'package:mull/features/collections/collections_screen.dart';
import 'package:mull/features/dictionary/search_screen.dart';
import 'package:mull/features/dictionary/word_sheet.dart';
import 'package:mull/features/home/home_screen.dart';
import 'package:mull/features/settings/more_screen.dart';
import 'package:mull/features/settings/settings_controller.dart' show prefsProvider;
import 'package:mull/shared/widgets/app_icon_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Map<String, dynamic> results = <String, dynamic>{};
final List<FrameTiming> all = <FrameTiming>[];

double ms(Duration d) => (d.inMicroseconds / 100).round() / 10;

Future<void> settle(WidgetTester t, int n) async {
  final Stopwatch sw = Stopwatch()..start();
  while (sw.elapsedMilliseconds < n) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

Map<String, dynamic> stats(int t0, int t1) {
  final List<FrameTiming> f = all.where((FrameTiming t) {
    final int b = t.timestampInMicroseconds(FramePhase.buildStart);
    return b >= t0 && b <= t1;
  }).toList();
  return <String, dynamic>{
    'n': f.length,
    'build': <double>[for (final FrameTiming t in f) ms(t.buildDuration)],
    'raster': <double>[for (final FrameTiming t in f) ms(t.rasterDuration)],
    'first_frame_after_ms': f.isEmpty ? -1 : (f.first.timestampInMicroseconds(FramePhase.rasterFinish) - t0) / 1000,
  };
}

Finder navItem(int i) => find.descendant(
  of: find.byType(MullNavPill),
  matching: find.byWidgetPredicate((Widget w) => w is Semantics && w.properties.label == kDestinations[i].label),
);

void main() {
  final IntegrationTestWidgetsFlutterBinding binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  binding.reportData = <String, dynamic>{'results': results};
  testWidgets('feel', (WidgetTester tester) async {
    SchedulerBinding.instance.addTimingsCallback(all.addAll);
    Future<Map<String, dynamic>> window(int after, Future<void> Function() body) async {
      final int t0 = Timeline.now;
      await body();
      await settle(tester, after);
      final int t1 = Timeline.now;
      await settle(tester, 1200);
      return stats(t0, t1);
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app.onboarded', true);
    final DictionaryInstaller installer = await DictionaryInstaller.forApp();
    await installer.ensureInstalled();
    final UserDatabase userDb = UserDatabase();
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        prefsProvider.overrideWithValue(prefs),
        installerProvider.overrideWithValue(installer),
        userDatabaseProvider.overrideWithValue(userDb),
      ],
      child: const MullApp(),
    ));
    while (find.byType(HomeScreen).evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 4));
    }
    const int wait = int.fromEnvironment('WAIT', defaultValue: 1500);
    final int h0 = Timeline.now;
    await settle(tester, wait);
    final int h1 = Timeline.now;
    const List<Type> screens = <Type>[HomeScreen, Object, CollectionsScreen, SearchScreen, MoreScreen];
    for (final (int i, String name) in const <(int, String)>[(2, 'shelves'), (3, 'search'), (4, 'more')]) {
      results['cold_$name'] = await window(700, () async => tester.tap(navItem(i)));
      expect(find.byType(screens[i]).hitTestable(), findsOneWidget);
      await tester.tap(navItem(0));
      await settle(tester, 700);
      results['warm_$name'] = await window(700, () async => tester.tap(navItem(i)));
      await tester.tap(navItem(0));
      await settle(tester, 700);
    }
    results['idle_after_home'] = stats(h0, h1);

    // ---- the word sheet: a long entry, opened over Home
    final String long = ProviderScope.containerOf(tester.element(find.byType(HomeScreen))).read(dictProvider).senses('happy').first.wordKey;
    if (const bool.fromEnvironment('TRACE_SHEET')) {
      widgets.debugProfileBuildsEnabled = true;
      widgets.debugProfileLayoutsEnabled = true;
      await binding.traceAction(() async {
        unawaited(showWordSheet(tester.element(find.byType(HomeScreen)), wordKey: long));
        await settle(tester, 600);
      }, reportKey: 'trace_cold_shelves');
      return;
    }
    for (int i = 0; i < 4; i++) {
      results['sheet_open_$i'] = await window(800, () async {
        unawaited(showWordSheet(tester.element(find.byType(HomeScreen)), wordKey: long));
      });
      expect(find.text('happy'), findsWidgets);
      rootNavigatorKey.currentState!.pop();
      await settle(tester, 700);
    }

    for (final (String slug, String name) in const <(String, String)>[('everyday', 'everyday')]) {
      final List<String> slugs = <String>[
        for (final c in ProviderScope.containerOf(tester.element(find.byType(HomeScreen))).read(collectionsProvider)) c.slug,
      ];
      final String s = slugs.contains(slug) ? slug : slugs[1];
      results['open_shelf_$name'] = await window(900, () async {
        unawaited(GoRouter.of(tester.element(find.byType(MullNavPill))).push(Routes.collection(s)));
      });
      final Finder more = find.descendant(of: find.byType(CollectionScreen), matching: find.byType(AppIconButton)).hitTestable().last;
      if (const bool.fromEnvironment('TRACE')) {
        widgets.debugProfileBuildsEnabled = true;
        widgets.debugProfileLayoutsEnabled = true;
        await binding.traceAction(() async {
          await tester.tap(find.byWidgetPredicate((Widget w) => w is AppIconButton && w.semanticLabel == 'More').hitTestable().last);
          await settle(tester, 500);
        }, reportKey: 'trace_cold_shelves');
        return;
      }
      for (int i = 0; i < 4; i++) {
        results['menu_open_$i'] = await window(700, () async => tester.tap(find.byWidgetPredicate((Widget w) => w is AppIconButton && w.semanticLabel == 'More').hitTestable().last));
        expect(find.text('Shelf stats'), findsOneWidget);
        results['menu_close_$i'] = await window(500, () async => tester.tapAt(const Offset(8, 500)));
      }
      expect(more, findsOneWidget);
      rootNavigatorKey.currentState!.pop();
      await settle(tester, 600);
    }
    await settle(tester, 2000);
  }, semanticsEnabled: false); // as on a phone with no screen reader
}
