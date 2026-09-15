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
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/states.dart';
import 'idiom_sheet.dart';
import 'word_sheet.dart';

enum SearchSegment { words, idioms }

/// HANDOFF 3.4. Field focused on entry, real-time results, Words/Idioms
/// carrying counts. Before typing: RECENT searches. Results are dense rows
/// with the matched run tinted; idioms render as cards.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

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
  SearchSegment _segment = SearchSegment.words;
  bool _slow = false;
  List<String> _recent = const <String>[];
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
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
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const AppHeader(title: 'Search'),
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
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onChanged: _run,
                        style: MullType.body.copyWith(fontSize: 14, color: c.onSurface),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          hintText: 'Search words and idioms',
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
                  (SearchSegment.idioms, 'Idioms'),
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
    if (_segment == SearchSegment.words) {
      if (_words.isEmpty) return _noResults(c);
      return ListView.builder(
        padding: const EdgeInsets.only(top: Space.sm, bottom: Space.bottomSafe),
        itemCount: _words.length,
        itemBuilder: (BuildContext context, int i) =>
            SearchResultRow(word: _words[i], query: _query, onTap: () => unawaited(_openWord(_words[i]))),
      );
    }
    if (_idioms.isEmpty) return _noResults(c);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, Space.bottomSafe),
      itemCount: _idioms.length,
      separatorBuilder: (BuildContext _, int _) => const SizedBox(height: Space.row),
      itemBuilder: (BuildContext context, int i) =>
          IdiomCard(idiom: _idioms[i], query: _query, onTap: () => showIdiomSheet(context, idiom: _idioms[i])),
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

/// One line, 44dp: headword (fixed 104dp, matched run tinted `accent`), then
/// part of speech italic + short definition in `onSurfaceVariant`.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({required this.word, required this.query, required this.onTap, super.key});

  final DictionaryWord word;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: Space.screen),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: Space.md,
          children: <Widget>[
            SizedBox(
              width: 104,
              child: highlighted(word.headword, query, MullType.titleMedium.copyWith(color: c.onSurface), c.accent),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(text: '${posLabel(word.pos)} · ', style: const TextStyle(fontStyle: FontStyle.italic)),
                    TextSpan(text: word.definitionShort),
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

/// A card, not a row: radius 20, `surfaceContainer`, phrase in `sheetTitle`
/// with the matched run highlighted `primaryContainer`, meaning in `body`, a
/// register chip below.
class IdiomCard extends StatelessWidget {
  const IdiomCard({required this.idiom, required this.query, required this.onTap, super.key});

  final Idiom idiom;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.cardR,
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: Radii.cardR,
          border: Border.all(color: c.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            highlighted(idiom.phrase, query, MullType.sheetTitle.copyWith(color: c.onSurface), c.onPrimaryContainer, background: c.primaryContainer),
            const SizedBox(height: 6),
            Text(idiom.meaning, style: MullType.body.copyWith(color: c.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: Space.sm),
            BandChip(idiom.register),
          ],
        ),
      ),
    );
  }
}

/// [text] with the first case-insensitive occurrence of [query] tinted.
Widget highlighted(String text, String query, TextStyle style, Color tint, {Color? background}) {
  final String q = query.trim().toLowerCase();
  final int i = q.isEmpty ? -1 : text.toLowerCase().indexOf(q);
  if (i < 0) return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  return Text.rich(
    TextSpan(
      children: <InlineSpan>[
        TextSpan(text: text.substring(0, i)),
        TextSpan(text: text.substring(i, i + q.length), style: TextStyle(color: tint, backgroundColor: background)),
        TextSpan(text: text.substring(i + q.length)),
      ],
    ),
    style: style,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}
