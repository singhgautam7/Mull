import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/database/dictionary_db.dart';
import 'core/providers.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/palette.dart';
import 'core/theme/tokens.dart';
import 'core/utils/wallpaper_seed.dart';
import 'core/utils/platform_surfaces.dart';
import 'features/settings/install_screen.dart';
import 'features/settings/settings_controller.dart';

/// The theme for one brightness from the settings and, with dynamic colour
/// on, the wallpaper seed. Shared by the app and the define sheet so the two
/// never differ.
ThemeData themeFor(AppSettings s, Color? seed, Brightness b) {
  final Tone tone = s.toneFor(b);
  return seed == null ? AppTheme.of(s.family, tone) : AppTheme.fromSeed(seed, tone);
}

class MullApp extends ConsumerStatefulWidget {
  const MullApp({super.key});

  @override
  ConsumerState<MullApp> createState() => _MullAppState();
}

class _MullAppState extends ConsumerState<MullApp> {
  late final GoRouter _router = buildRouter(
    onboarded: ref.read(settingsProvider).onboarded,
  );
  bool _widgetSynced = false;

  @override
  void initState() {
    super.initState();
    PlatformSurfaces.listenForArrivals(_handleArrival);
  }

  /// The arrival Mull was launched with (selection menu, share sheet, widget
  /// tap), pulled once the dictionary is open; the platform clears it on read.
  Future<void> _checkInitialIntent() async {
    final Map<Object?, Object?>? data = await PlatformSurfaces.incomingText();
    if (data != null) await _handleArrival(data);
  }

  Future<void> _handleArrival(Map<Object?, Object?> data) async {
    final BuildContext? ctx = rootNavigatorKey.currentContext;
    if (!mounted || ctx == null || !ctx.mounted) return;
    if (ref.read(dictionaryProvider) is! AsyncData<DictionaryDb>) return;
    // The define sheet handing the user over to a screen of the app.
    if (data['route'] case final String route) {
      _router.go(route);
      return;
    }
    await PlatformSurfaces.handleIncomingIntent(context: ctx, ref: ref, data: data);
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings s = ref.watch(settingsProvider);
    final AsyncValue<DictionaryDb> dict = ref.watch(dictionaryProvider);
    // Dynamic colour takes one seed from the OS; every other role is derived
    // exactly as a bundled family's would be, so the two never diverge.
    final Color? seed = s.dynamicColor
        ? ref.watch(wallpaperSeedProvider).value
        : null;

    // The install state is shown while the dictionary is unpacked; the router
    // takes over once it is open. The two cross-fade (`sheet`, decelerate) so
    // the first run has no hard cut; there is no MediaQuery above a
    // MaterialApp, so reduced motion is read from the platform directly.
    final bool reduced = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    Widget crossFade(Widget child) => AnimatedSwitcher(
      duration: reduced ? Motion.reducedFade : Motion.sheet,
      switchInCurve: reduced ? Curves.linear : Motion.decelerate,
      switchOutCurve: reduced ? Curves.linear : Motion.decelerate,
      child: child,
    );
    if (dict is! AsyncData<DictionaryDb>) {
      return crossFade(
        MaterialApp(
          key: const ValueKey<String>('install'),
          title: 'Mull',
          debugShowCheckedModeBanner: false,
          themeMode: s.themeMode,
          theme: themeFor(s, seed, Brightness.light),
          darkTheme: themeFor(s, seed, Brightness.dark),
          home: const InstallScreen(),
        ),
      );
    }
    if (!_widgetSynced) {
      _widgetSynced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await PlatformSurfaces.syncWidgetSchedule(
          dict: dict.value,
          prefs: ref.read(prefsProvider),
        );
        // The reminder reads that schedule; re-arm it from the saved setting
        // so an install that predates the alarm gets one.
        await PlatformSurfaces.scheduleReminder();
        if (mounted) await _checkInitialIntent();
      });
    }
    return crossFade(
      MaterialApp.router(
      key: const ValueKey<String>('app'),
      title: 'Mull',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      themeMode: s.themeMode,
      theme: themeFor(s, seed, Brightness.light),
      darkTheme: themeFor(s, seed, Brightness.dark),
      // The text size setting sits on top of the OS scale.
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            MediaQuery.textScalerOf(context).scale(1) * s.textScale,
          ),
        ),
        child: child!,
      ),
      ),
    );
  }
}
