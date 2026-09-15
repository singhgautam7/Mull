import 'package:flutter/material.dart';

import 'palette.dart';
import 'tokens.dart';
import 'typography.dart';

/// Builds, and caches, one [ThemeData] per (family, tone).
///
/// `ThemeData` construction is not free and a theme is stable for the life of
/// a setting, so it is built once and handed out on every rebuild after that.
abstract final class AppTheme {
  static final Map<String, ThemeData> _cache = <String, ThemeData>{};

  static ThemeData of(ThemeFamily family, Tone tone) {
    return _cache.putIfAbsent('${family.id}:${tone.name}', () {
      return _build(family.colors(tone), tone != Tone.light);
    });
  }

  /// Android dynamic colour, keyed by the wallpaper seed so it caches like any
  /// other theme.
  static ThemeData fromSeed(Color seed, Tone tone) {
    return _cache.putIfAbsent('seed:${seed.toARGB32()}:${tone.name}', () {
      return _build(
        ThemeFamily.fromSeed(seed).colors(tone),
        tone != Tone.light,
      );
    });
  }

  static ThemeData _build(MullColors c, bool isDark) {
    final TextTheme text = MullType.textTheme(c.onSurface, c.onSurfaceVariant);
    // Material roles are filled from the token map so any stock widget that
    // reads the ColorScheme lands on the same colours as the rest of the app.
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: c.primary,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: c.primary,
          onPrimary: c.onPrimary,
          primaryContainer: c.primaryContainer,
          onPrimaryContainer: c.onPrimaryContainer,
          surface: c.surface,
          onSurface: c.onSurface,
          surfaceContainer: c.surfaceContainer,
          surfaceContainerHigh: c.surfaceContainerHigh,
          onSurfaceVariant: c.onSurfaceVariant,
          outline: c.outline,
          outlineVariant: c.divider,
          error: c.danger,
          errorContainer: c.dangerContainer,
          onErrorContainer: c.onDangerContainer,
          inverseSurface: c.inverseSurface,
          onInverseSurface: c.onInverseSurface,
          shadow: c.shadow,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: c.surface,
      canvasColor: c.surface,
      textTheme: text,
      fontFamily: MullType.sans,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[c],
      // Depth lives in 1px outlines. Material's tonal elevation is off.
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.surfaceContainer,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.cardR,
          side: BorderSide(color: c.outline),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.divider,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheetR),
        showDragHandle: false,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.primaryContainer,
        selectionHandleColor: c.primary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) =>
              s.contains(WidgetState.selected) ? c.onPrimary : c.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected)
              ? c.primary
              : c.surfaceContainerHigh,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) =>
              s.contains(WidgetState.selected) ? c.primary : c.outline,
        ),
      ),
    );
  }
}

extension MullThemeContext on BuildContext {
  /// The role token map for the active theme.
  MullColors get colors => Theme.of(this).extension<MullColors>()!;

  TextTheme get text => Theme.of(this).textTheme;
}
