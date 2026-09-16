import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../features/linger/linger_rules.dart';
import 'user_db.dart';

/// A mix, resolved: what the Mull tab plays. A query over collections plus a
/// rule about seen words, never a bag of words.
@immutable
class MixSpec {
  const MixSpec({
    required this.id,
    required this.name,
    required this.isPreset,
    required this.sources,
    required this.seenPolicy,
    this.shuffle = true,
    this.includeBookmarkedOnly = false,
  }) : _scope = null;

  /// Scoped play from a collection card, built-in or the user's own: an
  /// ephemeral spec that is never written to the database and never touches
  /// the active mix.
  const MixSpec.scoped(String collectionSlug, SeenPolicy policy)
    : id = null,
      name = collectionSlug,
      isPreset = false,
      sources = const <String>[],
      _scope = collectionSlug,
      seenPolicy = policy,
      shuffle = true,
      includeBookmarkedOnly = false;

  final int? id;
  final String name;
  final bool isPreset;
  final List<String> sources;
  final SeenPolicy seenPolicy;
  final bool shuffle;

  /// The Review preset: the pool is whatever the user has bookmarked.
  final bool includeBookmarkedOnly;
  final String? _scope;

  bool get isScoped => _scope != null;

  /// The collections the pool is drawn from.
  List<String> get effectiveSources =>
      _scope != null ? <String>[_scope] : sources;
}

/// Mixes, presets and the two pieces of app state the Mull tab depends on.
class MixRepository {
  MixRepository(this._db);

  final UserDatabase _db;

  static const String kActiveMix = 'active_mix_id';
  static const String kScoped = 'last_scoped_collection';

  static const String presetAnything = 'Anything';
  static const String presetQuickWins = 'Quick wins';
  static const String presetStretchMe = 'Stretch me';
  static const String presetReview = 'Review';

