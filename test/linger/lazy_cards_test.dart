import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/mix_repository.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/providers.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/features/linger/linger_rules.dart';
import 'package:mull/features/linger/linger_screen.dart';
import 'package:mull/features/linger/word_card.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

/// The Mull tab pages a finite queue, it does not lay out a pool. A
/// pre-constructed child list would build all two hundred cards on open
/// however the queue is batched, so the count is what proves the list is a
/// builder.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final ByteData font = ByteData.sublistView(
      File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync(),
    );
    await (FontLoader('Instrument Sans')..addFont(Future<ByteData>.value(font))).load();
  });

  testWidgets('only a handful of cards exist after opening and three swipes', (WidgetTester tester) async {
    final List<FakeWord> words = <FakeWord>[
      for (int i = 0; i < 200; i++)
        FakeWord(
          'wordnumber$i',
          'noun',
          'A definition, the ${i}th of its kind.',
          examples: <String>['An example sentence, number $i.'],
          synonyms: <String>['synonym$i'],
        ),
    ];
    final DictionaryDb dict = fakeDictionary(
      words: words,
      collections: <String, List<String>>{
        'core': <String>[for (final FakeWord w in words) w.key],
      },
      details: <String, (String, String, String)>{
        'core': ('band', 'Easy Words', 'The common core.'),
      },
    );
    addTearDown(dict.close);
    final UserDatabase userDb = UserDatabase.forTesting(NativeDatabase.memory());
    addTearDown(userDb.close);

    final MixRepository mixes = MixRepository(userDb);
    await mixes.ensurePresets(bandSlugs: <String>['core'], topicSlugs: const <String>[]);
    final List<MixSpec> all = await mixes.all();
    await mixes.setActive(all.first.id!);

    SharedPreferences.setMockInitialValues(<String, Object>{'onboarded': true});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            prefsProvider.overrideWithValue(prefs),
            userDatabaseProvider.overrideWithValue(userDb),
            dictProvider.overrideWithValue(dict),
          ],
          child: MaterialApp(
            theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
            home: const LingerScreen(),
          ),
        ),
      );

      int cards() =>
          tester.widgetList(find.byType(WordCard, skipOffstage: false)).length;
      Future<void> settle() async {
        for (int i = 0; i < 12; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      }

      await settle();
      expect(find.byType(WordCard), findsWidgets, reason: 'the first card is served');
      expect(
        cards(),
        lessThanOrEqualTo(3),
        reason: 'the pool is 200 words and the batch is $kQueueBatchSize, '
            'so anything beyond a handful means the list is not a builder',
      );

      // Three pages on. A pre-constructed child list would already hold
      // every card in the queue, however the queue itself is batched.
      final PageView pager = tester.widget<PageView>(find.byType(PageView));
      for (int swipe = 1; swipe <= 3; swipe++) {
        pager.controller!.jumpToPage(swipe);
        await settle();
        expect(
          cards(),
          lessThanOrEqualTo(3),
          reason: 'after $swipe pages the list is still a builder',
        );
      }

      await tester.pumpWidget(const SizedBox());
      await settle();
    });
  });
}
