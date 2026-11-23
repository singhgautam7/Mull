import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/linger/queue_builder.dart';
import '../features/settings/settings_controller.dart';
import 'database/data_transfer_repository.dart';
import 'database/dictionary_db.dart';
import 'database/dictionary_installer.dart';
import 'database/mix_repository.dart';
import 'database/user_db.dart';
import 'database/user_repository.dart';

/// Overridden in `main` with the instances created during bootstrap.
final Provider<UserDatabase> userDatabaseProvider = Provider<UserDatabase>(
  (Ref ref) =>
      throw UnimplementedError('userDatabaseProvider must be overridden'),
);

final Provider<DictionaryInstaller> installerProvider =
    Provider<DictionaryInstaller>(
      (Ref ref) =>
          throw UnimplementedError('installerProvider must be overridden'),
    );

final Provider<UserRepository> userRepositoryProvider =
    Provider<UserRepository>(
      (Ref ref) => UserRepository(ref.watch(userDatabaseProvider)),
    );

final Provider<MixRepository> mixRepositoryProvider = Provider<MixRepository>(
  (Ref ref) => MixRepository(ref.watch(userDatabaseProvider)),
);

/// Installs the shipped dictionary if this build carries a newer one, opens
/// it read-only, and makes sure the four preset mixes and the two system
/// collections exist. Loading while this runs is the first-run install state.
final FutureProvider<DictionaryDb> dictionaryProvider =
    FutureProvider<DictionaryDb>((Ref ref) async {
      final String path = await ref.watch(installerProvider).ensureInstalled();
      final DictionaryDb dict = DictionaryDb.open(path);
      ref.onDispose(dict.close);
      final List<Collection> collections = dict.collections();
      await ref
          .read(mixRepositoryProvider)
          .ensurePresets(
            bandSlugs: <String>[
              for (final Collection c in collections)
                if (c.kind == 'band') c.slug,
            ],
            topicSlugs: <String>[
              for (final Collection c in collections)
                if (c.kind == 'topic') c.slug,
            ],
          );
      await ref.read(userRepositoryProvider).ensureSystemCollections();
      return dict;
    });

/// The open dictionary. Only read below the install gate.
final Provider<DictionaryDb> dictProvider = Provider<DictionaryDb>(
  (Ref ref) => ref.watch(dictionaryProvider).requireValue,
);

final Provider<DataTransferRepository> dataTransferRepositoryProvider =
    Provider<DataTransferRepository>(
      (Ref ref) => DataTransferRepository(
        ref.watch(userDatabaseProvider),
        ref.watch(dictProvider),
        ref.watch(prefsProvider),
      ),
    );

final Provider<QueueBuilder> queueBuilderProvider = Provider<QueueBuilder>(
  (Ref ref) =>
      QueueBuilder(ref.watch(dictProvider), ref.watch(userRepositoryProvider)),
);

/// The user's own collections (system and user kinds) and their word keys,
/// live from the user database.
final StreamProvider<List<UserCollection>> userCollectionsProvider =
    StreamProvider<List<UserCollection>>(
      (Ref ref) => ref.watch(userRepositoryProvider).watchCollections(),
    );

final StreamProvider<Map<String, List<String>>> userCollectionKeysProvider =
    StreamProvider<Map<String, List<String>>>(
      (Ref ref) => ref.watch(userRepositoryProvider).watchCollectionWordKeys(),
    );

/// Every collection, both databases, in sort order: bands, topics, idioms,
/// then the user's own. The one read every screen and the mix sheet use.
final Provider<List<Collection>> collectionsProvider =
    Provider<List<Collection>>((Ref ref) {
      final List<Collection> builtIn = ref.watch(dictProvider).collections();
      final List<UserCollection> own =
          ref.watch(userCollectionsProvider).value ?? const <UserCollection>[];
      final Map<String, List<String>> keys = ref.watch(collectionKeysProvider);
      final int base = builtIn.isEmpty ? 0 : builtIn.last.sortOrder + 1;
      return <Collection>[
        for (final Collection c in builtIn)
          Collection(
            id: c.id,
            slug: c.slug,
            title: c.title,
            description: c.description,
            kind: c.kind,
            band: c.band,
            icon: c.icon,
            sortOrder: c.sortOrder,
            wordCount: keys[c.slug]?.length ?? c.wordCount,
            color: c.color,
          ),
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
            icon: c.icon,
            note: c.note,
            sortOrder: base + i,
            wordCount: keys[c.slug]?.length ?? 0,
            color: c.color,
          ),
      ];
    });

/// The collections a mix can draw from: everything but idioms and pairs.
final Provider<List<Collection>> mixSourceCollectionsProvider =
    Provider<List<Collection>>(
      (Ref ref) => ref
          .watch(collectionsProvider)
          .where((Collection c) => c.isMixable)
          .toList(),
    );

final Provider<Map<String, Collection>> collectionBySlugProvider =
    Provider<Map<String, Collection>>(
      (Ref ref) => <String, Collection>{
        for (final Collection c in ref.watch(collectionsProvider)) c.slug: c,
      },
    );

