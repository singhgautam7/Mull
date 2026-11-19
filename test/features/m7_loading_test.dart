import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/mix_repository.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/database/user_repository.dart';
import 'package:mull/core/theme/tokens.dart';
import 'package:mull/core/motion/motion.dart' show SkeletonCrossFade;
import 'package:mull/core/providers.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/features/collections/collection_cards.dart';
import 'package:mull/features/collections/collections_screen.dart';
import 'package:mull/features/linger/linger_screen.dart';
import 'package:mull/features/linger/linger_rules.dart';
import 'package:mull/features/linger/queue_builder.dart';
import 'package:mull/features/linger/word_card.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:mull/shared/widgets/states.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/fake_dictionary.dart';

/// M7. A loader that flashes is worse than none: a fast load draws no
/// skeleton at all, a slow one (past `Delayed.threshold`) draws one and
/// cross-fades it into the content.
class _GatedQueue extends QueueBuilder {
  _GatedQueue(super.dict, super.user, this.gate);

  final Completer<void> gate;

  @override
  Future<List<String>> build(
    MixSpec mix, {
    int size = kQueueBatchSize,
    Set<String> exclude = const <String>{},
    DateTime? now,
    Random? random,
  }) async {
    await gate.future;
    return super.build(mix, size: size, exclude: exclude, now: now, random: random);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final ByteData font = ByteData.sublistView(
      File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync(),
    );
    await (FontLoader('Instrument Sans')..addFont(Future<ByteData>.value(font))).load();
  });

  group('Shelves tab', () {
    late SharedPreferences prefs;
    late DictionaryDb dict;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{'onboarded': true});
      prefs = await SharedPreferences.getInstance();
      final List<FakeWord> words = <FakeWord>[
        for (int i = 0; i < 12; i++) FakeWord('shelfword$i', 'noun', 'A definition number $i.'),
      ];
      dict = fakeDictionary(
        words: words,
        collections: <String, List<String>>{
          'core': <String>[for (final FakeWord w in words) w.key],
          for (int t = 0; t < 4; t++) 'topic$t': <String>[for (final FakeWord w in words.take(3 + t)) w.key],
        },
        details: <String, (String, String, String)>{
          'core': ('band', 'Easy Words', 'Common.'),
          for (int t = 0; t < 4; t++) 'topic$t': ('topic', 'Topic $t', 'About topic $t.'),
        },
      );
      addTearDown(dict.close);
    });

    Future<void> open(WidgetTester tester, Future<Map<String, List<String>>> keys) => tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          prefsProvider.overrideWithValue(prefs),
          dictProvider.overrideWithValue(dict),
          userCollectionsProvider.overrideWith((Ref ref) => Stream<List<UserCollection>>.value(const <UserCollection>[])),
          userCollectionKeysProvider.overrideWith((Ref ref) => Stream<Map<String, List<String>>>.value(const <String, List<String>>{})),
          seenMapProvider.overrideWith((Ref ref) => Stream<Map<String, SeenWord>>.value(const <String, SeenWord>{})),
          dictionaryCollectionKeysProvider.overrideWith((Ref ref) => keys),
        ],
        child: MaterialApp(
          theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
          home: const CollectionsScreen(),
        ),
      ),
    );

    testWidgets('a fast load never draws a skeleton', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 880);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await open(tester, Future<Map<String, List<String>>>.value(<String, List<String>>{}));
      for (final int ms in <int>[0, 16, 60, 200, 400, 600]) {
        await tester.pump(Duration(milliseconds: ms));
        expect(find.byType(SkeletonCard), findsNothing, reason: 'after $ms ms');
        expect(find.byType(SkeletonRow), findsNothing, reason: 'after $ms ms');
      }
      expect(find.byType(TopicCard), findsWidgets);
    });

    testWidgets('a slow load draws skeletons after the threshold and cross-fades to the cards', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 880);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final Completer<Map<String, List<String>>> gate = Completer<Map<String, List<String>>>();
      await open(tester, gate.future);
      await tester.pump(Delayed.threshold - const Duration(milliseconds: 100));
      expect(find.byType(SkeletonCard), findsNothing, reason: 'under the threshold');
      expect(find.byType(SkeletonRow), findsNothing);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.byType(SkeletonCard), findsWidgets, reason: 'past the threshold');
      expect(find.byType(SkeletonRow), findsWidgets);

      gate.complete(<String, List<String>>{
        'core': <String>['shelfword0|noun|1'],
      });
      await tester.pump();
      await tester.pump(Motion.fxDefault ~/ 2);
      expect(find.byType(SkeletonCard), findsWidgets, reason: 'mid cross-fade the skeleton is still leaving');
      expect(find.byType(TopicCard), findsWidgets, reason: 'and the cards are arriving');

      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(SkeletonCard), findsNothing, reason: 'the skeleton is gone once faded');
      expect(find.byType(SkeletonRow), findsNothing);
      expect(find.byType(TopicCard), findsWidgets);
    });
  });

  group('Mull tab', () {
    late DictionaryDb dict;
    late UserDatabase userDb;
    late SharedPreferences prefs;

    setUp(() async {
      final List<FakeWord> words = <FakeWord>[
        for (int i = 0; i < 40; i++)
          FakeWord('mulltabword$i', 'noun', 'A definition, number $i.', examples: <String>['Example $i.']),
      ];
      dict = fakeDictionary(
        words: words,
        collections: <String, List<String>>{
          'core': <String>[for (final FakeWord w in words) w.key],
        },
        details: <String, (String, String, String)>{'core': ('band', 'Easy Words', 'The common core.')},
      );
      userDb = UserDatabase.forTesting(NativeDatabase.memory());
      final MixRepository mixes = MixRepository(userDb);
      await mixes.ensurePresets(bandSlugs: <String>['core'], topicSlugs: const <String>[]);
      await mixes.setActive((await mixes.all()).first.id!);
      SharedPreferences.setMockInitialValues(<String, Object>{'onboarded': true});
      prefs = await SharedPreferences.getInstance();
      addTearDown(() async {
        dict.close();
        await userDb.close();
      });
    });

    Future<void> open(WidgetTester tester, Completer<void> gate) => tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          prefsProvider.overrideWithValue(prefs),
          userDatabaseProvider.overrideWithValue(userDb),
          dictProvider.overrideWithValue(dict),
          queueBuilderProvider.overrideWith((Ref ref) => _GatedQueue(dict, UserRepository(userDb), gate)),
        ],
        child: MaterialApp(
          theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
          home: const LingerScreen(),
        ),
      ),
    );

    Future<void> real(WidgetTester tester, int ms) async {
      await Future<void>.delayed(Duration(milliseconds: ms));
      await tester.pump();
    }

    testWidgets('a fast first card draws no skeleton', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 880);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await open(tester, Completer<void>()..complete());
        for (int i = 0; i < 20; i++) {
          await real(tester, 20);
          expect(find.byType(SkeletonWordCard), findsNothing, reason: 'step $i');
        }
        expect(find.byType(WordCard), findsWidgets);
        await tester.pumpWidget(const SizedBox());
      });
    });

    testWidgets('a slow first card draws the skeleton after the threshold, then fades to the card', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 880);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final Completer<void> gate = Completer<void>();
      await tester.runAsync(() async {
        await open(tester, gate);
        await real(tester, 100);
        expect(find.byType(SkeletonWordCard), findsNothing, reason: 'under the threshold');
        expect(find.byType(WordCard), findsNothing);

        await real(tester, 300);
        await tester.pump();
        expect(find.byType(SkeletonWordCard), findsOneWidget, reason: 'past the threshold');
        expect(find.byType(SkeletonCrossFade), findsOneWidget);

        gate.complete();
        for (int i = 0; i < 25; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.byType(SkeletonWordCard), findsNothing, reason: 'faded out');
        expect(find.byType(WordCard), findsWidgets);
        await tester.pumpWidget(const SizedBox());
      });
    });
  });
}
