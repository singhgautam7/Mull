import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/motion/motion.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/did_you_mean.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/states.dart';
import '../settings/settings_controller.dart';
import 'add_to_list_sheet.dart';
import 'idiom_sheet.dart';
import 'word_sheet.dart';

enum SearchSegment { words, idioms }

/// HANDOFF 3.4. Field focused on entry, real-time results, Words/Phrases
/// carrying counts. Before typing: RECENT searches. Results are cards or
/// dense rows (Settings > Appearance > Search results) with the matched run
/// tinted.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.initialSegment = SearchSegment.words, this.initialQuery, this.focusToken, super.key});

  final SearchSegment initialSegment;

  /// Pre-filled and run on open: the selection an arrival could not resolve.
  final String? initialQuery;

  /// Set (to anything, each arrival a new value) by the launcher's search
  /// widget: the field takes focus and the keyboard comes up. Normal
  /// navigation to the tab leaves both alone.
  final String? focusToken;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

/// How long the field must be quiet before a keystroke becomes a query. A
/// keystroke every 60 ms would otherwise queue an FTS query for each.
const Duration kSearchDebounce = Duration(milliseconds: 100);

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _field = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';
  List<DictionaryWord> _words = const <DictionaryWord>[];
  List<Idiom> _idioms = const <Idiom>[];
  List<DictionaryWord> _suggestions = const <DictionaryWord>[];
  late SearchSegment _segment = widget.initialSegment;
  bool _slow = false;
  List<String> _recent = const <String>[];

  /// History rows leaving: still drawn, animating out.
  final Set<String> _leaving = <String>{};
  Timer? _recordTimer;
  Timer? _debounce;

  /// Bumped per keystroke; a result for an older query is dropped.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _segment = widget.initialSegment;
    unawaited(_loadRecent());
    if (widget.initialQuery case final String q when q.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _set(q));
    }
    if (widget.focusToken != null) _raiseKeyboard();
  }

  void _raiseKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  Future<void> _loadRecent() async {
    final List<String> r = await ref.read(userRepositoryProvider).recentSearches();
    if (mounted) setState(() => _recent = r);
  }

  /// A new query handed in by a route (`/search?q=`) while this tab is
  /// already built, as the define sheet's "Search Mull for it" does.
  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    final String? q = widget.initialQuery;
    if (q != null && q.isNotEmpty && q != old.initialQuery) _set(q);
    if (widget.focusToken != null && widget.focusToken != old.focusToken) _raiseKeyboard();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _debounce?.cancel();
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _run(String q) {
    _debounce?.cancel();
    _recordTimer?.cancel();
    final int generation = ++_generation;
    if (q.trim().isEmpty) {
      // Clearing the field brings the recent searches straight back.
      setState(() {
        _query = q;
        _words = const <DictionaryWord>[];
        _idioms = const <Idiom>[];
        _suggestions = const <DictionaryWord>[];
        _slow = false;
      });
      return;
    }
    _debounce = Timer(kSearchDebounce, () => unawaited(_search(q, generation)));
  }

  /// The query runs on the dictionary worker; the previous results stay on
  /// screen until the new ones land, and `_query` moves with them so the
  /// empty state never shows for a query still in flight.
  Future<void> _search(String q, int generation) async {
    final Stopwatch sw = Stopwatch()..start();
    final SearchResults r = await ref.read(dictProvider).searchAll(q);
    sw.stop();
    if (!mounted || generation != _generation) return;
    setState(() {
      _query = q;
      _words = r.words;
      _idioms = r.idioms;
      _suggestions = r.suggestions;
      // A 2dp hairline, only if a query exceeds 120 ms.
      _slow = sw.elapsedMilliseconds > 120;
      if (r.words.isEmpty && r.idioms.isNotEmpty) _segment = SearchSegment.idioms;
    });
    if (q.trim().length >= 2) {
      _recordTimer = Timer(const Duration(seconds: 2), () {
        unawaited(ref.read(userRepositoryProvider).recordSearch(q.trim()).then((_) => _loadRecent()));
      });
    }
  }

  void _set(String q) {
    _field.text = q;
    _field.selection = TextSelection.collapsed(offset: q.length);
    _run(q);
  }

  Future<void> _openWord(DictionaryWord w) async {
    await ref.read(userRepositoryProvider).recordLookup(w.wordKey);
    if (!mounted) return;
    await showWordSheet(context, wordKey: w.wordKey, fromSearch: true);
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final bool typing = _query.trim().isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        // Fixed header: the field and the toggle are this page's primary
        // control, and nothing docks under a floating one.
        body: HeaderPage(
          floating: false,
          header: AppHeader(
            title: 'Search',
            onBack: Navigator.of(context).canPop() ? () => Navigator.of(context).pop() : null,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              HeaderPage.gap(),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.md),
                child: SearchField(
                  controller: _field,
                  focusNode: _focus,
                  hint: 'Search words and phrases',
                  onChanged: _run,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                child: SegmentedToggle<SearchSegment>(
                  options: const <(SearchSegment, String)>[
                    (SearchSegment.words, 'Words'),
                    (SearchSegment.idioms, 'Phrases'),
                  ],
                  selected: _segment,
                  counts: typing
                      ? <Object?, int>{SearchSegment.words: _words.length, SearchSegment.idioms: _idioms.length}
                      : const <Object?, int>{},
                  onChanged: (SearchSegment s) => setState(() => _segment = s),
                  accent: true,
                ),
              ),
              LoadingHairline(visible: _slow),
              Expanded(child: typing ? _results(c) : _recentList(c)),
            ],
          ),
        ),
      ),
    );
  }

  /// "Remove from history?" with the term itself; Remove deletes that entry
  /// only and the row animates out. Cancel or a swipe down changes nothing.
  Future<void> _confirmRemove(String q) async {
    final bool? ok = await showAppBottomSheet<bool>(
      context: context,
      title: 'Remove from history?',
      builder: (BuildContext ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(q, style: MullType.titleMedium.copyWith(color: ctx.colors.onSurface)),
          const SizedBox(height: Space.lg),
          AppButton(
            label: 'Remove',
            type: AppButtonType.danger,
            fullWidth: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          const SizedBox(height: Space.sm),
          AppButton(
            label: 'Cancel',
            type: AppButtonType.outlined,
            fullWidth: true,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(userRepositoryProvider).deleteRecentSearch(q);
    if (mounted) setState(() => _leaving.add(q));
  }

  Widget _recentList(MullColors c) {
    return ListView(
      padding: const EdgeInsets.only(top: Space.lg, bottom: Space.bottomSafe),
      children: <Widget>[
        const SectionHeader(label: 'Recent'),
        for (final String q in _recent)
          MotionListItem(
            key: ValueKey<String>(q),
            present: !_leaving.contains(q),
            onRemoved: () => setState(() {
              _recent = <String>[
                for (final String r in _recent)
                  if (r != q) r,
              ];
              _leaving.remove(q);
            }),
            child: Semantics(
              customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
                const CustomSemanticsAction(label: 'Remove from history'): () => unawaited(_confirmRemove(q)),
              },
              child: Pressable(
                kind: PressKind.row,
                onTap: () => _set(q),
                onLongPress: () => unawaited(_confirmRemove(q)),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                  alignment: Alignment.centerLeft,
                  child: Text(q, style: MullType.titleMedium.copyWith(color: c.onSurface)),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, 0),
          child: Text(
            'Anything you look up is kept here and on Home, so a word you met once is easy to find again.',
            style: MullType.note.copyWith(color: c.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _results(MullColors c) {
    final bool words = _segment == SearchSegment.words;
    if (words ? _words.isEmpty : _idioms.isEmpty) return _noResults(c);
    final int n = words ? _words.length : _idioms.length;
    SearchResult at(int i) => words ? SearchResult.word(_words[i]) : SearchResult.idiom(_idioms[i]);
    Widget? add(int i) => words ? _AddToListButton(word: _words[i]) : null;
    void open(int i) => words ? unawaited(_openWord(_words[i])) : unawaited(showIdiomSheet(context, idiom: _idioms[i]));

    if (ref.watch(settingsProvider.select((AppSettings s) => s.searchStyle)) == SearchStyle.table) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: Space.sm, bottom: Space.bottomSafe),
        itemCount: n,
        itemBuilder: (BuildContext context, int i) =>
            SearchResultRow(result: at(i), query: _query, onTap: () => open(i), trailing: add(i)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, Space.bottomSafe),
      itemCount: n,
      separatorBuilder: (BuildContext _, int _) => const SizedBox(height: Space.row),
      itemBuilder: (BuildContext context, int i) =>
          SearchResultCard(result: at(i), query: _query, onTap: () => open(i), trailing: add(i)),
    );
  }

  Widget _noResults(MullColors c) {
    final bool otherHas = _segment == SearchSegment.words ? _idioms.isNotEmpty : _words.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.screen, 48, Space.screen, Space.bottomSafe),
      children: <Widget>[
        Text('No entry for ${_query.trim()}', style: MullType.display.copyWith(fontSize: 28, color: c.onSurface)),
        const SizedBox(height: Space.row),
        Text(
          'The spelling may differ, or this edition may not carry it.',
          style: MullType.body.copyWith(color: c.onSurfaceVariant),
        ),
        if (_suggestions.isNotEmpty) ...<Widget>[
          const SizedBox(height: Space.lg),
          DidYouMean(words: _suggestions, onPick: (DictionaryWord w) => _set(w.headword)),
        ],
        const SizedBox(height: Space.lg),
        Pressable(
          onTap: () =>
              setState(() => _segment = _segment == SearchSegment.words ? SearchSegment.idioms : SearchSegment.words),
          child: Text(
            otherHas
                ? (_segment == SearchSegment.words ? 'Or search the idioms instead.' : 'Or search the words instead.')
                : 'Or search the idioms instead.',
            style: MullType.body.copyWith(color: c.accent),
          ),
        ),
      ],
    );
  }
}

/// One result, whichever table it came from. The card and the row draw the
/// same object; neither knows whether it holds a word or a phrase.
class SearchResult {
  const SearchResult({required this.title, required this.definition, required this.chip, this.pos});

  SearchResult.word(DictionaryWord w)
    : this(title: w.headword, pos: posLabel(w.pos), definition: w.definitionShort, chip: bandLabel(w.band));

  SearchResult.idiom(Idiom i) : this(title: i.phrase, definition: i.meaning, chip: i.register);

  SearchResult.phrase(Phrase p) : this(title: p.phrase, definition: p.meaning, chip: p.register);

  final String title;

  /// Null for a phrase.
  final String? pos;
  final String definition;

  /// Band for a word, register for a phrase; both are a [BandChip].
  final String chip;
}

/// One line, 44dp minimum: title (fixed 104dp, matched run tinted `accent`),
/// then part of speech italic + short definition in `onSurfaceVariant`.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    required this.result,
    required this.query,
    required this.onTap,
    this.trailing,
    this.tinted = false,
    super.key,
  });

  final SearchResult result;
  final String query;
  final VoidCallback onTap;

  /// A control at the end of the row (the shelf picker's tick).
  final Widget? trailing;

  /// `surfaceContainer` behind the row: on the shelf already.
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Pressable(
      kind: PressKind.row,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
        color: tinted ? c.surfaceContainer : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: Space.md,
          children: <Widget>[
            SizedBox(
              width: 104,
              child: highlighted(
                result.title,
                query,
                MullType.titleMedium.copyWith(color: c.onSurface),
                c.accent,
                maxLines: 1,
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    if (result.pos != null)
                      TextSpan(
                        text: '${result.pos} · ',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    TextSpan(text: result.definition),
                  ],
                ),
                style: MullType.bodySmall.copyWith(fontSize: 12.5, color: c.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// A card, not a row: radius 20, `surfaceContainer`, title in `sheetTitle`
/// with the matched run highlighted `primaryContainer`, meaning in `body`, a
/// band or register chip below. A phrase is never mistaken for a headword.
class SearchResultCard extends StatelessWidget {
  const SearchResultCard({
    required this.result,
    required this.query,
    required this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
    this.trailing,
    super.key,
  });

  final SearchResult result;
  final String query;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;

  /// A control at the top right, beside the chip (the shelf picker's tick).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: selected ? c.surfaceContainer : c.surfaceContainer,
          borderRadius: Radii.cardR,
          border: Border.all(color: selected ? c.primary : c.outline, width: selected ? 1.5 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (selecting) ...<Widget>[
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: Space.md, top: 2),
                decoration: BoxDecoration(
                  color: selected ? c.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: selected ? c.primary : c.outline, width: 1.5),
                ),
                child: selected ? Icon(Icons.check_rounded, size: 15, color: c.onPrimary) : null,
              ),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  highlighted(
                    result.title,
                    query,
                    MullType.sheetTitle.copyWith(color: c.onSurface),
                    c.onPrimaryContainer,
                    background: c.primaryContainer,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result.definition,
                    style: MullType.body.copyWith(color: c.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Space.sm),
                  BandChip(result.chip),
                ],
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(left: Space.md),
                child: trailing,
              ),
          ],
        ),
      ),
    );
  }
}

