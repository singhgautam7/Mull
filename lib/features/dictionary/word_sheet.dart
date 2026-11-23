import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/user_db.dart';
import '../../core/database/user_repository.dart';
import '../../core/motion/motion.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/pronunciation.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/definable_text.dart';
import '../linger/share_word_sheet.dart';
import '../settings/settings_controller.dart';
import 'add_to_list_sheet.dart';
import 'arrival_sheet.dart';
import 'note_sheet.dart';

/// HANDOFF 3.5, the word detail sheet. Opened from a search row, a table
/// row, or the Mull tab's overflow. One sense and eight senses use the same
/// layout.
Future<void> showWordSheet(
  BuildContext context, {
  required String wordKey,
  bool fromSearch = false,
  bool fromOutside = false,
  String? sourceHint,
}) {
  // The sheet is as tall as the entry, up to 90%: a one-sense word is a
  // short sheet, never a full one with the actions marooned at the bottom.
  return showAppBottomSheet<void>(
    context: context,
    showClose: false,
    actions: _WordSheetActions(wordKey: wordKey, fromSearch: fromSearch),
    builder: (BuildContext ctx) => _WordSheet(
      wordKey: wordKey,
      fromSearch: fromSearch,
      fromOutside: fromOutside,
      sourceHint: sourceHint,
    ),
  );
}

/// Everything the sheet reads from the dictionary, read once when it opens
/// (never in `build()`, which reruns for every note, context and setting
/// change). All indexed point queries.
class _WordEntry {
  _WordEntry(this._dict, String wordKey) : word = _dict.byKey(wordKey);

  final DictionaryDb _dict;
  final DictionaryWord? word;

  late final List<DictionaryWord> senses =
      word == null ? const <DictionaryWord>[] : _dict.senses(word!.headwordNorm);
  late final String? us = _dict.usSpelling(senses.first.wordKey);
  late final List<String> inflections = _dict.inflections(senses.first.wordKey);
  late final Map<String, List<String>> examples = <String, List<String>>{
    for (final DictionaryWord w in senses) w.wordKey: _dict.examples(w.wordKey),
  };

  // The relations are read when their sections first build, which for a long
  // entry is after the sheet has opened.
  late final List<_Related> synonyms = _resolve(<String>{
    for (final DictionaryWord w in senses) ..._dict.synonyms(w.wordKey),
  }.map((String t) => (t, null)));
  late final List<_Related> antonyms = _resolve(<String>{
    for (final DictionaryWord w in senses) ..._dict.antonyms(w.wordKey),
  }.map((String t) => (t, null)));
  late final List<_Related> wordFamily = () {
    final Set<String> seen = <String>{};
    return _resolve(<(String, String?)>[
      for (final DictionaryWord w in senses)
        for (final WordFamilyMember m in _dict.wordFamily(w.wordKey))
          if (seen.add(m.headword.toLowerCase())) (m.headword, m.pos),
    ]);
  }();

  /// Resolves each related term to its word key once, so a chip is tappable
  /// only when the word exists and the tap is a direct `showWordSheet`.
  List<_Related> _resolve(Iterable<(String, String?)> terms) => <_Related>[
    for (final (String term, String? pos) in terms)
      _Related(term, _dict.senses(DictionaryDb.normalise(term)).firstOrNull?.wordKey, pos),
  ];

  /// A rough height of a sense at the normal text size: 22dp a line of 42
  /// characters, plus its gaps.
  double senseHeight(DictionaryWord w) {
    double lines(String t) => (t.length / 42).ceilToDouble() * 22;
    return lines(w.definitionFull) +
        Space.lg +
        (examples[w.wordKey] ?? const <String>[]).fold<double>(0, (double h, String e) => h + lines(e) + 6);
  }
}

/// A related term: [key] is its word key, or null when it is not in the
/// dictionary. [pos] is set for word family members.
class _Related {
  const _Related(this.term, this.key, this.pos);

  final String term;
  final String? key;
  final String? pos;
}

class _WordSheet extends ConsumerStatefulWidget {
  const _WordSheet({
    required this.wordKey,
    required this.fromSearch,
    this.fromOutside = false,
    this.sourceHint,
  });

  final String wordKey;
  final bool fromSearch;
  final bool fromOutside;
  final String? sourceHint;

  @override
  ConsumerState<_WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends ConsumerState<_WordSheet> {
  late final _WordEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = _WordEntry(ref.read(dictProvider), widget.wordKey);
  }

