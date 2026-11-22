import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'oklch.dart';

/// The role tokens from HANDOFF 1.2. Nothing in a screen names a raw color,
/// so a theme swap is a single map replacement, which is what [ThemeFamily]
/// does.
@immutable
class MullColors extends ThemeExtension<MullColors> {
  const MullColors({
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.outline,
    required this.divider,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onSurfaceMuted,
    required this.icon,
    required this.iconMuted,
    required this.primary,
    required this.primaryPressed,
    required this.primaryContainer,
    required this.onPrimary,
    required this.onPrimaryContainer,
    required this.accent,
    required this.success,
    required this.danger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.shadow,
    required this.tone,
    required this.accentHue,
  });

  /// Page background.
  final Color surface;

  /// Cards, rows, sheets.
  final Color surfaceContainer;

  /// Nav pill, chips, fields.
  final Color surfaceContainerHigh;

  /// 1px borders. Depth lives here.
  final Color outline;

  /// Hairline between rows inside one container.
  final Color divider;

  /// Titles, definitions.
  final Color onSurface;

  /// Part of speech, counts, labels.
  final Color onSurfaceVariant;

  /// Disabled labels.
  final Color onSurfaceMuted;

  /// Top-bar icon actions.
  final Color icon;

  /// Inactive nav glyphs, a step lighter than [icon].
  final Color iconMuted;

  /// Progress, the active indicator, the seen dot.
  final Color primary;
  final Color primaryPressed;

  /// Selected tab, bookmarked card, the scope chip.
  final Color primaryContainer;

  /// Text on accent.
  final Color onPrimary;
  final Color onPrimaryContainer;

  /// Accent-coloured text and icons sitting directly on a surface.
  final Color accent;

  final Color success;
  final Color danger;

  /// The tinted well behind a destructive row.
  final Color dangerContainer;
  final Color onDangerContainer;

  /// The undo strip: dark in a light theme, light in a dark one.
  final Color inverseSurface;
  final Color onInverseSurface;

  /// Only the nav pill casts one.
  final Color shadow;

  /// Which variant this map is.
  final Tone tone;

  /// The family's accent hue, so a derived role stays in the same family.
  final double accentHue;

  bool get isDark => tone != Tone.light;

  /// Pure black's page, and its swatch on the theme screen.
  static const Color pureBlack = Color(0xFF000000);

  /// HANDOFF 1.3, AMOLED: the Mull tab's page background is true black in dark
  /// and pure white in light, regardless of the toggle and regardless of
  /// family. Card surfaces inside it keep [surfaceContainer].
  Color get lingerSurface => isDark ? pureBlack : const Color(0xFFFFFFFF);

