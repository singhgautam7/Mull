import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Material You seed Android derives from the wallpaper (Android 12+).
///
/// Only the seed is taken; every role is then derived by [ThemeFamily.fromSeed]
/// exactly as a bundled family's is, at Mull's chroma. Null below Android 12,
/// where the "Use wallpaper colours" toggle simply has nothing to apply.
final FutureProvider<Color?> wallpaperSeedProvider = FutureProvider<Color?>((
  Ref ref,
) async {
  // dynamic_color still hands the palette back as the deprecated CorePalette;
  // only its primary tone 40 is read, which is the seed Android used.
  // ignore: deprecated_member_use
  final palette = await DynamicColorPlugin.getCorePalette();
  return palette == null ? null : Color(palette.primary.get(40));
});
