import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart' show themeFor;
import 'core/database/dictionary_db.dart';
import 'core/database/dictionary_installer.dart';
import 'core/database/user_db.dart';
import 'core/providers.dart';
import 'core/utils/platform_surfaces.dart';
import 'core/utils/wallpaper_seed.dart';
import 'features/settings/install_screen.dart';
import 'features/settings/settings_controller.dart';

/// The entrypoint `DefineActivity` runs: the word sheet over the app the text
/// was selected in, and nothing else. No router, no tabs, no widget sync.
/// The activity is translucent, so the first frame is an empty, see-through
/// scaffold and the sheet slides up over the caller.
@pragma('vm:entry-point')
Future<void> defineMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final DictionaryInstaller installer = await DictionaryInstaller.forApp();
  final UserDatabase userDb = UserDatabase();
  runApp(
    ProviderScope(
      overrides: <Override>[
        prefsProvider.overrideWithValue(prefs),
        installerProvider.overrideWithValue(installer),
        userDatabaseProvider.overrideWithValue(userDb),
      ],
      child: const DefineApp(),
    ),
  );
}

class DefineApp extends ConsumerWidget {
  const DefineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings s = ref.watch(settingsProvider);
    final AsyncValue<DictionaryDb> dict = ref.watch(dictionaryProvider);
    final Color? seed = s.dynamicColor ? ref.watch(wallpaperSeedProvider).value : null;
    return MaterialApp(
      title: 'Mull',
      debugShowCheckedModeBanner: false,
      themeMode: s.themeMode,
      theme: themeFor(s, seed, Brightness.light),
      darkTheme: themeFor(s, seed, Brightness.dark),
      color: Colors.transparent,
      navigatorObservers: <NavigatorObserver>[_FinishWhenEmpty()],
      // The first run unpacks the dictionary before the sheet can open; the
      // install state covers the caller for those seconds, as it would the app.
      home: dict is AsyncData<DictionaryDb> ? const _DefineHost() : const InstallScreen(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1) * s.textScale),
        ),
        child: child!,
      ),
    );
  }
}

/// Pulls the arrival once the dictionary is open and shows what it asks for.
/// Nothing to show (an empty selection) finishes at once.
class _DefineHost extends ConsumerStatefulWidget {
  const _DefineHost();

  @override
  ConsumerState<_DefineHost> createState() => _DefineHostState();
}

class _DefineHostState extends ConsumerState<_DefineHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_open()));
  }

  Future<void> _open() async {
    final Map<Object?, Object?>? data = await PlatformSurfaces.incomingText();
    if (!mounted) return;
    if (data == null || (data['text'] as String? ?? '').trim().isEmpty && data['wordKey'] == null) {
      await PlatformSurfaces.finish();
      return;
    }
    await PlatformSurfaces.handleIncomingIntent(context: context, ref: ref, data: data);
    // A sheet that chains into another (Full entry) pushes it before this
    // resumes; the observer finishes once no sheet is left.
    if (mounted && !Navigator.of(context).canPop()) await PlatformSurfaces.finish();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(backgroundColor: Colors.transparent);
}

/// Finishes the activity when the last sheet has been dismissed, whether by
/// its button, a swipe, the scrim or the back gesture.
class _FinishWhenEmpty extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator case final NavigatorState n when !n.canPop()) {
        unawaited(PlatformSurfaces.finish());
      }
    });
  }
}
