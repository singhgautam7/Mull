import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';

/// Every family x tone x expressive builds opaque roles that stay readable,
/// the neutral ramp is shared, and Pure black is exactly black.
void main() {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  double contrast(Color a, Color b) {
    final double la = lum(a), lb = lum(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  List<Color> roles(MullColors c) => <Color>[
    c.surface,
    c.surfaceContainer,
    c.surfaceContainerHigh,
    c.outline,
    c.divider,
    c.onSurface,
    c.onSurfaceVariant,
    c.onSurfaceMuted,
    c.icon,
    c.iconMuted,
    c.primary,
    c.primaryPressed,
    c.primaryContainer,
    c.onPrimary,
    c.onPrimaryContainer,
    c.accent,
    c.success,
    c.danger,
    c.dangerContainer,
    c.onDangerContainer,
    c.inverseSurface,
    c.onInverseSurface,
  ];

  test('every family, tone and expressive setting is opaque and readable', () {
    for (final ThemeFamily f in ThemeFamily.all) {
      for (final Tone tone in Tone.values) {
        for (final bool x in <bool>[true, false]) {
          final String tag = '${f.id} ${tone.name} expressive=$x';
          final MullColors c = f.colors(tone, expressive: x);
          for (final Color r in roles(c)) {
            expect(r.a, 1.0, reason: tag);
          }
          expect(
            contrast(c.onSurface, c.surface),
            greaterThan(12),
            reason: tag,
          );
          expect(
            contrast(c.onSurface, c.surfaceContainer),
            greaterThan(10),
            reason: tag,
          );
          expect(
            contrast(c.onSurfaceVariant, c.surface),
            greaterThan(4.5),
            reason: tag,
          );
          expect(
            contrast(c.onSurfaceVariant, c.surfaceContainerHigh),
            greaterThan(3.0),
            reason: tag,
          );
          expect(
            contrast(c.onPrimaryContainer, c.primaryContainer),
            greaterThan(4.5),
            reason: tag,
          );
          expect(
            contrast(c.onDangerContainer, c.dangerContainer),
            greaterThan(4.5),
            reason: tag,
          );
          expect(
            contrast(c.onInverseSurface, c.inverseSurface),
            greaterThan(10),
            reason: tag,
          );
          // Slate is deliberately near-grey, so its accent is the floor.
          expect(
            contrast(c.onPrimary, c.primary),
            greaterThan(3.0),
            reason: tag,
          );
          expect(contrast(c.accent, c.surface), greaterThan(3.0), reason: tag);
          // The built ThemeData carries the same map.
          final ThemeData t = AppTheme.of(f, tone, expressive: x);
          expect(t.extension<MullColors>()!.surface, c.surface, reason: tag);
        }
      }
    }
  });

  test(
    'expressive off: one neutral ramp for every family, accents untouched',
    () {
      for (final Tone tone in Tone.values) {
        final MullColors a = ThemeFamily.mull.colors(tone, expressive: false);
        final MullColors b = ThemeFamily.ruby.colors(tone, expressive: false);
        for (final (Color, Color) p in <(Color, Color)>[
          (a.surface, b.surface),
          (a.surfaceContainer, b.surfaceContainer),
          (a.surfaceContainerHigh, b.surfaceContainerHigh),
          (a.outline, b.outline),
          (a.divider, b.divider),
          (a.onSurface, b.onSurface),
          (a.onSurfaceVariant, b.onSurfaceVariant),
          (a.inverseSurface, b.inverseSurface),
        ]) {
          expect(p.$1, p.$2, reason: tone.name);
        }
        expect(a.primary, isNot(b.primary), reason: tone.name);
        expect(a.accent, isNot(b.accent), reason: tone.name);
        // Surface roles are grey: no channel spread.
        for (final Color g in <Color>[
          a.surface,
          a.surfaceContainer,
          a.outline,
        ]) {
          expect((g.r - g.b).abs(), lessThan(0.005));
        }
        // Accents, tag hues and danger never change with the switch.
        final MullColors on = ThemeFamily.mull.colors(tone);
        expect(a.primary, on.primary);
        expect(a.danger, on.danger);
        expect(a.tagColor(2), on.tagColor(2));
        expect(a.lingerSurface, on.lingerSurface);
      }
      // On is the tinted derivation: two families differ.
      expect(
        ThemeFamily.mull.colors(Tone.dark).surface,
        isNot(ThemeFamily.ruby.colors(Tone.dark).surface),
      );
    },
  );

  test('Pure black is exactly black for every family, on and off', () {
    for (final ThemeFamily f in ThemeFamily.all) {
      expect(f.hasAmoled, isTrue, reason: f.id);
      for (final bool x in <bool>[true, false]) {
        final MullColors c = f.colors(Tone.amoled, expressive: x);
        expect(c.surface, const Color(0xff000000), reason: f.id);
        expect(c.surface, MullColors.pureBlack);
        expect(lum(c.surfaceContainer), greaterThan(0), reason: f.id);
        expect(
          lum(c.surfaceContainer),
          lessThan(lum(c.surfaceContainerHigh)),
          reason: f.id,
        );
      }
    }
  });

  test('the dynamic scheme honours expressive too', () {
    const Color seed = Color(0xff6750a4);
    final MullColors off = ThemeFamily.fromSeed(seed)
        .colors(Tone.dark, expressive: false);
    expect(
      off.surface,
      ThemeFamily.mull.colors(Tone.dark, expressive: false).surface,
    );
    expect(
      AppTheme.fromSeed(
        seed,
        Tone.dark,
        expressive: false,
      ).extension<MullColors>()!.surface,
      off.surface,
    );
  });

  test('the new families are keyed by their hue', () {
    expect(ThemeFamily.byId('saffron').primaryHue, 90);
    expect(ThemeFamily.byId('sky').primaryHue, 238);
    expect(ThemeFamily.byId('ruby').primaryHue, 18);
  });
}