  /// Seven fixed list hues off the accent wheel. A list stores its index, not
  /// an ARGB value, so it re-derives per theme and stays legible in light,
  /// dark and AMOLED.
  /// Shelf and list colours: Kuber's category palette (`color_palette.dart`,
  /// Vibrant 18, Muted 8, Neutral 6) as oklch, so they are re-derived per
  /// theme like every other role. A stored colour is an index into this
  /// list; 0 to 6 are the seven hues Mull shipped first (Blue, Teal, Green,
  /// Amber, Red, Pink, Purple), kept in place so saved shelves keep theirs.
  static const List<TagSwatch> tags = <TagSwatch>[
    TagSwatch('Blue', 0.623, 0.188, 259.8, TagBank.vibrant),
    TagSwatch('Teal', 0.704, 0.123, 182.5, TagBank.vibrant),
    TagSwatch('Green', 0.723, 0.192, 149.6, TagBank.vibrant),
    TagSwatch('Amber', 0.769, 0.165, 70.1, TagBank.vibrant),
    TagSwatch('Red', 0.637, 0.208, 25.3, TagBank.vibrant),
    TagSwatch('Pink', 0.656, 0.212, 354.3, TagBank.vibrant),
    TagSwatch('Purple', 0.627, 0.233, 303.9, TagBank.vibrant),
    TagSwatch('Indigo', 0.585, 0.204, 277.1, TagBank.vibrant),
    TagSwatch('Violet', 0.606, 0.219, 292.7, TagBank.vibrant),
    TagSwatch('Rose', 0.645, 0.215, 16.4, TagBank.vibrant),
    TagSwatch('Orange', 0.705, 0.187, 47.6, TagBank.vibrant),
    TagSwatch('Yellow', 0.795, 0.162, 86.0, TagBank.vibrant),
    TagSwatch('Lime', 0.768, 0.204, 130.8, TagBank.vibrant),
    TagSwatch('Emerald', 0.696, 0.149, 162.5, TagBank.vibrant),
    TagSwatch('Cyan', 0.715, 0.126, 215.2, TagBank.vibrant),
    TagSwatch('Sky', 0.685, 0.148, 237.3, TagBank.vibrant),
    TagSwatch('Fuchsia', 0.667, 0.259, 322.1, TagBank.vibrant),
    TagSwatch('Coral', 0.719, 0.169, 13.4, TagBank.vibrant),
    TagSwatch('Slate blue', 0.554, 0.041, 257.4, TagBank.muted),
    TagSwatch('Sage', 0.692, 0.082, 179.1, TagBank.muted),
    TagSwatch('Moss', 0.663, 0.067, 142.1, TagBank.muted),
    TagSwatch('Tan', 0.705, 0.070, 78.2, TagBank.muted),
    TagSwatch('Dusty rose', 0.638, 0.090, 358.1, TagBank.muted),
    TagSwatch('Lavender', 0.620, 0.079, 298.2, TagBank.muted),
    TagSwatch('Slate', 0.607, 0.029, 268.7, TagBank.muted),
    TagSwatch('Sand', 0.705, 0.030, 86.7, TagBank.muted),
    TagSwatch('Charcoal', 0.274, 0.005, 286.0, TagBank.neutral),
    TagSwatch('Graphite', 0.442, 0.015, 285.8, TagBank.neutral),
    TagSwatch('Grey', 0.552, 0.014, 285.9, TagBank.neutral),
    TagSwatch('Silver', 0.712, 0.013, 286.1, TagBank.neutral),
    TagSwatch('Mist', 0.871, 0.005, 286.3, TagBank.neutral),
    TagSwatch('Stone', 0.553, 0.012, 58.1, TagBank.neutral),
  ];

  /// Indices into [tags] in Kuber's picker order, per bank.
  static const Map<TagBank, List<int>> tagBanks = <TagBank, List<int>>{
    TagBank.vibrant: <int>[0, 7, 8, 5, 9, 4, 10, 3, 11, 12, 2, 13, 1, 14, 15, 6, 16, 17],
    TagBank.muted: <int>[18, 19, 20, 21, 22, 23, 24, 25],
    TagBank.neutral: <int>[26, 27, 28, 29, 30, 31],
  };

  static TagSwatch _tag(int index) => tags[index.abs() % tags.length];

  /// A tag as a strong colour (dots, chart marks): Mull's lightness, the
  /// tag's hue and chroma (capped at Mull's).
  Color tagColor(int? index) {
    if (index == null) return primary;
    final TagSwatch t = _tag(index);
    return isDark
        ? Oklch(0.74, math.min(t.chroma, 0.13), t.hue).toColor()
        : Oklch(0.55, math.min(t.chroma, 0.14), t.hue).toColor();
  }

  /// The tag as the picker shows it: its own lightness, hue and chroma
  /// (Kuber's swatches are the raw colour).
  Color tagSwatch(int? index) {
    if (index == null) return primary;
    final TagSwatch t = _tag(index);
    return Oklch(t.lightness, t.chroma, t.hue).toColor();
  }

  /// A tag as a tonal pair (Kuber's `categoryTones`: hue and chroma kept, only
  /// the tone moves, the container's chroma capped): a soft container and the
  /// strong glyph tone on it. Null is the accent family.
  Color tagContainer(int? index) {
    if (index == null) return primaryContainer;
    final TagSwatch t = _tag(index);
    return isDark
        ? Oklch(0.30, math.min(t.chroma, 0.05), t.hue).toColor()
        : Oklch(0.93, math.min(t.chroma, 0.045), t.hue).toColor();
  }

