import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/linger/queue_builder.dart';
import 'database/dictionary_db.dart';
import 'database/dictionary_installer.dart';
import 'database/mix_repository.dart';
import 'database/user_db.dart';
import 'database/user_repository.dart';

/// Overridden in `main` with the instances created during bootstrap.
final Provider<UserDatabase> userDatabaseProvider = Provider<UserDatabase>(
  (Ref ref) => throw UnimplementedError('userDatabaseProvider must be overridden'),
);

final Provider<DictionaryInstaller> installerProvider = Provider<DictionaryInstaller>(
  (Ref ref) => throw UnimplementedError('installerProvider must be overridden'),
);

final Provider<UserRepository> userRepositoryProvider = Provider<UserRepository>(
  (Ref ref) => UserRepository(ref.watch(userDatabaseProvider)),
);

final Provider<MixRepository> mixRepositoryProvider = Provider<MixRepository>(
  (Ref ref) => MixRepository(ref.watch(userDatabaseProvider)),
);

/// Installs the shipped dictionary if this build carries a newer one, opens
/// it read-only, and makes sure the four preset mixes and the two system
/// collections exist. Loading while this runs is the first-run install state.
final FutureProvider<DictionaryDb> dictionaryProvider = FutureProvider<DictionaryDb>((Ref ref) async {
  final String path = await ref.watch(installerProvider).ensureInstalled();
  final DictionaryDb dict = DictionaryDb.open(path);
  ref.onDispose(dict.close);
  final List<Collection> collections = dict.collections();
  await ref.read(mixRepositoryProvider).ensurePresets(
    bandSlugs: <String>[for (final Collection c in collections) if (c.kind == 'band') c.slug],
    topicSlugs: <String>[for (final Collection c in collections) if (c.kind == 'topic') c.slug],
  );
  await ref.read(userRepositoryProvider).ensureSystemCollections();
  return dict;
});

/// The open dictionary. Only read below the install gate.
final Provider<DictionaryDb> dictProvider = Provider<DictionaryDb>(
  (Ref ref) => ref.watch(dictionaryProvider).requireValue,
);

final Provider<QueueBuilder> queueBuilderProvider = Provider<QueueBuilder>(
  (Ref ref) => QueueBuilder(ref.watch(dictProvider), ref.watch(userRepositoryProvider)),
);

/// The user's own collections (system and user kinds) and their word keys,
/// live from the user database.
final StreamProvider<List<UserCollection>> userCollectionsProvider = StreamProvider<List<UserCollection>>(
  (Ref ref) => ref.watch(userRepositoryProvider).watchCollections(),
);

final StreamProvider<Map<String, List<String>>> userCollectionKeysProvider =
    StreamProvider<Map<String, List<String>>>(
      (Ref ref) => ref.watch(userRepositoryProvider).watchCollectionWordKeys(),
    );

/// Every collection, both databases, in sort order: bands, topics, idioms,
/// then the user's own. The one read every screen and the mix sheet use.
final Provider<List<Collection>> collectionsProvider = Provider<List<Collection>>((Ref ref) {
  final List<Collection> builtIn = ref.watch(dictProvider).collections();
  final List<UserCollection> own = ref.watch(userCollectionsProvider).value ?? const <UserCollection>[];
  final Map<String, List<String>> keys = ref.watch(userCollectionKeysProvider).value ?? const <String, List<String>>{};
  final int base = builtIn.isEmpty ? 0 : builtIn.last.sortOrder + 1;
  return <Collection>[
    ...builtIn,
    for (final (int i, UserCollection c) in own.indexed)
      Collection(
        id: c.id,
        slug: c.slug,
        title: c.name,
        description: switch (c.slug) {
          UserRepository.bookmarksSlug => 'Words you kept.',
          UserRepository.readingSlug => 'Added from search.',
          _ => 'Your own words.',
        },
        kind: c.kind,
        band: null,
        icon: null,
        sortOrder: base + i,
        wordCount: keys[c.slug]?.length ?? 0,
        color: c.color,
      ),
  ];
});

/// The collections a mix can draw from: everything but idioms and pairs.
final Provider<List<Collection>> mixSourceCollectionsProvider = Provider<List<Collection>>(
  (Ref ref) => ref.watch(collectionsProvider).where((Collection c) => c.isMixable).toList(),
);