  /// Creates the four presets on first run and refreshes their sources on
  /// every call, so a dictionary update that adds a collection reaches
  /// "Anything" without a migration. Presets are not editable; users
  /// duplicate them.
  Future<void> ensurePresets({
    required List<String> bandSlugs,
    required List<String> topicSlugs,
  }) async {
    final Map<String, (List<String>, SeenPolicy, bool)> presets =
        <String, (List<String>, SeenPolicy, bool)>{
          presetAnything: (
            <String>[...bandSlugs, ...topicSlugs],
            SeenPolicy.light,
            false,
          ),
          presetQuickWins: (
            <String>['core', 'everyday'],
            SeenPolicy.unseenOnly,
            false,
          ),
          presetStretchMe: (
            <String>['well_read', 'uncommon'],
            SeenPolicy.unseenOnly,
            false,
          ),
          presetReview: (<String>[], SeenPolicy.reviewOnly, true),
        };
    await _db.transaction(() async {
      for (final MapEntry<String, (List<String>, SeenPolicy, bool)> e
          in presets.entries) {
        final (List<String> sources, SeenPolicy policy, bool bookmarked) =
            e.value;
        Mix? row = await (_db.select(_db.mixes)
              ..where((Mixes m) => m.name.equals(e.key) & m.isPreset.equals(true)))
            .getSingleOrNull();
        final DateTime now = DateTime.now();
        if (row == null) {
          final int id = await _db
              .into(_db.mixes)
              .insert(
                MixesCompanion.insert(
                  name: e.key,
                  isPreset: const Value<bool>(true),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          await _db
              .into(_db.mixSettings)
              .insert(
                MixSettingsCompanion.insert(
                  mixId: Value<int>(id),
                  seenPolicy: policy.dbValue,
                  includeBookmarkedOnly: Value<bool>(bookmarked),
                ),
              );
          row = await (_db.select(_db.mixes)
                ..where((Mixes m) => m.id.equals(id)))
              .getSingle();
        }
        await _replaceSources(row.id, sources);
      }
    });
    if (await activeMixId() == null) {
      final Mix anything = await (_db.select(_db.mixes)
            ..where((Mixes m) => m.name.equals(presetAnything)))
          .getSingle();
      await setActive(anything.id);
    }
  }

  Future<void> _replaceSources(int mixId, List<String> sources) async {
    await (_db.delete(_db.mixSources)
          ..where((MixSources s) => s.mixId.equals(mixId)))
        .go();
    await _db.batch((Batch b) {
      b.insertAll(_db.mixSources, <MixSourcesCompanion>[
        for (final String slug in sources)
          MixSourcesCompanion.insert(mixId: mixId, collectionSlug: slug),
      ]);
    });
  }

  Future<MixSpec?> byId(int id) async {
    final Mix? row = await (_db.select(_db.mixes)
          ..where((Mixes m) => m.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _resolve(row);
  }

  Future<List<MixSpec>> all() async {
    final List<Mix> rows = await (_db.select(_db.mixes)
          ..orderBy(<OrderingTerm Function(Mixes)>[
            (Mixes m) => OrderingTerm.desc(m.isPreset),
            (Mixes m) => OrderingTerm.asc(m.createdAt),
          ]))
        .get();
    return <MixSpec>[for (final Mix r in rows) await _resolve(r)];
  }

  Future<MixSpec> _resolve(Mix row) async {
    final MixSetting? s = await (_db.select(_db.mixSettings)
          ..where((MixSettings t) => t.mixId.equals(row.id)))
        .getSingleOrNull();
    final List<MixSource> sources = await (_db.select(_db.mixSources)
          ..where((MixSources t) => t.mixId.equals(row.id)))
        .get();
    return MixSpec(
      id: row.id,
      name: row.name,
      isPreset: row.isPreset,
      sources: sources.map((MixSource m) => m.collectionSlug).toList(),
      seenPolicy: SeenPolicy.fromDb(s?.seenPolicy ?? 'light'),
      shuffle: s?.shuffle ?? true,
      includeBookmarkedOnly: s?.includeBookmarkedOnly ?? false,
    );
  }

  Future<int> create({
    required String name,
    required List<String> sources,
    required SeenPolicy seenPolicy,
    bool shuffle = true,
    bool includeBookmarkedOnly = false,
  }) async {
    final DateTime now = DateTime.now();
    return _db.transaction(() async {
      final int id = await _db
          .into(_db.mixes)
          .insert(MixesCompanion.insert(name: name, createdAt: now, updatedAt: now));
      await _db
          .into(_db.mixSettings)
          .insert(
            MixSettingsCompanion.insert(
              mixId: Value<int>(id),
              seenPolicy: seenPolicy.dbValue,
              shuffle: Value<bool>(shuffle),
              includeBookmarkedOnly: Value<bool>(includeBookmarkedOnly),
            ),
          );
      await _replaceSources(id, sources);
      return id;
    });
  }

  Future<void> rename(int id, String name) =>
      (_db.update(_db.mixes)..where((Mixes m) => m.id.equals(id))).write(
        MixesCompanion(name: Value<String>(name), updatedAt: Value<DateTime>(DateTime.now())),
      );

  /// Rewrites a user mix's sources and policy. Presets are never edited.
  Future<void> update(
    int id, {
    required List<String> sources,
    required SeenPolicy seenPolicy,
  }) async {
    final MixSpec? m = await byId(id);
    if (m == null || m.isPreset) return;
    await _db.transaction(() async {
      await (_db.update(_db.mixSettings)..where((MixSettings t) => t.mixId.equals(id)))
          .write(MixSettingsCompanion(seenPolicy: Value<String>(seenPolicy.dbValue)));
      await (_db.update(_db.mixes)..where((Mixes t) => t.id.equals(id)))
          .write(MixesCompanion(updatedAt: Value<DateTime>(DateTime.now())));
      await _replaceSources(id, sources);
    });
  }

  Stream<List<Mix>> watchMixRows() => _db.select(_db.mixes).watch();

  /// A preset cannot be edited, but it can be copied into a user mix.
  Future<int> duplicate(int id, {required String name}) async {
    final MixSpec src = (await byId(id))!;
    return create(
      name: name,
      sources: src.sources,
      seenPolicy: src.seenPolicy,
      shuffle: src.shuffle,
      includeBookmarkedOnly: src.includeBookmarkedOnly,
    );
  }

  Future<void> delete(int id) async {
    final MixSpec? m = await byId(id);
    if (m == null || m.isPreset) return;
    await (_db.delete(_db.mixes)..where((Mixes t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------- app state

  Future<int?> activeMixId() async {
    final AppStateRow? r = await (_db.select(_db.appState)
          ..where((AppState a) => a.key.equals(kActiveMix)))
        .getSingleOrNull();
    return r == null ? null : int.tryParse(r.value);
  }

  Future<MixSpec?> active() async {
    final int? id = await activeMixId();
    return id == null ? null : byId(id);
  }

  Future<void> setActive(int mixId) => _db
      .into(_db.appState)
      .insertOnConflictUpdate(
        AppStateCompanion.insert(key: kActiveMix, value: '$mixId'),
      );

  /// Scoped play from a collection card. Stored beside, never instead of,
  /// the active mix; cleared on exit.
  Future<String?> scopedCollection() async =>
      (await (_db.select(_db.appState)
                ..where((AppState a) => a.key.equals(kScoped)))
              .getSingleOrNull())
          ?.value;

  Future<void> setScoped(String collectionSlug) => _db
      .into(_db.appState)
      .insertOnConflictUpdate(
        AppStateCompanion.insert(key: kScoped, value: collectionSlug),
      );

  Future<void> clearScoped() =>
      (_db.delete(_db.appState)..where((AppState a) => a.key.equals(kScoped)))
          .go();
}
