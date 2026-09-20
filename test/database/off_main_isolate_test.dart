import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/dictionary_installer.dart';
import 'package:mull/features/quiz/quiz_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Watches the calling isolate's event loop while [work] runs and reports the
/// longest stretch it was starved. A blocked UI isolate cannot service a
/// 10 ms timer, so a large gap here is a frozen frame in the app.
Future<Duration> longestStall(Future<void> Function() work) async {
  DateTime last = DateTime.now();
  Duration worst = Duration.zero;
  final Timer watchdog = Timer.periodic(const Duration(milliseconds: 10), (_) {
    final DateTime now = DateTime.now();
    final Duration gap = now.difference(last);
    if (gap > worst) worst = gap;
    last = now;
  });
  try {
    await work();
  } finally {
    watchdog.cancel();
  }
  return worst;
}

/// The two pieces of dictionary work heavy enough to freeze a phone, run
/// against the real shipped dictionary: the first-run unpack and the fuzzy
/// matching an arrival or an import can trigger. Both must leave the calling
/// isolate free; a frame is 16 ms and an ANR is five seconds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const Duration budget = Duration(milliseconds: 100);
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mull_off_main_');
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() => dir.delete(recursive: true));

  test('unpacking and matching against the shipped dictionary never stall the main isolate', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final DictionaryInstaller installer = DictionaryInstaller(prefs: prefs, directory: dir);

    late String path;
    final Duration installStall = await longestStall(() async {
      path = await installer.ensureInstalled();
    });
    expect(File(path).lengthSync(), greaterThan(50 << 20), reason: 'the real dictionary');
    expect(installStall, lessThan(budget), reason: 'install ran on the UI isolate');

    final DictionaryDb dict = DictionaryDb.open(path);
    addTearDown(dict.close);

    // None of these is a headword, but each is built from common English
    // trigrams, so every one falls through to the trigram query and makes it
    // score thousands of rows. A shared paragraph of names does exactly this.
    final List<({String word, String? definition})> junk = <({String word, String? definition})>[
      for (final String name in const <String>[
        'okonkwo', 'bassett', 'vrishabhanath', 'quenneville', 'thorsby',
        'krzyzanowski', 'oyelaran', 'nkemdirim', 'szczepanski', 'bhattacharyya',
        'featherstonehaugh', 'ravindranathan', 'wojciechowski', 'thistlewaite',
        'pemberton', 'ashworthington', 'cranleighs', 'montgomerie', 'stanislavsky',
        'winterbottoms', 'harringtons', 'brambledown', 'castleforde', 'lightermans',
      ])
        (word: name, definition: null),
    ];

    final Stopwatch synchronous = Stopwatch()..start();
    final List<WordMatch> expected = dict.batchMatchWords(junk);
    synchronous.stop();
    expect(
      synchronous.elapsed,
      greaterThan(const Duration(milliseconds: 100)),
      reason: 'the work is heavy enough for the test to mean something',
    );

    late List<WordMatch> matches;
    final Duration matchStall = await longestStall(() async {
      matches = await dict.matchWords(junk);
    });
    expect(matchStall, lessThan(budget), reason: 'matching ran on the UI isolate');
    expect(
      matches.map((WordMatch m) => (m.rawWord, m.word?.wordKey, m.isNearMatch)),
      expected.map((WordMatch m) => (m.rawWord, m.word?.wordKey, m.isNearMatch)),
      reason: 'the worker gives the same answer as the direct call',
    );

    // Search per keystroke and quiz generation go through the same worker.
    for (final String q in const <String>['mitigate', 'wistfl', 'zzzzqqq']) {
      final SearchResults async = await dict.searchAll(q);
      expect(
        async.words.map((DictionaryWord w) => w.wordKey),
        dict.search(q).map((DictionaryWord w) => w.wordKey),
        reason: 'searchAll("$q") differs from search()',
      );
      expect(
        async.suggestions.map((DictionaryWord w) => w.wordKey),
        async.words.isEmpty ? dict.suggestions(q).map((DictionaryWord w) => w.wordKey) : isEmpty,
      );
    }
    // The real worker, not the in-memory inline path, is what proves the
    // closure is sendable: one made inside an async method is not.
    final List<String> shelf = dict.collectionWordKeys(<String>['everyday']);
    final List<QuizQuestion> quiz = await dict.compute(
      QuizEngine.generator(shelf, seenKeys: const <String>{}, minimumWords: 10),
    );
    expect(quiz, isNotEmpty);
    await expectLater(
      dict.compute((DictionaryDb db) => throw StateError('boom')),
      throwsA(contains('boom')),
      reason: 'a failure in the worker surfaces to the caller',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
