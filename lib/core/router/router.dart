import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/nav_shell.dart';
import '../../app/transitions.dart';
import '../../features/collections/collection_screen.dart';
import '../../features/collections/collections_screen.dart';
import '../../features/dictionary/search_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/linger/linger_screen.dart';
import '../../features/linger/saved_mixes_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../features/settings/data_screen.dart';
import '../../features/settings/debug_screen.dart';
import '../../features/settings/dictionary_info_screen.dart';
import '../../features/settings/export_screen.dart';
import '../../features/settings/more_screen.dart';
import '../../features/settings/permissions_screen.dart';
import '../../features/settings/privacy_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/theme_screen.dart';
import '../../features/settings/welcome_screen.dart';
import '../../features/stats/stats_screen.dart';

/// HANDOFF section 4, the navigation map.
abstract final class Routes {
  static const String welcome = '/welcome';
  static const String home = '/home';
  static const String mull = '/mull';
  static const String search = '/search';
  static const String more = '/more';

  static const String collections = '/collections';
  static const String mixes = '/mixes';
  static const String stats = '/more/stats';
  static const String settings = '/more/settings';
  static const String theme = '/more/settings/theme';
  static const String data = '/more/data';
  static const String dictionary = '/more/dictionary';
  static const String about = '/more/about';
  static const String privacy = '/more/privacy';
  static const String export = '/more/export';
  static const String permissions = '/more/permissions';
  static const String debug = '/debug';

  /// A dictionary slug or one of the user's (`bookmarks`, `reading`, `u{n}`).
  static String collection(String slug) => '/collection/$slug';

  /// Scoped play: the Mull tab plays one collection, mix untouched.
  static String scoped(String slug) => '$mull?scope=$slug';

  /// Add words/phrases to collection via search screen.
  static String searchAdd(String slug, {String? segment}) =>
      segment != null ? '/search/add/$slug?segment=$segment' : '/search/add/$slug';

  /// Play a saved mix from the saved mixes page.
  static String playMix(int id) => '$mull?mix=$id';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter({required bool onboarded}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: onboarded ? Routes.home : Routes.welcome,
    routes: <RouteBase>[
      GoRoute(
        path: Routes.welcome,
        builder: (BuildContext c, GoRouterState s) => const WelcomeScreen(),
      ),
      GoRoute(
        path: Routes.debug,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            mullPage<void>(state: s, child: const DebugScreen()),
      ),
      // Pages sit above the shell with their own back, as in Perch.
      GoRoute(
        path: '/collection/:slug',
        pageBuilder: (BuildContext c, GoRouterState s) => mullPage<void>(
          state: s,
          child: CollectionScreen(slug: s.pathParameters['slug']!),
        ),
      ),
      GoRoute(
        path: Routes.mixes,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            mullPage<void>(state: s, child: const SavedMixesScreen()),
      ),
      GoRoute(
        path: Routes.stats,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            mullPage<void>(state: s, child: const StatsScreen()),
      ),
      GoRoute(
        path: Routes.settings,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            mullPage<void>(state: s, child: const SettingsScreen()),
      ),
      GoRoute(
        path: Routes.theme,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            mullPage<void>(state: s, child: const ThemeScreen()),
      ),
      GoRoute(
        path: Routes.dictionary,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            mullPage<void>(state: s, child: const DictionaryInfoScreen()),
      ),
      GoRoute(
        path: Routes.about,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            mullPage<void>(state: s, child: const AboutScreen()),
      ),
      GoRoute(
        path: Routes.privacy,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            mullPage<void>(state: s, child: const PrivacyScreen()),
      ),
      GoRoute(
        path: Routes.data,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            mullPage<void>(state: s, child: const DataScreen()),
      ),
      GoRoute(
        path: Routes.export,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            mullPage<void>(state: s, child: const ExportScreen()),
      ),
      GoRoute(
        path: Routes.permissions,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            mullPage<void>(state: s, child: const PermissionsScreen()),
      ),
      GoRoute(
        path: '/search/add/:slug',
        pageBuilder: (BuildContext c, GoRouterState s) {
          final String slug = s.pathParameters['slug']!;
          final String? seg = s.uri.queryParameters['segment'];
          final SearchSegment initialSegment =
              seg == 'phrases' ? SearchSegment.idioms : SearchSegment.words;
          return mullPage<void>(
            state: s,
            child: SearchScreen(
              addToCollectionSlug: slug,
              initialSegment: initialSegment,
            ),
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state, StatefulNavigationShell shell) {
          return NavShell(
            index: shell.currentIndex,
            tabCount: shell.route.branches.length,
            onSelect: (int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
            child: shell,
          );
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.home,
                builder: (BuildContext c, GoRouterState s) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.mull,
                builder: (BuildContext c, GoRouterState s) => LingerScreen(
                  scope: s.uri.queryParameters['scope'],
                  mixId: int.tryParse(s.uri.queryParameters['mix'] ?? ''),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.collections,
                builder: (BuildContext c, GoRouterState s) => const CollectionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.search,
                builder: (BuildContext c, GoRouterState s) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.more,
                builder: (BuildContext c, GoRouterState s) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
