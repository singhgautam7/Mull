import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/features/linger/share_image_builder.dart';

import '../database/fake_dictionary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ShareImageCard renders without overflow on long headwords and definitions', (
    WidgetTester tester,
  ) async {
    const FakeWord longWord = FakeWord(
      'electroencephalography',
      'noun',
      'A method to record an electrogram of the spontaneous electrical activity of the brain over a period of time, as recorded from multiple electrodes placed on the scalp.',
      examples: <String>[
        'Clinical electroencephalography typically involves recording electrical activity from multiple channels across the scalp for thirty minutes.',
      ],
      ipa: '/ɪˌlɛktrəʊɛnˌsɛfəˈlɒɡrəfi/',
      band: 'rare',
    );

    final DictionaryDb dict = fakeDictionary(words: <FakeWord>[longWord]);
    final DictionaryWord word = dict.byKey(longWord.key)!;

    final MullColors colors = ThemeFamily.mull.colors(Tone.light);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              child: ShareImageCard(
                word: word,
                example: longWord.examples.first,
                colors: colors,
              ),
            ),
          ),
        ),
      ),
    );

    // Verify headword and footer elements rendered
    expect(find.text('electroencephalography'), findsOneWidget);
    expect(find.text('MULL'), findsOneWidget);
    expect(find.text('offline dictionary'), findsOneWidget);

    // Assert that no FlutterError (e.g. RenderFlex overflowed) occurred
    expect(tester.takeException(), isNull);

    dict.close();
  });

  test('AMOLED steps back to the family dark surface, so the crop reads as a card', () {
    final MullColors amoled = ThemeFamily.mull.colors(Tone.amoled);
    final MullColors dark = ThemeFamily.mull.colors(Tone.dark);
    expect(ShareImageCard.shareColors(amoled, ThemeFamily.mull).surface, dark.surface);
    expect(ShareImageCard.shareColors(dark, ThemeFamily.mull), same(dark));
    final MullColors light = ThemeFamily.mull.colors(Tone.light);
    expect(ShareImageCard.shareColors(light, ThemeFamily.mull), same(light));
  });
}
