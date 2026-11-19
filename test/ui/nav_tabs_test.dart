import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mull/app/nav_bar.dart';
import 'package:mull/app/nav_shell.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';

/// The bottom nav: another tab switches, the active tab scrolls to the top
/// (and nothing is popped), the Mull tab does nothing.
void main() {
  late List<ScrollController> sc;
  late GoRouter router;

  Widget list(ScrollController c, String name) => Scaffold(
    body: ListView(
      controller: c,
      children: <Widget>[
        Text(name),
        for (int i = 0; i < 80; i++) SizedBox(height: 60, child: Text('$name $i')),
      ],
    ),
  );

  Future<void> pump(WidgetTester tester) async {
    sc = List<ScrollController>.generate(6, (int _) => ScrollController());
    addTearDown(() {
      for (final ScrollController c in sc) {
        c.dispose();
      }
    });
    router = GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (BuildContext context, GoRouterState state, StatefulNavigationShell shell) => NavShell(
            index: shell.currentIndex,
            tabCount: shell.route.branches.length,
            onSelect: (int i) => onTabSelected(context, shell, i, searchPath: '/search'),
            child: shell,
          ),
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/home',
                  builder: (BuildContext c, GoRouterState s) => list(sc[0], 'home'),
                  routes: <RouteBase>[
                    GoRoute(path: 'detail', builder: (BuildContext c, GoRouterState s) => list(sc[5], 'detail')),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(path: '/mull', builder: (BuildContext c, GoRouterState s) => list(sc[1], 'mull')),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(path: '/collections', builder: (BuildContext c, GoRouterState s) => list(sc[2], 'shelves')),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(path: '/search', builder: (BuildContext c, GoRouterState s) => list(sc[3], 'search')),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(path: '/more', builder: (BuildContext c, GoRouterState s) => list(sc[4], 'more')),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(RegExp('^$label')));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping the active tab scrolls its list to the top, and does nothing at the top', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester);
    sc[0].jumpTo(2000);
    await tester.pump();
    await tapTab(tester, 'Home');
    expect(sc[0].offset, 0);
    expect(find.text('home'), findsOneWidget);

    await tapTab(tester, 'Home');
    expect(sc[0].offset, 0);
    expect(tester.hasRunningAnimations, isFalse);
    h.dispose();
  });

  testWidgets('tapping another tab switches as before', (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester);
    sc[0].jumpTo(500);
    await tester.pump();
    await tapTab(tester, 'Shelves');
    expect(find.text('shelves'), findsOneWidget);
    await tapTab(tester, 'More');
    expect(find.text('more'), findsOneWidget);
    // The tab left behind keeps its place.
    expect(sc[0].offset, 500);
    h.dispose();
  });

  testWidgets('re-tapping does not pop a page pushed inside the tab', (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester);
    router.go('/home/detail');
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
    sc[5].jumpTo(1200);
    await tester.pump();
    await tapTab(tester, 'Home');
    expect(find.text('detail'), findsOneWidget, reason: 'still on the pushed page');
    expect(sc[5].offset, 0, reason: 'its list scrolled to the top');
    h.dispose();
  });

  testWidgets('the Mull tab ignores a re-tap', (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester);
    await tapTab(tester, 'Mull');
    sc[1].jumpTo(900);
    await tester.pump();
    await tapTab(tester, 'Mull');
    expect(sc[1].offset, 900);
    h.dispose();
  });

  testWidgets('Search scrolls to the top and asks for focus again', (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester);
    await tapTab(tester, 'Search');
    sc[3].jumpTo(700);
    await tester.pump();
    await tapTab(tester, 'Search');
    expect(sc[3].offset, 0);
    expect(router.routerDelegate.currentConfiguration.uri.queryParameters['focus'], isNotNull);
    h.dispose();
  });

  testWidgets('every nav item is at least a 48 x 48 touch target', (WidgetTester tester) async {
    await pump(tester);
    final Finder items = find.descendant(of: find.byType(MullNavPill), matching: find.byType(InkWell));
    expect(items, findsNWidgets(5));
    for (final Element e in items.evaluate()) {
      final Size size = tester.getSize(find.byWidget(e.widget));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });
}
