import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/dictionary_db.dart';
import 'core/motion/motion.dart';
import 'core/providers.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/palette.dart';
import 'core/theme/tokens.dart';
import 'core/utils/wallpaper_seed.dart';
import 'core/utils/platform_surfaces.dart';
import 'features/settings/install_screen.dart';
import 'features/settings/settings_controller.dart';
import 'shared/widgets/states.dart';

/// The theme for one brightness from the settings and, with dynamic colour
/// on, the wallpaper seed. Shared by the app and the define sheet so the two
/// never differ.
ThemeData themeFor(AppSettings s, Color? seed, Brightness b) {
  final Tone tone = s.toneFor(b);
  final bool x = s.expressiveColors;
  return seed == null
      ? AppTheme.of(s.family, tone, expressive: x)
      : AppTheme.fromSeed(seed, tone, expressive: x);
}

/// The Motion level for everything below: the setting resolved with the
/// device class, and the phone's Remove animations (or an accessibility
/// navigation service) forcing Off. Rebuilds only when one of those changes.
/// Also tells [MullHaptics] when a scroll is under way, so no haptic fires
/// mid-scroll. Shared by the app and the define sheet.
class MullMotionScope extends ConsumerWidget {
  const MullMotionScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MotionLevel level = ref.watch(settingsProvider.select((AppSettings s) => s.motionLevel));
    final bool off = systemMotionOff(context);
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification n) {
        if (n is ScrollStartNotification) MullHaptics.scrolling = true;
        if (n is ScrollEndNotification) MullHaptics.scrolling = false;
        return false;
      },
      child: MotionScope(level: off ? MotionLevel.off : level, systemOff: off, child: child),
    );
  }
}

/// What the widgets' colours depend on, so the push fires on exactly those.
typedef _WidgetThemeKey = ({String family, ThemeMode mode, bool amoled, bool expressive, Color? seed});

final Provider<_WidgetThemeKey> _widgetThemeKeyProvider = Provider<_WidgetThemeKey>((Ref ref) {
  final bool dynamic = ref.watch(settingsProvider.select((AppSettings s) => s.dynamicColor));
  return (
    family: ref.watch(settingsProvider.select((AppSettings s) => s.familyId)),
    mode: ref.watch(settingsProvider.select((AppSettings s) => s.themeMode)),
    amoled: ref.watch(settingsProvider.select((AppSettings s) => s.amoled)),
    expressive: ref.watch(settingsProvider.select((AppSettings s) => s.expressiveColors)),
    seed: dynamic ? ref.watch(wallpaperSeedProvider).value : null,
  );
});

/// What the MaterialApp itself is built from: the theme inputs, the text
/// size and nothing else. A change to any other setting (header, reminder,
/// pronunciation) used to rebuild the whole app from its root.
typedef _AppKey = ({
  String family,
  ThemeMode mode,
  bool amoled,
  bool expressive,
  bool dynamic,
  double textScale,
});