/// The add-to-list control at the end of a word result. Mull shows no saved
/// state on this glyph anywhere (only bookmark has one), so neither does it.
class _AddToListButton extends StatelessWidget {
  const _AddToListButton({required this.word});

  final DictionaryWord word;

  @override
  Widget build(BuildContext context) => AppIconButton(
    icon: Icons.playlist_add_rounded,
    semanticLabel: 'Add ${word.headword} to a list',
    filled: false,
    onPressed: () => unawaited(showAddToListSheet(context, wordKey: word.wordKey, headword: word.headword)),
  );
}

/// [text] with the first case-insensitive occurrence of [query] tinted.
/// Wraps freely unless [maxLines] bounds it.
Widget highlighted(String text, String query, TextStyle style, Color tint, {Color? background, int? maxLines}) {
  final String q = query.trim().toLowerCase();
  final int i = q.isEmpty ? -1 : text.toLowerCase().indexOf(q);
  if (i < 0) return Text(text, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
  return Text.rich(
    TextSpan(
      children: <InlineSpan>[
        TextSpan(text: text.substring(0, i)),
        TextSpan(
          text: text.substring(i, i + q.length),
          style: TextStyle(color: tint, backgroundColor: background),
        ),
        TextSpan(text: text.substring(i + q.length)),
      ],
    ),
    style: style,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
  );
}
