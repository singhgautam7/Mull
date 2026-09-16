import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/mix_repository.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/database/user_repository.dart';
import 'package:mull/core/providers.dart';
import 'package:mull/features/linger/linger_rules.dart';
import 'package:mull/features/linger/queue_builder.dart';

import 'fake_dictionary.dart';

/// Everything is a collection. A list the user creates is read through the
/// same query as the built-in bands and topics, so it appears on the
/// Collections page, on Home, and as a mix source, at once.
void main() {
  const FakeWord abate = FakeWord('abate', 'verb', 'To lessen in force or intensity.');
  const FakeWord colour = FakeWord('colour', 'noun', 'The spectral composition of light.');
  const FakeWord dither = FakeWord('dither', 'verb', 'To be indecisive.');

  late DictionaryDb dict;
  late UserDatabase userDb;
  late ProviderContainer container;

  setUp(() {
    dict = fakeDictionary(
      words: <FakeWord>[abate, colour, dither],
      collections: <String, List<String>>{
        'everyday': <String>[abate.key, colour.key],
      },
    );
    userDb = UserDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: <Override>[
        userDatabaseProvider.overrideWithValue(userDb),
        dictProvider.overrideWithValue(dict),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await userDb.close();
    dict.close();
  });

  /// Waits for the user database's streams to deliver.
  Future<void> until(bool Function() ready) async {
    for (int i = 0; i < 200 && !ready(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(ready(), isTrue);
  }

  test('a created list appears in Collections, on Home, and as a mix source', () async {
    container.listen(collectionsProvider, (_, _) {});
    container.listen(homeCollectionsProvider, (_, _) {});
    container.listen(mixSourceCollectionsProvider, (_, _) {});
    final UserRepository user = container.read(userRepositoryProvider);
    await user.ensureSystemCollections();

    final String slug = await user.createCollection('Viva words', color: 2);
    await user.addToCollection(slug, dither.key);
    await user.setAppState(UserRepository.kLastOpened, slug);

    List<Collection> all() => container.read(collectionsProvider);
    await until(() => all().any((Collection c) => c.slug == slug && c.wordCount == 1));

    final Collection mine = all().singleWhere((Collection c) => c.slug == slug);
    expect(mine.kind, 'user');
    expect(mine.title, 'Viva words');
    expect(mine.color, 2);
    expect(mine.isUsers, isTrue);
    // Built-ins first, then the system rows, then the user's own.
    expect(all().map((Collection c) => c.slug), <String>['everyday', 'bookmarks', 'reading', slug]);

    // Home: last opened comes first.
    await until(() => container.read(homeCollectionsProvider).firstOrNull?.slug == slug);

    // The mix sheet offers it, and a mix drawn from it plays its words.
    expect(container.read(mixSourceCollectionsProvider).map((Collection c) => c.slug), contains(slug));
    final QueueBuilder builder = QueueBuilder(dict, user);
    final MixSpec mix = MixSpec(id: null, name: 'Mine', isPreset: false, sources: <String>['everyday', slug], seenPolicy: SeenPolicy.unseenOnly);
    expect((await builder.pool(mix)).toSet(), <String>{abate.key, colour.key, dither.key});
    expect(await builder.build(MixSpec.scoped(slug, SeenPolicy.unseenOnly)), <String>[dither.key]);
  });

  test('bookmarks are the system collection and cannot be deleted', () async {
    final UserRepository user = container.read(userRepositoryProvider);
    await user.toggleBookmark(abate.key);
    expect(await user.collectionWordKeys(UserRepository.bookmarksSlug), <String>[abate.key]);
    expect(await user.isBookmarked(abate.key), isTrue);

    await user.deleteCollection(UserRepository.bookmarksSlug);
    expect((await user.collections()).map((UserCollection c) => c.slug), contains(UserRepository.bookmarksSlug));
    expect(await user.bookmarkedKeys(), <String>[abate.key]);

    final String slug = await user.createCollection('Gone soon');
    await user.deleteCollection(slug);
    expect((await user.collections()).map((UserCollection c) => c.slug), isNot(contains(slug)));
  });
}