  /// True once the sheet has opened. Until then a long entry builds only what
  /// fits on it: the rest (senses below the fold, three sections of chips) was
  /// most of a 28 to 126 ms first frame.
  bool _opened = false;
  Animation<double>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_route != null) return;
    _route = ModalRoute.of(context)?.animation;
    if (_route == null || _route!.isCompleted) {
      _opened = true;
    } else {
      _route!.addStatusListener(_onRoute);
    }
  }

  void _onRoute(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    _route!.removeStatusListener(_onRoute);
    if (mounted) setState(() => _opened = true);
  }

  @override
  void dispose() {
    _route?.removeStatusListener(_onRoute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String wordKey = widget.wordKey;
    final bool fromOutside = widget.fromOutside;
    final String? sourceHint = widget.sourceHint;
    final MullColors c = context.colors;
    final DictionaryWord? word = _entry.word;
    if (word == null) {
      return Text(
        'No entry for $wordKey',
        style: MullType.body.copyWith(color: c.onSurfaceVariant),
      );
    }
    final List<DictionaryWord> senses = _entry.senses;
    final String? us = _entry.us;
    final List<String> inflections = _entry.inflections;
    final bool american = ref.watch(settingsProvider.select((AppSettings s) => s.spelling == Spelling.american));
    final double ttsRate = ref.watch(settingsProvider.select((AppSettings s) => s.ttsRate));
    final String headword = american && us != null
        ? us
        : word.headword;
    final UserRepository user = ref.read(userRepositoryProvider);
    final List<WordContext> contexts =
        ref.watch(_contextsProvider(wordKey)).value ?? const <WordContext>[];

    // Senses grouped by part of speech, in dictionary order.
    final Map<String, List<DictionaryWord>> byPos =
        <String, List<DictionaryWord>>{};
    // Enough text to fill the sheet on its own: only then is the rest late,
    // and the sheet takes its full height from the start.
    final double screen = MediaQuery.sizeOf(context).height;
    final bool late = !_opened && senses.fold<double>(0, (double h, DictionaryWord w) => h + _entry.senseHeight(w)) > screen;
    double shown = 0;
    for (final DictionaryWord w in senses) {
      if (late && shown > screen) break;
      shown += _entry.senseHeight(w);
      byPos.putIfAbsent(w.pos, () => <DictionaryWord>[]).add(w);
    }
    final List<String> plural = inflections
        .where(
          (String f) =>
              f.endsWith('s') && f.length == word.headwordNorm.length + 1 ||
              f.endsWith('es'),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (fromOutside) ...<Widget>[
          ArrivalTopRow(sourceHint: sourceHint),
          const SizedBox(height: Space.lg),
        ],
        if (contexts.isNotEmpty) ...<Widget>[
          _ContextCard(
            contexts: contexts,
            headword: word.headword,
            onDelete: (int id) => unawaited(user.deleteContext(id)),
          ),
          const SizedBox(height: Space.lg),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: Space.md,
          children: <Widget>[
            Flexible(
              child: Text(
                headword,
                style: MullType.headwordL.copyWith(
                  fontSize: 46,
                  color: c.onSurface,
                ),
                softWrap: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: BandChip(bandLabel(word.band)),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (word.ipa != null) ...<Widget>[
              Text(
                word.ipa!,
                style: MullType.monoTabular.copyWith(color: c.onSurfaceVariant),
              ),
              AppIconButton(
                icon: Icons.volume_up_rounded,
                size: 30,
                glyphSize: 16,
                semanticLabel: 'Pronounce ${word.headword}',
                onPressed: () => unawaited(
                  ref
                      .read(pronunciationProvider)
                      .speak(word.headword, rate: ttsRate),
                ),
              ),
            ] else
              Text(
                'no pronunciation recorded',
                style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
              ),
            if (plural.isNotEmpty)
              Text(
                'plural ${plural.first}',
                style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(height: Space.xl),
        for (final MapEntry<String, List<DictionaryWord>> group
            in byPos.entries) ...<Widget>[
          Text(
            posLabel(group.key).toUpperCase(),
            style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: Space.md),
          for (final DictionaryWord sense in group.value) ...<Widget>[
            _Sense(sense: sense, examples: _entry.examples[sense.wordKey] ?? const <String>[]),
            const SizedBox(height: Space.lg),
          ],
          const SizedBox(height: Space.sm),
        ],
        if (late)
          SizedBox(height: screen)
        else ...<Widget>[
          _RelationSection(title: 'SYNONYMS', items: _entry.synonyms),
          _RelationSection(title: 'ANTONYMS', items: _entry.antonyms),
          _RelationSection(title: 'WORD FAMILY', items: _entry.wordFamily),
        ],
        if (!late && us != null) ...<Widget>[
          const SizedBox(height: Space.xl),
          Text(
            american
                ? 'British spelling: ${word.headword}'
                : 'American spelling: $us',
            style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
          ),
        ],
        if (!late) NoteSection(noteKey: wordKey, title: word.headword, showAdd: false),
      ],
    );
  }
}

/// The action row pinned under the entry, the same whether the sheet was
/// opened in the app or over another app: the entry above it is already the
/// whole entry, so there is nothing fuller to open. Bookmarking is the
/// Bookmarks row of the add-to-shelf sheet.
class _WordSheetActions extends ConsumerStatefulWidget {
  const _WordSheetActions({required this.wordKey, required this.fromSearch});

  final String wordKey;
  final bool fromSearch;

  @override
  ConsumerState<_WordSheetActions> createState() => _WordSheetActionsState();
}

class _WordSheetActionsState extends ConsumerState<_WordSheetActions> {
  late final DictionaryWord? _word;

  @override
  void initState() {
    super.initState();
    _word = ref.read(dictProvider).byKey(widget.wordKey);
  }

  @override
  Widget build(BuildContext context) {
    final DictionaryDb dict = ref.read(dictProvider);
    final String wordKey = widget.wordKey;
    final DictionaryWord? word = _word;
    if (word == null) return const SizedBox.shrink();
    final bool hasNote = ref.watch(noteProvider(wordKey).select((AsyncValue<String?> n) => n.value != null));
    return Row(
      spacing: Space.md,
      children: <Widget>[
        Expanded(
          child: AppButton(
            label: 'Add to shelf',
            icon: Icons.library_add_outlined,
            fullWidth: true,
            onPressed: () => showAddToListSheet(
              context,
              wordKey: wordKey,
              headword: word.headword,
              fromSearch: widget.fromSearch,
            ),
          ),
        ),
        AppIconButton(
          icon: hasNote ? Icons.sticky_note_2_rounded : Icons.sticky_note_2_outlined,
          size: 48,
          active: hasNote,
          semanticLabel: hasNote ? 'Edit note' : 'Add note',
          onPressed: () => showNoteSheet(context, wordKey: wordKey, headword: word.headword),
        ),
        AppIconButton(
          icon: Icons.share_rounded,
          size: 48,
          semanticLabel: 'Share',
          onPressed: () => showShareWordSheet(
            context,
            word: word,
            example: dict.examples(word.wordKey).firstOrNull,
          ),
        ),
      ],
    );
  }
}

final StreamProvider<List<WordContext>> Function(String) _contextsProvider =
    StreamProvider.autoDispose.family<List<WordContext>, String>(
      (Ref ref, String key) =>
          ref.watch(userRepositoryProvider).watchContexts(key),
    );

class _ContextCard extends StatefulWidget {
  const _ContextCard({
    required this.contexts,
    required this.headword,
    required this.onDelete,
  });

  final List<WordContext> contexts;
  final String headword;
  final void Function(int id) onDelete;

  @override
  State<_ContextCard> createState() => _ContextCardState();
}

class _ContextCardState extends State<_ContextCard> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    if (widget.contexts.isEmpty) return const SizedBox.shrink();
    final MullColors c = context.colors;
    final bool multi = widget.contexts.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              multi
                  ? 'YOU MET THIS IN · ${widget.contexts.length} PLACES'
                  : 'YOU MET THIS IN',
              style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant),
            ),
            if (multi)
              Semantics(
                button: true,
                label: _editing ? 'Done' : 'Edit',
                excludeSemantics: true,
                child: Pressable(
                  kind: PressKind.chip,
                  onTap: () => setState(() => _editing = !_editing),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                    child: Center(
                      child: Text(
                        _editing ? 'Done' : 'Edit',
                        style: MullType.monoLabel.copyWith(
                          color: c.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Text(
                widget.contexts.first.capturedAt
                    .toLocal()
                    .toIso8601String()
                    .split('T')
                    .first,
                style: MullType.monoTabular.copyWith(
                  fontSize: 10,
                  color: c.onSurfaceMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.sm),
        for (final WordContext ctx in widget.contexts) ...<Widget>[
          Dismissible(
            key: ValueKey<int>(ctx.id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => widget.onDelete(ctx.id),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: Space.lg),
              decoration: BoxDecoration(
                color: c.dangerContainer,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: c.onDangerContainer,
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Space.md),
              decoration: BoxDecoration(
                color: c.surfaceContainerHigh,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                border: Border(left: BorderSide(color: c.primary, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _highlightText(ctx.contextText, widget.headword, c),
                  if (multi || ctx.sourceHint != null) ...<Widget>[
                    const SizedBox(height: Space.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          _contextMeta(ctx),
                          style: MullType.monoLabel.copyWith(
                            fontSize: 10,
                            color: c.onSurfaceMuted,
                          ),
                        ),
                        if (_editing)
                          AppIconButton(
                            icon: Icons.delete_outline_rounded,
                            size: 32,
                            glyphSize: 16,
                            filled: false,
                            tint: c.danger,
                            semanticLabel: 'Delete this place',
                            onPressed: () => widget.onDelete(ctx.id),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.sm),
        ],
      ],
    );
  }

  String _contextMeta(WordContext ctx) {
    final String date = ctx.capturedAt
        .toLocal()
        .toIso8601String()
        .split('T')
        .first;
    if (ctx.sourceHint != null && ctx.sourceHint!.isNotEmpty) {
      return '$date · ${formatAppName(ctx.sourceHint)}'.toUpperCase();
    }
    return date;
  }

  Widget _highlightText(String text, String headword, MullColors c) {
    final TextStyle base = MullType.body.copyWith(
      fontSize: 14,
      height: 1.6,
      fontStyle: FontStyle.italic,
      color: c.onSurfaceVariant,
    );
    final String stem = headword.length > 4
        ? headword.substring(0, headword.length - 1)
        : headword;
    final RegExp re = RegExp(
      '\\b(${RegExp.escape(headword)}|${RegExp.escape(stem)})[a-z]*',
      caseSensitive: false,
    );
    final List<InlineSpan> spans = <InlineSpan>[];
    int last = 0;
    for (final RegExpMatch m in re.allMatches(text)) {
      spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(
        TextSpan(
          text: m.group(0),
          style: base.copyWith(color: c.accent, fontWeight: FontWeight.w600),
        ),
      );
      last = m.end;
    }
    spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(children: spans), style: base);
  }
}

class _Sense extends StatelessWidget {
  const _Sense({required this.sense, required this.examples});

  final DictionaryWord sense;
  final List<String> examples;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.md,
      children: <Widget>[
        SizedBox(
          width: 18,
          child: Text(
            '${sense.senseIndex}',
            style: MullType.monoTabular.copyWith(color: c.accent),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DefinableText(
                sense.definitionFull,
                style: MullType.body.copyWith(color: c.onSurface),
              ),
              for (final String ex in examples) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  ex,
                  style: MullType.note.copyWith(
                    color: c.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One relation section (synonyms, antonyms, word family): label, `Space.sm`,
/// a wrap of chips, with `Space.xl` above. A term in the dictionary is a chip
/// that opens its sheet on top; one that is not is plain muted text. Past
/// [_kRelationVisible] the rest sits behind "Show all (N)".
const int _kRelationVisible = 8;

class _RelationSection extends StatefulWidget {
  const _RelationSection({required this.title, required this.items});

  final String title;
  final List<_Related> items;

  @override
  State<_RelationSection> createState() => _RelationSectionState();
}

class _RelationSectionState extends State<_RelationSection> {
  bool _expanded = false;

  Widget _item(BuildContext context, _Related r) {
    final String? key = r.key;
    if (key == null) {
      // As tall as a chip's hit region, so every row of the wrap is.
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: IconSpec.tapTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.sm),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              r.pos == null ? r.term : '${r.term} (${posLabel(r.pos!)})',
              style: MullType.label.copyWith(fontSize: 13, color: context.colors.onSurfaceMuted),
            ),
          ),
        ),
      );
    }
    return PillChip(
      label: r.term,
      trailing: r.pos == null
          ? null
          : Text(posLabel(r.pos!), style: MullType.monoLabel.copyWith(color: context.colors.onSurfaceMuted)),
      onTap: () => showWordSheet(context, wordKey: key),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<_Related> items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final bool more = items.length > _kRelationVisible;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.title, style: MullType.sectionHeader.copyWith(color: context.colors.onSurfaceVariant)),
          // The chips' own hit region leaves the 8dp under the label.
          AnimatedSize(
            alignment: Alignment.topLeft,
            duration: Motion.of(context, Motion.reflow),
            curve: Motion.curveOf(context, Motion.decelerate),
            child: Wrap(
              spacing: Space.sm,
              runSpacing: PillChip.runSpacing,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (final _Related r in _expanded ? items : items.take(_kRelationVisible)) _item(context, r),
              ],
            ),
          ),
          if (more)
            Semantics(
              button: true,
              child: Pressable(
                kind: PressKind.chip,
                morphCorners: false,
                onTap: () => setState(() => _expanded = !_expanded),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: IconSpec.tapTarget),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: Text(
                      _expanded ? 'Show less' : 'Show all (${items.length})',
                      style: MullType.label.copyWith(fontSize: 13, color: context.colors.accent).weight(600),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
