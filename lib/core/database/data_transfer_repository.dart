import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dictionary_db.dart';
import 'user_db.dart';
import 'user_repository.dart';

enum ImportMode { merge, replace }

class DataTransferException implements Exception {
  const DataTransferException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ImportPreview {
  const ImportPreview(this.data, this.fileName);

  final Map<String, Object?> data;
  final String fileName;

  DateTime? get exportedAt =>
      DateTime.tryParse(data['exported_at'] as String? ?? '');
  int count(String section) =>
      (data[section] as List<Object?>? ?? const <Object?>[]).length;
}

class ImportResult {
  const ImportResult({required this.unresolvedCount});
  final int unresolvedCount;
}

/// Portable JSON backup/import. This is deliberately independent of UI so a
/// parsed file can always be previewed before this repository writes anything.
class DataTransferRepository {
  DataTransferRepository(this._db, this._dictionary, this._prefs);

  static const String format = 'mull.export';
  static const int formatVersion = 1;
  static const String lastExportKey = 'data.last_export_at';

  /// Separates an imported note from the one already on the phone.
  static const String importedNoteMarker = '--- imported note ·';

  final UserDatabase _db;
  final DictionaryDb _dictionary;
  final SharedPreferences _prefs;

  DateTime? get lastExportedAt =>
      DateTime.tryParse(_prefs.getString(lastExportKey) ?? '');

  Future<void> markExported() =>
      _prefs.setString(lastExportKey, DateTime.now().toUtc().toIso8601String());