/// Every dictionary collection's word keys, read on the worker isolate.
///
/// 8,084 strings over 27 collections: 22 ms of synchronous sqlite and Dart
/// that used to land in whichever screen watched it first, which was Home's
/// or the Shelves tab's first `build()`. It does not depend on user data, so
/// it is read once per open dictionary and never again.
final FutureProvider<Map<String, List<String>>> dictionaryCollectionKeysProvider =
    FutureProvider<Map<String, List<String>>>(
      (Ref ref) => ref.watch(dictProvider).collectionKeysBySlug(),
    );

/// Word keys per collection slug: the dictionary's read once on the worker,
/// the user's live. Progress is this against seen.
///
/// Empty for the frame or two before the worker answers. Every reader either
/// falls back (a collection keeps the dictionary's own `wordCount`, progress
/// reads 0 / 0) or shows the placeholders that
/// [collectionKeysSettlingProvider] gates, so nothing here blocks a frame.
final Provider<Map<String, List<String>>> collectionKeysProvider =
    Provider<Map<String, List<String>>>((Ref ref) {
      final Map<String, List<String>> builtInKeys =
          ref.watch(dictionaryCollectionKeysProvider).value ??
          const <String, List<String>>{};
      final Map<String, List<String>> userKeys =
          ref.watch(userCollectionKeysProvider).value ??
          const <String, List<String>>{};
      final Map<String, List<String>> result = <String, List<String>>{};
      for (final MapEntry<String, List<String>> e in builtInKeys.entries) {
        final List<String>? extra = userKeys[e.key];
        result[e.key] = extra == null || extra.isEmpty
            ? e.value
            : <String>{...e.value, ...extra}.toList();
      }
      for (final MapEntry<String, List<String>> entry in userKeys.entries) {
        result.putIfAbsent(entry.key, () => entry.value);
      }
      return result;
    });

/// Whether the keys behind counts and progress are still being read. The
/// screens hold their shape with placeholders while it is true.
final Provider<bool> collectionKeysSettlingProvider = Provider<bool>(
  (Ref ref) =>
      ref.watch(dictionaryCollectionKeysProvider).isLoading ||
      ref.watch(userCollectionKeysProvider).isLoading,
);

/// Tracks which collections contain words and which contain phrases.
///
/// A dictionary collection's kind settles this without a query: the pipeline
/// fills `band` and `topic` from `words` and `idiom` from `phrases`, and
/// `test/database/shelf_kinds_test.dart` holds the shipped dictionary to it.
/// Only the user's own shelves can hold either, so only those are asked, two
/// queries each and existence only. Before this the loop asked all 27 shelves and
/// its 44 queries were the whole 69 ms first build of the Shelves tab, paid
/// again on every bookmark toggle.
final Provider<({Set<String> withWords, Set<String> withPhrases})>
shelfKindsProvider =
    Provider<({Set<String> withWords, Set<String> withPhrases})>((Ref ref) {
      final DictionaryDb dict = ref.watch(dictProvider);
      final List<Collection> all = ref.watch(collectionsProvider);
      final Map<String, List<String>> userKeys =
          ref.watch(userCollectionKeysProvider).value ??
          const <String, List<String>>{};

      final Set<String> withWords = <String>{};
      final Set<String> withPhrases = <String>{};

      for (final Collection c in all) {
        if (!c.isUsers) {
          if (c.kind == 'idiom') {
            withPhrases.add(c.slug);
          } else {
            withWords.add(c.slug);
          }
          continue;
        }
        final List<String> keys = userKeys[c.slug] ?? const <String>[];
        if (keys.isEmpty) continue;
        if (dict.hasAnyWord(keys)) withWords.add(c.slug);
        if (dict.hasAnyPhrase(keys)) withPhrases.add(c.slug);
      }

      return (withWords: withWords, withPhrases: withPhrases);
    });

/// The slug of the collection opened most recently, for Home's shortlist.
final StreamProvider<String?> lastOpenedCollectionProvider =
    StreamProvider<String?>(
      (Ref ref) => ref
          .watch(userRepositoryProvider)
          .watchAppState(UserRepository.kLastOpened),
    );

/// Home's shortlist: last opened, then in progress, then a couple of
/// built-ins, five in all. Watches only the in-progress set, never the
/// progress numbers, so a swipe on the Mull tab does not rebuild it.
final Provider<List<Collection>> homeCollectionsProvider =
    Provider<List<Collection>>((Ref ref) {
      final List<Collection> all = ref.watch(collectionsProvider);
      final SlugSet inProgress = ref.watch(inProgressSlugsProvider);
      final String? last = ref.watch(lastOpenedCollectionProvider).value;
      final List<Collection> out = <Collection>[
        ...all.where((Collection c) => c.slug == last),
        ...all.where((Collection c) => inProgress.contains(c.slug)),
        ...all.where((Collection c) => c.kind == 'topic' || c.kind == 'band'),
      ];
      final Set<String> seen = <String>{};
      return out.where((Collection c) => seen.add(c.slug)).take(5).toList();
    });

