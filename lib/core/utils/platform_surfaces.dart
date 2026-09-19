import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/dictionary/arrival_sheet.dart';
import '../../features/dictionary/word_sheet.dart';
import '../database/dictionary_db.dart';
import '../database/user_repository.dart';
import '../providers.dart';

/// The Android surfaces outside the app: the launcher widget's data, and
/// arrivals from the text-selection menu, the share sheet and a widget tap.
class PlatformSurfaces {
  static const MethodChannel _channel = MethodChannel(
    'com.grs.dictionary/platform',
  );

  /// Preference the widget reads (see WordOfDayWidget.kt). A 30-day schedule
  /// keyed by date, so the launcher stays right through days the app is not
  /// opened and through a reboot.
  static const String scheduleKey = 'widget.schedule';
  static const int scheduleDays = 30;

  static Future<void> syncWidgetSchedule({
    required DictionaryDb dict,
    required SharedPreferences prefs,
  }) async {
    final DateTime today = DateTime.now();
    final List<Map<String, String>> schedule = <Map<String, String>>[
      for (int i = 0; i < scheduleDays; i++)
        if (dict.wordOfTheDay(today.add(Duration(days: i))) case final DictionaryWord w)
          <String, String>{
            'date': today
                .add(Duration(days: i))
                .toIso8601String()
                .substring(0, 10),
            'key': w.wordKey,
            'word': w.headword,
            'pos': w.pos,
            'ipa': w.ipa ?? '',
            'detail': w.definitionShort,
          },
    ];
    if (schedule.isEmpty) return;
    await prefs.setString(scheduleKey, jsonEncode(schedule));
    try {
      await _channel.invokeMethod<void>('refreshWidget');
    } on MissingPluginException {
      // Android only; tests and other hosts have no widget to redraw.
    }
  }

  /// Arrivals while the app is open are pushed by the activity.
  static void listenForArrivals(void Function(Map<Object?, Object?> data) onArrival) {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onIntentReceived' && call.arguments is Map<Object?, Object?>) {
        onArrival(call.arguments as Map<Object?, Object?>);
      }
    });
  }

  /// The launch arrival, if any, cleared on read. Null everywhere but Android.
  static Future<Map<Object?, Object?>?> incomingText() async {
    try {
      return await _channel.invokeMapMethod<Object?, Object?>('incomingText');
    } on MissingPluginException {
      return null;
    }
  }

  /// HANDOFF 21.2 and 21.3. One word opens its sheet. Longer text keeps the
  /// sentence as context: when exactly one uncommon word is in it that word
  /// opens directly, otherwise the user picks from what Mull knows.
  static Future<void> handleIncomingIntent({
    required BuildContext context,
    required WidgetRef ref,
    required Map<Object?, Object?> data,
  }) async {
    final String? sourceHint = data['sourceHint'] as String?;
    final DictionaryDb dict = ref.read(dictProvider);
    final UserRepository user = ref.read(userRepositoryProvider);

    final String? wordKey = data['wordKey'] as String?;
    if (wordKey != null && dict.byKey(wordKey) != null) {
      await user.recordLookup(wordKey);
      if (context.mounted) await showWordSheet(context, wordKey: wordKey);
      return;
    }

    final String text = (data['text'] as String? ?? '').trim();
    if (text.isEmpty) return;
    final List<String> tokens = words(text);

    if (tokens.length <= 1) {
      // A single selection carries no sentence, so none is invented.
      final WordMatch match = (await dict.matchWords(
        <({String word, String? definition})>[(word: text, definition: null)],
      )).single;
      if (match.isMatched) {
        await user.recordLookup(match.word!.wordKey);
        if (context.mounted) {
          await showWordSheet(
            context,
            wordKey: match.word!.wordKey,
            fromOutside: true,
            sourceHint: sourceHint,
          );
        }
      } else if (context.mounted) {
        await showUnknownWordSheet(
          context,
          text: text,
          nearMatch: match.word,
          sourceHint: sourceHint,
        );
      }
      return;
    }

    // Worth offering: the curated set, plus rarer-band words the sentence
    // spells exactly. That drops articles and the like, which Mull also has
    // entries for, and alias quirks such as `Mr` resolving to `millirem`.
    final List<WordMatch> known = (await dict.matchWords(
      <({String word, String? definition})>[
        for (final String w in tokens.toSet()) (word: w, definition: null),
      ],
    )).where(
          (WordMatch m) =>
              m.isMatched &&
              (m.word!.inLearningSet ||
                  (m.word!.isUncommon &&
                      m.word!.headwordNorm == DictionaryDb.normalise(m.rawWord))),
        )
        .toList();
    final List<WordMatch> uncommon = known
        .where((WordMatch m) => m.word!.isUncommon)
        .toList();

    if (uncommon.length == 1) {
      final DictionaryWord word = uncommon.single.word!;
      await user.recordLookup(word.wordKey);
      await user.addContext(
        word.wordKey,
        sentenceAround(text, uncommon.single.rawWord),
        sourceHint: sourceHint,
      );
      if (context.mounted) {
        await showWordSheet(
          context,
          wordKey: word.wordKey,
          fromOutside: true,
          sourceHint: sourceHint,
        );
      }
      return;
    }
    if (context.mounted) {
      await showMultipleWordsArrivalSheet(
        context,
        text: text,
        matches: known,
        sourceHint: sourceHint,
      );
    }
  }

  /// The alphabetic words of [text], apostrophes kept, in order.
  @visibleForTesting
  static List<String> words(String text) => RegExp(r"[\p{L}][\p{L}'’-]*", unicode: true)
      .allMatches(text)
      .map((RegExpMatch m) => m.group(0)!)
      .toList();

  /// The sentence of [text] that contains [word], trimmed to at most
  /// [maxLength] characters around it at a word boundary.
  static String sentenceAround(String text, String word, {int maxLength = 240}) {
    final String flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final RegExp target = RegExp(
      '\\b${RegExp.escape(word)}\\b',
      caseSensitive: false,
    );
    final int at = target.firstMatch(flat)?.start ?? 0;
    // Sentence bounds: the previous and next terminator around the word.
    final RegExp terminator = RegExp(r'(?<=[.!?])\s+');
    int start = 0;
    int end = flat.length;
    for (final RegExpMatch m in terminator.allMatches(flat)) {
      if (m.end <= at) start = m.end;
      if (m.start >= at + word.length) {
        end = m.start;
        break;
      }
    }
    String sentence = flat.substring(start, end).trim();
    if (sentence.length > maxLength) {
      // Keep the word inside the window, cut on spaces, mark the cuts.
      final int wordAt = target.firstMatch(sentence)?.start ?? 0;
      int from = (wordAt - maxLength ~/ 2).clamp(0, sentence.length);
      int to = (from + maxLength).clamp(0, sentence.length);
      if (from > 0) from = sentence.indexOf(' ', from) + 1;
      if (to < sentence.length) to = sentence.lastIndexOf(' ', to);
      sentence =
          '${from > 0 ? '… ' : ''}${sentence.substring(from, to).trim()}${to < sentence.length ? ' …' : ''}';
    }
    return sentence;
  }
}