final Provider<_AppKey> _appKeyProvider = Provider<_AppKey>((Ref ref) {
  _AppKey key(AppSettings s) => (
    family: s.familyId,
    mode: s.themeMode,
    amoled: s.amoled,
    expressive: s.expressiveColors,
    dynamic: s.dynamicColor,
    textScale: s.textScale,
  );
  return ref.watch(settingsProvider.select(key));
});

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

  /// Since the first build. A dictionary that opens inside
  /// [Delayed.threshold] never showed the install state, so there is
  /// nothing to cross-fade from: the router appears at once instead of
  /// running Home's first build under a 260 ms fade of two whole apps.
  final Stopwatch _sinceStart = Stopwatch()..start();
  bool? _fadeIn;

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
      // The search widget's route carries `focus=1`; a fresh value per
      // arrival, so a second tap while already on Search raises the
      // keyboard again.
      _router.go(
        route.contains('focus=')
            ? route.replaceFirst('focus=1', 'focus=${DateTime.now().millisecondsSinceEpoch}')
            : route,
      );
      return;
    }
    await PlatformSurfaces.handleIncomingIntent(context: ctx, ref: ref, data: data);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(_appKeyProvider);
    final AppSettings s = ref.read(settingsProvider);
    final AsyncValue<DictionaryDb> dict = ref.watch(dictionaryProvider);
    // Dynamic colour takes one seed from the OS; every other role is derived
    // exactly as a bundled family's would be, so the two never diverge.
    final Color? seed = s.dynamicColor
        ? ref.watch(wallpaperSeedProvider).value
        : null;
    // The launcher widgets draw from the theme the app last wrote: push it
    // whenever the family, mode, true black or the wallpaper seed changes.
    ref.listen<_WidgetThemeKey>(
      _widgetThemeKeyProvider,
      (_WidgetThemeKey? old, _WidgetThemeKey next) => unawaited(
        PlatformSurfaces.syncWidgetTheme(
          settings: ref.read(settingsProvider),
          seed: next.seed,
          prefs: ref.read(prefsProvider),
        ),
      ),
    );

    // The install state is shown while the dictionary is unpacked; the router
    // takes over once it is open. The two cross-fade (`sheet`, decelerate) so
    // the first run has no hard cut; there is no MediaQuery above a
    // MaterialApp, so reduced motion is read from the platform directly.
    final bool reduced = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (dict is AsyncData<DictionaryDb>) _fadeIn ??= _sinceStart.elapsed > Delayed.threshold;
    Widget crossFade(Widget child) => AnimatedSwitcher(
      duration: _fadeIn == false ? Duration.zero : reduced ? Motion.reducedFade : Motion.sheet,
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
      // The theme ripple reveals a change; an implicit theme tween under it
      // would fight it.
      themeAnimationDuration: Duration.zero,
          themeMode: s.themeMode,
          theme: themeFor(s, seed, Brightness.light),
          darkTheme: themeFor(s, seed, Brightness.dark),
          // A warm start opens the dictionary in well under the threshold,
          // so the install state never renders and the splash hands over
          // straight to the route. Only a real unpack is slow enough to
          // reach it.
          home: const Delayed(
            placeholder: Scaffold(body: SizedBox.shrink()),
            child: InstallScreen(),
          ),
        ),
      );
    }
    if (!_widgetSynced) {
      _widgetSynced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        // Read before the first await: `ref` is not safe once the widget has
        // been unmounted, and the widget can go between these calls.
        final AppSettings settings = ref.read(settingsProvider);
        final Color? widgetSeed = ref.read(_widgetThemeKeyProvider).seed;
        final SharedPreferences prefs = ref.read(prefsProvider);
        await PlatformSurfaces.syncWidgetTheme(
          settings: settings,
          seed: widgetSeed,
          prefs: prefs,
        );
        // Each of these is a platform round trip, and the dictionary closes
        // with the tree: a teardown mid-startup must not leave one reading a
        // closed database.
        if (!mounted) return;
        await PlatformSurfaces.syncWidgetSchedule(
          dict: dict.value,
          prefs: prefs,
        );
        // The reminder reads that schedule; re-arm it from the saved setting
        // so an install that predates the alarm gets one.
        if (!mounted) return;
        await PlatformSurfaces.scheduleReminder();
        // Motion level Auto: the one-off RAM check, after the first frame
        // and only until it has an answer (cached in prefs).
        if (!mounted) return;
        await ref.read(settingsProvider.notifier).checkDevice(PlatformSurfaces.deviceMemory);
        if (mounted) await _checkInitialIntent();
      });
    }
    return crossFade(
      MaterialApp.router(
      key: const ValueKey<String>('app'),
      title: 'Mull',
      debugShowCheckedModeBanner: false,
      // The theme ripple reveals a change; an implicit theme tween under it
      // would fight it.
      themeAnimationDuration: Duration.zero,
      routerConfig: _router,
      themeMode: s.themeMode,
      theme: themeFor(s, seed, Brightness.light),
      darkTheme: themeFor(s, seed, Brightness.dark),
      // The text size setting sits on top of the OS scale. The motion scope
      // and the theme ripple wrap the navigator, so sheets and dialogs are
      // covered too.
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            MediaQuery.textScalerOf(context).scale(1) * s.textScale,
          ),
        ),
        child: MullMotionScope(child: ThemeRipple(child: child!)),
      ),
      ),
    );
  }
}