  Color tagOnContainer(int? index) {
    if (index == null) return onPrimaryContainer;
    final TagSwatch t = _tag(index);
    return isDark
        ? Oklch(0.82, math.min(t.chroma, 0.11), t.hue).toColor()
        : Oklch(0.45, math.min(t.chroma, 0.13), t.hue).toColor();
  }

  /// The name of a stored tag index, or the accent.
  static String tagName(int? index) => index == null ? 'Accent' : _tag(index).name;

  @override
  MullColors copyWith({
    Color? surface,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? outline,
    Color? divider,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? onSurfaceMuted,
    Color? icon,
    Color? iconMuted,
    Color? primary,
    Color? primaryPressed,
    Color? primaryContainer,
    Color? onPrimary,
    Color? onPrimaryContainer,
    Color? accent,
    Color? success,
    Color? danger,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? inverseSurface,
    Color? onInverseSurface,
    Color? shadow,
    Tone? tone,
    double? accentHue,
  }) {
    return MullColors(
      surface: surface ?? this.surface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      outline: outline ?? this.outline,
      divider: divider ?? this.divider,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      icon: icon ?? this.icon,
      iconMuted: iconMuted ?? this.iconMuted,
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimary: onPrimary ?? this.onPrimary,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      inverseSurface: inverseSurface ?? this.inverseSurface,
      onInverseSurface: onInverseSurface ?? this.onInverseSurface,
      shadow: shadow ?? this.shadow,
      tone: tone ?? this.tone,
      accentHue: accentHue ?? this.accentHue,
    );
  }

  @override
  MullColors lerp(ThemeExtension<MullColors>? other, double t) {
    if (other is! MullColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return MullColors(
      surface: l(surface, other.surface),
      surfaceContainer: l(surfaceContainer, other.surfaceContainer),
      surfaceContainerHigh: l(surfaceContainerHigh, other.surfaceContainerHigh),
      outline: l(outline, other.outline),
      divider: l(divider, other.divider),
      onSurface: l(onSurface, other.onSurface),
      onSurfaceVariant: l(onSurfaceVariant, other.onSurfaceVariant),
      onSurfaceMuted: l(onSurfaceMuted, other.onSurfaceMuted),
      icon: l(icon, other.icon),
      iconMuted: l(iconMuted, other.iconMuted),
      primary: l(primary, other.primary),
      primaryPressed: l(primaryPressed, other.primaryPressed),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimary: l(onPrimary, other.onPrimary),
      onPrimaryContainer: l(onPrimaryContainer, other.onPrimaryContainer),
      accent: l(accent, other.accent),
      success: l(success, other.success),
      danger: l(danger, other.danger),
      dangerContainer: l(dangerContainer, other.dangerContainer),
      onDangerContainer: l(onDangerContainer, other.onDangerContainer),
      inverseSurface: l(inverseSurface, other.inverseSurface),
      onInverseSurface: l(onInverseSurface, other.onInverseSurface),
      shadow: l(shadow, other.shadow),
      tone: t < 0.5 ? tone : other.tone,
      accentHue: t < 0.5 ? accentHue : other.accentHue,
    );
  }
}

/// How dark a variant is. AMOLED is not a mode. It is a true-black toggle that
/// only applies while dark is in effect.
enum Tone { light, dark, amoled }

/// One accent family. HANDOFF 1.3 ships four plus Android dynamic colour.
@immutable
class ThemeFamily {
  const ThemeFamily({
    required this.id,
    required this.name,
    required this.blurb,
    required this.neutralHue,
    required this.neutralChroma,
    required this.primaryHue,
    required this.primaryLightness,
    required this.primaryChroma,
    required this.primaryContainerChroma,
    this.lightSurfaceSink = 0,
    double? darkNeutralChroma,
  }) : darkNeutralChroma = darkNeutralChroma ?? neutralChroma;

