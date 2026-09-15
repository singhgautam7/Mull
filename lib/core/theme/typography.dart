import 'package:flutter/material.dart';

/// HANDOFF 1.4, the type ramp.
///
/// One typeface carries the whole interface: Instrument Sans (variable), from
/// 11px labels to the 56px headword. There is no serif in Mull. A tabular mono
/// carries IPA, counts, stats and section headers.
///
/// Instrument Sans is a variable font, so every weight sets `fontVariations`
/// alongside `fontWeight`. The axis is what actually moves the glyphs.
abstract final class MullType {
  static const String sans = 'Instrument Sans';

  /// The platform's own monospace, `ui-monospace` in the handoff.
  static const String mono = 'monospace';

  /// Display sizes take weight 600 and `letter-spacing: -0.022em`.
  static const double _displayTracking = -0.022;

  static FontWeight _fw(int weight) => FontWeight.values[weight ~/ 100 - 1];

  static TextStyle _sans(
    double size,
    double height,
    int weight, {
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: sans,
      fontSize: size,
      height: height,
      fontWeight: _fw(weight),
      fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
      letterSpacing: letterSpacing,
    );
  }

  /// A display step: 600 with the display tracking, in em.
  static TextStyle _display(double size, double height) =>
      _sans(size, height, 600, letterSpacing: size * _displayTracking);

  static TextStyle _mono(double size, int weight, {double? letterSpacing}) {
    return TextStyle(
      fontFamily: mono,
      fontSize: size,
      height: 1.3,
      fontWeight: _fw(weight),
      letterSpacing: letterSpacing,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  /// The word card headword, 8 or fewer graphemes.
  static TextStyle get headwordXL => _display(56, 1.02);

  /// 9 to 13 graphemes.
  static TextStyle get headwordL => _display(44, 1.04);

  /// 14 to 19 graphemes.
  static TextStyle get headwordM => _display(38, 1.08);

  /// 20 or more; the only step that wraps to a second line.
  static TextStyle get headwordS => _display(30, 1.1);

  /// The headword rule: pick the step by grapheme count, never by measuring,
  /// so it is stable between renders. It never shrinks for font scale.
  static TextStyle headword(String word) {
    final int n = word.characters.length;
    if (n <= 8) return headwordXL;
    if (n <= 13) return headwordL;
    if (n <= 19) return headwordM;
    return headwordS;
  }

  /// Empty states, first run.
  static TextStyle get display => _display(40, 1.05);

  /// Sheet titles, idiom phrase.
  static TextStyle get sheetTitle => _sans(22, 1.1, 400);

  /// Screen title, tab root.
  static TextStyle get headerTitle => _sans(22, 1.25, 600, letterSpacing: -0.2);

  /// Scrolled / collapsed header.
  static TextStyle get screenTitle =>
      _sans(19, 1.25, 600, letterSpacing: -0.19);

  static TextStyle get title => _sans(20, 1.25, 600, letterSpacing: -0.2);

  /// The definition on a word card.
  static TextStyle get cardDefinition => _sans(26, 1.4, 400);

  /// Definitions, sheet body.
  static TextStyle get body => _sans(15, 1.55, 400);

  /// Settings row, button, word row.
  static TextStyle get titleMedium => _sans(14.5, 1.3, 600);

  /// Nav label.
  static TextStyle get titleSmall => _sans(13.5, 1.3, 600);

  /// Notes, secondary body.
  static TextStyle get note => _sans(13.5, 1.65, 400);

  /// Table definition and example.
  static TextStyle get tableCell => _sans(12.5, 1.45, 400);

  static TextStyle get bodySmall => _sans(12, 1.5, 400);

  static TextStyle get label => _sans(12, 1.3, 500);

  /// IPA, counts, stat figures.
  static TextStyle get monoTabular => _mono(13, 500);

  /// Metadata under a name.
  static TextStyle get monoLabel => _mono(11, 500);

  /// ALL-CAPS section headers: `600 11px · letter-spacing .08em`.
  static TextStyle get sectionHeader => _mono(11, 600, letterSpacing: 0.88);

  static TextTheme textTheme(Color onSurface, Color onSurfaceVariant) {
    return TextTheme(
      displayLarge: display.copyWith(color: onSurface),
      headlineSmall: screenTitle.copyWith(color: onSurface),
      titleLarge: title.copyWith(color: onSurface),
      titleMedium: titleMedium.copyWith(color: onSurface),
      titleSmall: titleSmall.copyWith(color: onSurface),
      bodyLarge: body.copyWith(color: onSurface),
      bodyMedium: note.copyWith(color: onSurface),
      bodySmall: bodySmall.copyWith(color: onSurfaceVariant),
      labelLarge: titleMedium.copyWith(color: onSurface),
      labelMedium: label.copyWith(color: onSurfaceVariant),
      labelSmall: monoLabel.copyWith(color: onSurfaceVariant),
    );
  }
}

extension MullTextStyle on TextStyle {
  /// Sets the weight on a variable-font style. Plain `copyWith(fontWeight:)`
  /// does nothing for Instrument Sans; the `wght` axis has to move too.
  TextStyle weight(int w) => copyWith(
    fontWeight: MullType._fw(w),
    fontVariations: fontFamily == MullType.sans
        ? <FontVariation>[FontVariation('wght', w.toDouble())]
        : null,
  );
}
