import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/utils/platform_surfaces.dart';

void main() {
  group('sentenceAround', () {
    const String paragraph =
        'It rained all week. The storm began to abate towards evening, '
        'and the river fell. By Sunday the roads were dry.';

    test('keeps only the sentence holding the word', () {
      expect(
        PlatformSurfaces.sentenceAround(paragraph, 'abate'),
        'The storm began to abate towards evening, and the river fell.',
      );
    });

    test('a first or last sentence has no neighbour to trim', () {
      expect(PlatformSurfaces.sentenceAround(paragraph, 'rained'), 'It rained all week.');
      expect(PlatformSurfaces.sentenceAround(paragraph, 'dry'), 'By Sunday the roads were dry.');
    });

    test('a long sentence is cut on spaces around the word', () {
      final String long = '${'lorem ipsum ' * 30}abate ${'dolor sit ' * 30}';
      final String out = PlatformSurfaces.sentenceAround(long, 'abate', maxLength: 80);
      expect(out.length, lessThanOrEqualTo(84));
      expect(out, contains('abate'));
      expect(out, startsWith('… '));
      expect(out, endsWith(' …'));
    });

    test('newlines and runs of spaces collapse', () {
      expect(
        PlatformSurfaces.sentenceAround('A  tenuous\n\nclaim.', 'tenuous'),
        'A tenuous claim.',
      );
    });
  });

  test('words keeps apostrophes and drops punctuation and digits', () {
    expect(
      PlatformSurfaces.words("Don't abate, it's 2026 (still)!"),
      <String>["Don't", 'abate', "it's", 'still'],
    );
    expect(PlatformSurfaces.words('abate'), <String>['abate']);
  });
}
