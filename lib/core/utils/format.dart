/// `1,284` from 1284. British thousands separator, no locale package needed.
String grouped(int n) {
  final String s = n.abs().toString();
  final StringBuffer b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

/// `2 topics`, `1 topic`.
String plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';

/// `08:30` from minutes after midnight.
String clock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// The part of speech as the interface prints it.
String posLabel(String pos) => switch (pos) {
  'adj' => 'adjective',
  'adv' => 'adverb',
  'intj' => 'interjection',
  'prep' => 'preposition',
  'conj' => 'conjunction',
  'pron' => 'pronoun',
  'det' => 'determiner',
  'num' => 'numeral',
  _ => pos,
};

/// The band chip label: COMMON / UNCOMMON / RARE, never a number.
String bandLabel(String band) => switch (band) {
  'core' || 'everyday' => 'COMMON',
  'well_read' => 'UNCOMMON',
  _ => 'RARE',
};