  final String id;
  final String name;
  final String blurb;

  /// Hue for the near-grey surfaces and text.
  final double neutralHue;

  /// Multiplier on the reference neutral chromas.
  final double neutralChroma;

  final double primaryHue;
  final double primaryLightness;
  final double primaryChroma;
  final double primaryContainerChroma;

  /// Pure black is on offer for every family (Kuber). Kept as a getter for
  /// callers that still gate on it.
  bool get hasAmoled => true;

  /// How far below the shared construction the light surfaces sit, so a
  /// greige family can carry its character in the surfaces (HANDOFF 1.3,
  /// Clay: `#f6f3ee` is L 0.965 where every other family's page is 0.99).
  /// The three surface steps sink by 1x, 1.6x and 2.2x of this.
  final double lightSurfaceSink;

  /// The neutral multiplier in dark, where Clay's 2.2 would read as brown:
  /// its dark surfaces in HANDOFF 1.3 sit near the base chroma.
  final double darkNeutralChroma;

  static const ThemeFamily mull = ThemeFamily(
    id: 'mull',
    name: 'Mull',
    blurb: 'default',
    neutralHue: 215,
    neutralChroma: 1,
    primaryHue: 215,
    primaryLightness: 0.52,
    primaryChroma: 0.11,
    primaryContainerChroma: 0.04,
  );

  static const ThemeFamily vellum = ThemeFamily(
    id: 'vellum',
    name: 'Vellum',
    blurb: 'warm',
    neutralHue: 80,
    neutralChroma: 1.3,
    primaryHue: 70,
    primaryLightness: 0.58,
    primaryChroma: 0.10,
    primaryContainerChroma: 0.04,
  );

  static const ThemeFamily foxglove = ThemeFamily(
    id: 'foxglove',
    name: 'Foxglove',
    blurb: 'soft',
    neutralHue: 330,
    neutralChroma: 1.05,
    primaryHue: 325,
    primaryLightness: 0.55,
    primaryChroma: 0.12,
    primaryContainerChroma: 0.04,
  );

  static const ThemeFamily slate = ThemeFamily(
    id: 'slate',
    name: 'Slate',
    blurb: 'mono',
    neutralHue: 215,
    neutralChroma: 0.4,
    primaryHue: 215,
    primaryLightness: 0.42,
    primaryChroma: 0.012,
    primaryContainerChroma: 0.006,
  );

  /// The warm greige behind the pass 02 widget mock-ups. Neutral-led: the
  /// accent stays low chroma so the surfaces carry the character.
  static const ThemeFamily clay = ThemeFamily(
    id: 'clay',
    name: 'Clay',
    blurb: 'greige',
    neutralHue: 75,
    neutralChroma: 2.2,
    primaryHue: 45,
    primaryLightness: 0.50,
    primaryChroma: 0.055,
    primaryContainerChroma: 0.02,
    lightSurfaceSink: 0.025,
    darkNeutralChroma: 1.2,
  );

  // Perch's families, at Mull's chroma so they sit in the same register.
  static const ThemeFamily perch = ThemeFamily(
    id: 'perch',
    name: 'Perch',
    blurb: 'violet',
    neutralHue: 265,
    neutralChroma: 1,
    primaryHue: 265,
    primaryLightness: 0.52,
    primaryChroma: 0.11,
    primaryContainerChroma: 0.04,
  );

  static const ThemeFamily ember = ThemeFamily(
    id: 'ember',
    name: 'Ember',
    blurb: 'amber',
    neutralHue: 55,
    neutralChroma: 1.35,
    primaryHue: 45,
    primaryLightness: 0.58,
    primaryChroma: 0.11,
    primaryContainerChroma: 0.04,
  );

  static const ThemeFamily fern = ThemeFamily(
    id: 'fern',
    name: 'Fern',
    blurb: 'cool green',
    neutralHue: 160,
    neutralChroma: 1.15,
    primaryHue: 162,
    primaryLightness: 0.54,
    primaryChroma: 0.10,
    primaryContainerChroma: 0.04,
  );

