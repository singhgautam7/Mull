import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/states.dart';
import '../settings/settings_controller.dart';
import 'idiom_sheet.dart';
import 'word_sheet.dart';

enum SearchSegment { words, idioms }

/// HANDOFF 3.4. Field focused on entry, real-time results, Words/Phrases
/// carrying counts. Before typing: RECENT searches. Results are cards or
/// dense rows (Settings > Appearance > Search results) with the matched run
/// tinted.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    this.addToCollectionSlug,
    this.initialSegment = SearchSegment.words,
    super.key,
  });

  final String? addToCollectionSlug;
  final SearchSegment initialSegment;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _field = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';
  List<DictionaryWord> _words = const <DictionaryWord>[];
  List<Idiom> _idioms = const <Idiom>[];
  String? _suggestion;
  late SearchSegment _segment = widget.initialSegment;
  bool _slow = false;
  List<String> _recent = const <String>[];
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _segment = widget.initialSegment;
    unawaited(_loadRecent());
  }

  Future<void> _loadRecent() async {
    final List<String> r = await ref.read(userRepositoryProvider).recentSearches();
    if (mounted) setState(() => _recent = r);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _run(String q) {
    final DictionaryDb dict = ref.read(dictProvider);
    final Stopwatch sw = Stopwatch()..start();
    final List<DictionaryWord> words = dict.search(q);
    final List<Idiom> idioms = dict.searchIdioms(q);
    sw.stop();
    setState(() {
      _query = q;
      _words = words;
      _idioms = idioms;
      _suggestion = words.isEmpty && q.trim().isNotEmpty ? dict.suggest(q) : null;
      // A 2dp hairline, only if a query exceeds 120 ms.
      _slow = sw.elapsedMilliseconds > 120;
      if (words.isEmpty && idioms.isNotEmpty) _segment = SearchSegment.idioms;
    });
    _recordTimer?.cancel();
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
    final Collection? targetCol = widget.addToCollectionSlug != null
        ? ref.watch(collectionBySlugProvider)[widget.addToCollectionSlug!]
        : null;
    final String title = widget.addToCollectionSlug != null
        ? 'Add to ${targetCol?.title ?? 'Shelf'}'
        : 'Search';

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppHeader(
                title: title,
                onBack: (widget.addToCollectionSlug != null || Navigator.of(context).canPop())
                    ? () => Navigator.of(context).pop()
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.surfaceContainer,
                    borderRadius: Radii.fullR,
                    border: Border.all(color: c.outline),
                  ),
                  child: Row(
                    spacing: 11,
                    children: <Widget>[
                      Icon(Icons.search_rounded, size: 18, color: c.iconMuted),
                      Expanded(
                        child: TextField(
                          controller: _field,
                          focusNode: _focus,
                          autofocus: widget.addToCollectionSlug == null,
                          textInputAction: TextInputAction.search,
                          onChanged: _run,
                          style: MullType.body.copyWith(fontSize: 14, color: c.onSurface),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            hintText: 'Search words and phrases',
                            hintStyle: MullType.body.copyWith(fontSize: 14, color: c.onSurfaceMuted),
                          ),
                        ),
                      ),
                      if (typing)
                        AppIconButton(
                          icon: Icons.close_rounded,
                          size: 30,
                          glyphSize: 16,
                          filled: false,
                          semanticLabel: 'Clear',
                          onPressed: () => _set(''),
                        ),
                    ],
                  ),
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
                  counts: typing ? <Object?, int>{SearchSegment.words: _words.length, SearchSegment.idioms: _idioms.length} : const <Object?, int>{},
                  onChanged: (SearchSegment s) => setState(() => _segment = s),
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

  Widget _recentList(MullColors c) {
    return ListView(
      padding: const EdgeInsets.only(top: Space.lg, bottom: Space.bottomSafe),
      children: <Widget>[
        const SectionHeader(label: 'Recent'),
        for (final String q in _recent)
          InkWell(
            onTap: () => _set(q),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: Space.screen),
              alignment: Alignment.centerLeft,
              child: Text(q, style: MullType.titleMedium.copyWith(color: c.onSurface)),
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
    void open(int i) => words ? unawaited(_openWord(_words[i])) : unawaited(showIdiomSheet(context, idiom: _idioms[i]));

    Future<void> handleTap(int i) async {
      if (widget.addToCollectionSlug != null) {
        final String slug = widget.addToCollectionSlug!;
        final String key = words ? _words[i].wordKey : _idioms[i].idiomKey;
        final List<String> currentKeys = ref.read(collectionKeysProvider)[slug] ?? const <String>[];
        final bool alreadyExists = currentKeys.contains(key) ||
            ref.read(dictProvider).collectionIdioms(slug).any((Idiom idm) => idm.idiomKey == key);
        if (alreadyExists) {
          if (mounted) {
            AppSnackbar.info(
              context,
              words
                  ? 'Word already exists in the shelf'
                  : 'Phrase already exists in the shelf',
            );
          }
          return;
        }
        await ref.read(userRepositoryProvider).addToCollection(slug, key);
        if (mounted) {
          final Collection? col = ref.read(collectionBySlugProvider)[slug];
          AppSnackbar.info(context, 'Added to ${col?.title ?? 'shelf'}');
        }
      } else {
        open(i);
      }
    }

    if (ref.watch(settingsProvider.select((AppSettings s) => s.searchStyle)) == SearchStyle.table) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: Space.sm, bottom: Space.bottomSafe),
        itemCount: n,
        itemBuilder: (BuildContext context, int i) => SearchResultRow(result: at(i), query: _query, onTap: () => handleTap(i)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, Space.bottomSafe),
      itemCount: n,
      separatorBuilder: (BuildContext _, int _) => const SizedBox(height: Space.row),
      itemBuilder: (BuildContext context, int i) => SearchResultCard(result: at(i), query: _query, onTap: () => handleTap(i)),
    );
  }

  Widget _noResults(MullColors c) {
    final bool otherHas = _segment == SearchSegment.words ? _idioms.isNotEmpty : _words.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.screen, 48, Space.screen, Space.bottomSafe),
      children: <Widget>[
        Text('No entry for ${_query.trim()}', style: MullType.display.copyWith(fontSize: 28, color: c.onSurface)),
        const SizedBox(height: Space.row),
        Text('The spelling may differ, or this edition may not carry it.', style: MullType.body.copyWith(color: c.onSurfaceVariant)),
        if (_suggestion != null) ...<Widget>[
          const SizedBox(height: Space.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: PillChip(label: 'Did you mean ${_suggestion!}?', onTap: () => _set(_suggestion!)),
          ),
        ],
        const SizedBox(height: Space.lg),
        InkWell(
          onTap: () => setState(() => _segment = _segment == SearchSegment.words ? SearchSegment.idioms : SearchSegment.words),
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

  SearchResult.phrase(Phrase p)
      : this(title: p.phrase, definition: p.meaning, chip: p.register);

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
  const SearchResultRow({required this.result, required this.query, required this.onTap, super.key});

  final SearchResult result;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: Space.md,
          children: <Widget>[
            SizedBox(
              width: 104,
              child: highlighted(result.title, query, MullType.titleMedium.copyWith(color: c.onSurface), c.accent, maxLines: 1),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    if (result.pos != null)
                      TextSpan(text: '${result.pos} · ', style: const TextStyle(fontStyle: FontStyle.italic)),
                    TextSpan(text: result.definition),
                  ],
                ),
                style: MullType.bodySmall.copyWith(fontSize: 12.5, color: c.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
    super.key,
  });

  final SearchResult result;
  final String query;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: Radii.cardR,
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: selected ? c.surfaceContainer : c.surfaceContainer,
          borderRadius: Radii.cardR,
          border: Border.all(
            color: selected ? c.primary : c.outline,
            width: selected ? 1.5 : 1,
          ),
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
                  highlighted(result.title, query, MullType.sheetTitle.copyWith(color: c.onSurface), c.onPrimaryContainer, background: c.primaryContainer),
                  const SizedBox(height: 6),
                  Text(result.definition, style: MullType.body.copyWith(color: c.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: Space.sm),
                  BandChip(result.chip),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
        TextSpan(text: text.substring(i, i + q.length), style: TextStyle(color: tint, backgroundColor: background)),
        TextSpan(text: text.substring(i + q.length)),
      ],
    ),
    style: style,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
  );
}