/// A set of slugs with value equality, so a provider that returns one only
/// notifies when the membership changes.
@immutable
class SlugSet {
  const SlugSet(this.slugs);

  final Set<String> slugs;

  bool contains(String slug) => slugs.contains(slug);

  @override
  bool operator ==(Object other) => other is SlugSet && setEquals(other.slugs, slugs);

  @override
  int get hashCode => Object.hashAllUnordered(slugs);
}

/// Shelves started and not finished. Recomputed on every seen write, but
/// its watchers rebuild only when a shelf starts or finishes.
final Provider<SlugSet> inProgressSlugsProvider = Provider<SlugSet>((Ref ref) {
  final Map<String, Progress> progress = ref.watch(collectionProgressProvider);
  return SlugSet(<String>{
    for (final MapEntry<String, Progress> e in progress.entries)
      if (e.value.started && !e.value.complete) e.key,
  });
});

/// Home's "Continue": the started, unfinished shelf whose words were seen
/// most recently. A slug, so Home's section rebuilds only when it changes;
/// the ring under it watches its own shelf's progress.
final Provider<String?> continueSlugProvider = Provider<String?>((Ref ref) {
  final SlugSet inProgress = ref.watch(inProgressSlugsProvider);
  if (inProgress.slugs.isEmpty) return null;
  final Map<String, SeenWord> seen =
      ref.watch(seenMapProvider).value ?? const <String, SeenWord>{};
  final Map<String, List<String>> keys = ref.watch(collectionKeysProvider);
  String? cont;
  DateTime? latest;
  for (final Collection col in ref.watch(collectionsProvider)) {
    if (!inProgress.contains(col.slug)) continue;
    for (final String k in keys[col.slug] ?? const <String>[]) {
      final DateTime? at = seen[k]?.lastSeenAt;
      if (at != null && (latest == null || at.isAfter(latest))) {
        latest = at;
        cont = col.slug;
      }
    }
  }
  return cont;
});

final StreamProvider<Map<String, SeenWord>> seenMapProvider =
    StreamProvider<Map<String, SeenWord>>(
      (Ref ref) => ref.watch(userRepositoryProvider).watchAllSeen(),
    );

final StreamProvider<Set<String>> bookmarksProvider =
    StreamProvider<Set<String>>(
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

  @override
  bool operator ==(Object other) => other is Progress && other.seen == seen && other.total == total;

  @override
  int get hashCode => Object.hash(seen, total);
}

/// One shelf's progress. Watch this (or `select` the map) in the widget that
/// draws the number, never the whole map in a screen's build.
final progressOfProvider = Provider.autoDispose.family<Progress, String>(
  (Ref ref, String slug) => ref.watch(
    collectionProgressProvider.select((Map<String, Progress> m) => m[slug] ?? const Progress(0, 0)),
  ),
);

/// Seen count per collection, live.
final Provider<Map<String, Progress>> collectionProgressProvider =
    Provider<Map<String, Progress>>((Ref ref) {
      final Map<String, List<String>> keys = ref.watch(collectionKeysProvider);
      final Map<String, SeenWord> seen =
          ref.watch(seenMapProvider).value ?? const <String, SeenWord>{};
      return <String, Progress>{
        for (final MapEntry<String, List<String>> e in keys.entries)
          e.key: Progress(
            e.value.where(seen.containsKey).length,
            e.value.length,
          ),
      };
    });

/// One word a day, the same for everyone on the same day: picked from the
/// banded words by the day number, so it never needs storing.
///
/// On the worker: the first pick builds the pool (a DISTINCT join over three
/// shelves, 31 ms on a laptop, so about 100 ms on the emulator and more on a
/// phone), which used to run inside Home's first build.
final FutureProvider<DictionaryWord?> wordOfTheDayProvider =
    FutureProvider<DictionaryWord?>(
      (Ref ref) => ref.watch(dictProvider).compute(wordOfTheDayWork(DateTime.now())),
    );

/// Built synchronously so the closure captures only [day] (CLAUDE.md:
/// a closure made inside an async body cannot be sent). Public for
/// `off_main_isolate_test.dart`.
DictionaryWord? Function(DictionaryDb) wordOfTheDayWork(DateTime day) =>
    (DictionaryDb db) => db.wordOfTheDay(day);

final StreamProvider<List<String>> recentLookupsProvider =
    StreamProvider<List<String>>(
      (Ref ref) => ref.watch(userRepositoryProvider).watchRecentLookups(),
    );

/// Every mix, presets first, resolved. Re-read whenever the mixes table
/// changes.
final StreamProvider<List<MixSpec>> mixesProvider =
    StreamProvider<List<MixSpec>>((Ref ref) {
      final MixRepository repo = ref.watch(mixRepositoryProvider);
      return repo.watchMixRows().asyncMap((_) => repo.all());
    });