  // Dally's accents as families, each keyed by the oklch hue of its light
  // accent. Ink, Paper and Void are Azure in dark, light and true black,
  // which in Mull are tones, not families.
  static const ThemeFamily azure = ThemeFamily(
    id: 'azure',
    name: 'Azure',
    blurb: 'blue',
    neutralHue: 259,
    neutralChroma: 1,
    primaryHue: 259,
    primaryLightness: 0.52,
    primaryChroma: 0.12,
    primaryContainerChroma: 0.04,
  );

  static const ThemeFamily tide = ThemeFamily(
    id: 'tide',
    name: 'Tide',
    blurb: 'teal',
    neutralHue: 189,
    neutralChroma: 1,
    primaryHue: 189,
    primaryLightness: 0.50,
    primaryChroma: 0.09,
    primaryContainerChroma: 0.04,
  );

  static const ThemeFamily meadow = ThemeFamily(
    id: 'meadow',
    name: 'Meadow',
    blurb: 'green',
    neutralHue: 145,
    neutralChroma: 1.1,
    primaryHue: 145,
    primaryLightness: 0.52,
    primaryChroma: 0.10,
    primaryContainerChroma: 0.04,
  );

  static const ThemeFamily blush = ThemeFamily(
    id: 'blush',
    name: 'Blush',
    blurb: 'rose',
    neutralHue: 359,
    neutralChroma: 1.05,
    primaryHue: 359,
    primaryLightness: 0.55,
    primaryChroma: 0.12,
    primaryContainerChroma: 0.04,
  );

  static const ThemeFamily iris = ThemeFamily(
    id: 'iris',
    name: 'Iris',
    blurb: 'purple',
    neutralHue: 290,
    neutralChroma: 1,
    primaryHue: 290,
    primaryLightness: 0.55,
    primaryChroma: 0.12,
    primaryContainerChroma: 0.04,
  );

  static const ThemeFamily coral = ThemeFamily(
    id: 'coral',
    name: 'Coral',
    blurb: 'red orange',
    neutralHue: 30,
    neutralChroma: 1.2,
    primaryHue: 30,
    primaryLightness: 0.56,
    primaryChroma: 0.12,
    primaryContainerChroma: 0.04,
  );

  static const ThemeFamily citron = ThemeFamily(
    id: 'citron',
    name: 'Citron',
    blurb: 'yellow green',
    neutralHue: 113,
    neutralChroma: 1.2,
    primaryHue: 113,
    primaryLightness: 0.55,
    primaryChroma: 0.10,
    primaryContainerChroma: 0.04,
  );

  // Kuber's additions, same hue-keyed derivation as the families above.
  static const ThemeFamily saffron = ThemeFamily(
    id: 'saffron',
    name: 'Saffron',
    blurb: 'gold',
    neutralHue: 90,
    neutralChroma: 1.25,
    primaryHue: 90,
    primaryLightness: 0.60,
    primaryChroma: 0.12,
    primaryContainerChroma: 0.05,
  );

  static const ThemeFamily sky = ThemeFamily(
    id: 'sky',
    name: 'Sky',
    blurb: 'light blue',
    neutralHue: 238,
    neutralChroma: 1,
    primaryHue: 238,
    primaryLightness: 0.56,
    primaryChroma: 0.11,
    primaryContainerChroma: 0.04,
  );

  static const ThemeFamily ruby = ThemeFamily(
    id: 'ruby',
    name: 'Ruby',
    blurb: 'red',
    neutralHue: 18,
    neutralChroma: 1.15,
    primaryHue: 18,
    primaryLightness: 0.50,
    primaryChroma: 0.16,
    primaryContainerChroma: 0.05,
  );

  static const ThemeFamily neon = ThemeFamily(
    id: 'neon',
    name: 'Neon',
    blurb: 'vivid green',
    neutralHue: 147,
    neutralChroma: 0.8,
    primaryHue: 147,
    primaryLightness: 0.60,
    primaryChroma: 0.14,
    primaryContainerChroma: 0.05,
  );

