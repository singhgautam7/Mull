import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/dictionary/arrival_sheet.dart';
import '../../features/dictionary/idiom_sheet.dart';
import '../../features/dictionary/word_sheet.dart';
import '../../features/settings/settings_controller.dart';
import '../database/dictionary_db.dart';
import '../theme/palette.dart';
import '../database/user_repository.dart';
import '../providers.dart';

/// The Android surfaces outside the app: the launcher widget's data, and
/// arrivals from the text-selection menu, the share sheet and a widget tap.
class PlatformSurfaces {
  static const MethodChannel _channel = MethodChannel(
    'com.grs.dictionary/platform',
  );

  @visibleForTesting
  static MethodChannel get channel => _channel;

  /// Takes the user to [route] in the app. Inside the app that is the
  /// router; inside the define sheet (no router) the platform opens the app
  /// on that route and finishes the sheet.
  static Future<void> go(BuildContext context, String route) async {
    if (GoRouter.maybeOf(context) case final GoRouter router) {
      router.go(route);
      return;
    }
    try {
      await _channel.invokeMethod<void>('openInApp', <String, String>{'route': route});
    } on MissingPluginException {
      // Tests and other hosts.
    }
  }

  /// Asks Android for permission to post notifications (a system dialog on
  /// Android 13 and later). True when notifications may be posted.
  static Future<bool> requestNotifications() async {
    try {
      return await _channel.invokeMethod<bool>('requestNotifications') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Arms or clears the daily word-of-the-day alarm from the saved setting.
  static Future<void> scheduleReminder() async {
    try {
      await _channel.invokeMethod<void>('scheduleReminder');
    } on MissingPluginException {
      // Tests and other hosts.
    }
  }

  /// Total RAM in MB and Android's low-RAM flag, for the Motion level's Auto.
  /// Null off Android (tests), which Auto treats as a normal phone.
  static Future<(int, bool)?> deviceMemory() async {
    try {
      final Map<Object?, Object?>? m = await _channel.invokeMapMethod<Object?, Object?>('deviceMemory');
      if (m == null) return null;
      return ((m['totalMb'] as int?) ?? 0, (m['lowRam'] as bool?) ?? false);
    } on MissingPluginException {
      return null;
    }
  }

  /// Android's API level (33 is Android 13), or null off Android.
  static Future<int?> sdkInt() async {
    try {
      return await _channel.invokeMethod<int>('sdkInt');
    } on MissingPluginException {
      return null;
    }
  }

  /// The installed version name (`1.0.0`), or null off Android.
  static Future<String?> appVersion() async {
    try {
      return await _channel.invokeMethod<String>('appVersion');
    } on MissingPluginException {
      return null;
    }
  }

  /// Hands [url] to the browser or Play. Mull has no network permission; the
  /// app that opens the link does the fetching.
  static Future<void> openUrl(String url) async {
    try {
      await _channel.invokeMethod<bool>('openUrl', <String, String>{'url': url});
    } on MissingPluginException {
      // Tests and other hosts.
    }
  }

  /// Ends the define sheet's activity, returning the user to the app the text
  /// came from.
  static Future<void> finish() async {
    try {
      await _channel.invokeMethod<void>('finish');
    } on MissingPluginException {
      // Tests and other hosts.
    }
  }

  /// Preference the widget reads (see WordOfDayWidget.kt). A 30-day schedule
  /// keyed by date, so the launcher stays right through days the app is not
  /// opened and through a reboot.
  static const String scheduleKey = 'widget.schedule';
  static const int scheduleDays = 30;

  /// Preference the search widget reads (see WidgetTheme.kt): the app's
  /// palette for both tones and which one applies, so the launcher can draw
  /// the widget in the user's theme without the app running.
  static const String themeKey = 'widget.theme';

  /// Writes the current theme for the widgets and asks for a redraw. Called
  /// on every change of family, mode, true black or dynamic colour.
  static Future<void> syncWidgetTheme({
    required AppSettings settings,
    required Color? seed,
    required SharedPreferences prefs,
  }) async {
    final ThemeFamily family = seed == null ? settings.family : ThemeFamily.fromSeed(seed);
    Map<String, int> roles(MullColors c) => <String, int>{
      'panel': c.surfaceContainer.toARGB32(),
      'field': c.surface.toARGB32(),
      'outline': c.outline.toARGB32(),
      'text': c.onSurface.toARGB32(),
      'muted': c.onSurfaceVariant.toARGB32(),
      'primary': c.primary.toARGB32(),
      'onPrimary': c.onPrimary.toARGB32(),
    };
    final Tone darkTone = settings.amoled && family.hasAmoled ? Tone.amoled : Tone.dark;
    await prefs.setString(
      themeKey,
      jsonEncode(<String, Object>{
        'mode': switch (settings.themeMode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
        'light': roles(family.colors(Tone.light)),
        'dark': roles(family.colors(darkTone)),
      }),
    );
    try {
      await _channel.invokeMethod<void>('refreshWidget');
    } on MissingPluginException {
      // Android only.
    }
  }

  static Future<void> syncWidgetSchedule({
    required DictionaryDb dict,
    required SharedPreferences prefs,
  }) async {
    // Thirty word-of-the-day picks (the first builds the pool, a DISTINCT
    // join over three shelves): on the worker, never in the frames right
    // after Home's first one.
    final List<Map<String, String>> schedule = await dict.compute(_scheduleWork(DateTime.now()));
    if (schedule.isEmpty) return;
    await prefs.setString(scheduleKey, jsonEncode(schedule));
    try {
      await _channel.invokeMethod<void>('refreshWidget');
    } on MissingPluginException {
      // Android only; tests and other hosts have no widget to redraw.
    }
  }

  /// Built synchronously, so the closure captures only [today] and is
  /// sendable to the dictionary's worker isolate.
  static List<Map<String, String>> Function(DictionaryDb) _scheduleWork(DateTime today) =>
      (DictionaryDb db) => <Map<String, String>>[
        for (int i = 0; i < scheduleDays; i++)
          if (db.wordOfTheDay(today.add(Duration(days: i))) case final DictionaryWord w)
            <String, String>{
              'date': today.add(Duration(days: i)).toIso8601String().substring(0, 10),
              'key': w.wordKey,
              'word': w.headword,
              'pos': w.pos,
              'ipa': w.ipa ?? '',
              'detail': w.definitionShort,
            },
      ];

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

  /// The one define entry point: opens the entry [text] names and says
  /// whether there was one. Exact and alias hits only, so an arrival never
  /// opens a near miss. [fromDefinition] (the menu on a definition's text)
  /// also takes a phrase entry and a lemma ("angered" opens "anger"); never
  /// the trigram fuzzy step. Records the lookup for a word.
  static Future<bool> defineText(
    BuildContext context,
    WidgetRef ref,
    String text, {
    bool fromOutside = false,
    String? sourceHint,
    bool fromDefinition = false,
  }) async {
    final ({DictionaryWord? word, Idiom? idiom}) hit = ref
        .read(dictProvider)
        .resolveSelection(text, phrases: fromDefinition, lemma: fromDefinition);
    if (hit.word case final DictionaryWord w) {
      await ref.read(userRepositoryProvider).recordLookup(w.wordKey);
      if (context.mounted) {
        await showWordSheet(
          context,
          wordKey: w.wordKey,
          fromOutside: fromOutside,
          sourceHint: sourceHint,
        );
      }
      return true;
    }
    if (hit.idiom case final Idiom i) {
      if (context.mounted) await showIdiomSheet(context, idiom: i);
      return true;
    }
    return false;
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

    // The whole selection first: one word, or a phrase Mull has as a
    // headword ("Command Line" is `command-line`). An exact or alias hit
    // opens the entry; a near miss is offered, never opened.
    if (await defineText(
      context,
      ref,
      text,
      fromOutside: true,
      sourceHint: sourceHint,
    )) {
      return;
    }
    if (tokens.length <= 1) {
      // A single selection carries no sentence, so none is invented.
      final List<DictionaryWord> near = await dict.compute(
        _suggestionsFor(text),
      );
      if (context.mounted) {
        await showUnknownWordSheet(
          context,
          text: text,
          suggestions: near,
          sourceHint: sourceHint,
        );
      }
      return;
    }

    // Worth offering: the curated set, plus rarer-band words the sentence
    // spells exactly. That drops articles and the like, which Mull also has
    // entries for, and alias quirks such as `Mr` resolving to `millirem`.
    final List<WordMatch> matched = await dict.matchWords(
      <({String word, String? definition})>[
        for (final String w in tokens.toSet()) (word: w, definition: null),
      ],
    );
    List<WordMatch> known = matched
        .where(
          (WordMatch m) =>
              m.isMatched &&
              (m.word!.inLearningSet ||
                  (m.word!.isUncommon &&
                      m.word!.headwordNorm == DictionaryDb.normalise(m.rawWord))),
        )
        .toList();
    // When nothing in the selection stands out, every word Mull spells the
    // same way is still an answer: "command line" is two entries, not none.
    final bool everyday = known.isEmpty;
    if (everyday) {
      known = matched
          .where(
            (WordMatch m) =>
                m.isMatched &&
                m.word!.headwordNorm == DictionaryDb.normalise(m.rawWord),
          )
          .toList();
    }
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
        everyday: everyday,
        sourceHint: sourceHint,
      );
    }
  }

  /// `DictionaryDb.suggestions` for the worker, made here (not inside the
  /// async handler) so the closure carries only the text.
  static List<DictionaryWord> Function(DictionaryDb) _suggestionsFor(String text) =>
      (DictionaryDb db) => db.suggestions(text);

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