  Future<String> exportJson() async {
    final List<UserCollection> collections = await _db
        .select(_db.userCollections)
        .get();
    final List<UserCollectionWord> members = await _db
        .select(_db.userCollectionWords)
        .get();
    final List<Note> notes = await _db.select(_db.notes).get();
    final List<SeenWord> seen = await _db.select(_db.seen).get();
    final List<Mix> mixes = await _db.select(_db.mixes).get();
    final List<MixSource> sources = await _db.select(_db.mixSources).get();
    final List<MixSetting> mixSettings = await _db
        .select(_db.mixSettings)
        .get();
    final List<WordContext> contexts = await _db.select(_db.wordContexts).get();
    final List<QuizSession> sessions = await _db.select(_db.quizSessions).get();
    final List<QuizAnswer> answers = await _db.select(_db.quizAnswers).get();
    final List<CollectionStat> stats = await _db
        .select(_db.collectionStats)
        .get();

    final Map<int, String> collectionSlugs = <int, String>{
      for (final UserCollection c in collections) c.id: c.slug,
    };
    final Map<int, List<Object?>> collectionMembers = <int, List<Object?>>{};
    for (final UserCollectionWord member in members) {
      collectionMembers.putIfAbsent(member.collectionId, () => <Object?>[]).add(
        <String, Object?>{
          'word_key': member.wordKey,
          'position': member.position,
          'added_at': member.addedAt.toIso8601String(),
        },
      );
    }

    final Map<String, Object?> payload = <String, Object?>{
      'format': format,
      'format_version': formatVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'app_version': const String.fromEnvironment(
        'APP_VERSION',
        defaultValue: '1.0.0+1',
      ),
      'dict_version': _dictionary.version,
      'collections': <Object?>[
        for (final UserCollection collection in collections)
          <String, Object?>{
            'slug': collection.slug,
            'name': collection.name,
            'kind': collection.kind,
            'color': collection.color,
            'created_at': collection.createdAt.toIso8601String(),
            'members': collectionMembers[collection.id] ?? const <Object?>[],
          },
      ],
      'notes': <Object?>[
        for (final Note note in notes)
          <String, Object?>{
            'word_key': note.wordKey,
            'body': note.body,
            'updated_at': note.updatedAt.toIso8601String(),
          },
      ],
      'bookmarks': <Object?>[
        for (final UserCollectionWord member in members)
          if (collectionSlugs[member.collectionId] ==
              UserRepository.bookmarksSlug)
            member.wordKey,
      ],
      'progress': <Object?>[
        for (final SeenWord row in seen)
          <String, Object?>{
            'word_key': row.wordKey,
            'seen_count': row.seenCount,
            'first_seen_at': row.firstSeenAt.toIso8601String(),
            'last_seen_at': row.lastSeenAt.toIso8601String(),
          },
      ],
      'mixes': <Object?>[
        for (final Mix mix in mixes)
          <String, Object?>{
            'name': mix.name,
            'is_preset': mix.isPreset,
            'created_at': mix.createdAt.toIso8601String(),
            'updated_at': mix.updatedAt.toIso8601String(),
            'sources': <Object?>[
              for (final MixSource source in sources.where(
                (MixSource s) => s.mixId == mix.id,
              ))
                source.collectionSlug,
            ],
            'settings': _settingsForMix(mixSettings, mix.id),
          },
      ],
      'contexts': <Object?>[
        for (final WordContext context in contexts)
          <String, Object?>{
            'word_key': context.wordKey,
            'context_text': context.contextText,
            'captured_at': context.capturedAt.toIso8601String(),
            'source_hint': context.sourceHint,
          },
      ],
      // Additive by design: future quiz fields do not change the file format.
      'quiz_history': <String, Object?>{
        'sessions': <Object?>[
          for (final QuizSession session in sessions)
            <String, Object?>{
              'export_id': session.id,
              'collection_slug': session.collectionSlug,
              'started_at': session.startedAt.toIso8601String(),
              'completed_at': session.completedAt?.toIso8601String(),
              'question_count': session.questionCount,
              'correct_count': session.correctCount,
              'was_abandoned': session.wasAbandoned,
            },
        ],
        'answers': <Object?>[
          for (final QuizAnswer answer in answers)
            <String, Object?>{
              'session_export_id': answer.sessionId,
              'word_key': answer.wordKey,
              'question_type': answer.questionType,
              'was_correct': answer.wasCorrect,
              'chosen_key': answer.chosenKey,
              'answered_at': answer.answeredAt.toIso8601String(),
            },
        ],
      },
      'collection_stats': <Object?>[
        for (final CollectionStat stat in stats)
          <String, Object?>{
            'collection_slug': stat.collectionSlug,
            'times_opened': stat.timesOpened,
            'last_opened_at': stat.lastOpenedAt?.toIso8601String(),
          },
      ],
      'settings': _exportSettings(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  ImportPreview parse(String source, {required String fileName}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const DataTransferException('That file is not a Mull export.');
    }
    if (decoded is! Map<Object?, Object?>) {
      throw const DataTransferException('That file is not a Mull export.');
    }
    final Map<String, Object?> data = <String, Object?>{
      for (final MapEntry<Object?, Object?> e in decoded.entries)
        if (e.key is String) e.key as String: e.value,
    };
    if (data['format'] != format) {
      throw const DataTransferException('That file is not a Mull export.');
    }
    if (data['format_version'] != formatVersion) {
      throw const DataTransferException(
        'This Mull export uses a format this version cannot import.',
      );
    }
    return ImportPreview(data, fileName);
  }

  Future<ImportResult> apply(
    ImportPreview preview, {
    required ImportMode mode,
  }) async {
    int unresolved = 0;
    await _db.transaction(() async {
      if (mode == ImportMode.replace) await _clearUserData();
      await _ensureSystemCollections();
      final Map<String, String> importedSlugs = await _importCollections(
        preview.data,
        countUnresolved: () => unresolved++,
      );
      await _importNotes(preview.data);
      await _importSeen(preview.data);
      await _importContexts(preview.data);
      await _importQuizHistory(preview.data, importedSlugs);
      await _importCollectionStats(preview.data, importedSlugs);
      await _importMixes(preview.data, importedSlugs);
    });
    await _importSettings(preview.data['settings']);
    return ImportResult(unresolvedCount: unresolved);
  }

  Map<String, Object?> _exportSettings() => <String, Object?>{
    for (final String key in _prefs.getKeys().where(
      (String key) =>
          key.startsWith('theme.') ||
          key.startsWith('text.') ||
          key.startsWith('search.') ||
          key.startsWith('dictionary.') ||
          key.startsWith('linger.') ||
          key.startsWith('wotd.'),
    ))
      key: _prefs.get(key),
  };

  Future<void> _clearUserData() async {
    for (final TableInfo<Table, Object?> table in <TableInfo<Table, Object?>>[
      _db.quizAnswers,
      _db.quizSessions,
      _db.collectionStats,
      _db.wordContexts,
      _db.mixSources,
      _db.mixSettings,
      _db.mixes,
      _db.userCollectionWords,
      _db.userCollections,
      _db.notes,
      _db.seen,
      _db.seenEvents,
      _db.recentLookups,
      _db.recentSearches,
      _db.appState,
    ]) {
      await _db.delete(table).go();
    }
  }

  Future<void> _ensureSystemCollections() async {
    for (final MapEntry<String, String> entry in const <String, String>{
      UserRepository.bookmarksSlug: 'Bookmarks',
      UserRepository.readingSlug: UserRepository.readingListName,
    }.entries) {
      await _db
          .into(_db.userCollections)
          .insert(
            UserCollectionsCompanion.insert(
              slug: entry.key,
              kind: 'system',
              name: entry.value,
              createdAt: DateTime.now(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<Map<String, String>> _importCollections(
    Map<String, Object?> data, {
    required void Function() countUnresolved,
  }) async {
    final Map<String, String> slugMap = <String, String>{};
    for (final Object? raw in _list(data['collections'])) {
      final Map<String, Object?> row = _map(raw);
      final String oldSlug = row['slug'] as String? ?? '';
      final String name = row['name'] as String? ?? oldSlug;
      if (name.isEmpty) continue;
      final String kind = row['kind'] as String? ?? 'user';
      final UserCollection? existing = await (_db.select(
        _db.userCollections,
      )..where((UserCollections c) => c.name.equals(name))).getSingleOrNull();
      final int collectionId;
      final String slug;
      if (existing != null) {
        collectionId = existing.id;
        slug = existing.slug;
      } else {
        slug =
            kind == 'system' &&
                (oldSlug == UserRepository.bookmarksSlug ||
                    oldSlug == UserRepository.readingSlug)
            ? oldSlug
            : 'u${DateTime.now().microsecondsSinceEpoch}${slugMap.length}';
        collectionId = await _db
            .into(_db.userCollections)
            .insert(
              UserCollectionsCompanion.insert(
                slug: slug,
                kind: kind == 'system' ? 'system' : 'user',
                name: name,
                color: Value<int?>(row['color'] as int?),
                createdAt: _date(row['created_at']) ?? DateTime.now(),
              ),
            );
      }
      slugMap[oldSlug] = slug;
      for (final Object? memberRaw in _list(row['members'])) {
        final Map<String, Object?> member = _map(memberRaw);
        final String key = member['word_key'] as String? ?? '';
        if (key.isEmpty) continue;
        if (_dictionary.byKey(key) == null &&
            _dictionary.phraseByKey(key) == null) {
          countUnresolved();
        }
        await _db
            .into(_db.userCollectionWords)
            .insert(
              UserCollectionWordsCompanion.insert(
                collectionId: collectionId,
                wordKey: key,
                position: Value<int>(member['position'] as int? ?? 0),
                addedAt: _date(member['added_at']) ?? DateTime.now(),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    }
    return slugMap;
  }

  /// A note is the only thing in the app the user wrote, so a merge never
  /// overwrites one: an existing note keeps its text and the imported one is
  /// appended beneath it, marked as imported.
  Future<void> _importNotes(Map<String, Object?> data) async {
    for (final Object? raw in _list(data['notes'])) {
      final Map<String, Object?> row = _map(raw);
      final String key = row['word_key'] as String? ?? '';
      final String body = (row['body'] as String? ?? '').trim();
      if (key.isEmpty || body.isEmpty) continue;
      final DateTime importedAt = _date(row['updated_at']) ?? DateTime.now();
      final Note? existing = await (_db.select(
        _db.notes,
      )..where((Notes n) => n.wordKey.equals(key))).getSingleOrNull();
      if (existing != null && existing.body.contains(body)) continue;
      final String merged = existing == null
          ? body
          : '${existing.body}\n\n$importedNoteMarker '
                '${importedAt.toIso8601String().substring(0, 10)}\n$body';
      await _db
          .into(_db.notes)
          .insertOnConflictUpdate(
            NotesCompanion.insert(
              wordKey: key,
              body: merged,
              updatedAt: existing == null ? importedAt : DateTime.now(),
            ),
          );
    }
  }

  Future<void> _importSeen(Map<String, Object?> data) async {
    for (final Object? raw in _list(data['progress'])) {
      final Map<String, Object?> row = _map(raw);
      final String key = row['word_key'] as String? ?? '';
      if (key.isEmpty) continue;
      final SeenWord? existing = await (_db.select(
        _db.seen,
      )..where((Seen s) => s.wordKey.equals(key))).getSingleOrNull();
      final int importedCount = row['seen_count'] as int? ?? 0;
      await _db
          .into(_db.seen)
          .insertOnConflictUpdate(
            SeenCompanion.insert(
              wordKey: key,
              seenCount: Value<int>(
                existing == null
                    ? importedCount
                    : existing.seenCount > importedCount
                    ? existing.seenCount
                    : importedCount,
              ),
              firstSeenAt:
                  existing?.firstSeenAt ??
                  _date(row['first_seen_at']) ??
                  DateTime.now(),
              lastSeenAt:
                  _latest(existing?.lastSeenAt, _date(row['last_seen_at'])) ??
                  DateTime.now(),
            ),
          );
    }
  }

  Future<void> _importContexts(Map<String, Object?> data) async {
    for (final Object? raw in _list(data['contexts'])) {
      final Map<String, Object?> row = _map(raw);
      final String key = row['word_key'] as String? ?? '';
      final String text = row['context_text'] as String? ?? '';
      if (key.isEmpty || text.isEmpty) continue;
      await _db
          .into(_db.wordContexts)
          .insert(
            WordContextsCompanion.insert(
              wordKey: key,
              contextText: text,
              capturedAt: _date(row['captured_at']) ?? DateTime.now(),
              sourceHint: Value<String?>(row['source_hint'] as String?),
            ),
          );
    }
  }

  Future<void> _importQuizHistory(
    Map<String, Object?> data,
    Map<String, String> slugMap,
  ) async {
    final Map<String, Object?> history = _map(data['quiz_history']);
    final Map<int, int> sessionIds = <int, int>{};
    for (final Object? raw in _list(history['sessions'])) {
      final Map<String, Object?> row = _map(raw);
      final int newId = await _db
          .into(_db.quizSessions)
          .insert(
            QuizSessionsCompanion.insert(
              collectionSlug:
                  slugMap[row['collection_slug']] ??
                  row['collection_slug'] as String? ??
                  '',
              startedAt: _date(row['started_at']) ?? DateTime.now(),
              completedAt: Value<DateTime?>(_date(row['completed_at'])),
              questionCount: row['question_count'] as int? ?? 0,
              correctCount: Value<int>(row['correct_count'] as int? ?? 0),
              wasAbandoned: Value<bool>(row['was_abandoned'] as bool? ?? false),
            ),
          );
      if (row['export_id'] is int) sessionIds[row['export_id'] as int] = newId;
    }
    for (final Object? raw in _list(history['answers'])) {
      final Map<String, Object?> row = _map(raw);
      final int? sessionId = sessionIds[row['session_export_id']];
      if (sessionId == null) continue;
      await _db
          .into(_db.quizAnswers)
          .insert(
            QuizAnswersCompanion.insert(
              sessionId: sessionId,
              wordKey: row['word_key'] as String? ?? '',
              questionType: row['question_type'] as String? ?? '',
              wasCorrect: row['was_correct'] as bool? ?? false,
              chosenKey: Value<String?>(row['chosen_key'] as String?),
              answeredAt: _date(row['answered_at']) ?? DateTime.now(),
            ),
          );
    }
  }

  Future<void> _importCollectionStats(
    Map<String, Object?> data,
    Map<String, String> slugMap,
  ) async {
    for (final Object? raw in _list(data['collection_stats'])) {
      final Map<String, Object?> row = _map(raw);
      final String slug =
          slugMap[row['collection_slug']] ??
          row['collection_slug'] as String? ??
          '';
      if (slug.isEmpty) continue;
      final CollectionStat? existing =
          await (_db.select(_db.collectionStats)
                ..where((CollectionStats s) => s.collectionSlug.equals(slug)))
              .getSingleOrNull();
      await _db
          .into(_db.collectionStats)
          .insertOnConflictUpdate(
            CollectionStatsCompanion.insert(
              collectionSlug: slug,
              timesOpened: Value<int>(
                (existing?.timesOpened ?? 0) +
                    (row['times_opened'] as int? ?? 0),
              ),
              lastOpenedAt: Value<DateTime?>(
                _latest(existing?.lastOpenedAt, _date(row['last_opened_at'])),
              ),
            ),
          );
    }
  }

  Future<void> _importMixes(
    Map<String, Object?> data,
    Map<String, String> slugMap,
  ) async {
    final Set<String> existingNames = <String>{
      for (final Mix mix in await _db.select(_db.mixes).get()) mix.name,
    };
    for (final Object? raw in _list(data['mixes'])) {
      final Map<String, Object?> row = _map(raw);
      final String name = row['name'] as String? ?? 'Imported mix';
      // Presets are recreated on every install; a merge must not double them.
      if (!existingNames.add(name)) continue;
      final int id = await _db
          .into(_db.mixes)
          .insert(
            MixesCompanion.insert(
              name: name,
              isPreset: Value<bool>(row['is_preset'] as bool? ?? false),
              createdAt: _date(row['created_at']) ?? DateTime.now(),
              updatedAt: _date(row['updated_at']) ?? DateTime.now(),
            ),
          );
      for (final Object? source in _list(row['sources'])) {
        final String oldSlug = source as String? ?? '';
        if (oldSlug.isEmpty) {
          continue;
        }
        await _db
            .into(_db.mixSources)
            .insert(
              MixSourcesCompanion.insert(
                mixId: id,
                collectionSlug: slugMap[oldSlug] ?? oldSlug,
              ),
            );
      }
      final Map<String, Object?> settings = _map(row['settings']);
      await _db
          .into(_db.mixSettings)
          .insert(
            MixSettingsCompanion.insert(
              mixId: Value<int>(id),
              seenPolicy: settings['seen_policy'] as String? ?? 'light',
              shuffle: Value<bool>(settings['shuffle'] as bool? ?? true),
              includeBookmarkedOnly: Value<bool>(
                settings['include_bookmarked_only'] as bool? ?? false,
              ),
            ),
          );
    }
  }

  Future<void> _importSettings(Object? raw) async {
    for (final MapEntry<String, Object?> entry in _map(raw).entries) {
      final Object? value = entry.value;
      if (value is String) await _prefs.setString(entry.key, value);
      if (value is bool) await _prefs.setBool(entry.key, value);
      if (value is int) await _prefs.setInt(entry.key, value);
      if (value is double) await _prefs.setDouble(entry.key, value);
      if (value is List<Object?> &&
          value.every((Object? item) => item is String)) {
        await _prefs.setStringList(entry.key, value.cast<String>());
      }
    }
  }

  static List<Object?> _list(Object? value) =>
      value is List<Object?> ? value : const <Object?>[];

  static Map<String, Object?>? _settingsForMix(
    List<MixSetting> settings,
    int id,
  ) {
    final List<MixSetting> matches = settings
        .where((MixSetting setting) => setting.mixId == id)
        .toList();
    if (matches.isEmpty) return null;
    final MixSetting setting = matches.first;
    return <String, Object?>{
      'seen_policy': setting.seenPolicy,
      'shuffle': setting.shuffle,
      'include_bookmarked_only': setting.includeBookmarkedOnly,
    };
  }

  static Map<String, Object?> _map(Object? value) =>
      value is Map<Object?, Object?>
      ? <String, Object?>{
          for (final MapEntry<Object?, Object?> e in value.entries)
            if (e.key is String) e.key as String: e.value,
        }
      : const <String, Object?>{};
  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
  static DateTime? _latest(DateTime? a, DateTime? b) => a == null
      ? b
      : b == null || a.isAfter(b)
      ? a
      : b;
}
