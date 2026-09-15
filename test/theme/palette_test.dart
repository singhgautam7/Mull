import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/core/theme/typography.dart';

/// The role map is derived, so HANDOFF 1.2's printed hex values are checked
/// against the derivation rather than typed in anywhere.
void main() {
  int channel(Color c, int shift) => (c.toARGB32() >> shift) & 0xff;

  void near(Color actual, int expectedHex, {int tolerance = 4}) {
    final Color expected = Color(0xff000000 | expectedHex);
    for (final int shift in <int>[16, 8, 0]) {
      expect(
        (channel(actual, shift) - channel(expected, shift)).abs(),
        lessThanOrEqualTo(tolerance),
        reason: '${actual.toARGB32().toRadixString(16)} vs ${expectedHex.toRadixString(16)}',
      );
    }
  }

  test('Mull light and dark primaries match the handoff', () {
    final MullColors light = ThemeFamily.mull.colors(Tone.light);
    final MullColors dark = ThemeFamily.mull.colors(Tone.dark);
    near(light.primary, 0x007890);
    near(dark.primary, 0x62b9ce);
    near(light.surface, 0xf9fcfd);
    near(dark.surface, 0x11191b);
    near(light.primaryContainer, 0xc8ecf5);
  });

  test('the other families land on their handoff primaries', () {
    near(ThemeFamily.vellum.colors(Tone.light).primary, 0xa06f30, tolerance: 8);
    near(ThemeFamily.foxglove.colors(Tone.light).primary, 0x945798, tolerance: 8);
    near(ThemeFamily.slate.colors(Tone.light).primary, 0x464f51, tolerance: 8);
  });

  test('AMOLED is true black and the Mull tab surface ignores the toggle', () {
    expect(ThemeFamily.mull.colors(Tone.amoled).surface, const Color(0xff000000));
    expect(ThemeFamily.mull.colors(Tone.dark).lingerSurface, const Color(0xff000000));
    expect(ThemeFamily.mull.colors(Tone.amoled).lingerSurface, const Color(0xff000000));
    expect(ThemeFamily.mull.colors(Tone.light).lingerSurface, const Color(0xffffffff));
    expect(ThemeFamily.vellum.colors(Tone.light).lingerSurface, const Color(0xffffffff));
  });

  test('dynamic colour keeps Mull\'s chroma', () {
    final ThemeFamily f = ThemeFamily.fromSeed(const Color(0xff6750a4));
    expect(f.primaryChroma, 0.11);
    expect(f.primaryLightness, 0.52);
  });

  test('the headword step is picked by grapheme count', () {
    expect(MullType.headword('abate').fontSize, 56);
    expect(MullType.headword('notwithstanding').fontSize, 38);
    expect(MullType.headword('wistful').fontSize, 56);
    expect(MullType.headword('unconstitutional').fontSize, 38);
    expect(MullType.headword('counterintuitively').fontSize, 38);
    expect(MullType.headword('electroencephalography').fontSize, 30);
    expect(MullType.headwordXL.fontVariations!.single.value, 600);
  });
}