final Provider<Map<String, Collection>> collectionBySlugProvider =
    Provider<Map<String, Collection>>(
      (Ref ref) => <String, Collection>{
        for (final Collection c in ref.watch(collectionsProvider)) c.slug: c,
      },
    );

/// Word keys per collection slug: the dictionary's read once, the user's
/// live. Progress is this against seen.
final Provider<Map<String, List<String>>> collectionKeysProvider = Provider<Map<String, List<String>>>((Ref ref) {
  final DictionaryDb dict = ref.watch(dictProvider);
  return <String, List<String>>{
    for (final Collection c in dict.collections()) c.slug: dict.collectionWordKeys(<String>[c.slug]),
    ...ref.watch(userCollectionKeysProvider).value ?? const <String, List<String>>{},
  };
});

/// The slug of the collection opened most recently, for Home's shortlist.
final StreamProvider<String?> lastOpenedCollectionProvider = StreamProvider<String?>(
  (Ref ref) => ref.watch(userRepositoryProvider).watchAppState(UserRepository.kLastOpened),
);

/// Home's shortlist: last opened, then in progress, then a couple of
/// built-ins, five in all.
final Provider<List<Collection>> homeCollectionsProvider = Provider<List<Collection>>((Ref ref) {
  final List<Collection> all = ref.watch(collectionsProvider);
  final Map<String, Progress> progress = ref.watch(collectionProgressProvider);
  final String? last = ref.watch(lastOpenedCollectionProvider).value;
  Progress of(Collection c) => progress[c.slug] ?? const Progress(0, 0);
  final List<Collection> out = <Collection>[
    ...all.where((Collection c) => c.slug == last),
    ...all.where((Collection c) => of(c).started && !of(c).complete),
    ...all.where((Collection c) => c.kind == 'topic' || c.kind == 'band'),
  ];
  final Set<String> seen = <String>{};
  return out.where((Collection c) => seen.add(c.slug)).take(5).toList();
});

final StreamProvider<Map<String, SeenWord>> seenMapProvider = StreamProvider<Map<String, SeenWord>>(
  (Ref ref) => ref.watch(userRepositoryProvider).watchAllSeen(),
);

final StreamProvider<Set<String>> bookmarksProvider = StreamProvider<Set<String>>(
  (Ref ref) => ref.watch(userRepositoryProvider).watchBookmarkedKeys(),
);

@immutable
class Progress {
  const Progress(this.seen, this.total);

  final int seen;
  final int total;

  double get fraction => total == 0 ? 0 : seen / total;
  bool get started => seen > 0;
  bool get complete => total > 0 && seen >= total;
}

/// Seen count per collection, live.
final Provider<Map<String, Progress>> collectionProgressProvider = Provider<Map<String, Progress>>((Ref ref) {
  final Map<String, List<String>> keys = ref.watch(collectionKeysProvider);
  final Map<String, SeenWord> seen = ref.watch(seenMapProvider).value ?? const <String, SeenWord>{};
  return <String, Progress>{
    for (final MapEntry<String, List<String>> e in keys.entries)
      e.key: Progress(e.value.where(seen.containsKey).length, e.value.length),
  };
});

/// One word a day, the same for everyone on the same day: picked from the
/// banded words by the day number, so it never needs storing.
final Provider<DictionaryWord?> wordOfTheDayProvider = Provider<DictionaryWord?>((Ref ref) {
  final DictionaryDb dict = ref.watch(dictProvider);
  final List<String> keys = dict.collectionWordKeys(<String>['everyday', 'well_read', 'uncommon']);
  if (keys.isEmpty) return null;
  final int day = DateTime.now().difference(DateTime(2026)).inDays;
  // A stride coprime with most sizes, so consecutive days are not neighbours.
  return dict.byKey(keys[(day * 7919) % keys.length]);
});

final StreamProvider<List<String>> recentLookupsProvider = StreamProvider<List<String>>(
  (Ref ref) => ref.watch(userRepositoryProvider).watchRecentLookups(),
);

/// Every mix, presets first, resolved. Re-read whenever the mixes table
/// changes.
final StreamProvider<List<MixSpec>> mixesProvider = StreamProvider<List<MixSpec>>((Ref ref) {
  final MixRepository repo = ref.watch(mixRepositoryProvider);
  return repo.watchMixRows().asyncMap((_) => repo.all());
});