  static const List<ThemeFamily> all = <ThemeFamily>[
    mull,
    vellum,
    foxglove,
    slate,
    clay,
    perch,
    ember,
    fern,
    azure,
    tide,
    meadow,
    blush,
    iris,
    coral,
    citron,
    saffron,
    sky,
    ruby,
    neon,
  ];

  static ThemeFamily byId(String id) =>
      all.firstWhere((ThemeFamily f) => f.id == id, orElse: () => mull);

  /// Android hands over one wallpaper seed; the rest of the role map is
  /// derived exactly as a bundled family's is. Chroma stays at 0.11 so a
  /// wallpaper scheme sits in Mull's register.
  static ThemeFamily fromSeed(Color seed) {
    final double hue = Oklch.hueOf(seed);
    return ThemeFamily(
      id: 'dynamic',
      name: 'Dynamic',
      blurb: 'wallpaper',
      neutralHue: hue,
      neutralChroma: 1,
      primaryHue: hue,
      primaryLightness: 0.52,
      primaryChroma: 0.11,
      primaryContainerChroma: 0.04,
    );
  }

  /// [expressive] off swaps the background roles for one neutral grey ramp
  /// shared by every family (Kuber's `applySurfaceRule`); accents, tag hues
  /// and danger never change.
  MullColors colors(Tone tone, {bool expressive = true}) {
    final MullColors c = tone == Tone.light
        ? _light()
        : _dark(amoled: tone == Tone.amoled, expressive: expressive);
    return expressive ? c : _neutral(c, tone);
  }

  /// The neutral ramp, chroma 0, at Kuber's lightness steps. Pure black keeps
  /// the page and containers it already built (at chroma 0, see [_dark]) and
  /// only takes the text roles.
  MullColors _neutral(MullColors c, Tone tone) {
    Color g(double l) => Oklch(l, 0, 0).toColor();
    if (tone == Tone.light) {
      return c.copyWith(
        surface: g(1),
        surfaceContainer: g(0.965),
        surfaceContainerHigh: g(0.935),
        outline: g(0.885),
        divider: g(0.91),
        onSurface: g(0.20),
        onSurfaceVariant: g(0.48),
        onSurfaceMuted: g(0.62),
        icon: g(0.30),
        iconMuted: g(0.45),
        inverseSurface: g(0.22),
        onInverseSurface: g(0.97),
      );
    }
    final bool pure = tone == Tone.amoled;
    return c.copyWith(
      surface: pure ? null : g(0.205),
      surfaceContainer: pure ? null : g(0.255),
      surfaceContainerHigh: pure ? null : g(0.30),
      outline: pure ? null : g(0.36),
      divider: pure ? null : g(0.33),
      onSurface: g(0.96),
      onSurfaceVariant: g(0.74),
      onSurfaceMuted: g(0.60),
      icon: g(0.90),
      iconMuted: g(0.74),
      inverseSurface: g(0.93),
      onInverseSurface: g(0.20),
    );
  }

  Oklch _n(double l, double c, {bool dark = false}) =>
      Oklch(l, c * (dark ? darkNeutralChroma : neutralChroma), neutralHue);
  Oklch _nd(double l, double c) => _n(l, c, dark: true);
  Oklch _p(double l, double c) => Oklch(l, c, primaryHue);

