// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_db.dart';

// ignore_for_file: type=lint
class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordKeyMeta = const VerificationMeta(
    'wordKey',
  );
  @override
  late final GeneratedColumn<String> wordKey = GeneratedColumn<String>(
    'word_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [wordKey, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word_key')) {
      context.handle(
        _wordKeyMeta,
        wordKey.isAcceptableOrUnknown(data['word_key']!, _wordKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_wordKeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {wordKey};
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      wordKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_key'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  final String wordKey;
  final DateTime createdAt;
  const Bookmark({required this.wordKey, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word_key'] = Variable<String>(wordKey);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      wordKey: Value(wordKey),
      createdAt: Value(createdAt),
    );
  }

  factory Bookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      wordKey: serializer.fromJson<String>(json['wordKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'wordKey': serializer.toJson<String>(wordKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Bookmark copyWith({String? wordKey, DateTime? createdAt}) => Bookmark(
    wordKey: wordKey ?? this.wordKey,
    createdAt: createdAt ?? this.createdAt,
  );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      wordKey: data.wordKey.present ? data.wordKey.value : this.wordKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('wordKey: $wordKey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(wordKey, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.wordKey == this.wordKey &&
          other.createdAt == this.createdAt);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<String> wordKey;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BookmarksCompanion({
    this.wordKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksCompanion.insert({
    required String wordKey,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : wordKey = Value(wordKey),
       createdAt = Value(createdAt);
  static Insertable<Bookmark> custom({
    Expression<String>? wordKey,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (wordKey != null) 'word_key': wordKey,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksCompanion copyWith({
    Value<String>? wordKey,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return BookmarksCompanion(
      wordKey: wordKey ?? this.wordKey,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (wordKey.present) {
      map['word_key'] = Variable<String>(wordKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('wordKey: $wordKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordKeyMeta = const VerificationMeta(
    'wordKey',
  );
  @override
  late final GeneratedColumn<String> wordKey = GeneratedColumn<String>(
    'word_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [wordKey, body, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word_key')) {
      context.handle(
        _wordKeyMeta,
        wordKey.isAcceptableOrUnknown(data['word_key']!, _wordKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_wordKeyMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {wordKey};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      wordKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_key'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final String wordKey;
  final String body;
  final DateTime updatedAt;
  const Note({
    required this.wordKey,
    required this.body,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word_key'] = Variable<String>(wordKey);
    map['body'] = Variable<String>(body);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      wordKey: Value(wordKey),
      body: Value(body),
      updatedAt: Value(updatedAt),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      wordKey: serializer.fromJson<String>(json['wordKey']),
      body: serializer.fromJson<String>(json['body']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'wordKey': serializer.toJson<String>(wordKey),
      'body': serializer.toJson<String>(body),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Note copyWith({String? wordKey, String? body, DateTime? updatedAt}) => Note(
    wordKey: wordKey ?? this.wordKey,
    body: body ?? this.body,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      wordKey: data.wordKey.present ? data.wordKey.value : this.wordKey,
      body: data.body.present ? data.body.value : this.body,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('wordKey: $wordKey, ')
          ..write('body: $body, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(wordKey, body, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.wordKey == this.wordKey &&
          other.body == this.body &&
          other.updatedAt == this.updatedAt);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<String> wordKey;
  final Value<String> body;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NotesCompanion({
    this.wordKey = const Value.absent(),
    this.body = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String wordKey,
    required String body,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : wordKey = Value(wordKey),
       body = Value(body),
       updatedAt = Value(updatedAt);
  static Insertable<Note> custom({
    Expression<String>? wordKey,
    Expression<String>? body,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (wordKey != null) 'word_key': wordKey,
      if (body != null) 'body': body,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? wordKey,
    Value<String>? body,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      wordKey: wordKey ?? this.wordKey,
      body: body ?? this.body,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (wordKey.present) {
      map['word_key'] = Variable<String>(wordKey.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('wordKey: $wordKey, ')
          ..write('body: $body, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WordListsTable extends WordLists
    with TableInfo<$WordListsTable, WordList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isReadingMeta = const VerificationMeta(
    'isReading',
  );
  @override
  late final GeneratedColumn<bool> isReading = GeneratedColumn<bool>(
    'is_reading',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_reading" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, color, isReading, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordList> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('is_reading')) {
      context.handle(
        _isReadingMeta,
        isReading.isAcceptableOrUnknown(data['is_reading']!, _isReadingMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WordList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordList(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
      isReading: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_reading'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WordListsTable createAlias(String alias) {
    return $WordListsTable(attachedDatabase, alias);
  }
}

class WordList extends DataClass implements Insertable<WordList> {
  final int id;
  final String name;

  /// An index into `MullColors.tagHues`, or null for the theme accent.
  final int? color;
  final bool isReading;
  final DateTime createdAt;
  const WordList({
    required this.id,
    required this.name,
    this.color,
    required this.isReading,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    map['is_reading'] = Variable<bool>(isReading);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WordListsCompanion toCompanion(bool nullToAbsent) {
    return WordListsCompanion(
      id: Value(id),
      name: Value(name),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      isReading: Value(isReading),
      createdAt: Value(createdAt),
    );
  }

  factory WordList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordList(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int?>(json['color']),
      isReading: serializer.fromJson<bool>(json['isReading']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int?>(color),
      'isReading': serializer.toJson<bool>(isReading),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WordList copyWith({
    int? id,
    String? name,
    Value<int?> color = const Value.absent(),
    bool? isReading,
    DateTime? createdAt,
  }) => WordList(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color.present ? color.value : this.color,
    isReading: isReading ?? this.isReading,
    createdAt: createdAt ?? this.createdAt,
  );
  WordList copyWithCompanion(WordListsCompanion data) {
    return WordList(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      isReading: data.isReading.present ? data.isReading.value : this.isReading,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordList(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('isReading: $isReading, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, isReading, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordList &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.isReading == this.isReading &&
          other.createdAt == this.createdAt);
}

class WordListsCompanion extends UpdateCompanion<WordList> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> color;
  final Value<bool> isReading;
  final Value<DateTime> createdAt;
  const WordListsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.isReading = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  WordListsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
    this.isReading = const Value.absent(),
    required DateTime createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<WordList> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<bool>? isReading,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (isReading != null) 'is_reading': isReading,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  WordListsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? color,
    Value<bool>? isReading,
    Value<DateTime>? createdAt,
  }) {
    return WordListsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      isReading: isReading ?? this.isReading,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (isReading.present) {
      map['is_reading'] = Variable<bool>(isReading.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordListsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('isReading: $isReading, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ListWordsTable extends ListWords
    with TableInfo<$ListWordsTable, ListWord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListWordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<int> listId = GeneratedColumn<int>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES word_lists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _wordKeyMeta = const VerificationMeta(
    'wordKey',
  );
  @override
  late final GeneratedColumn<String> wordKey = GeneratedColumn<String>(
    'word_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [listId, wordKey, position, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'list_words';
  @override
  VerificationContext validateIntegrity(
    Insertable<ListWord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('word_key')) {
      context.handle(
        _wordKeyMeta,
        wordKey.isAcceptableOrUnknown(data['word_key']!, _wordKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_wordKeyMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {listId, wordKey};
  @override
  ListWord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListWord(
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}list_id'],
      )!,
      wordKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_key'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $ListWordsTable createAlias(String alias) {
    return $ListWordsTable(attachedDatabase, alias);
  }
}

class ListWord extends DataClass implements Insertable<ListWord> {
  final int listId;
  final String wordKey;
  final int position;
  final DateTime addedAt;
  const ListWord({
    required this.listId,
    required this.wordKey,
    required this.position,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['list_id'] = Variable<int>(listId);
    map['word_key'] = Variable<String>(wordKey);
    map['position'] = Variable<int>(position);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  ListWordsCompanion toCompanion(bool nullToAbsent) {
    return ListWordsCompanion(
      listId: Value(listId),
      wordKey: Value(wordKey),
      position: Value(position),
      addedAt: Value(addedAt),
    );
  }

  factory ListWord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListWord(
      listId: serializer.fromJson<int>(json['listId']),
      wordKey: serializer.fromJson<String>(json['wordKey']),
      position: serializer.fromJson<int>(json['position']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'listId': serializer.toJson<int>(listId),
      'wordKey': serializer.toJson<String>(wordKey),
      'position': serializer.toJson<int>(position),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  ListWord copyWith({
    int? listId,
    String? wordKey,
    int? position,
    DateTime? addedAt,
  }) => ListWord(
    listId: listId ?? this.listId,
    wordKey: wordKey ?? this.wordKey,
    position: position ?? this.position,
    addedAt: addedAt ?? this.addedAt,
  );
  ListWord copyWithCompanion(ListWordsCompanion data) {
    return ListWord(
      listId: data.listId.present ? data.listId.value : this.listId,
      wordKey: data.wordKey.present ? data.wordKey.value : this.wordKey,
      position: data.position.present ? data.position.value : this.position,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListWord(')
          ..write('listId: $listId, ')
          ..write('wordKey: $wordKey, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(listId, wordKey, position, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListWord &&
          other.listId == this.listId &&
          other.wordKey == this.wordKey &&
          other.position == this.position &&
          other.addedAt == this.addedAt);
}

class ListWordsCompanion extends UpdateCompanion<ListWord> {
  final Value<int> listId;
  final Value<String> wordKey;
  final Value<int> position;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const ListWordsCompanion({
    this.listId = const Value.absent(),
    this.wordKey = const Value.absent(),
    this.position = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ListWordsCompanion.insert({
    required int listId,
    required String wordKey,
    this.position = const Value.absent(),
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : listId = Value(listId),
       wordKey = Value(wordKey),
       addedAt = Value(addedAt);
  static Insertable<ListWord> custom({
    Expression<int>? listId,
    Expression<String>? wordKey,
    Expression<int>? position,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (listId != null) 'list_id': listId,
      if (wordKey != null) 'word_key': wordKey,
      if (position != null) 'position': position,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ListWordsCompanion copyWith({
    Value<int>? listId,
    Value<String>? wordKey,
    Value<int>? position,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return ListWordsCompanion(
      listId: listId ?? this.listId,
      wordKey: wordKey ?? this.wordKey,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (listId.present) {
      map['list_id'] = Variable<int>(listId.value);
    }
    if (wordKey.present) {
      map['word_key'] = Variable<String>(wordKey.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListWordsCompanion(')
          ..write('listId: $listId, ')
          ..write('wordKey: $wordKey, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserCollectionsTable extends UserCollections
    with TableInfo<$UserCollectionsTable, UserCollection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserCollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
    'slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    slug,
    kind,
    name,
    color,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserCollection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('slug')) {
      context.handle(
        _slugMeta,
        slug.isAcceptableOrUnknown(data['slug']!, _slugMeta),
      );
    } else if (isInserting) {
      context.missing(_slugMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserCollection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserCollection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      slug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slug'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $UserCollectionsTable createAlias(String alias) {
    return $UserCollectionsTable(attachedDatabase, alias);
  }
}

class UserCollection extends DataClass implements Insertable<UserCollection> {
  final int id;

  /// The stable id every screen and every mix source uses: `bookmarks`,
  /// `reading`, or `u{n}` for a user collection.
  final String slug;

  /// system | user
  final String kind;
  final String name;

  /// An index into `MullColors.tagHues`, or null for the theme accent.
  final int? color;
  final DateTime createdAt;
  const UserCollection({
    required this.id,
    required this.slug,
    required this.kind,
    required this.name,
    this.color,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['slug'] = Variable<String>(slug);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UserCollectionsCompanion toCompanion(bool nullToAbsent) {
    return UserCollectionsCompanion(
      id: Value(id),
      slug: Value(slug),
      kind: Value(kind),
      name: Value(name),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      createdAt: Value(createdAt),
    );
  }

  factory UserCollection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserCollection(
      id: serializer.fromJson<int>(json['id']),
      slug: serializer.fromJson<String>(json['slug']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int?>(json['color']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'slug': serializer.toJson<String>(slug),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int?>(color),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  UserCollection copyWith({
    int? id,
    String? slug,
    String? kind,
    String? name,
    Value<int?> color = const Value.absent(),
    DateTime? createdAt,
  }) => UserCollection(
    id: id ?? this.id,
    slug: slug ?? this.slug,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    color: color.present ? color.value : this.color,
    createdAt: createdAt ?? this.createdAt,
  );
  UserCollection copyWithCompanion(UserCollectionsCompanion data) {
    return UserCollection(
      id: data.id.present ? data.id.value : this.id,
      slug: data.slug.present ? data.slug.value : this.slug,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserCollection(')
          ..write('id: $id, ')
          ..write('slug: $slug, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, slug, kind, name, color, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserCollection &&
          other.id == this.id &&
          other.slug == this.slug &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.color == this.color &&
          other.createdAt == this.createdAt);
}

class UserCollectionsCompanion extends UpdateCompanion<UserCollection> {
  final Value<int> id;
  final Value<String> slug;
  final Value<String> kind;
  final Value<String> name;
  final Value<int?> color;
  final Value<DateTime> createdAt;
  const UserCollectionsCompanion({
    this.id = const Value.absent(),
    this.slug = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  UserCollectionsCompanion.insert({
    this.id = const Value.absent(),
    required String slug,
    required String kind,
    required String name,
    this.color = const Value.absent(),
    required DateTime createdAt,
  }) : slug = Value(slug),
       kind = Value(kind),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<UserCollection> custom({
    Expression<int>? id,
    Expression<String>? slug,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<int>? color,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (slug != null) 'slug': slug,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  UserCollectionsCompanion copyWith({
    Value<int>? id,
    Value<String>? slug,
    Value<String>? kind,
    Value<String>? name,
    Value<int?>? color,
    Value<DateTime>? createdAt,
  }) {
    return UserCollectionsCompanion(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserCollectionsCompanion(')
          ..write('id: $id, ')
          ..write('slug: $slug, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $UserCollectionWordsTable extends UserCollectionWords
    with TableInfo<$UserCollectionWordsTable, UserCollectionWord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserCollectionWordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<int> collectionId = GeneratedColumn<int>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES user_collections (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _wordKeyMeta = const VerificationMeta(
    'wordKey',
  );
  @override
  late final GeneratedColumn<String> wordKey = GeneratedColumn<String>(
    'word_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    collectionId,
    wordKey,
    position,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_collection_words';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserCollectionWord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('word_key')) {
      context.handle(
        _wordKeyMeta,
        wordKey.isAcceptableOrUnknown(data['word_key']!, _wordKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_wordKeyMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collectionId, wordKey};
  @override
  UserCollectionWord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserCollectionWord(
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}collection_id'],
      )!,
      wordKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_key'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $UserCollectionWordsTable createAlias(String alias) {
    return $UserCollectionWordsTable(attachedDatabase, alias);
  }
}

class UserCollectionWord extends DataClass
    implements Insertable<UserCollectionWord> {
  final int collectionId;
  final String wordKey;
  final int position;
  final DateTime addedAt;
  const UserCollectionWord({
    required this.collectionId,
    required this.wordKey,
    required this.position,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection_id'] = Variable<int>(collectionId);
    map['word_key'] = Variable<String>(wordKey);
    map['position'] = Variable<int>(position);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  UserCollectionWordsCompanion toCompanion(bool nullToAbsent) {
    return UserCollectionWordsCompanion(
      collectionId: Value(collectionId),
      wordKey: Value(wordKey),
      position: Value(position),
      addedAt: Value(addedAt),
    );
  }

  factory UserCollectionWord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserCollectionWord(
      collectionId: serializer.fromJson<int>(json['collectionId']),
      wordKey: serializer.fromJson<String>(json['wordKey']),
      position: serializer.fromJson<int>(json['position']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collectionId': serializer.toJson<int>(collectionId),
      'wordKey': serializer.toJson<String>(wordKey),
      'position': serializer.toJson<int>(position),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  UserCollectionWord copyWith({
    int? collectionId,
    String? wordKey,
    int? position,
    DateTime? addedAt,
  }) => UserCollectionWord(
    collectionId: collectionId ?? this.collectionId,
    wordKey: wordKey ?? this.wordKey,
    position: position ?? this.position,
    addedAt: addedAt ?? this.addedAt,
  );
  UserCollectionWord copyWithCompanion(UserCollectionWordsCompanion data) {
    return UserCollectionWord(
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      wordKey: data.wordKey.present ? data.wordKey.value : this.wordKey,
      position: data.position.present ? data.position.value : this.position,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserCollectionWord(')
          ..write('collectionId: $collectionId, ')
          ..write('wordKey: $wordKey, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collectionId, wordKey, position, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserCollectionWord &&
          other.collectionId == this.collectionId &&
          other.wordKey == this.wordKey &&
          other.position == this.position &&
          other.addedAt == this.addedAt);
}

class UserCollectionWordsCompanion extends UpdateCompanion<UserCollectionWord> {
  final Value<int> collectionId;
  final Value<String> wordKey;
  final Value<int> position;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const UserCollectionWordsCompanion({
    this.collectionId = const Value.absent(),
    this.wordKey = const Value.absent(),
    this.position = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserCollectionWordsCompanion.insert({
    required int collectionId,
    required String wordKey,
    this.position = const Value.absent(),
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : collectionId = Value(collectionId),
       wordKey = Value(wordKey),
       addedAt = Value(addedAt);
  static Insertable<UserCollectionWord> custom({
    Expression<int>? collectionId,
    Expression<String>? wordKey,
    Expression<int>? position,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collectionId != null) 'collection_id': collectionId,
      if (wordKey != null) 'word_key': wordKey,
      if (position != null) 'position': position,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserCollectionWordsCompanion copyWith({
    Value<int>? collectionId,
    Value<String>? wordKey,
    Value<int>? position,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return UserCollectionWordsCompanion(
      collectionId: collectionId ?? this.collectionId,
      wordKey: wordKey ?? this.wordKey,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collectionId.present) {
      map['collection_id'] = Variable<int>(collectionId.value);
    }
    if (wordKey.present) {
      map['word_key'] = Variable<String>(wordKey.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserCollectionWordsCompanion(')
          ..write('collectionId: $collectionId, ')
          ..write('wordKey: $wordKey, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeenTable extends Seen with TableInfo<$SeenTable, SeenWord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordKeyMeta = const VerificationMeta(
    'wordKey',
  );
  @override
  late final GeneratedColumn<String> wordKey = GeneratedColumn<String>(
    'word_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seenCountMeta = const VerificationMeta(
    'seenCount',
  );
  @override
  late final GeneratedColumn<int> seenCount = GeneratedColumn<int>(
    'seen_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta(
    'firstSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstSeenAt = GeneratedColumn<DateTime>(
    'first_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    wordKey,
    seenCount,
    firstSeenAt,
    lastSeenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seen';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeenWord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word_key')) {
      context.handle(
        _wordKeyMeta,
        wordKey.isAcceptableOrUnknown(data['word_key']!, _wordKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_wordKeyMeta);
    }
    if (data.containsKey('seen_count')) {
      context.handle(
        _seenCountMeta,
        seenCount.isAcceptableOrUnknown(data['seen_count']!, _seenCountMeta),
      );
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
        _firstSeenAtMeta,
        firstSeenAt.isAcceptableOrUnknown(
          data['first_seen_at']!,
          _firstSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstSeenAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {wordKey};
  @override
  SeenWord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeenWord(
      wordKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_key'],
      )!,
      seenCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seen_count'],
      )!,
      firstSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_seen_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
    );
  }

  @override
  $SeenTable createAlias(String alias) {
    return $SeenTable(attachedDatabase, alias);
  }
}

class SeenWord extends DataClass implements Insertable<SeenWord> {
  final String wordKey;
  final int seenCount;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  const SeenWord({
    required this.wordKey,
    required this.seenCount,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word_key'] = Variable<String>(wordKey);
    map['seen_count'] = Variable<int>(seenCount);
    map['first_seen_at'] = Variable<DateTime>(firstSeenAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    return map;
  }

  SeenCompanion toCompanion(bool nullToAbsent) {
    return SeenCompanion(
      wordKey: Value(wordKey),
      seenCount: Value(seenCount),
      firstSeenAt: Value(firstSeenAt),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory SeenWord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeenWord(
      wordKey: serializer.fromJson<String>(json['wordKey']),
      seenCount: serializer.fromJson<int>(json['seenCount']),
      firstSeenAt: serializer.fromJson<DateTime>(json['firstSeenAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'wordKey': serializer.toJson<String>(wordKey),
      'seenCount': serializer.toJson<int>(seenCount),
      'firstSeenAt': serializer.toJson<DateTime>(firstSeenAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
    };
  }

  SeenWord copyWith({
    String? wordKey,
    int? seenCount,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
  }) => SeenWord(
    wordKey: wordKey ?? this.wordKey,
    seenCount: seenCount ?? this.seenCount,
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );
  SeenWord copyWithCompanion(SeenCompanion data) {
    return SeenWord(
      wordKey: data.wordKey.present ? data.wordKey.value : this.wordKey,
      seenCount: data.seenCount.present ? data.seenCount.value : this.seenCount,
      firstSeenAt: data.firstSeenAt.present
          ? data.firstSeenAt.value
          : this.firstSeenAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeenWord(')
          ..write('wordKey: $wordKey, ')
          ..write('seenCount: $seenCount, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(wordKey, seenCount, firstSeenAt, lastSeenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeenWord &&
          other.wordKey == this.wordKey &&
          other.seenCount == this.seenCount &&
          other.firstSeenAt == this.firstSeenAt &&
          other.lastSeenAt == this.lastSeenAt);
}

class SeenCompanion extends UpdateCompanion<SeenWord> {
  final Value<String> wordKey;
  final Value<int> seenCount;
  final Value<DateTime> firstSeenAt;
  final Value<DateTime> lastSeenAt;
  final Value<int> rowid;
  const SeenCompanion({
    this.wordKey = const Value.absent(),
    this.seenCount = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeenCompanion.insert({
    required String wordKey,
    this.seenCount = const Value.absent(),
    required DateTime firstSeenAt,
    required DateTime lastSeenAt,
    this.rowid = const Value.absent(),
  }) : wordKey = Value(wordKey),
       firstSeenAt = Value(firstSeenAt),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<SeenWord> custom({
    Expression<String>? wordKey,
    Expression<int>? seenCount,
    Expression<DateTime>? firstSeenAt,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (wordKey != null) 'word_key': wordKey,
      if (seenCount != null) 'seen_count': seenCount,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeenCompanion copyWith({
    Value<String>? wordKey,
    Value<int>? seenCount,
    Value<DateTime>? firstSeenAt,
    Value<DateTime>? lastSeenAt,
    Value<int>? rowid,
  }) {
    return SeenCompanion(
      wordKey: wordKey ?? this.wordKey,
      seenCount: seenCount ?? this.seenCount,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (wordKey.present) {
      map['word_key'] = Variable<String>(wordKey.value);
    }
    if (seenCount.present) {
      map['seen_count'] = Variable<int>(seenCount.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<DateTime>(firstSeenAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeenCompanion(')
          ..write('wordKey: $wordKey, ')
          ..write('seenCount: $seenCount, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeenEventsTable extends SeenEvents
    with TableInfo<$SeenEventsTable, SeenEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeenEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _wordKeyMeta = const VerificationMeta(
    'wordKey',
  );
  @override
  late final GeneratedColumn<String> wordKey = GeneratedColumn<String>(
    'word_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, wordKey, at];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seen_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeenEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('word_key')) {
      context.handle(
        _wordKeyMeta,
        wordKey.isAcceptableOrUnknown(data['word_key']!, _wordKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_wordKeyMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SeenEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeenEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      wordKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_key'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
    );
  }

  @override
  $SeenEventsTable createAlias(String alias) {
    return $SeenEventsTable(attachedDatabase, alias);
  }
}

class SeenEvent extends DataClass implements Insertable<SeenEvent> {
  final int id;
  final String wordKey;
  final DateTime at;
  const SeenEvent({required this.id, required this.wordKey, required this.at});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['word_key'] = Variable<String>(wordKey);
    map['at'] = Variable<DateTime>(at);
    return map;
  }

  SeenEventsCompanion toCompanion(bool nullToAbsent) {
    return SeenEventsCompanion(
      id: Value(id),
      wordKey: Value(wordKey),
      at: Value(at),
    );
  }

  factory SeenEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeenEvent(
      id: serializer.fromJson<int>(json['id']),
      wordKey: serializer.fromJson<String>(json['wordKey']),
      at: serializer.fromJson<DateTime>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'wordKey': serializer.toJson<String>(wordKey),
      'at': serializer.toJson<DateTime>(at),
    };
  }

  SeenEvent copyWith({int? id, String? wordKey, DateTime? at}) => SeenEvent(
    id: id ?? this.id,
    wordKey: wordKey ?? this.wordKey,
    at: at ?? this.at,
  );
  SeenEvent copyWithCompanion(SeenEventsCompanion data) {
    return SeenEvent(
      id: data.id.present ? data.id.value : this.id,
      wordKey: data.wordKey.present ? data.wordKey.value : this.wordKey,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeenEvent(')
          ..write('id: $id, ')
          ..write('wordKey: $wordKey, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, wordKey, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeenEvent &&
          other.id == this.id &&
          other.wordKey == this.wordKey &&
          other.at == this.at);
}

class SeenEventsCompanion extends UpdateCompanion<SeenEvent> {
  final Value<int> id;
  final Value<String> wordKey;
  final Value<DateTime> at;
  const SeenEventsCompanion({
    this.id = const Value.absent(),
    this.wordKey = const Value.absent(),
    this.at = const Value.absent(),
  });
  SeenEventsCompanion.insert({
    this.id = const Value.absent(),
    required String wordKey,
    required DateTime at,
  }) : wordKey = Value(wordKey),
       at = Value(at);
  static Insertable<SeenEvent> custom({
    Expression<int>? id,
    Expression<String>? wordKey,
    Expression<DateTime>? at,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (wordKey != null) 'word_key': wordKey,
      if (at != null) 'at': at,
    });
  }

  SeenEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? wordKey,
    Value<DateTime>? at,
  }) {
    return SeenEventsCompanion(
      id: id ?? this.id,
      wordKey: wordKey ?? this.wordKey,
      at: at ?? this.at,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (wordKey.present) {
      map['word_key'] = Variable<String>(wordKey.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeenEventsCompanion(')
          ..write('id: $id, ')
          ..write('wordKey: $wordKey, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }
}

class $RecentSearchesTable extends RecentSearches
    with TableInfo<$RecentSearchesTable, RecentSearch> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentSearchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [query, at];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_searches';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecentSearch> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {query};
  @override
  RecentSearch map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentSearch(
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
    );
  }

  @override
  $RecentSearchesTable createAlias(String alias) {
    return $RecentSearchesTable(attachedDatabase, alias);
  }
}

class RecentSearch extends DataClass implements Insertable<RecentSearch> {
  final String query;
  final DateTime at;
  const RecentSearch({required this.query, required this.at});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['query'] = Variable<String>(query);
    map['at'] = Variable<DateTime>(at);
    return map;
  }

  RecentSearchesCompanion toCompanion(bool nullToAbsent) {
    return RecentSearchesCompanion(query: Value(query), at: Value(at));
  }

  factory RecentSearch.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentSearch(
      query: serializer.fromJson<String>(json['query']),
      at: serializer.fromJson<DateTime>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'query': serializer.toJson<String>(query),
      'at': serializer.toJson<DateTime>(at),
    };
  }

  RecentSearch copyWith({String? query, DateTime? at}) =>
      RecentSearch(query: query ?? this.query, at: at ?? this.at);
  RecentSearch copyWithCompanion(RecentSearchesCompanion data) {
    return RecentSearch(
      query: data.query.present ? data.query.value : this.query,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentSearch(')
          ..write('query: $query, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(query, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentSearch &&
          other.query == this.query &&
          other.at == this.at);
}

class RecentSearchesCompanion extends UpdateCompanion<RecentSearch> {
  final Value<String> query;
  final Value<DateTime> at;
  final Value<int> rowid;
  const RecentSearchesCompanion({
    this.query = const Value.absent(),
    this.at = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecentSearchesCompanion.insert({
    required String query,
    required DateTime at,
    this.rowid = const Value.absent(),
  }) : query = Value(query),
       at = Value(at);
  static Insertable<RecentSearch> custom({
    Expression<String>? query,
    Expression<DateTime>? at,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (query != null) 'query': query,
      if (at != null) 'at': at,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecentSearchesCompanion copyWith({
    Value<String>? query,
    Value<DateTime>? at,
    Value<int>? rowid,
  }) {
    return RecentSearchesCompanion(
      query: query ?? this.query,
      at: at ?? this.at,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentSearchesCompanion(')
          ..write('query: $query, ')
          ..write('at: $at, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecentLookupsTable extends RecentLookups
    with TableInfo<$RecentLookupsTable, RecentLookup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentLookupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordKeyMeta = const VerificationMeta(
    'wordKey',
  );
  @override
  late final GeneratedColumn<String> wordKey = GeneratedColumn<String>(
    'word_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [wordKey, at];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_lookups';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecentLookup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word_key')) {
      context.handle(
        _wordKeyMeta,
        wordKey.isAcceptableOrUnknown(data['word_key']!, _wordKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_wordKeyMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {wordKey};
  @override
  RecentLookup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentLookup(
      wordKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_key'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
    );
  }

  @override
  $RecentLookupsTable createAlias(String alias) {
    return $RecentLookupsTable(attachedDatabase, alias);
  }
}

class RecentLookup extends DataClass implements Insertable<RecentLookup> {
  final String wordKey;
  final DateTime at;
  const RecentLookup({required this.wordKey, required this.at});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word_key'] = Variable<String>(wordKey);
    map['at'] = Variable<DateTime>(at);
    return map;
  }

  RecentLookupsCompanion toCompanion(bool nullToAbsent) {
    return RecentLookupsCompanion(wordKey: Value(wordKey), at: Value(at));
  }

  factory RecentLookup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentLookup(
      wordKey: serializer.fromJson<String>(json['wordKey']),
      at: serializer.fromJson<DateTime>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'wordKey': serializer.toJson<String>(wordKey),
      'at': serializer.toJson<DateTime>(at),
    };
  }

  RecentLookup copyWith({String? wordKey, DateTime? at}) =>
      RecentLookup(wordKey: wordKey ?? this.wordKey, at: at ?? this.at);
  RecentLookup copyWithCompanion(RecentLookupsCompanion data) {
    return RecentLookup(
      wordKey: data.wordKey.present ? data.wordKey.value : this.wordKey,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentLookup(')
          ..write('wordKey: $wordKey, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(wordKey, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentLookup &&
          other.wordKey == this.wordKey &&
          other.at == this.at);
}

class RecentLookupsCompanion extends UpdateCompanion<RecentLookup> {
  final Value<String> wordKey;
  final Value<DateTime> at;
  final Value<int> rowid;
  const RecentLookupsCompanion({
    this.wordKey = const Value.absent(),
    this.at = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecentLookupsCompanion.insert({
    required String wordKey,
    required DateTime at,
    this.rowid = const Value.absent(),
  }) : wordKey = Value(wordKey),
       at = Value(at);
  static Insertable<RecentLookup> custom({
    Expression<String>? wordKey,
    Expression<DateTime>? at,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (wordKey != null) 'word_key': wordKey,
      if (at != null) 'at': at,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecentLookupsCompanion copyWith({
    Value<String>? wordKey,
    Value<DateTime>? at,
    Value<int>? rowid,
  }) {
    return RecentLookupsCompanion(
      wordKey: wordKey ?? this.wordKey,
      at: at ?? this.at,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (wordKey.present) {
      map['word_key'] = Variable<String>(wordKey.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentLookupsCompanion(')
          ..write('wordKey: $wordKey, ')
          ..write('at: $at, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MixesTable extends Mixes with TableInfo<$MixesTable, Mix> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MixesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPresetMeta = const VerificationMeta(
    'isPreset',
  );
  @override
  late final GeneratedColumn<bool> isPreset = GeneratedColumn<bool>(
    'is_preset',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_preset" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    isPreset,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mixes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Mix> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_preset')) {
      context.handle(
        _isPresetMeta,
        isPreset.isAcceptableOrUnknown(data['is_preset']!, _isPresetMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Mix map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Mix(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isPreset: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_preset'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MixesTable createAlias(String alias) {
    return $MixesTable(attachedDatabase, alias);
  }
}

class Mix extends DataClass implements Insertable<Mix> {
  final int id;
  final String name;
  final bool isPreset;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Mix({
    required this.id,
    required this.name,
    required this.isPreset,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['is_preset'] = Variable<bool>(isPreset);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MixesCompanion toCompanion(bool nullToAbsent) {
    return MixesCompanion(
      id: Value(id),
      name: Value(name),
      isPreset: Value(isPreset),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Mix.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Mix(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      isPreset: serializer.fromJson<bool>(json['isPreset']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'isPreset': serializer.toJson<bool>(isPreset),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Mix copyWith({
    int? id,
    String? name,
    bool? isPreset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Mix(
    id: id ?? this.id,
    name: name ?? this.name,
    isPreset: isPreset ?? this.isPreset,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Mix copyWithCompanion(MixesCompanion data) {
    return Mix(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isPreset: data.isPreset.present ? data.isPreset.value : this.isPreset,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Mix(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isPreset: $isPreset, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, isPreset, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Mix &&
          other.id == this.id &&
          other.name == this.name &&
          other.isPreset == this.isPreset &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MixesCompanion extends UpdateCompanion<Mix> {
  final Value<int> id;
  final Value<String> name;
  final Value<bool> isPreset;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const MixesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isPreset = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  MixesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.isPreset = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Mix> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<bool>? isPreset,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isPreset != null) 'is_preset': isPreset,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  MixesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<bool>? isPreset,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return MixesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      isPreset: isPreset ?? this.isPreset,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isPreset.present) {
      map['is_preset'] = Variable<bool>(isPreset.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MixesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isPreset: $isPreset, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $MixSourcesTable extends MixSources
    with TableInfo<$MixSourcesTable, MixSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MixSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mixIdMeta = const VerificationMeta('mixId');
  @override
  late final GeneratedColumn<int> mixId = GeneratedColumn<int>(
    'mix_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mixes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _collectionSlugMeta = const VerificationMeta(
    'collectionSlug',
  );
  @override
  late final GeneratedColumn<String> collectionSlug = GeneratedColumn<String>(
    'collection_slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [mixId, collectionSlug];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mix_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<MixSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mix_id')) {
      context.handle(
        _mixIdMeta,
        mixId.isAcceptableOrUnknown(data['mix_id']!, _mixIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mixIdMeta);
    }
    if (data.containsKey('collection_slug')) {
      context.handle(
        _collectionSlugMeta,
        collectionSlug.isAcceptableOrUnknown(
          data['collection_slug']!,
          _collectionSlugMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionSlugMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mixId, collectionSlug};
  @override
  MixSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MixSource(
      mixId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mix_id'],
      )!,
      collectionSlug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_slug'],
      )!,
    );
  }

  @override
  $MixSourcesTable createAlias(String alias) {
    return $MixSourcesTable(attachedDatabase, alias);
  }
}

class MixSource extends DataClass implements Insertable<MixSource> {
  final int mixId;
  final String collectionSlug;
  const MixSource({required this.mixId, required this.collectionSlug});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mix_id'] = Variable<int>(mixId);
    map['collection_slug'] = Variable<String>(collectionSlug);
    return map;
  }

  MixSourcesCompanion toCompanion(bool nullToAbsent) {
    return MixSourcesCompanion(
      mixId: Value(mixId),
      collectionSlug: Value(collectionSlug),
    );
  }

  factory MixSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MixSource(
      mixId: serializer.fromJson<int>(json['mixId']),
      collectionSlug: serializer.fromJson<String>(json['collectionSlug']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mixId': serializer.toJson<int>(mixId),
      'collectionSlug': serializer.toJson<String>(collectionSlug),
    };
  }

  MixSource copyWith({int? mixId, String? collectionSlug}) => MixSource(
    mixId: mixId ?? this.mixId,
    collectionSlug: collectionSlug ?? this.collectionSlug,
  );
  MixSource copyWithCompanion(MixSourcesCompanion data) {
    return MixSource(
      mixId: data.mixId.present ? data.mixId.value : this.mixId,
      collectionSlug: data.collectionSlug.present
          ? data.collectionSlug.value
          : this.collectionSlug,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MixSource(')
          ..write('mixId: $mixId, ')
          ..write('collectionSlug: $collectionSlug')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mixId, collectionSlug);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MixSource &&
          other.mixId == this.mixId &&
          other.collectionSlug == this.collectionSlug);
}

class MixSourcesCompanion extends UpdateCompanion<MixSource> {
  final Value<int> mixId;
  final Value<String> collectionSlug;
  final Value<int> rowid;
  const MixSourcesCompanion({
    this.mixId = const Value.absent(),
    this.collectionSlug = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MixSourcesCompanion.insert({
    required int mixId,
    required String collectionSlug,
    this.rowid = const Value.absent(),
  }) : mixId = Value(mixId),
       collectionSlug = Value(collectionSlug);
  static Insertable<MixSource> custom({
    Expression<int>? mixId,
    Expression<String>? collectionSlug,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mixId != null) 'mix_id': mixId,
      if (collectionSlug != null) 'collection_slug': collectionSlug,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MixSourcesCompanion copyWith({
    Value<int>? mixId,
    Value<String>? collectionSlug,
    Value<int>? rowid,
  }) {
    return MixSourcesCompanion(
      mixId: mixId ?? this.mixId,
      collectionSlug: collectionSlug ?? this.collectionSlug,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mixId.present) {
      map['mix_id'] = Variable<int>(mixId.value);
    }
    if (collectionSlug.present) {
      map['collection_slug'] = Variable<String>(collectionSlug.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MixSourcesCompanion(')
          ..write('mixId: $mixId, ')
          ..write('collectionSlug: $collectionSlug, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MixSettingsTable extends MixSettings
    with TableInfo<$MixSettingsTable, MixSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MixSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mixIdMeta = const VerificationMeta('mixId');
  @override
  late final GeneratedColumn<int> mixId = GeneratedColumn<int>(
    'mix_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mixes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _seenPolicyMeta = const VerificationMeta(
    'seenPolicy',
  );
  @override
  late final GeneratedColumn<String> seenPolicy = GeneratedColumn<String>(
    'seen_policy',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shuffleMeta = const VerificationMeta(
    'shuffle',
  );
  @override
  late final GeneratedColumn<bool> shuffle = GeneratedColumn<bool>(
    'shuffle',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("shuffle" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _includeBookmarkedOnlyMeta =
      const VerificationMeta('includeBookmarkedOnly');
  @override
  late final GeneratedColumn<bool> includeBookmarkedOnly =
      GeneratedColumn<bool>(
        'include_bookmarked_only',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("include_bookmarked_only" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  @override
  List<GeneratedColumn> get $columns => [
    mixId,
    seenPolicy,
    shuffle,
    includeBookmarkedOnly,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mix_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<MixSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mix_id')) {
      context.handle(
        _mixIdMeta,
        mixId.isAcceptableOrUnknown(data['mix_id']!, _mixIdMeta),
      );
    }
    if (data.containsKey('seen_policy')) {
      context.handle(
        _seenPolicyMeta,
        seenPolicy.isAcceptableOrUnknown(data['seen_policy']!, _seenPolicyMeta),
      );
    } else if (isInserting) {
      context.missing(_seenPolicyMeta);
    }
    if (data.containsKey('shuffle')) {
      context.handle(
        _shuffleMeta,
        shuffle.isAcceptableOrUnknown(data['shuffle']!, _shuffleMeta),
      );
    }
    if (data.containsKey('include_bookmarked_only')) {
      context.handle(
        _includeBookmarkedOnlyMeta,
        includeBookmarkedOnly.isAcceptableOrUnknown(
          data['include_bookmarked_only']!,
          _includeBookmarkedOnlyMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mixId};
  @override
  MixSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MixSetting(
      mixId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mix_id'],
      )!,
      seenPolicy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seen_policy'],
      )!,
      shuffle: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}shuffle'],
      )!,
      includeBookmarkedOnly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}include_bookmarked_only'],
      )!,
    );
  }

  @override
  $MixSettingsTable createAlias(String alias) {
    return $MixSettingsTable(attachedDatabase, alias);
  }
}

class MixSetting extends DataClass implements Insertable<MixSetting> {
  final int mixId;

  /// unseen_only | light | mixed | review_only
  final String seenPolicy;
  final bool shuffle;
  final bool includeBookmarkedOnly;
  const MixSetting({
    required this.mixId,
    required this.seenPolicy,
    required this.shuffle,
    required this.includeBookmarkedOnly,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mix_id'] = Variable<int>(mixId);
    map['seen_policy'] = Variable<String>(seenPolicy);
    map['shuffle'] = Variable<bool>(shuffle);
    map['include_bookmarked_only'] = Variable<bool>(includeBookmarkedOnly);
    return map;
  }

  MixSettingsCompanion toCompanion(bool nullToAbsent) {
    return MixSettingsCompanion(
      mixId: Value(mixId),
      seenPolicy: Value(seenPolicy),
      shuffle: Value(shuffle),
      includeBookmarkedOnly: Value(includeBookmarkedOnly),
    );
  }

  factory MixSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MixSetting(
      mixId: serializer.fromJson<int>(json['mixId']),
      seenPolicy: serializer.fromJson<String>(json['seenPolicy']),
      shuffle: serializer.fromJson<bool>(json['shuffle']),
      includeBookmarkedOnly: serializer.fromJson<bool>(
        json['includeBookmarkedOnly'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mixId': serializer.toJson<int>(mixId),
      'seenPolicy': serializer.toJson<String>(seenPolicy),
      'shuffle': serializer.toJson<bool>(shuffle),
      'includeBookmarkedOnly': serializer.toJson<bool>(includeBookmarkedOnly),
    };
  }

  MixSetting copyWith({
    int? mixId,
    String? seenPolicy,
    bool? shuffle,
    bool? includeBookmarkedOnly,
  }) => MixSetting(
    mixId: mixId ?? this.mixId,
    seenPolicy: seenPolicy ?? this.seenPolicy,
    shuffle: shuffle ?? this.shuffle,
    includeBookmarkedOnly: includeBookmarkedOnly ?? this.includeBookmarkedOnly,
  );
  MixSetting copyWithCompanion(MixSettingsCompanion data) {
    return MixSetting(
      mixId: data.mixId.present ? data.mixId.value : this.mixId,
      seenPolicy: data.seenPolicy.present
          ? data.seenPolicy.value
          : this.seenPolicy,
      shuffle: data.shuffle.present ? data.shuffle.value : this.shuffle,
      includeBookmarkedOnly: data.includeBookmarkedOnly.present
          ? data.includeBookmarkedOnly.value
          : this.includeBookmarkedOnly,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MixSetting(')
          ..write('mixId: $mixId, ')
          ..write('seenPolicy: $seenPolicy, ')
          ..write('shuffle: $shuffle, ')
          ..write('includeBookmarkedOnly: $includeBookmarkedOnly')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(mixId, seenPolicy, shuffle, includeBookmarkedOnly);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MixSetting &&
          other.mixId == this.mixId &&
          other.seenPolicy == this.seenPolicy &&
          other.shuffle == this.shuffle &&
          other.includeBookmarkedOnly == this.includeBookmarkedOnly);
}

class MixSettingsCompanion extends UpdateCompanion<MixSetting> {
  final Value<int> mixId;
  final Value<String> seenPolicy;
  final Value<bool> shuffle;
  final Value<bool> includeBookmarkedOnly;
  const MixSettingsCompanion({
    this.mixId = const Value.absent(),
    this.seenPolicy = const Value.absent(),
    this.shuffle = const Value.absent(),
    this.includeBookmarkedOnly = const Value.absent(),
  });
  MixSettingsCompanion.insert({
    this.mixId = const Value.absent(),
    required String seenPolicy,
    this.shuffle = const Value.absent(),
    this.includeBookmarkedOnly = const Value.absent(),
  }) : seenPolicy = Value(seenPolicy);
  static Insertable<MixSetting> custom({
    Expression<int>? mixId,
    Expression<String>? seenPolicy,
    Expression<bool>? shuffle,
    Expression<bool>? includeBookmarkedOnly,
  }) {
    return RawValuesInsertable({
      if (mixId != null) 'mix_id': mixId,
      if (seenPolicy != null) 'seen_policy': seenPolicy,
      if (shuffle != null) 'shuffle': shuffle,
      if (includeBookmarkedOnly != null)
        'include_bookmarked_only': includeBookmarkedOnly,
    });
  }

  MixSettingsCompanion copyWith({
    Value<int>? mixId,
    Value<String>? seenPolicy,
    Value<bool>? shuffle,
    Value<bool>? includeBookmarkedOnly,
  }) {
    return MixSettingsCompanion(
      mixId: mixId ?? this.mixId,
      seenPolicy: seenPolicy ?? this.seenPolicy,
      shuffle: shuffle ?? this.shuffle,
      includeBookmarkedOnly:
          includeBookmarkedOnly ?? this.includeBookmarkedOnly,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mixId.present) {
      map['mix_id'] = Variable<int>(mixId.value);
    }
    if (seenPolicy.present) {
      map['seen_policy'] = Variable<String>(seenPolicy.value);
    }
    if (shuffle.present) {
      map['shuffle'] = Variable<bool>(shuffle.value);
    }
    if (includeBookmarkedOnly.present) {
      map['include_bookmarked_only'] = Variable<bool>(
        includeBookmarkedOnly.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MixSettingsCompanion(')
          ..write('mixId: $mixId, ')
          ..write('seenPolicy: $seenPolicy, ')
          ..write('shuffle: $shuffle, ')
          ..write('includeBookmarkedOnly: $includeBookmarkedOnly')
          ..write(')'))
        .toString();
  }
}

class $WordContextsTable extends WordContexts
    with TableInfo<$WordContextsTable, WordContext> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordContextsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _wordKeyMeta = const VerificationMeta(
    'wordKey',
  );
  @override
  late final GeneratedColumn<String> wordKey = GeneratedColumn<String>(
    'word_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contextTextMeta = const VerificationMeta(
    'contextText',
  );
  @override
  late final GeneratedColumn<String> contextText = GeneratedColumn<String>(
    'context_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceHintMeta = const VerificationMeta(
    'sourceHint',
  );
  @override
  late final GeneratedColumn<String> sourceHint = GeneratedColumn<String>(
    'source_hint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    wordKey,
    contextText,
    capturedAt,
    sourceHint,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_contexts';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordContext> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('word_key')) {
      context.handle(
        _wordKeyMeta,
        wordKey.isAcceptableOrUnknown(data['word_key']!, _wordKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_wordKeyMeta);
    }
    if (data.containsKey('context_text')) {
      context.handle(
        _contextTextMeta,
        contextText.isAcceptableOrUnknown(
          data['context_text']!,
          _contextTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contextTextMeta);
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('source_hint')) {
      context.handle(
        _sourceHintMeta,
        sourceHint.isAcceptableOrUnknown(data['source_hint']!, _sourceHintMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WordContext map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordContext(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      wordKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_key'],
      )!,
      contextText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context_text'],
      )!,
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      )!,
      sourceHint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_hint'],
      ),
    );
  }

  @override
  $WordContextsTable createAlias(String alias) {
    return $WordContextsTable(attachedDatabase, alias);
  }
}

class WordContext extends DataClass implements Insertable<WordContext> {
  final int id;
  final String wordKey;
  final String contextText;
  final DateTime capturedAt;
  final String? sourceHint;
  const WordContext({
    required this.id,
    required this.wordKey,
    required this.contextText,
    required this.capturedAt,
    this.sourceHint,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['word_key'] = Variable<String>(wordKey);
    map['context_text'] = Variable<String>(contextText);
    map['captured_at'] = Variable<DateTime>(capturedAt);
    if (!nullToAbsent || sourceHint != null) {
      map['source_hint'] = Variable<String>(sourceHint);
    }
    return map;
  }

  WordContextsCompanion toCompanion(bool nullToAbsent) {
    return WordContextsCompanion(
      id: Value(id),
      wordKey: Value(wordKey),
      contextText: Value(contextText),
      capturedAt: Value(capturedAt),
      sourceHint: sourceHint == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceHint),
    );
  }

  factory WordContext.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordContext(
      id: serializer.fromJson<int>(json['id']),
      wordKey: serializer.fromJson<String>(json['wordKey']),
      contextText: serializer.fromJson<String>(json['contextText']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      sourceHint: serializer.fromJson<String?>(json['sourceHint']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'wordKey': serializer.toJson<String>(wordKey),
      'contextText': serializer.toJson<String>(contextText),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'sourceHint': serializer.toJson<String?>(sourceHint),
    };
  }

  WordContext copyWith({
    int? id,
    String? wordKey,
    String? contextText,
    DateTime? capturedAt,
    Value<String?> sourceHint = const Value.absent(),
  }) => WordContext(
    id: id ?? this.id,
    wordKey: wordKey ?? this.wordKey,
    contextText: contextText ?? this.contextText,
    capturedAt: capturedAt ?? this.capturedAt,
    sourceHint: sourceHint.present ? sourceHint.value : this.sourceHint,
  );
  WordContext copyWithCompanion(WordContextsCompanion data) {
    return WordContext(
      id: data.id.present ? data.id.value : this.id,
      wordKey: data.wordKey.present ? data.wordKey.value : this.wordKey,
      contextText: data.contextText.present
          ? data.contextText.value
          : this.contextText,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      sourceHint: data.sourceHint.present
          ? data.sourceHint.value
          : this.sourceHint,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordContext(')
          ..write('id: $id, ')
          ..write('wordKey: $wordKey, ')
          ..write('contextText: $contextText, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('sourceHint: $sourceHint')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, wordKey, contextText, capturedAt, sourceHint);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordContext &&
          other.id == this.id &&
          other.wordKey == this.wordKey &&
          other.contextText == this.contextText &&
          other.capturedAt == this.capturedAt &&
          other.sourceHint == this.sourceHint);
}

class WordContextsCompanion extends UpdateCompanion<WordContext> {
  final Value<int> id;
  final Value<String> wordKey;
  final Value<String> contextText;
  final Value<DateTime> capturedAt;
  final Value<String?> sourceHint;
  const WordContextsCompanion({
    this.id = const Value.absent(),
    this.wordKey = const Value.absent(),
    this.contextText = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.sourceHint = const Value.absent(),
  });
  WordContextsCompanion.insert({
    this.id = const Value.absent(),
    required String wordKey,
    required String contextText,
    required DateTime capturedAt,
    this.sourceHint = const Value.absent(),
  }) : wordKey = Value(wordKey),
       contextText = Value(contextText),
       capturedAt = Value(capturedAt);
  static Insertable<WordContext> custom({
    Expression<int>? id,
    Expression<String>? wordKey,
    Expression<String>? contextText,
    Expression<DateTime>? capturedAt,
    Expression<String>? sourceHint,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (wordKey != null) 'word_key': wordKey,
      if (contextText != null) 'context_text': contextText,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (sourceHint != null) 'source_hint': sourceHint,
    });
  }

  WordContextsCompanion copyWith({
    Value<int>? id,
    Value<String>? wordKey,
    Value<String>? contextText,
    Value<DateTime>? capturedAt,
    Value<String?>? sourceHint,
  }) {
    return WordContextsCompanion(
      id: id ?? this.id,
      wordKey: wordKey ?? this.wordKey,
      contextText: contextText ?? this.contextText,
      capturedAt: capturedAt ?? this.capturedAt,
      sourceHint: sourceHint ?? this.sourceHint,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (wordKey.present) {
      map['word_key'] = Variable<String>(wordKey.value);
    }
    if (contextText.present) {
      map['context_text'] = Variable<String>(contextText.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (sourceHint.present) {
      map['source_hint'] = Variable<String>(sourceHint.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordContextsCompanion(')
          ..write('id: $id, ')
          ..write('wordKey: $wordKey, ')
          ..write('contextText: $contextText, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('sourceHint: $sourceHint')
          ..write(')'))
        .toString();
  }
}

class $QuizSessionsTable extends QuizSessions
    with TableInfo<$QuizSessionsTable, QuizSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuizSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _collectionSlugMeta = const VerificationMeta(
    'collectionSlug',
  );
  @override
  late final GeneratedColumn<String> collectionSlug = GeneratedColumn<String>(
    'collection_slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _questionCountMeta = const VerificationMeta(
    'questionCount',
  );
  @override
  late final GeneratedColumn<int> questionCount = GeneratedColumn<int>(
    'question_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctCountMeta = const VerificationMeta(
    'correctCount',
  );
  @override
  late final GeneratedColumn<int> correctCount = GeneratedColumn<int>(
    'correct_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wasAbandonedMeta = const VerificationMeta(
    'wasAbandoned',
  );
  @override
  late final GeneratedColumn<bool> wasAbandoned = GeneratedColumn<bool>(
    'was_abandoned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("was_abandoned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    collectionSlug,
    startedAt,
    completedAt,
    questionCount,
    correctCount,
    wasAbandoned,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quiz_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuizSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('collection_slug')) {
      context.handle(
        _collectionSlugMeta,
        collectionSlug.isAcceptableOrUnknown(
          data['collection_slug']!,
          _collectionSlugMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionSlugMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('question_count')) {
      context.handle(
        _questionCountMeta,
        questionCount.isAcceptableOrUnknown(
          data['question_count']!,
          _questionCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_questionCountMeta);
    }
    if (data.containsKey('correct_count')) {
      context.handle(
        _correctCountMeta,
        correctCount.isAcceptableOrUnknown(
          data['correct_count']!,
          _correctCountMeta,
        ),
      );
    }
    if (data.containsKey('was_abandoned')) {
      context.handle(
        _wasAbandonedMeta,
        wasAbandoned.isAcceptableOrUnknown(
          data['was_abandoned']!,
          _wasAbandonedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuizSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuizSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      collectionSlug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_slug'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      questionCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}question_count'],
      )!,
      correctCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct_count'],
      )!,
      wasAbandoned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}was_abandoned'],
      )!,
    );
  }

  @override
  $QuizSessionsTable createAlias(String alias) {
    return $QuizSessionsTable(attachedDatabase, alias);
  }
}

class QuizSession extends DataClass implements Insertable<QuizSession> {
  final int id;
  final String collectionSlug;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int questionCount;
  final int correctCount;
  final bool wasAbandoned;
  const QuizSession({
    required this.id,
    required this.collectionSlug,
    required this.startedAt,
    this.completedAt,
    required this.questionCount,
    required this.correctCount,
    required this.wasAbandoned,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['collection_slug'] = Variable<String>(collectionSlug);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['question_count'] = Variable<int>(questionCount);
    map['correct_count'] = Variable<int>(correctCount);
    map['was_abandoned'] = Variable<bool>(wasAbandoned);
    return map;
  }

  QuizSessionsCompanion toCompanion(bool nullToAbsent) {
    return QuizSessionsCompanion(
      id: Value(id),
      collectionSlug: Value(collectionSlug),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      questionCount: Value(questionCount),
      correctCount: Value(correctCount),
      wasAbandoned: Value(wasAbandoned),
    );
  }

  factory QuizSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuizSession(
      id: serializer.fromJson<int>(json['id']),
      collectionSlug: serializer.fromJson<String>(json['collectionSlug']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      questionCount: serializer.fromJson<int>(json['questionCount']),
      correctCount: serializer.fromJson<int>(json['correctCount']),
      wasAbandoned: serializer.fromJson<bool>(json['wasAbandoned']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'collectionSlug': serializer.toJson<String>(collectionSlug),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'questionCount': serializer.toJson<int>(questionCount),
      'correctCount': serializer.toJson<int>(correctCount),
      'wasAbandoned': serializer.toJson<bool>(wasAbandoned),
    };
  }

  QuizSession copyWith({
    int? id,
    String? collectionSlug,
    DateTime? startedAt,
    Value<DateTime?> completedAt = const Value.absent(),
    int? questionCount,
    int? correctCount,
    bool? wasAbandoned,
  }) => QuizSession(
    id: id ?? this.id,
    collectionSlug: collectionSlug ?? this.collectionSlug,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    questionCount: questionCount ?? this.questionCount,
    correctCount: correctCount ?? this.correctCount,
    wasAbandoned: wasAbandoned ?? this.wasAbandoned,
  );
  QuizSession copyWithCompanion(QuizSessionsCompanion data) {
    return QuizSession(
      id: data.id.present ? data.id.value : this.id,
      collectionSlug: data.collectionSlug.present
          ? data.collectionSlug.value
          : this.collectionSlug,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      questionCount: data.questionCount.present
          ? data.questionCount.value
          : this.questionCount,
      correctCount: data.correctCount.present
          ? data.correctCount.value
          : this.correctCount,
      wasAbandoned: data.wasAbandoned.present
          ? data.wasAbandoned.value
          : this.wasAbandoned,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuizSession(')
          ..write('id: $id, ')
          ..write('collectionSlug: $collectionSlug, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('questionCount: $questionCount, ')
          ..write('correctCount: $correctCount, ')
          ..write('wasAbandoned: $wasAbandoned')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    collectionSlug,
    startedAt,
    completedAt,
    questionCount,
    correctCount,
    wasAbandoned,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuizSession &&
          other.id == this.id &&
          other.collectionSlug == this.collectionSlug &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.questionCount == this.questionCount &&
          other.correctCount == this.correctCount &&
          other.wasAbandoned == this.wasAbandoned);
}

class QuizSessionsCompanion extends UpdateCompanion<QuizSession> {
  final Value<int> id;
  final Value<String> collectionSlug;
  final Value<DateTime> startedAt;
  final Value<DateTime?> completedAt;
  final Value<int> questionCount;
  final Value<int> correctCount;
  final Value<bool> wasAbandoned;
  const QuizSessionsCompanion({
    this.id = const Value.absent(),
    this.collectionSlug = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.questionCount = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.wasAbandoned = const Value.absent(),
  });
  QuizSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String collectionSlug,
    required DateTime startedAt,
    this.completedAt = const Value.absent(),
    required int questionCount,
    this.correctCount = const Value.absent(),
    this.wasAbandoned = const Value.absent(),
  }) : collectionSlug = Value(collectionSlug),
       startedAt = Value(startedAt),
       questionCount = Value(questionCount);
  static Insertable<QuizSession> custom({
    Expression<int>? id,
    Expression<String>? collectionSlug,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? questionCount,
    Expression<int>? correctCount,
    Expression<bool>? wasAbandoned,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (collectionSlug != null) 'collection_slug': collectionSlug,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (questionCount != null) 'question_count': questionCount,
      if (correctCount != null) 'correct_count': correctCount,
      if (wasAbandoned != null) 'was_abandoned': wasAbandoned,
    });
  }

  QuizSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? collectionSlug,
    Value<DateTime>? startedAt,
    Value<DateTime?>? completedAt,
    Value<int>? questionCount,
    Value<int>? correctCount,
    Value<bool>? wasAbandoned,
  }) {
    return QuizSessionsCompanion(
      id: id ?? this.id,
      collectionSlug: collectionSlug ?? this.collectionSlug,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      questionCount: questionCount ?? this.questionCount,
      correctCount: correctCount ?? this.correctCount,
      wasAbandoned: wasAbandoned ?? this.wasAbandoned,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (collectionSlug.present) {
      map['collection_slug'] = Variable<String>(collectionSlug.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (questionCount.present) {
      map['question_count'] = Variable<int>(questionCount.value);
    }
    if (correctCount.present) {
      map['correct_count'] = Variable<int>(correctCount.value);
    }
    if (wasAbandoned.present) {
      map['was_abandoned'] = Variable<bool>(wasAbandoned.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuizSessionsCompanion(')
          ..write('id: $id, ')
          ..write('collectionSlug: $collectionSlug, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('questionCount: $questionCount, ')
          ..write('correctCount: $correctCount, ')
          ..write('wasAbandoned: $wasAbandoned')
          ..write(')'))
        .toString();
  }
}

class $QuizAnswersTable extends QuizAnswers
    with TableInfo<$QuizAnswersTable, QuizAnswer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuizAnswersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES quiz_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _wordKeyMeta = const VerificationMeta(
    'wordKey',
  );
  @override
  late final GeneratedColumn<String> wordKey = GeneratedColumn<String>(
    'word_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionTypeMeta = const VerificationMeta(
    'questionType',
  );
  @override
  late final GeneratedColumn<String> questionType = GeneratedColumn<String>(
    'question_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wasCorrectMeta = const VerificationMeta(
    'wasCorrect',
  );
  @override
  late final GeneratedColumn<bool> wasCorrect = GeneratedColumn<bool>(
    'was_correct',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("was_correct" IN (0, 1))',
    ),
  );
  static const VerificationMeta _chosenKeyMeta = const VerificationMeta(
    'chosenKey',
  );
  @override
  late final GeneratedColumn<String> chosenKey = GeneratedColumn<String>(
    'chosen_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _answeredAtMeta = const VerificationMeta(
    'answeredAt',
  );
  @override
  late final GeneratedColumn<DateTime> answeredAt = GeneratedColumn<DateTime>(
    'answered_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    wordKey,
    questionType,
    wasCorrect,
    chosenKey,
    answeredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quiz_answers';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuizAnswer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('word_key')) {
      context.handle(
        _wordKeyMeta,
        wordKey.isAcceptableOrUnknown(data['word_key']!, _wordKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_wordKeyMeta);
    }
    if (data.containsKey('question_type')) {
      context.handle(
        _questionTypeMeta,
        questionType.isAcceptableOrUnknown(
          data['question_type']!,
          _questionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_questionTypeMeta);
    }
    if (data.containsKey('was_correct')) {
      context.handle(
        _wasCorrectMeta,
        wasCorrect.isAcceptableOrUnknown(data['was_correct']!, _wasCorrectMeta),
      );
    } else if (isInserting) {
      context.missing(_wasCorrectMeta);
    }
    if (data.containsKey('chosen_key')) {
      context.handle(
        _chosenKeyMeta,
        chosenKey.isAcceptableOrUnknown(data['chosen_key']!, _chosenKeyMeta),
      );
    }
    if (data.containsKey('answered_at')) {
      context.handle(
        _answeredAtMeta,
        answeredAt.isAcceptableOrUnknown(data['answered_at']!, _answeredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_answeredAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuizAnswer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuizAnswer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      wordKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_key'],
      )!,
      questionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_type'],
      )!,
      wasCorrect: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}was_correct'],
      )!,
      chosenKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chosen_key'],
      ),
      answeredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}answered_at'],
      )!,
    );
  }

  @override
  $QuizAnswersTable createAlias(String alias) {
    return $QuizAnswersTable(attachedDatabase, alias);
  }
}

class QuizAnswer extends DataClass implements Insertable<QuizAnswer> {
  final int id;
  final int sessionId;
  final String wordKey;
  final String questionType;
  final bool wasCorrect;
  final String? chosenKey;
  final DateTime answeredAt;
  const QuizAnswer({
    required this.id,
    required this.sessionId,
    required this.wordKey,
    required this.questionType,
    required this.wasCorrect,
    this.chosenKey,
    required this.answeredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['word_key'] = Variable<String>(wordKey);
    map['question_type'] = Variable<String>(questionType);
    map['was_correct'] = Variable<bool>(wasCorrect);
    if (!nullToAbsent || chosenKey != null) {
      map['chosen_key'] = Variable<String>(chosenKey);
    }
    map['answered_at'] = Variable<DateTime>(answeredAt);
    return map;
  }

  QuizAnswersCompanion toCompanion(bool nullToAbsent) {
    return QuizAnswersCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      wordKey: Value(wordKey),
      questionType: Value(questionType),
      wasCorrect: Value(wasCorrect),
      chosenKey: chosenKey == null && nullToAbsent
          ? const Value.absent()
          : Value(chosenKey),
      answeredAt: Value(answeredAt),
    );
  }

  factory QuizAnswer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuizAnswer(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      wordKey: serializer.fromJson<String>(json['wordKey']),
      questionType: serializer.fromJson<String>(json['questionType']),
      wasCorrect: serializer.fromJson<bool>(json['wasCorrect']),
      chosenKey: serializer.fromJson<String?>(json['chosenKey']),
      answeredAt: serializer.fromJson<DateTime>(json['answeredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'wordKey': serializer.toJson<String>(wordKey),
      'questionType': serializer.toJson<String>(questionType),
      'wasCorrect': serializer.toJson<bool>(wasCorrect),
      'chosenKey': serializer.toJson<String?>(chosenKey),
      'answeredAt': serializer.toJson<DateTime>(answeredAt),
    };
  }

  QuizAnswer copyWith({
    int? id,
    int? sessionId,
    String? wordKey,
    String? questionType,
    bool? wasCorrect,
    Value<String?> chosenKey = const Value.absent(),
    DateTime? answeredAt,
  }) => QuizAnswer(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    wordKey: wordKey ?? this.wordKey,
    questionType: questionType ?? this.questionType,
    wasCorrect: wasCorrect ?? this.wasCorrect,
    chosenKey: chosenKey.present ? chosenKey.value : this.chosenKey,
    answeredAt: answeredAt ?? this.answeredAt,
  );
  QuizAnswer copyWithCompanion(QuizAnswersCompanion data) {
    return QuizAnswer(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      wordKey: data.wordKey.present ? data.wordKey.value : this.wordKey,
      questionType: data.questionType.present
          ? data.questionType.value
          : this.questionType,
      wasCorrect: data.wasCorrect.present
          ? data.wasCorrect.value
          : this.wasCorrect,
      chosenKey: data.chosenKey.present ? data.chosenKey.value : this.chosenKey,
      answeredAt: data.answeredAt.present
          ? data.answeredAt.value
          : this.answeredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuizAnswer(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('wordKey: $wordKey, ')
          ..write('questionType: $questionType, ')
          ..write('wasCorrect: $wasCorrect, ')
          ..write('chosenKey: $chosenKey, ')
          ..write('answeredAt: $answeredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    wordKey,
    questionType,
    wasCorrect,
    chosenKey,
    answeredAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuizAnswer &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.wordKey == this.wordKey &&
          other.questionType == this.questionType &&
          other.wasCorrect == this.wasCorrect &&
          other.chosenKey == this.chosenKey &&
          other.answeredAt == this.answeredAt);
}

class QuizAnswersCompanion extends UpdateCompanion<QuizAnswer> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<String> wordKey;
  final Value<String> questionType;
  final Value<bool> wasCorrect;
  final Value<String?> chosenKey;
  final Value<DateTime> answeredAt;
  const QuizAnswersCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.wordKey = const Value.absent(),
    this.questionType = const Value.absent(),
    this.wasCorrect = const Value.absent(),
    this.chosenKey = const Value.absent(),
    this.answeredAt = const Value.absent(),
  });
  QuizAnswersCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required String wordKey,
    required String questionType,
    required bool wasCorrect,
    this.chosenKey = const Value.absent(),
    required DateTime answeredAt,
  }) : sessionId = Value(sessionId),
       wordKey = Value(wordKey),
       questionType = Value(questionType),
       wasCorrect = Value(wasCorrect),
       answeredAt = Value(answeredAt);
  static Insertable<QuizAnswer> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<String>? wordKey,
    Expression<String>? questionType,
    Expression<bool>? wasCorrect,
    Expression<String>? chosenKey,
    Expression<DateTime>? answeredAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (wordKey != null) 'word_key': wordKey,
      if (questionType != null) 'question_type': questionType,
      if (wasCorrect != null) 'was_correct': wasCorrect,
      if (chosenKey != null) 'chosen_key': chosenKey,
      if (answeredAt != null) 'answered_at': answeredAt,
    });
  }

  QuizAnswersCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<String>? wordKey,
    Value<String>? questionType,
    Value<bool>? wasCorrect,
    Value<String?>? chosenKey,
    Value<DateTime>? answeredAt,
  }) {
    return QuizAnswersCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      wordKey: wordKey ?? this.wordKey,
      questionType: questionType ?? this.questionType,
      wasCorrect: wasCorrect ?? this.wasCorrect,
      chosenKey: chosenKey ?? this.chosenKey,
      answeredAt: answeredAt ?? this.answeredAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (wordKey.present) {
      map['word_key'] = Variable<String>(wordKey.value);
    }
    if (questionType.present) {
      map['question_type'] = Variable<String>(questionType.value);
    }
    if (wasCorrect.present) {
      map['was_correct'] = Variable<bool>(wasCorrect.value);
    }
    if (chosenKey.present) {
      map['chosen_key'] = Variable<String>(chosenKey.value);
    }
    if (answeredAt.present) {
      map['answered_at'] = Variable<DateTime>(answeredAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuizAnswersCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('wordKey: $wordKey, ')
          ..write('questionType: $questionType, ')
          ..write('wasCorrect: $wasCorrect, ')
          ..write('chosenKey: $chosenKey, ')
          ..write('answeredAt: $answeredAt')
          ..write(')'))
        .toString();
  }
}

class $CollectionStatsTable extends CollectionStats
    with TableInfo<$CollectionStatsTable, CollectionStat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionSlugMeta = const VerificationMeta(
    'collectionSlug',
  );
  @override
  late final GeneratedColumn<String> collectionSlug = GeneratedColumn<String>(
    'collection_slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timesOpenedMeta = const VerificationMeta(
    'timesOpened',
  );
  @override
  late final GeneratedColumn<int> timesOpened = GeneratedColumn<int>(
    'times_opened',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    collectionSlug,
    timesOpened,
    lastOpenedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collection_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectionStat> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection_slug')) {
      context.handle(
        _collectionSlugMeta,
        collectionSlug.isAcceptableOrUnknown(
          data['collection_slug']!,
          _collectionSlugMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionSlugMeta);
    }
    if (data.containsKey('times_opened')) {
      context.handle(
        _timesOpenedMeta,
        timesOpened.isAcceptableOrUnknown(
          data['times_opened']!,
          _timesOpenedMeta,
        ),
      );
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collectionSlug};
  @override
  CollectionStat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionStat(
      collectionSlug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_slug'],
      )!,
      timesOpened: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}times_opened'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      ),
    );
  }

  @override
  $CollectionStatsTable createAlias(String alias) {
    return $CollectionStatsTable(attachedDatabase, alias);
  }
}

class CollectionStat extends DataClass implements Insertable<CollectionStat> {
  final String collectionSlug;
  final int timesOpened;
  final DateTime? lastOpenedAt;
  const CollectionStat({
    required this.collectionSlug,
    required this.timesOpened,
    this.lastOpenedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection_slug'] = Variable<String>(collectionSlug);
    map['times_opened'] = Variable<int>(timesOpened);
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    }
    return map;
  }

  CollectionStatsCompanion toCompanion(bool nullToAbsent) {
    return CollectionStatsCompanion(
      collectionSlug: Value(collectionSlug),
      timesOpened: Value(timesOpened),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
    );
  }

  factory CollectionStat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionStat(
      collectionSlug: serializer.fromJson<String>(json['collectionSlug']),
      timesOpened: serializer.fromJson<int>(json['timesOpened']),
      lastOpenedAt: serializer.fromJson<DateTime?>(json['lastOpenedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collectionSlug': serializer.toJson<String>(collectionSlug),
      'timesOpened': serializer.toJson<int>(timesOpened),
      'lastOpenedAt': serializer.toJson<DateTime?>(lastOpenedAt),
    };
  }

  CollectionStat copyWith({
    String? collectionSlug,
    int? timesOpened,
    Value<DateTime?> lastOpenedAt = const Value.absent(),
  }) => CollectionStat(
    collectionSlug: collectionSlug ?? this.collectionSlug,
    timesOpened: timesOpened ?? this.timesOpened,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
  );
  CollectionStat copyWithCompanion(CollectionStatsCompanion data) {
    return CollectionStat(
      collectionSlug: data.collectionSlug.present
          ? data.collectionSlug.value
          : this.collectionSlug,
      timesOpened: data.timesOpened.present
          ? data.timesOpened.value
          : this.timesOpened,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionStat(')
          ..write('collectionSlug: $collectionSlug, ')
          ..write('timesOpened: $timesOpened, ')
          ..write('lastOpenedAt: $lastOpenedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collectionSlug, timesOpened, lastOpenedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionStat &&
          other.collectionSlug == this.collectionSlug &&
          other.timesOpened == this.timesOpened &&
          other.lastOpenedAt == this.lastOpenedAt);
}

class CollectionStatsCompanion extends UpdateCompanion<CollectionStat> {
  final Value<String> collectionSlug;
  final Value<int> timesOpened;
  final Value<DateTime?> lastOpenedAt;
  final Value<int> rowid;
  const CollectionStatsCompanion({
    this.collectionSlug = const Value.absent(),
    this.timesOpened = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollectionStatsCompanion.insert({
    required String collectionSlug,
    this.timesOpened = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : collectionSlug = Value(collectionSlug);
  static Insertable<CollectionStat> custom({
    Expression<String>? collectionSlug,
    Expression<int>? timesOpened,
    Expression<DateTime>? lastOpenedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collectionSlug != null) 'collection_slug': collectionSlug,
      if (timesOpened != null) 'times_opened': timesOpened,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollectionStatsCompanion copyWith({
    Value<String>? collectionSlug,
    Value<int>? timesOpened,
    Value<DateTime?>? lastOpenedAt,
    Value<int>? rowid,
  }) {
    return CollectionStatsCompanion(
      collectionSlug: collectionSlug ?? this.collectionSlug,
      timesOpened: timesOpened ?? this.timesOpened,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collectionSlug.present) {
      map['collection_slug'] = Variable<String>(collectionSlug.value);
    }
    if (timesOpened.present) {
      map['times_opened'] = Variable<int>(timesOpened.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionStatsCompanion(')
          ..write('collectionSlug: $collectionSlug, ')
          ..write('timesOpened: $timesOpened, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppStateTable extends AppState
    with TableInfo<$AppStateTable, AppStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppStateRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppStateTable createAlias(String alias) {
    return $AppStateTable(attachedDatabase, alias);
  }
}

class AppStateRow extends DataClass implements Insertable<AppStateRow> {
  final String key;
  final String value;
  const AppStateRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppStateCompanion toCompanion(bool nullToAbsent) {
    return AppStateCompanion(key: Value(key), value: Value(value));
  }

  factory AppStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppStateRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppStateRow copyWith({String? key, String? value}) =>
      AppStateRow(key: key ?? this.key, value: value ?? this.value);
  AppStateRow copyWithCompanion(AppStateCompanion data) {
    return AppStateRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppStateRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppStateRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppStateCompanion extends UpdateCompanion<AppStateRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppStateCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppStateRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppStateCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppStateCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$UserDatabase extends GeneratedDatabase {
  _$UserDatabase(QueryExecutor e) : super(e);
  $UserDatabaseManager get managers => $UserDatabaseManager(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $WordListsTable wordLists = $WordListsTable(this);
  late final $ListWordsTable listWords = $ListWordsTable(this);
  late final $UserCollectionsTable userCollections = $UserCollectionsTable(
    this,
  );
  late final $UserCollectionWordsTable userCollectionWords =
      $UserCollectionWordsTable(this);
  late final $SeenTable seen = $SeenTable(this);
  late final $SeenEventsTable seenEvents = $SeenEventsTable(this);
  late final $RecentSearchesTable recentSearches = $RecentSearchesTable(this);
  late final $RecentLookupsTable recentLookups = $RecentLookupsTable(this);
  late final $MixesTable mixes = $MixesTable(this);
  late final $MixSourcesTable mixSources = $MixSourcesTable(this);
  late final $MixSettingsTable mixSettings = $MixSettingsTable(this);
  late final $WordContextsTable wordContexts = $WordContextsTable(this);
  late final $QuizSessionsTable quizSessions = $QuizSessionsTable(this);
  late final $QuizAnswersTable quizAnswers = $QuizAnswersTable(this);
  late final $CollectionStatsTable collectionStats = $CollectionStatsTable(
    this,
  );
  late final $AppStateTable appState = $AppStateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    bookmarks,
    notes,
    wordLists,
    listWords,
    userCollections,
    userCollectionWords,
    seen,
    seenEvents,
    recentSearches,
    recentLookups,
    mixes,
    mixSources,
    mixSettings,
    wordContexts,
    quizSessions,
    quizAnswers,
    collectionStats,
    appState,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'word_lists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('list_words', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'user_collections',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('user_collection_words', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'mixes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('mix_sources', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'mixes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('mix_settings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'quiz_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('quiz_answers', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$BookmarksTableCreateCompanionBuilder = BookmarksCompanion Function({
  required String wordKey,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$BookmarksTableUpdateCompanionBuilder = BookmarksCompanion Function({
  Value<String> wordKey,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$BookmarksTableFilterComposer
    extends Composer<_$UserDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$UserDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$UserDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get wordKey =>
      $composableBuilder(column: $table.wordKey, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $BookmarksTable,
          Bookmark,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (Bookmark, BaseReferences<_$UserDatabase, $BookmarksTable, Bookmark>),
          Bookmark,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableManager(_$UserDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> wordKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion(
                wordKey: wordKey,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String wordKey,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion.insert(
                wordKey: wordKey,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookmarksTable, Bookmark>(table),
                  BaseReferences<_$UserDatabase, $BookmarksTable, Bookmark>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $BookmarksTable,
      Bookmark,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (Bookmark, BaseReferences<_$UserDatabase, $BookmarksTable, Bookmark>),
      Bookmark,
      PrefetchHooks Function()
    >;
typedef $$NotesTableCreateCompanionBuilder = NotesCompanion Function({
  required String wordKey,
  required String body,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$NotesTableUpdateCompanionBuilder = NotesCompanion Function({
  Value<String> wordKey,
  Value<String> body,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$NotesTableFilterComposer extends Composer<_$UserDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer
    extends Composer<_$UserDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$UserDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get wordKey =>
      $composableBuilder(column: $table.wordKey, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, BaseReferences<_$UserDatabase, $NotesTable, Note>),
          Note,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$UserDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> wordKey = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                wordKey: wordKey,
                body: body,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String wordKey,
                required String body,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                wordKey: wordKey,
                body: body,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotesTable, Note>(table),
                  BaseReferences<_$UserDatabase, $NotesTable, Note>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, BaseReferences<_$UserDatabase, $NotesTable, Note>),
      Note,
      PrefetchHooks Function()
    >;
typedef $$WordListsTableCreateCompanionBuilder = WordListsCompanion Function({
  Value<int> id,
  required String name,
  Value<int?> color,
  Value<bool> isReading,
  required DateTime createdAt,
});
typedef $$WordListsTableUpdateCompanionBuilder = WordListsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int?> color,
  Value<bool> isReading,
  Value<DateTime> createdAt,
});

final class $$WordListsTableReferences
    extends BaseReferences<_$UserDatabase, $WordListsTable, WordList> {
  $$WordListsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ListWordsTable, List<ListWord>>
  _listWordsRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.listWords,
    aliasName: 'word_lists__id__list_words__list_id',
  );

  $$ListWordsTableProcessedTableManager get listWordsRefs {
    final manager = $$ListWordsTableTableManager(
      $_db,
      $_db.listWords,
    ).filter((f) => f.listId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_listWordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WordListsTableFilterComposer
    extends Composer<_$UserDatabase, $WordListsTable> {
  $$WordListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isReading => $composableBuilder(
    column: $table.isReading,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> listWordsRefs(
    Expression<bool> Function($$ListWordsTableFilterComposer f) f,
  ) {
    final $$ListWordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.listWords,
      getReferencedColumn: (t) => t.listId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ListWordsTableFilterComposer(
            $db: $db,
            $table: $db.listWords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WordListsTableOrderingComposer
    extends Composer<_$UserDatabase, $WordListsTable> {
  $$WordListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isReading => $composableBuilder(
    column: $table.isReading,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WordListsTableAnnotationComposer
    extends Composer<_$UserDatabase, $WordListsTable> {
  $$WordListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<bool> get isReading =>
      $composableBuilder(column: $table.isReading, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> listWordsRefs<T extends Object>(
    Expression<T> Function($$ListWordsTableAnnotationComposer a) f,
  ) {
    final $$ListWordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.listWords,
      getReferencedColumn: (t) => t.listId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ListWordsTableAnnotationComposer(
            $db: $db,
            $table: $db.listWords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WordListsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $WordListsTable,
          WordList,
          $$WordListsTableFilterComposer,
          $$WordListsTableOrderingComposer,
          $$WordListsTableAnnotationComposer,
          $$WordListsTableCreateCompanionBuilder,
          $$WordListsTableUpdateCompanionBuilder,
          (WordList, $$WordListsTableReferences),
          WordList,
          PrefetchHooks Function({bool listWordsRefs})
        > {
  $$WordListsTableTableManager(_$UserDatabase db, $WordListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<bool> isReading = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => WordListsCompanion(
                id: id,
                name: name,
                color: color,
                isReading: isReading,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int?> color = const Value.absent(),
                Value<bool> isReading = const Value.absent(),
                required DateTime createdAt,
              }) => WordListsCompanion.insert(
                id: id,
                name: name,
                color: color,
                isReading: isReading,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WordListsTable, WordList>(table),
                  $$WordListsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({listWordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (listWordsRefs) db.listWords],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (listWordsRefs)
                    await $_getPrefetchedData<
                      WordList,
                      $WordListsTable,
                      ListWord
                    >(
                      currentTable: table,
                      referencedTable: $$WordListsTableReferences
                          ._listWordsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WordListsTableReferences(
                            db,
                            table,
                            p0,
                          ).listWordsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.listId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WordListsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $WordListsTable,
      WordList,
      $$WordListsTableFilterComposer,
      $$WordListsTableOrderingComposer,
      $$WordListsTableAnnotationComposer,
      $$WordListsTableCreateCompanionBuilder,
      $$WordListsTableUpdateCompanionBuilder,
      (WordList, $$WordListsTableReferences),
      WordList,
      PrefetchHooks Function({bool listWordsRefs})
    >;
typedef $$ListWordsTableCreateCompanionBuilder = ListWordsCompanion Function({
  required int listId,
  required String wordKey,
  Value<int> position,
  required DateTime addedAt,
  Value<int> rowid,
});
typedef $$ListWordsTableUpdateCompanionBuilder = ListWordsCompanion Function({
  Value<int> listId,
  Value<String> wordKey,
  Value<int> position,
  Value<DateTime> addedAt,
  Value<int> rowid,
});

final class $$ListWordsTableReferences
    extends BaseReferences<_$UserDatabase, $ListWordsTable, ListWord> {
  $$ListWordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WordListsTable _listIdTable(_$UserDatabase db) =>
      db.wordLists.createAlias('list_words__list_id__word_lists__id');

  $$WordListsTableProcessedTableManager get listId {
    final $_column = $_itemColumn<int>('list_id')!;

    final manager = $$WordListsTableTableManager(
      $_db,
      $_db.wordLists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_listIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ListWordsTableFilterComposer
    extends Composer<_$UserDatabase, $ListWordsTable> {
  $$ListWordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WordListsTableFilterComposer get listId {
    final $$WordListsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.wordLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordListsTableFilterComposer(
            $db: $db,
            $table: $db.wordLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ListWordsTableOrderingComposer
    extends Composer<_$UserDatabase, $ListWordsTable> {
  $$ListWordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WordListsTableOrderingComposer get listId {
    final $$WordListsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.wordLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordListsTableOrderingComposer(
            $db: $db,
            $table: $db.wordLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ListWordsTableAnnotationComposer
    extends Composer<_$UserDatabase, $ListWordsTable> {
  $$ListWordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get wordKey =>
      $composableBuilder(column: $table.wordKey, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$WordListsTableAnnotationComposer get listId {
    final $$WordListsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.wordLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WordListsTableAnnotationComposer(
            $db: $db,
            $table: $db.wordLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ListWordsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $ListWordsTable,
          ListWord,
          $$ListWordsTableFilterComposer,
          $$ListWordsTableOrderingComposer,
          $$ListWordsTableAnnotationComposer,
          $$ListWordsTableCreateCompanionBuilder,
          $$ListWordsTableUpdateCompanionBuilder,
          (ListWord, $$ListWordsTableReferences),
          ListWord,
          PrefetchHooks Function({bool listId})
        > {
  $$ListWordsTableTableManager(_$UserDatabase db, $ListWordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListWordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListWordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListWordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> listId = const Value.absent(),
                Value<String> wordKey = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListWordsCompanion(
                listId: listId,
                wordKey: wordKey,
                position: position,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int listId,
                required String wordKey,
                Value<int> position = const Value.absent(),
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => ListWordsCompanion.insert(
                listId: listId,
                wordKey: wordKey,
                position: position,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ListWordsTable, ListWord>(table),
                  $$ListWordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({listId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (listId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.listId,
                        referencedTable: $$ListWordsTableReferences
                            ._listIdTable(db),
                        referencedColumn: $$ListWordsTableReferences
                            ._listIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ListWordsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $ListWordsTable,
      ListWord,
      $$ListWordsTableFilterComposer,
      $$ListWordsTableOrderingComposer,
      $$ListWordsTableAnnotationComposer,
      $$ListWordsTableCreateCompanionBuilder,
      $$ListWordsTableUpdateCompanionBuilder,
      (ListWord, $$ListWordsTableReferences),
      ListWord,
      PrefetchHooks Function({bool listId})
    >;
typedef $$UserCollectionsTableCreateCompanionBuilder =
    UserCollectionsCompanion Function({
      Value<int> id,
      required String slug,
      required String kind,
      required String name,
      Value<int?> color,
      required DateTime createdAt,
    });
typedef $$UserCollectionsTableUpdateCompanionBuilder =
    UserCollectionsCompanion Function({
      Value<int> id,
      Value<String> slug,
      Value<String> kind,
      Value<String> name,
      Value<int?> color,
      Value<DateTime> createdAt,
    });

final class $$UserCollectionsTableReferences
    extends
        BaseReferences<_$UserDatabase, $UserCollectionsTable, UserCollection> {
  $$UserCollectionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $UserCollectionWordsTable,
    List<UserCollectionWord>
  >
  _userCollectionWordsRefsTable(_$UserDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.userCollectionWords,
        aliasName: 'user_collections__id__user_collection_words__collection_id',
      );

  $$UserCollectionWordsTableProcessedTableManager get userCollectionWordsRefs {
    final manager = $$UserCollectionWordsTableTableManager(
      $_db,
      $_db.userCollectionWords,
    ).filter((f) => f.collectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _userCollectionWordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UserCollectionsTableFilterComposer
    extends Composer<_$UserDatabase, $UserCollectionsTable> {
  $$UserCollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> userCollectionWordsRefs(
    Expression<bool> Function($$UserCollectionWordsTableFilterComposer f) f,
  ) {
    final $$UserCollectionWordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userCollectionWords,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserCollectionWordsTableFilterComposer(
            $db: $db,
            $table: $db.userCollectionWords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UserCollectionsTableOrderingComposer
    extends Composer<_$UserDatabase, $UserCollectionsTable> {
  $$UserCollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserCollectionsTableAnnotationComposer
    extends Composer<_$UserDatabase, $UserCollectionsTable> {
  $$UserCollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> userCollectionWordsRefs<T extends Object>(
    Expression<T> Function($$UserCollectionWordsTableAnnotationComposer a) f,
  ) {
    final $$UserCollectionWordsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.userCollectionWords,
          getReferencedColumn: (t) => t.collectionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$UserCollectionWordsTableAnnotationComposer(
                $db: $db,
                $table: $db.userCollectionWords,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$UserCollectionsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $UserCollectionsTable,
          UserCollection,
          $$UserCollectionsTableFilterComposer,
          $$UserCollectionsTableOrderingComposer,
          $$UserCollectionsTableAnnotationComposer,
          $$UserCollectionsTableCreateCompanionBuilder,
          $$UserCollectionsTableUpdateCompanionBuilder,
          (UserCollection, $$UserCollectionsTableReferences),
          UserCollection,
          PrefetchHooks Function({bool userCollectionWordsRefs})
        > {
  $$UserCollectionsTableTableManager(
    _$UserDatabase db,
    $UserCollectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserCollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserCollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserCollectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> slug = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => UserCollectionsCompanion(
                id: id,
                slug: slug,
                kind: kind,
                name: name,
                color: color,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String slug,
                required String kind,
                required String name,
                Value<int?> color = const Value.absent(),
                required DateTime createdAt,
              }) => UserCollectionsCompanion.insert(
                id: id,
                slug: slug,
                kind: kind,
                name: name,
                color: color,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserCollectionsTable, UserCollection>(table),
                  $$UserCollectionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userCollectionWordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (userCollectionWordsRefs) db.userCollectionWords,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (userCollectionWordsRefs)
                    await $_getPrefetchedData<
                      UserCollection,
                      $UserCollectionsTable,
                      UserCollectionWord
                    >(
                      currentTable: table,
                      referencedTable: $$UserCollectionsTableReferences
                          ._userCollectionWordsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$UserCollectionsTableReferences(
                            db,
                            table,
                            p0,
                          ).userCollectionWordsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.collectionId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$UserCollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $UserCollectionsTable,
      UserCollection,
      $$UserCollectionsTableFilterComposer,
      $$UserCollectionsTableOrderingComposer,
      $$UserCollectionsTableAnnotationComposer,
      $$UserCollectionsTableCreateCompanionBuilder,
      $$UserCollectionsTableUpdateCompanionBuilder,
      (UserCollection, $$UserCollectionsTableReferences),
      UserCollection,
      PrefetchHooks Function({bool userCollectionWordsRefs})
    >;
typedef $$UserCollectionWordsTableCreateCompanionBuilder =
    UserCollectionWordsCompanion Function({
      required int collectionId,
      required String wordKey,
      Value<int> position,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$UserCollectionWordsTableUpdateCompanionBuilder =
    UserCollectionWordsCompanion Function({
      Value<int> collectionId,
      Value<String> wordKey,
      Value<int> position,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

final class $$UserCollectionWordsTableReferences
    extends
        BaseReferences<
          _$UserDatabase,
          $UserCollectionWordsTable,
          UserCollectionWord
        > {
  $$UserCollectionWordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $UserCollectionsTable _collectionIdTable(_$UserDatabase db) =>
      db.userCollections.createAlias(
        'user_collection_words__collection_id__user_collections__id',
      );

  $$UserCollectionsTableProcessedTableManager get collectionId {
    final $_column = $_itemColumn<int>('collection_id')!;

    final manager = $$UserCollectionsTableTableManager(
      $_db,
      $_db.userCollections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_collectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$UserCollectionWordsTableFilterComposer
    extends Composer<_$UserDatabase, $UserCollectionWordsTable> {
  $$UserCollectionWordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$UserCollectionsTableFilterComposer get collectionId {
    final $$UserCollectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.userCollections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserCollectionsTableFilterComposer(
            $db: $db,
            $table: $db.userCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserCollectionWordsTableOrderingComposer
    extends Composer<_$UserDatabase, $UserCollectionWordsTable> {
  $$UserCollectionWordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$UserCollectionsTableOrderingComposer get collectionId {
    final $$UserCollectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.userCollections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserCollectionsTableOrderingComposer(
            $db: $db,
            $table: $db.userCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserCollectionWordsTableAnnotationComposer
    extends Composer<_$UserDatabase, $UserCollectionWordsTable> {
  $$UserCollectionWordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get wordKey =>
      $composableBuilder(column: $table.wordKey, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$UserCollectionsTableAnnotationComposer get collectionId {
    final $$UserCollectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.userCollections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserCollectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.userCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserCollectionWordsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $UserCollectionWordsTable,
          UserCollectionWord,
          $$UserCollectionWordsTableFilterComposer,
          $$UserCollectionWordsTableOrderingComposer,
          $$UserCollectionWordsTableAnnotationComposer,
          $$UserCollectionWordsTableCreateCompanionBuilder,
          $$UserCollectionWordsTableUpdateCompanionBuilder,
          (UserCollectionWord, $$UserCollectionWordsTableReferences),
          UserCollectionWord,
          PrefetchHooks Function({bool collectionId})
        > {
  $$UserCollectionWordsTableTableManager(
    _$UserDatabase db,
    $UserCollectionWordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserCollectionWordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserCollectionWordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$UserCollectionWordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> collectionId = const Value.absent(),
                Value<String> wordKey = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserCollectionWordsCompanion(
                collectionId: collectionId,
                wordKey: wordKey,
                position: position,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int collectionId,
                required String wordKey,
                Value<int> position = const Value.absent(),
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => UserCollectionWordsCompanion.insert(
                collectionId: collectionId,
                wordKey: wordKey,
                position: position,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserCollectionWordsTable, UserCollectionWord>(
                    table,
                  ),
                  $$UserCollectionWordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({collectionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (collectionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.collectionId,
                        referencedTable: $$UserCollectionWordsTableReferences
                            ._collectionIdTable(db),
                        referencedColumn: $$UserCollectionWordsTableReferences
                            ._collectionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$UserCollectionWordsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $UserCollectionWordsTable,
      UserCollectionWord,
      $$UserCollectionWordsTableFilterComposer,
      $$UserCollectionWordsTableOrderingComposer,
      $$UserCollectionWordsTableAnnotationComposer,
      $$UserCollectionWordsTableCreateCompanionBuilder,
      $$UserCollectionWordsTableUpdateCompanionBuilder,
      (UserCollectionWord, $$UserCollectionWordsTableReferences),
      UserCollectionWord,
      PrefetchHooks Function({bool collectionId})
    >;
typedef $$SeenTableCreateCompanionBuilder = SeenCompanion Function({
  required String wordKey,
  Value<int> seenCount,
  required DateTime firstSeenAt,
  required DateTime lastSeenAt,
  Value<int> rowid,
});
typedef $$SeenTableUpdateCompanionBuilder = SeenCompanion Function({
  Value<String> wordKey,
  Value<int> seenCount,
  Value<DateTime> firstSeenAt,
  Value<DateTime> lastSeenAt,
  Value<int> rowid,
});

class $$SeenTableFilterComposer extends Composer<_$UserDatabase, $SeenTable> {
  $$SeenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seenCount => $composableBuilder(
    column: $table.seenCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeenTableOrderingComposer extends Composer<_$UserDatabase, $SeenTable> {
  $$SeenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seenCount => $composableBuilder(
    column: $table.seenCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeenTableAnnotationComposer
    extends Composer<_$UserDatabase, $SeenTable> {
  $$SeenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get wordKey =>
      $composableBuilder(column: $table.wordKey, builder: (column) => column);

  GeneratedColumn<int> get seenCount =>
      $composableBuilder(column: $table.seenCount, builder: (column) => column);

  GeneratedColumn<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );
}

class $$SeenTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $SeenTable,
          SeenWord,
          $$SeenTableFilterComposer,
          $$SeenTableOrderingComposer,
          $$SeenTableAnnotationComposer,
          $$SeenTableCreateCompanionBuilder,
          $$SeenTableUpdateCompanionBuilder,
          (SeenWord, BaseReferences<_$UserDatabase, $SeenTable, SeenWord>),
          SeenWord,
          PrefetchHooks Function()
        > {
  $$SeenTableTableManager(_$UserDatabase db, $SeenTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeenTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeenTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> wordKey = const Value.absent(),
                Value<int> seenCount = const Value.absent(),
                Value<DateTime> firstSeenAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeenCompanion(
                wordKey: wordKey,
                seenCount: seenCount,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String wordKey,
                Value<int> seenCount = const Value.absent(),
                required DateTime firstSeenAt,
                required DateTime lastSeenAt,
                Value<int> rowid = const Value.absent(),
              }) => SeenCompanion.insert(
                wordKey: wordKey,
                seenCount: seenCount,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SeenTable, SeenWord>(table),
                  BaseReferences<_$UserDatabase, $SeenTable, SeenWord>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeenTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $SeenTable,
      SeenWord,
      $$SeenTableFilterComposer,
      $$SeenTableOrderingComposer,
      $$SeenTableAnnotationComposer,
      $$SeenTableCreateCompanionBuilder,
      $$SeenTableUpdateCompanionBuilder,
      (SeenWord, BaseReferences<_$UserDatabase, $SeenTable, SeenWord>),
      SeenWord,
      PrefetchHooks Function()
    >;
typedef $$SeenEventsTableCreateCompanionBuilder = SeenEventsCompanion Function({
  Value<int> id,
  required String wordKey,
  required DateTime at,
});
typedef $$SeenEventsTableUpdateCompanionBuilder = SeenEventsCompanion Function({
  Value<int> id,
  Value<String> wordKey,
  Value<DateTime> at,
});

class $$SeenEventsTableFilterComposer
    extends Composer<_$UserDatabase, $SeenEventsTable> {
  $$SeenEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeenEventsTableOrderingComposer
    extends Composer<_$UserDatabase, $SeenEventsTable> {
  $$SeenEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeenEventsTableAnnotationComposer
    extends Composer<_$UserDatabase, $SeenEventsTable> {
  $$SeenEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get wordKey =>
      $composableBuilder(column: $table.wordKey, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);
}

class $$SeenEventsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $SeenEventsTable,
          SeenEvent,
          $$SeenEventsTableFilterComposer,
          $$SeenEventsTableOrderingComposer,
          $$SeenEventsTableAnnotationComposer,
          $$SeenEventsTableCreateCompanionBuilder,
          $$SeenEventsTableUpdateCompanionBuilder,
          (
            SeenEvent,
            BaseReferences<_$UserDatabase, $SeenEventsTable, SeenEvent>,
          ),
          SeenEvent,
          PrefetchHooks Function()
        > {
  $$SeenEventsTableTableManager(_$UserDatabase db, $SeenEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeenEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeenEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeenEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> wordKey = const Value.absent(),
            Value<DateTime> at = const Value.absent(),
          }) => SeenEventsCompanion(id: id, wordKey: wordKey, at: at),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String wordKey,
            required DateTime at,
          }) => SeenEventsCompanion.insert(id: id, wordKey: wordKey, at: at),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SeenEventsTable, SeenEvent>(table),
                  BaseReferences<_$UserDatabase, $SeenEventsTable, SeenEvent>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeenEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $SeenEventsTable,
      SeenEvent,
      $$SeenEventsTableFilterComposer,
      $$SeenEventsTableOrderingComposer,
      $$SeenEventsTableAnnotationComposer,
      $$SeenEventsTableCreateCompanionBuilder,
      $$SeenEventsTableUpdateCompanionBuilder,
      (SeenEvent, BaseReferences<_$UserDatabase, $SeenEventsTable, SeenEvent>),
      SeenEvent,
      PrefetchHooks Function()
    >;
typedef $$RecentSearchesTableCreateCompanionBuilder =
    RecentSearchesCompanion Function({
      required String query,
      required DateTime at,
      Value<int> rowid,
    });
typedef $$RecentSearchesTableUpdateCompanionBuilder =
    RecentSearchesCompanion Function({
      Value<String> query,
      Value<DateTime> at,
      Value<int> rowid,
    });

class $$RecentSearchesTableFilterComposer
    extends Composer<_$UserDatabase, $RecentSearchesTable> {
  $$RecentSearchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecentSearchesTableOrderingComposer
    extends Composer<_$UserDatabase, $RecentSearchesTable> {
  $$RecentSearchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecentSearchesTableAnnotationComposer
    extends Composer<_$UserDatabase, $RecentSearchesTable> {
  $$RecentSearchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);
}

class $$RecentSearchesTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $RecentSearchesTable,
          RecentSearch,
          $$RecentSearchesTableFilterComposer,
          $$RecentSearchesTableOrderingComposer,
          $$RecentSearchesTableAnnotationComposer,
          $$RecentSearchesTableCreateCompanionBuilder,
          $$RecentSearchesTableUpdateCompanionBuilder,
          (
            RecentSearch,
            BaseReferences<_$UserDatabase, $RecentSearchesTable, RecentSearch>,
          ),
          RecentSearch,
          PrefetchHooks Function()
        > {
  $$RecentSearchesTableTableManager(
    _$UserDatabase db,
    $RecentSearchesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentSearchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentSearchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentSearchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> query = const Value.absent(),
            Value<DateTime> at = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => RecentSearchesCompanion(query: query, at: at, rowid: rowid),
          createCompanionCallback:
              ({
                required String query,
                required DateTime at,
                Value<int> rowid = const Value.absent(),
              }) => RecentSearchesCompanion.insert(
                query: query,
                at: at,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecentSearchesTable, RecentSearch>(table),
                  BaseReferences<
                    _$UserDatabase,
                    $RecentSearchesTable,
                    RecentSearch
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecentSearchesTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $RecentSearchesTable,
      RecentSearch,
      $$RecentSearchesTableFilterComposer,
      $$RecentSearchesTableOrderingComposer,
      $$RecentSearchesTableAnnotationComposer,
      $$RecentSearchesTableCreateCompanionBuilder,
      $$RecentSearchesTableUpdateCompanionBuilder,
      (
        RecentSearch,
        BaseReferences<_$UserDatabase, $RecentSearchesTable, RecentSearch>,
      ),
      RecentSearch,
      PrefetchHooks Function()
    >;
typedef $$RecentLookupsTableCreateCompanionBuilder =
    RecentLookupsCompanion Function({
      required String wordKey,
      required DateTime at,
      Value<int> rowid,
    });
typedef $$RecentLookupsTableUpdateCompanionBuilder =
    RecentLookupsCompanion Function({
      Value<String> wordKey,
      Value<DateTime> at,
      Value<int> rowid,
    });

class $$RecentLookupsTableFilterComposer
    extends Composer<_$UserDatabase, $RecentLookupsTable> {
  $$RecentLookupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecentLookupsTableOrderingComposer
    extends Composer<_$UserDatabase, $RecentLookupsTable> {
  $$RecentLookupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecentLookupsTableAnnotationComposer
    extends Composer<_$UserDatabase, $RecentLookupsTable> {
  $$RecentLookupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get wordKey =>
      $composableBuilder(column: $table.wordKey, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);
}

class $$RecentLookupsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $RecentLookupsTable,
          RecentLookup,
          $$RecentLookupsTableFilterComposer,
          $$RecentLookupsTableOrderingComposer,
          $$RecentLookupsTableAnnotationComposer,
          $$RecentLookupsTableCreateCompanionBuilder,
          $$RecentLookupsTableUpdateCompanionBuilder,
          (
            RecentLookup,
            BaseReferences<_$UserDatabase, $RecentLookupsTable, RecentLookup>,
          ),
          RecentLookup,
          PrefetchHooks Function()
        > {
  $$RecentLookupsTableTableManager(_$UserDatabase db, $RecentLookupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentLookupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentLookupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentLookupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> wordKey = const Value.absent(),
            Value<DateTime> at = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => RecentLookupsCompanion(wordKey: wordKey, at: at, rowid: rowid),
          createCompanionCallback:
              ({
                required String wordKey,
                required DateTime at,
                Value<int> rowid = const Value.absent(),
              }) => RecentLookupsCompanion.insert(
                wordKey: wordKey,
                at: at,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecentLookupsTable, RecentLookup>(table),
                  BaseReferences<
                    _$UserDatabase,
                    $RecentLookupsTable,
                    RecentLookup
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecentLookupsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $RecentLookupsTable,
      RecentLookup,
      $$RecentLookupsTableFilterComposer,
      $$RecentLookupsTableOrderingComposer,
      $$RecentLookupsTableAnnotationComposer,
      $$RecentLookupsTableCreateCompanionBuilder,
      $$RecentLookupsTableUpdateCompanionBuilder,
      (
        RecentLookup,
        BaseReferences<_$UserDatabase, $RecentLookupsTable, RecentLookup>,
      ),
      RecentLookup,
      PrefetchHooks Function()
    >;
typedef $$MixesTableCreateCompanionBuilder = MixesCompanion Function({
  Value<int> id,
  required String name,
  Value<bool> isPreset,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$MixesTableUpdateCompanionBuilder = MixesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<bool> isPreset,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$MixesTableReferences
    extends BaseReferences<_$UserDatabase, $MixesTable, Mix> {
  $$MixesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MixSourcesTable, List<MixSource>>
  _mixSourcesRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.mixSources,
    aliasName: 'mixes__id__mix_sources__mix_id',
  );

  $$MixSourcesTableProcessedTableManager get mixSourcesRefs {
    final manager = $$MixSourcesTableTableManager(
      $_db,
      $_db.mixSources,
    ).filter((f) => f.mixId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mixSourcesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MixSettingsTable, List<MixSetting>>
  _mixSettingsRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.mixSettings,
    aliasName: 'mixes__id__mix_settings__mix_id',
  );

  $$MixSettingsTableProcessedTableManager get mixSettingsRefs {
    final manager = $$MixSettingsTableTableManager(
      $_db,
      $_db.mixSettings,
    ).filter((f) => f.mixId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mixSettingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MixesTableFilterComposer extends Composer<_$UserDatabase, $MixesTable> {
  $$MixesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPreset => $composableBuilder(
    column: $table.isPreset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mixSourcesRefs(
    Expression<bool> Function($$MixSourcesTableFilterComposer f) f,
  ) {
    final $$MixSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mixSources,
      getReferencedColumn: (t) => t.mixId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MixSourcesTableFilterComposer(
            $db: $db,
            $table: $db.mixSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> mixSettingsRefs(
    Expression<bool> Function($$MixSettingsTableFilterComposer f) f,
  ) {
    final $$MixSettingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mixSettings,
      getReferencedColumn: (t) => t.mixId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MixSettingsTableFilterComposer(
            $db: $db,
            $table: $db.mixSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MixesTableOrderingComposer
    extends Composer<_$UserDatabase, $MixesTable> {
  $$MixesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPreset => $composableBuilder(
    column: $table.isPreset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MixesTableAnnotationComposer
    extends Composer<_$UserDatabase, $MixesTable> {
  $$MixesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isPreset =>
      $composableBuilder(column: $table.isPreset, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> mixSourcesRefs<T extends Object>(
    Expression<T> Function($$MixSourcesTableAnnotationComposer a) f,
  ) {
    final $$MixSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mixSources,
      getReferencedColumn: (t) => t.mixId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MixSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.mixSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> mixSettingsRefs<T extends Object>(
    Expression<T> Function($$MixSettingsTableAnnotationComposer a) f,
  ) {
    final $$MixSettingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mixSettings,
      getReferencedColumn: (t) => t.mixId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MixSettingsTableAnnotationComposer(
            $db: $db,
            $table: $db.mixSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MixesTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $MixesTable,
          Mix,
          $$MixesTableFilterComposer,
          $$MixesTableOrderingComposer,
          $$MixesTableAnnotationComposer,
          $$MixesTableCreateCompanionBuilder,
          $$MixesTableUpdateCompanionBuilder,
          (Mix, $$MixesTableReferences),
          Mix,
          PrefetchHooks Function({bool mixSourcesRefs, bool mixSettingsRefs})
        > {
  $$MixesTableTableManager(_$UserDatabase db, $MixesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MixesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MixesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MixesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isPreset = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => MixesCompanion(
                id: id,
                name: name,
                isPreset: isPreset,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<bool> isPreset = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => MixesCompanion.insert(
                id: id,
                name: name,
                isPreset: isPreset,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MixesTable, Mix>(table),
                  $$MixesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({mixSourcesRefs = false, mixSettingsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mixSourcesRefs) db.mixSources,
                    if (mixSettingsRefs) db.mixSettings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mixSourcesRefs)
                        await $_getPrefetchedData<Mix, $MixesTable, MixSource>(
                          currentTable: table,
                          referencedTable: $$MixesTableReferences
                              ._mixSourcesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MixesTableReferences(
                                db,
                                table,
                                p0,
                              ).mixSourcesRefs,
                          referencedItemsForCurrentItem: (
                            item,
                            referencedItems,
                          ) => referencedItems.where((e) => e.mixId == item.id),
                          typedResults: items,
                        ),
                      if (mixSettingsRefs)
                        await $_getPrefetchedData<Mix, $MixesTable, MixSetting>(
                          currentTable: table,
                          referencedTable: $$MixesTableReferences
                              ._mixSettingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MixesTableReferences(
                                db,
                                table,
                                p0,
                              ).mixSettingsRefs,
                          referencedItemsForCurrentItem: (
                            item,
                            referencedItems,
                          ) => referencedItems.where((e) => e.mixId == item.id),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MixesTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $MixesTable,
      Mix,
      $$MixesTableFilterComposer,
      $$MixesTableOrderingComposer,
      $$MixesTableAnnotationComposer,
      $$MixesTableCreateCompanionBuilder,
      $$MixesTableUpdateCompanionBuilder,
      (Mix, $$MixesTableReferences),
      Mix,
      PrefetchHooks Function({bool mixSourcesRefs, bool mixSettingsRefs})
    >;
typedef $$MixSourcesTableCreateCompanionBuilder = MixSourcesCompanion Function({
  required int mixId,
  required String collectionSlug,
  Value<int> rowid,
});
typedef $$MixSourcesTableUpdateCompanionBuilder = MixSourcesCompanion Function({
  Value<int> mixId,
  Value<String> collectionSlug,
  Value<int> rowid,
});

final class $$MixSourcesTableReferences
    extends BaseReferences<_$UserDatabase, $MixSourcesTable, MixSource> {
  $$MixSourcesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MixesTable _mixIdTable(_$UserDatabase db) =>
      db.mixes.createAlias('mix_sources__mix_id__mixes__id');

  $$MixesTableProcessedTableManager get mixId {
    final $_column = $_itemColumn<int>('mix_id')!;

    final manager = $$MixesTableTableManager(
      $_db,
      $_db.mixes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mixIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MixSourcesTableFilterComposer
    extends Composer<_$UserDatabase, $MixSourcesTable> {
  $$MixSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collectionSlug => $composableBuilder(
    column: $table.collectionSlug,
    builder: (column) => ColumnFilters(column),
  );

  $$MixesTableFilterComposer get mixId {
    final $$MixesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mixId,
      referencedTable: $db.mixes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MixesTableFilterComposer(
            $db: $db,
            $table: $db.mixes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MixSourcesTableOrderingComposer
    extends Composer<_$UserDatabase, $MixSourcesTable> {
  $$MixSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collectionSlug => $composableBuilder(
    column: $table.collectionSlug,
    builder: (column) => ColumnOrderings(column),
  );

  $$MixesTableOrderingComposer get mixId {
    final $$MixesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mixId,
      referencedTable: $db.mixes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MixesTableOrderingComposer(
            $db: $db,
            $table: $db.mixes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MixSourcesTableAnnotationComposer
    extends Composer<_$UserDatabase, $MixSourcesTable> {
  $$MixSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collectionSlug => $composableBuilder(
    column: $table.collectionSlug,
    builder: (column) => column,
  );

  $$MixesTableAnnotationComposer get mixId {
    final $$MixesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mixId,
      referencedTable: $db.mixes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MixesTableAnnotationComposer(
            $db: $db,
            $table: $db.mixes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MixSourcesTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $MixSourcesTable,
          MixSource,
          $$MixSourcesTableFilterComposer,
          $$MixSourcesTableOrderingComposer,
          $$MixSourcesTableAnnotationComposer,
          $$MixSourcesTableCreateCompanionBuilder,
          $$MixSourcesTableUpdateCompanionBuilder,
          (MixSource, $$MixSourcesTableReferences),
          MixSource,
          PrefetchHooks Function({bool mixId})
        > {
  $$MixSourcesTableTableManager(_$UserDatabase db, $MixSourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MixSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MixSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MixSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> mixId = const Value.absent(),
                Value<String> collectionSlug = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MixSourcesCompanion(
                mixId: mixId,
                collectionSlug: collectionSlug,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int mixId,
                required String collectionSlug,
                Value<int> rowid = const Value.absent(),
              }) => MixSourcesCompanion.insert(
                mixId: mixId,
                collectionSlug: collectionSlug,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MixSourcesTable, MixSource>(table),
                  $$MixSourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mixId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mixId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.mixId,
                        referencedTable: $$MixSourcesTableReferences
                            ._mixIdTable(db),
                        referencedColumn: $$MixSourcesTableReferences
                            ._mixIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MixSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $MixSourcesTable,
      MixSource,
      $$MixSourcesTableFilterComposer,
      $$MixSourcesTableOrderingComposer,
      $$MixSourcesTableAnnotationComposer,
      $$MixSourcesTableCreateCompanionBuilder,
      $$MixSourcesTableUpdateCompanionBuilder,
      (MixSource, $$MixSourcesTableReferences),
      MixSource,
      PrefetchHooks Function({bool mixId})
    >;
typedef $$MixSettingsTableCreateCompanionBuilder =
    MixSettingsCompanion Function({
      Value<int> mixId,
      required String seenPolicy,
      Value<bool> shuffle,
      Value<bool> includeBookmarkedOnly,
    });
typedef $$MixSettingsTableUpdateCompanionBuilder =
    MixSettingsCompanion Function({
      Value<int> mixId,
      Value<String> seenPolicy,
      Value<bool> shuffle,
      Value<bool> includeBookmarkedOnly,
    });

final class $$MixSettingsTableReferences
    extends BaseReferences<_$UserDatabase, $MixSettingsTable, MixSetting> {
  $$MixSettingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MixesTable _mixIdTable(_$UserDatabase db) =>
      db.mixes.createAlias('mix_settings__mix_id__mixes__id');

  $$MixesTableProcessedTableManager get mixId {
    final $_column = $_itemColumn<int>('mix_id')!;

    final manager = $$MixesTableTableManager(
      $_db,
      $_db.mixes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mixIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MixSettingsTableFilterComposer
    extends Composer<_$UserDatabase, $MixSettingsTable> {
  $$MixSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get seenPolicy => $composableBuilder(
    column: $table.seenPolicy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get shuffle => $composableBuilder(
    column: $table.shuffle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includeBookmarkedOnly => $composableBuilder(
    column: $table.includeBookmarkedOnly,
    builder: (column) => ColumnFilters(column),
  );

  $$MixesTableFilterComposer get mixId {
    final $$MixesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mixId,
      referencedTable: $db.mixes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MixesTableFilterComposer(
            $db: $db,
            $table: $db.mixes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MixSettingsTableOrderingComposer
    extends Composer<_$UserDatabase, $MixSettingsTable> {
  $$MixSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get seenPolicy => $composableBuilder(
    column: $table.seenPolicy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get shuffle => $composableBuilder(
    column: $table.shuffle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includeBookmarkedOnly => $composableBuilder(
    column: $table.includeBookmarkedOnly,
    builder: (column) => ColumnOrderings(column),
  );

  $$MixesTableOrderingComposer get mixId {
    final $$MixesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mixId,
      referencedTable: $db.mixes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MixesTableOrderingComposer(
            $db: $db,
            $table: $db.mixes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MixSettingsTableAnnotationComposer
    extends Composer<_$UserDatabase, $MixSettingsTable> {
  $$MixSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get seenPolicy => $composableBuilder(
    column: $table.seenPolicy,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get shuffle =>
      $composableBuilder(column: $table.shuffle, builder: (column) => column);

  GeneratedColumn<bool> get includeBookmarkedOnly => $composableBuilder(
    column: $table.includeBookmarkedOnly,
    builder: (column) => column,
  );

  $$MixesTableAnnotationComposer get mixId {
    final $$MixesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mixId,
      referencedTable: $db.mixes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MixesTableAnnotationComposer(
            $db: $db,
            $table: $db.mixes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MixSettingsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $MixSettingsTable,
          MixSetting,
          $$MixSettingsTableFilterComposer,
          $$MixSettingsTableOrderingComposer,
          $$MixSettingsTableAnnotationComposer,
          $$MixSettingsTableCreateCompanionBuilder,
          $$MixSettingsTableUpdateCompanionBuilder,
          (MixSetting, $$MixSettingsTableReferences),
          MixSetting,
          PrefetchHooks Function({bool mixId})
        > {
  $$MixSettingsTableTableManager(_$UserDatabase db, $MixSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MixSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MixSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MixSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> mixId = const Value.absent(),
                Value<String> seenPolicy = const Value.absent(),
                Value<bool> shuffle = const Value.absent(),
                Value<bool> includeBookmarkedOnly = const Value.absent(),
              }) => MixSettingsCompanion(
                mixId: mixId,
                seenPolicy: seenPolicy,
                shuffle: shuffle,
                includeBookmarkedOnly: includeBookmarkedOnly,
              ),
          createCompanionCallback:
              ({
                Value<int> mixId = const Value.absent(),
                required String seenPolicy,
                Value<bool> shuffle = const Value.absent(),
                Value<bool> includeBookmarkedOnly = const Value.absent(),
              }) => MixSettingsCompanion.insert(
                mixId: mixId,
                seenPolicy: seenPolicy,
                shuffle: shuffle,
                includeBookmarkedOnly: includeBookmarkedOnly,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MixSettingsTable, MixSetting>(table),
                  $$MixSettingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mixId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mixId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.mixId,
                        referencedTable: $$MixSettingsTableReferences
                            ._mixIdTable(db),
                        referencedColumn: $$MixSettingsTableReferences
                            ._mixIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MixSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $MixSettingsTable,
      MixSetting,
      $$MixSettingsTableFilterComposer,
      $$MixSettingsTableOrderingComposer,
      $$MixSettingsTableAnnotationComposer,
      $$MixSettingsTableCreateCompanionBuilder,
      $$MixSettingsTableUpdateCompanionBuilder,
      (MixSetting, $$MixSettingsTableReferences),
      MixSetting,
      PrefetchHooks Function({bool mixId})
    >;
typedef $$WordContextsTableCreateCompanionBuilder =
    WordContextsCompanion Function({
      Value<int> id,
      required String wordKey,
      required String contextText,
      required DateTime capturedAt,
      Value<String?> sourceHint,
    });
typedef $$WordContextsTableUpdateCompanionBuilder =
    WordContextsCompanion Function({
      Value<int> id,
      Value<String> wordKey,
      Value<String> contextText,
      Value<DateTime> capturedAt,
      Value<String?> sourceHint,
    });

class $$WordContextsTableFilterComposer
    extends Composer<_$UserDatabase, $WordContextsTable> {
  $$WordContextsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contextText => $composableBuilder(
    column: $table.contextText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceHint => $composableBuilder(
    column: $table.sourceHint,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WordContextsTableOrderingComposer
    extends Composer<_$UserDatabase, $WordContextsTable> {
  $$WordContextsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contextText => $composableBuilder(
    column: $table.contextText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceHint => $composableBuilder(
    column: $table.sourceHint,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WordContextsTableAnnotationComposer
    extends Composer<_$UserDatabase, $WordContextsTable> {
  $$WordContextsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get wordKey =>
      $composableBuilder(column: $table.wordKey, builder: (column) => column);

  GeneratedColumn<String> get contextText => $composableBuilder(
    column: $table.contextText,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceHint => $composableBuilder(
    column: $table.sourceHint,
    builder: (column) => column,
  );
}

class $$WordContextsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $WordContextsTable,
          WordContext,
          $$WordContextsTableFilterComposer,
          $$WordContextsTableOrderingComposer,
          $$WordContextsTableAnnotationComposer,
          $$WordContextsTableCreateCompanionBuilder,
          $$WordContextsTableUpdateCompanionBuilder,
          (
            WordContext,
            BaseReferences<_$UserDatabase, $WordContextsTable, WordContext>,
          ),
          WordContext,
          PrefetchHooks Function()
        > {
  $$WordContextsTableTableManager(_$UserDatabase db, $WordContextsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordContextsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordContextsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordContextsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> wordKey = const Value.absent(),
                Value<String> contextText = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<String?> sourceHint = const Value.absent(),
              }) => WordContextsCompanion(
                id: id,
                wordKey: wordKey,
                contextText: contextText,
                capturedAt: capturedAt,
                sourceHint: sourceHint,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String wordKey,
                required String contextText,
                required DateTime capturedAt,
                Value<String?> sourceHint = const Value.absent(),
              }) => WordContextsCompanion.insert(
                id: id,
                wordKey: wordKey,
                contextText: contextText,
                capturedAt: capturedAt,
                sourceHint: sourceHint,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WordContextsTable, WordContext>(table),
                  BaseReferences<
                    _$UserDatabase,
                    $WordContextsTable,
                    WordContext
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WordContextsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $WordContextsTable,
      WordContext,
      $$WordContextsTableFilterComposer,
      $$WordContextsTableOrderingComposer,
      $$WordContextsTableAnnotationComposer,
      $$WordContextsTableCreateCompanionBuilder,
      $$WordContextsTableUpdateCompanionBuilder,
      (
        WordContext,
        BaseReferences<_$UserDatabase, $WordContextsTable, WordContext>,
      ),
      WordContext,
      PrefetchHooks Function()
    >;
typedef $$QuizSessionsTableCreateCompanionBuilder =
    QuizSessionsCompanion Function({
      Value<int> id,
      required String collectionSlug,
      required DateTime startedAt,
      Value<DateTime?> completedAt,
      required int questionCount,
      Value<int> correctCount,
      Value<bool> wasAbandoned,
    });
typedef $$QuizSessionsTableUpdateCompanionBuilder =
    QuizSessionsCompanion Function({
      Value<int> id,
      Value<String> collectionSlug,
      Value<DateTime> startedAt,
      Value<DateTime?> completedAt,
      Value<int> questionCount,
      Value<int> correctCount,
      Value<bool> wasAbandoned,
    });

final class $$QuizSessionsTableReferences
    extends BaseReferences<_$UserDatabase, $QuizSessionsTable, QuizSession> {
  $$QuizSessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$QuizAnswersTable, List<QuizAnswer>>
  _quizAnswersRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.quizAnswers,
    aliasName: 'quiz_sessions__id__quiz_answers__session_id',
  );

  $$QuizAnswersTableProcessedTableManager get quizAnswersRefs {
    final manager = $$QuizAnswersTableTableManager(
      $_db,
      $_db.quizAnswers,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_quizAnswersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$QuizSessionsTableFilterComposer
    extends Composer<_$UserDatabase, $QuizSessionsTable> {
  $$QuizSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionSlug => $composableBuilder(
    column: $table.collectionSlug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get questionCount => $composableBuilder(
    column: $table.questionCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get wasAbandoned => $composableBuilder(
    column: $table.wasAbandoned,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> quizAnswersRefs(
    Expression<bool> Function($$QuizAnswersTableFilterComposer f) f,
  ) {
    final $$QuizAnswersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.quizAnswers,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuizAnswersTableFilterComposer(
            $db: $db,
            $table: $db.quizAnswers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$QuizSessionsTableOrderingComposer
    extends Composer<_$UserDatabase, $QuizSessionsTable> {
  $$QuizSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionSlug => $composableBuilder(
    column: $table.collectionSlug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get questionCount => $composableBuilder(
    column: $table.questionCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wasAbandoned => $composableBuilder(
    column: $table.wasAbandoned,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuizSessionsTableAnnotationComposer
    extends Composer<_$UserDatabase, $QuizSessionsTable> {
  $$QuizSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get collectionSlug => $composableBuilder(
    column: $table.collectionSlug,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get questionCount => $composableBuilder(
    column: $table.questionCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get wasAbandoned => $composableBuilder(
    column: $table.wasAbandoned,
    builder: (column) => column,
  );

  Expression<T> quizAnswersRefs<T extends Object>(
    Expression<T> Function($$QuizAnswersTableAnnotationComposer a) f,
  ) {
    final $$QuizAnswersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.quizAnswers,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuizAnswersTableAnnotationComposer(
            $db: $db,
            $table: $db.quizAnswers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$QuizSessionsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $QuizSessionsTable,
          QuizSession,
          $$QuizSessionsTableFilterComposer,
          $$QuizSessionsTableOrderingComposer,
          $$QuizSessionsTableAnnotationComposer,
          $$QuizSessionsTableCreateCompanionBuilder,
          $$QuizSessionsTableUpdateCompanionBuilder,
          (QuizSession, $$QuizSessionsTableReferences),
          QuizSession,
          PrefetchHooks Function({bool quizAnswersRefs})
        > {
  $$QuizSessionsTableTableManager(_$UserDatabase db, $QuizSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuizSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuizSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuizSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> collectionSlug = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> questionCount = const Value.absent(),
                Value<int> correctCount = const Value.absent(),
                Value<bool> wasAbandoned = const Value.absent(),
              }) => QuizSessionsCompanion(
                id: id,
                collectionSlug: collectionSlug,
                startedAt: startedAt,
                completedAt: completedAt,
                questionCount: questionCount,
                correctCount: correctCount,
                wasAbandoned: wasAbandoned,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String collectionSlug,
                required DateTime startedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                required int questionCount,
                Value<int> correctCount = const Value.absent(),
                Value<bool> wasAbandoned = const Value.absent(),
              }) => QuizSessionsCompanion.insert(
                id: id,
                collectionSlug: collectionSlug,
                startedAt: startedAt,
                completedAt: completedAt,
                questionCount: questionCount,
                correctCount: correctCount,
                wasAbandoned: wasAbandoned,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QuizSessionsTable, QuizSession>(table),
                  $$QuizSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({quizAnswersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (quizAnswersRefs) db.quizAnswers],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (quizAnswersRefs)
                    await $_getPrefetchedData<
                      QuizSession,
                      $QuizSessionsTable,
                      QuizAnswer
                    >(
                      currentTable: table,
                      referencedTable: $$QuizSessionsTableReferences
                          ._quizAnswersRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$QuizSessionsTableReferences(
                            db,
                            table,
                            p0,
                          ).quizAnswersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$QuizSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $QuizSessionsTable,
      QuizSession,
      $$QuizSessionsTableFilterComposer,
      $$QuizSessionsTableOrderingComposer,
      $$QuizSessionsTableAnnotationComposer,
      $$QuizSessionsTableCreateCompanionBuilder,
      $$QuizSessionsTableUpdateCompanionBuilder,
      (QuizSession, $$QuizSessionsTableReferences),
      QuizSession,
      PrefetchHooks Function({bool quizAnswersRefs})
    >;
typedef $$QuizAnswersTableCreateCompanionBuilder =
    QuizAnswersCompanion Function({
      Value<int> id,
      required int sessionId,
      required String wordKey,
      required String questionType,
      required bool wasCorrect,
      Value<String?> chosenKey,
      required DateTime answeredAt,
    });
typedef $$QuizAnswersTableUpdateCompanionBuilder =
    QuizAnswersCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<String> wordKey,
      Value<String> questionType,
      Value<bool> wasCorrect,
      Value<String?> chosenKey,
      Value<DateTime> answeredAt,
    });

final class $$QuizAnswersTableReferences
    extends BaseReferences<_$UserDatabase, $QuizAnswersTable, QuizAnswer> {
  $$QuizAnswersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $QuizSessionsTable _sessionIdTable(_$UserDatabase db) => db
      .quizSessions
      .createAlias('quiz_answers__session_id__quiz_sessions__id');

  $$QuizSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$QuizSessionsTableTableManager(
      $_db,
      $_db.quizSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$QuizAnswersTableFilterComposer
    extends Composer<_$UserDatabase, $QuizAnswersTable> {
  $$QuizAnswersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionType => $composableBuilder(
    column: $table.questionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get wasCorrect => $composableBuilder(
    column: $table.wasCorrect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chosenKey => $composableBuilder(
    column: $table.chosenKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnFilters(column),
  );

  $$QuizSessionsTableFilterComposer get sessionId {
    final $$QuizSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.quizSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuizSessionsTableFilterComposer(
            $db: $db,
            $table: $db.quizSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuizAnswersTableOrderingComposer
    extends Composer<_$UserDatabase, $QuizAnswersTable> {
  $$QuizAnswersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wordKey => $composableBuilder(
    column: $table.wordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionType => $composableBuilder(
    column: $table.questionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wasCorrect => $composableBuilder(
    column: $table.wasCorrect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chosenKey => $composableBuilder(
    column: $table.chosenKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$QuizSessionsTableOrderingComposer get sessionId {
    final $$QuizSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.quizSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuizSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.quizSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuizAnswersTableAnnotationComposer
    extends Composer<_$UserDatabase, $QuizAnswersTable> {
  $$QuizAnswersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get wordKey =>
      $composableBuilder(column: $table.wordKey, builder: (column) => column);

  GeneratedColumn<String> get questionType => $composableBuilder(
    column: $table.questionType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get wasCorrect => $composableBuilder(
    column: $table.wasCorrect,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chosenKey =>
      $composableBuilder(column: $table.chosenKey, builder: (column) => column);

  GeneratedColumn<DateTime> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => column,
  );

  $$QuizSessionsTableAnnotationComposer get sessionId {
    final $$QuizSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.quizSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuizSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.quizSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuizAnswersTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $QuizAnswersTable,
          QuizAnswer,
          $$QuizAnswersTableFilterComposer,
          $$QuizAnswersTableOrderingComposer,
          $$QuizAnswersTableAnnotationComposer,
          $$QuizAnswersTableCreateCompanionBuilder,
          $$QuizAnswersTableUpdateCompanionBuilder,
          (QuizAnswer, $$QuizAnswersTableReferences),
          QuizAnswer,
          PrefetchHooks Function({bool sessionId})
        > {
  $$QuizAnswersTableTableManager(_$UserDatabase db, $QuizAnswersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuizAnswersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuizAnswersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuizAnswersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<String> wordKey = const Value.absent(),
                Value<String> questionType = const Value.absent(),
                Value<bool> wasCorrect = const Value.absent(),
                Value<String?> chosenKey = const Value.absent(),
                Value<DateTime> answeredAt = const Value.absent(),
              }) => QuizAnswersCompanion(
                id: id,
                sessionId: sessionId,
                wordKey: wordKey,
                questionType: questionType,
                wasCorrect: wasCorrect,
                chosenKey: chosenKey,
                answeredAt: answeredAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required String wordKey,
                required String questionType,
                required bool wasCorrect,
                Value<String?> chosenKey = const Value.absent(),
                required DateTime answeredAt,
              }) => QuizAnswersCompanion.insert(
                id: id,
                sessionId: sessionId,
                wordKey: wordKey,
                questionType: questionType,
                wasCorrect: wasCorrect,
                chosenKey: chosenKey,
                answeredAt: answeredAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QuizAnswersTable, QuizAnswer>(table),
                  $$QuizAnswersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$QuizAnswersTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$QuizAnswersTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$QuizAnswersTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $QuizAnswersTable,
      QuizAnswer,
      $$QuizAnswersTableFilterComposer,
      $$QuizAnswersTableOrderingComposer,
      $$QuizAnswersTableAnnotationComposer,
      $$QuizAnswersTableCreateCompanionBuilder,
      $$QuizAnswersTableUpdateCompanionBuilder,
      (QuizAnswer, $$QuizAnswersTableReferences),
      QuizAnswer,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$CollectionStatsTableCreateCompanionBuilder =
    CollectionStatsCompanion Function({
      required String collectionSlug,
      Value<int> timesOpened,
      Value<DateTime?> lastOpenedAt,
      Value<int> rowid,
    });
typedef $$CollectionStatsTableUpdateCompanionBuilder =
    CollectionStatsCompanion Function({
      Value<String> collectionSlug,
      Value<int> timesOpened,
      Value<DateTime?> lastOpenedAt,
      Value<int> rowid,
    });

class $$CollectionStatsTableFilterComposer
    extends Composer<_$UserDatabase, $CollectionStatsTable> {
  $$CollectionStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collectionSlug => $composableBuilder(
    column: $table.collectionSlug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timesOpened => $composableBuilder(
    column: $table.timesOpened,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CollectionStatsTableOrderingComposer
    extends Composer<_$UserDatabase, $CollectionStatsTable> {
  $$CollectionStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collectionSlug => $composableBuilder(
    column: $table.collectionSlug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timesOpened => $composableBuilder(
    column: $table.timesOpened,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectionStatsTableAnnotationComposer
    extends Composer<_$UserDatabase, $CollectionStatsTable> {
  $$CollectionStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collectionSlug => $composableBuilder(
    column: $table.collectionSlug,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timesOpened => $composableBuilder(
    column: $table.timesOpened,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );
}

class $$CollectionStatsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $CollectionStatsTable,
          CollectionStat,
          $$CollectionStatsTableFilterComposer,
          $$CollectionStatsTableOrderingComposer,
          $$CollectionStatsTableAnnotationComposer,
          $$CollectionStatsTableCreateCompanionBuilder,
          $$CollectionStatsTableUpdateCompanionBuilder,
          (
            CollectionStat,
            BaseReferences<
              _$UserDatabase,
              $CollectionStatsTable,
              CollectionStat
            >,
          ),
          CollectionStat,
          PrefetchHooks Function()
        > {
  $$CollectionStatsTableTableManager(
    _$UserDatabase db,
    $CollectionStatsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> collectionSlug = const Value.absent(),
                Value<int> timesOpened = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionStatsCompanion(
                collectionSlug: collectionSlug,
                timesOpened: timesOpened,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collectionSlug,
                Value<int> timesOpened = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionStatsCompanion.insert(
                collectionSlug: collectionSlug,
                timesOpened: timesOpened,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CollectionStatsTable, CollectionStat>(table),
                  BaseReferences<
                    _$UserDatabase,
                    $CollectionStatsTable,
                    CollectionStat
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CollectionStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $CollectionStatsTable,
      CollectionStat,
      $$CollectionStatsTableFilterComposer,
      $$CollectionStatsTableOrderingComposer,
      $$CollectionStatsTableAnnotationComposer,
      $$CollectionStatsTableCreateCompanionBuilder,
      $$CollectionStatsTableUpdateCompanionBuilder,
      (
        CollectionStat,
        BaseReferences<_$UserDatabase, $CollectionStatsTable, CollectionStat>,
      ),
      CollectionStat,
      PrefetchHooks Function()
    >;
typedef $$AppStateTableCreateCompanionBuilder = AppStateCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppStateTableUpdateCompanionBuilder = AppStateCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppStateTableFilterComposer
    extends Composer<_$UserDatabase, $AppStateTable> {
  $$AppStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppStateTableOrderingComposer
    extends Composer<_$UserDatabase, $AppStateTable> {
  $$AppStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppStateTableAnnotationComposer
    extends Composer<_$UserDatabase, $AppStateTable> {
  $$AppStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppStateTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $AppStateTable,
          AppStateRow,
          $$AppStateTableFilterComposer,
          $$AppStateTableOrderingComposer,
          $$AppStateTableAnnotationComposer,
          $$AppStateTableCreateCompanionBuilder,
          $$AppStateTableUpdateCompanionBuilder,
          (
            AppStateRow,
            BaseReferences<_$UserDatabase, $AppStateTable, AppStateRow>,
          ),
          AppStateRow,
          PrefetchHooks Function()
        > {
  $$AppStateTableTableManager(_$UserDatabase db, $AppStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => AppStateCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppStateTable, AppStateRow>(table),
                  BaseReferences<_$UserDatabase, $AppStateTable, AppStateRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppStateTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $AppStateTable,
      AppStateRow,
      $$AppStateTableFilterComposer,
      $$AppStateTableOrderingComposer,
      $$AppStateTableAnnotationComposer,
      $$AppStateTableCreateCompanionBuilder,
      $$AppStateTableUpdateCompanionBuilder,
      (
        AppStateRow,
        BaseReferences<_$UserDatabase, $AppStateTable, AppStateRow>,
      ),
      AppStateRow,
      PrefetchHooks Function()
    >;

class $UserDatabaseManager {
  final _$UserDatabase _db;
  $UserDatabaseManager(this._db);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$WordListsTableTableManager get wordLists =>
      $$WordListsTableTableManager(_db, _db.wordLists);
  $$ListWordsTableTableManager get listWords =>
      $$ListWordsTableTableManager(_db, _db.listWords);
  $$UserCollectionsTableTableManager get userCollections =>
      $$UserCollectionsTableTableManager(_db, _db.userCollections);
  $$UserCollectionWordsTableTableManager get userCollectionWords =>
      $$UserCollectionWordsTableTableManager(_db, _db.userCollectionWords);
  $$SeenTableTableManager get seen => $$SeenTableTableManager(_db, _db.seen);
  $$SeenEventsTableTableManager get seenEvents =>
      $$SeenEventsTableTableManager(_db, _db.seenEvents);
  $$RecentSearchesTableTableManager get recentSearches =>
      $$RecentSearchesTableTableManager(_db, _db.recentSearches);
  $$RecentLookupsTableTableManager get recentLookups =>
      $$RecentLookupsTableTableManager(_db, _db.recentLookups);
  $$MixesTableTableManager get mixes =>
      $$MixesTableTableManager(_db, _db.mixes);
  $$MixSourcesTableTableManager get mixSources =>
      $$MixSourcesTableTableManager(_db, _db.mixSources);
  $$MixSettingsTableTableManager get mixSettings =>
      $$MixSettingsTableTableManager(_db, _db.mixSettings);
  $$WordContextsTableTableManager get wordContexts =>
      $$WordContextsTableTableManager(_db, _db.wordContexts);
  $$QuizSessionsTableTableManager get quizSessions =>
      $$QuizSessionsTableTableManager(_db, _db.quizSessions);
  $$QuizAnswersTableTableManager get quizAnswers =>
      $$QuizAnswersTableTableManager(_db, _db.quizAnswers);
  $$CollectionStatsTableTableManager get collectionStats =>
      $$CollectionStatsTableTableManager(_db, _db.collectionStats);
  $$AppStateTableTableManager get appState =>
      $$AppStateTableTableManager(_db, _db.appState);
}
