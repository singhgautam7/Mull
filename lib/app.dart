import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/database/dictionary_db.dart';
import 'core/providers.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/palette.dart';
import 'core/utils/wallpaper_seed.dart';
import 'features/settings/install_screen.dart';
import 'features/settings/settings_controller.dart';

class MullApp extends ConsumerStatefulWidget {
  const MullApp({super.key});

  @override
  ConsumerState<MullApp> createState() => _MullAppState();
}

class _MullAppState extends ConsumerState<MullApp> {
  late final GoRouter _router = buildRouter(onboarded: ref.read(settingsProvider).onboarded);

  @override
  Widget build(BuildContext context) {
    final AppSettings s = ref.watch(settingsProvider);
    final AsyncValue<DictionaryDb> dict = ref.watch(dictionaryProvider);
    // Dynamic colour takes one seed from the OS; every other role is derived
    // exactly as a bundled family's would be, so the two never diverge.
    final Color? seed = s.dynamicColor
        ? ref.watch(wallpaperSeedProvider).value
        : null;
    ThemeData themeFor(Brightness b) {
      final Tone tone = s.toneFor(b);
      return seed == null
          ? AppTheme.of(s.family, tone)
          : AppTheme.fromSeed(seed, tone);
    }

    // The install state is shown while the dictionary is unpacked; the router
    // takes over once it is open.
    if (dict is! AsyncData<DictionaryDb>) {
      return MaterialApp(
        title: 'Mull',
        debugShowCheckedModeBanner: false,
        themeMode: s.themeMode,
        theme: themeFor(Brightness.light),
        darkTheme: themeFor(Brightness.dark),
        home: const InstallScreen(),
      );
    }
    return MaterialApp.router(
      title: 'Mull',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      themeMode: s.themeMode,
      theme: themeFor(Brightness.light),
      darkTheme: themeFor(Brightness.dark),
      // The text size setting sits on top of the OS scale.
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1) * s.textScale),
        ),
        child: child!,
      ),
    );
  }
}