  MullColors _light() {
    final double pc = primaryChroma;
    final double sink = lightSurfaceSink;
    return MullColors(
      surface: _n(0.99 - sink, 0.004).toColor(),
      surfaceContainer: _n(0.965 - 1.6 * sink, 0.008).toColor(),
      surfaceContainerHigh: _n(0.935 - 2.2 * sink, 0.011).toColor(),
      outline: _n(0.885 - 2.2 * sink, 0.012).toColor(),
      divider: _n(0.92 - 1.6 * sink, 0.008).toColor(),
      onSurface: _n(0.20, 0.02).toColor(),
      onSurfaceVariant: _n(0.52, 0.02).toColor(),
      onSurfaceMuted: _n(0.62, 0.02).toColor(),
      icon: _n(0.30, 0.02).toColor(),
      iconMuted: _n(0.45, 0.02).toColor(),
      primary: _p(primaryLightness, pc).toColor(),
      primaryPressed: _p(primaryLightness - 0.07, pc - 0.01).toColor(),
      primaryContainer: _p(0.92, primaryContainerChroma).toColor(),
      onPrimary: const Oklch(1, 0, 0).toColor(),
      onPrimaryContainer: _p(0.38, pc).toColor(),
      accent: _p(0.45, pc).toColor(),
      success: const Oklch(0.55, 0.10, 145).toColor(),
      danger: const Oklch(0.55, 0.16, 25).toColor(),
      dangerContainer: const Oklch(0.97, 0.02, 25).toColor(),
      onDangerContainer: const Oklch(0.48, 0.17, 25).toColor(),
      inverseSurface: _n(0.22, 0.02).toColor(),
      onInverseSurface: _n(0.97, 0.004).toColor(),
      shadow: const Oklch(0.35, 0.06, 265, 0.09).toColor(),
      tone: Tone.light,
      accentHue: primaryHue,
    );
  }

  MullColors _dark({required bool amoled, bool expressive = true}) {
    // Pure black (Kuber's rule): the page is #000000, the containers a
    // near-black ramp at the family hue (grey when expressive is off).
    final double pcd = primaryChroma * 0.81;
    Color pb(double l, double c) =>
        Oklch(l, expressive ? c : 0, neutralHue).toColor();
    return MullColors(
      surface: amoled ? MullColors.pureBlack : _nd(0.205, 0.012).toColor(),
      surfaceContainer: amoled ? pb(0.18, 0.008) : _nd(0.255, 0.014).toColor(),
      surfaceContainerHigh: amoled
          ? pb(0.215, 0.010)
          : _nd(0.30, 0.016).toColor(),
      outline: amoled ? pb(0.33, 0.014) : _nd(0.36, 0.016).toColor(),
      divider: amoled ? pb(0.25, 0.012) : _nd(0.30, 0.014).toColor(),
      onSurface: _nd(0.96, 0.005).toColor(),
      onSurfaceVariant: _nd(0.72, 0.012).toColor(),
      onSurfaceMuted: _nd(0.60, 0.012).toColor(),
      icon: _nd(0.90, 0.008).toColor(),
      iconMuted: _nd(0.72, 0.012).toColor(),
      primary: _p(0.74, pcd).toColor(),
      primaryPressed: _p(0.68, pcd).toColor(),
      primaryContainer: amoled
          ? _p(0.27, 0.05).toColor()
          : _p(0.28, pcd * 0.46).toColor(),
      onPrimary: _nd(0.14, 0.01).toColor(),
      onPrimaryContainer: _p(0.90, pcd * 0.46).toColor(),
      accent: _p(0.85, pcd * 0.69).toColor(),
      success: const Oklch(0.72, 0.11, 145).toColor(),
      danger: const Oklch(0.72, 0.14, 25).toColor(),
      dangerContainer: Oklch(
        amoled ? 0.28 : 0.26,
        amoled ? 0.08 : 0.05,
        25,
      ).toColor(),
      onDangerContainer: const Oklch(0.82, 0.11, 25).toColor(),
      inverseSurface: _nd(0.93, 0.008).toColor(),
      onInverseSurface: _nd(0.20, 0.02).toColor(),
      shadow: const Oklch(0, 0, 0, 0.5).toColor(),
      tone: amoled ? Tone.amoled : Tone.dark,
      accentHue: primaryHue,
    );
  }
}

/// Kuber's colour banks.
enum TagBank { vibrant, muted, neutral }

/// One shelf colour as oklch (from Kuber's palette) and its bank.
class TagSwatch {
  const TagSwatch(this.name, this.lightness, this.chroma, this.hue, this.bank);

  final String name;
  final double lightness;
  final double chroma;
  final double hue;
  final TagBank bank;
}
