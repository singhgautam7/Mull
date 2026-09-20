import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/user_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/states.dart';
import '../dictionary/search_screen.dart';
import 'collection_screen.dart' show CollectionEntry, shelfEntriesProvider;

/// HANDOFF 26 (board D1): one search, many words, each row a toggle that
/// says whether the entry is on the shelf. Adding is silent, removing raises
/// Undo, nothing is staged and `Done` only closes the page.
class AddToShelfScreen extends ConsumerStatefulWidget {
  const AddToShelfScreen({required this.slug, required this.phrases, super.key});

  final String slug;

  /// Phrases search the phrase index and render as cards; words, rows.
  final bool phrases;

  @override
  ConsumerState<AddToShelfScreen> createState() => _AddToShelfScreenState();
}

class _AddToShelfScreenState extends ConsumerState<AddToShelfScreen> {
  final TextEditingController _field = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';
  List<DictionaryWord> _words = const <DictionaryWord>[];
  List<Idiom> _idioms = const <Idiom>[];
  int _addedNow = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  Timer? _debounce;
  int _generation = 0;

  /// Debounced and off the UI isolate, as the Search tab is.
  void _run(String q) {
    _debounce?.cancel();
    final int generation = ++_generation;
    if (q.trim().isEmpty) {
      setState(() {
        _query = q;
        _words = const <DictionaryWord>[];
        _idioms = const <Idiom>[];
      });
      return;
    }
    _debounce = Timer(kSearchDebounce, () async {
      final SearchResults r = await ref.read(dictProvider).searchAll(q);
      if (!mounted || generation != _generation) return;
      setState(() {
        _query = q;
        if (widget.phrases) {
          _idioms = r.idioms;
        } else {
          _words = r.words;
        }
      });
    });
  }

  /// [onShelf] keys the user put there; [builtIn] keys the dictionary ships
  /// on this shelf, which a tap cannot take off.
  Future<void> _toggle(String key, Set<String> onShelf, Set<String> builtIn) async {
    final UserRepository user = ref.read(userRepositoryProvider);
    if (onShelf.contains(key)) {
      await user.removeFromCollection(widget.slug, key);
      if (!mounted) return;
      setState(() => _addedNow = _addedNow > 0 ? _addedNow - 1 : 0);
      AppSnackbar.undo(
        context,
        'Taken off the shelf',
        () => user.addToCollection(widget.slug, key),
      );
    } else if (!builtIn.contains(key)) {
      await user.addToCollection(widget.slug, key);
      if (mounted) setState(() => _addedNow++);
    }
    // The field keeps its text and focus: type, tap, type, tap.
    if (mounted && _query.isNotEmpty) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final DictionaryDb dict = ref.watch(dictProvider);
    final Collection? shelf = ref.watch(collectionBySlugProvider)[widget.slug];
    final List<String> userKeys =
        ref.watch(userCollectionKeysProvider).value?[widget.slug] ?? const <String>[];
    final Set<String> onShelf = userKeys.toSet();
    final Set<String> builtIn = <String>{
      ...?ref.watch(collectionKeysProvider)[widget.slug],
      for (final Idiom i in dict.collectionIdioms(widget.slug)) i.idiomKey,
    }..removeAll(onShelf);
    final Set<String> ticked = <String>{...onShelf, ...builtIn};
    final int total = ticked.length;
    final bool typing = _query.trim().isNotEmpty;

    Widget tick(String key) => _Tick(on: ticked.contains(key));

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppHeader(
                title: widget.phrases ? 'Add phrases' : 'Add words',
                subtitle: '${shelf?.title ?? widget.slug} · ${plural(total, widget.phrases ? 'phrase' : 'word')}',
                onBack: () => context.pop(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.md),
                child: SearchField(
                  controller: _field,
                  focusNode: _focus,
                  autofocus: true,
                  hint: widget.phrases ? 'Search phrases to add' : 'Search words to add',
                  onChanged: _run,
                ),
              ),
              Expanded(
                child: typing
                    ? _results(c, tick, onShelf, builtIn)
                    : _shelf(c, userKeys, builtIn, tick, onShelf),
              ),
              _Footer(addedNow: _addedNow, total: total, onDone: () => context.pop()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _results(
    MullColors c,
    Widget Function(String key) tick,
    Set<String> onShelf,
    Set<String> builtIn,
  ) {
    if (widget.phrases ? _idioms.isEmpty : _words.isEmpty) {
      return EmptyState(
        title: 'No entry for ${_query.trim()}',
        message: 'The spelling may differ, or this edition may not carry it.',
        showMark: false,
      );
    }
    if (widget.phrases) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.lg),
        itemCount: _idioms.length,
        separatorBuilder: (BuildContext _, int _) => const SizedBox(height: Space.row),
        itemBuilder: (BuildContext context, int i) => SearchResultCard(
          result: SearchResult.idiom(_idioms[i]),
          query: _query,
          trailing: tick(_idioms[i].idiomKey),
          onTap: () => unawaited(_toggle(_idioms[i].idiomKey, onShelf, builtIn)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: Space.sm, bottom: Space.lg),
      children: <Widget>[
        for (final DictionaryWord w in _words)
          SearchResultRow(
            result: SearchResult.word(w),
            query: _query,
            tinted: onShelf.contains(w.wordKey) || builtIn.contains(w.wordKey),
            trailing: tick(w.wordKey),
            onTap: () => unawaited(_toggle(w.wordKey, onShelf, builtIn)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, Space.lg, Space.screen, 0),
          child: Text(
            'a tick means it is on the shelf · tap it again to take it off\nkeep typing · the field stays, so the next word is one word away',
            style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted, height: 1.6),
          ),
        ),
      ],
    );
  }

  /// Before a query: the shelf itself, newest first, every row ticked, so a
  /// word can come off without being searched for. The rows come from the
  /// shelf provider, read once per change of the shelf, and the list is
  /// built lazily: a 1,600-word shelf is not 1,600 widgets.
  Widget _shelf(
    MullColors c,
    List<String> userKeys,
    Set<String> builtIn,
    Widget Function(String key) tick,
    Set<String> onShelf,
  ) {
    final Map<String, CollectionEntry> byKey = <String, CollectionEntry>{
      for (final CollectionEntry e in ref.watch(shelfEntriesProvider(widget.slug)))
        e.key: e,
    };
    final List<(String, SearchResult)> entries = <(String, SearchResult)>[
      for (final String k in <String>[...userKeys, ...builtIn])
        if (byKey[k] case final CollectionEntry e)
          if (e.isWord != widget.phrases) (k, e.toSearchResult()),
    ];
    if (entries.isEmpty) {
      return const EmptyState(
        title: 'Nothing here yet',
        message: 'Search above, or paste a table from the overflow.',
      );
    }
    Widget row(int i) {
      final (String key, SearchResult r) = entries[i];
      return widget.phrases
          ? Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.row),
              child: SearchResultCard(
                result: r,
                query: '',
                trailing: tick(key),
                onTap: () => unawaited(_toggle(key, onShelf, builtIn)),
              ),
            )
          : SearchResultRow(
              result: r,
              query: '',
              tinted: true,
              trailing: tick(key),
              onTap: () => unawaited(_toggle(key, onShelf, builtIn)),
            );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: Space.lg),
      itemCount: entries.length + 2,
      itemBuilder: (BuildContext context, int i) {
        if (i == 0) {
          return SectionHeader(
            label: 'On this shelf · ${entries.length}',
            trailing: const SectionNote('newest first'),
          );
        }
        if (i == entries.length + 1) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen, Space.lg, Space.screen, 0),
            child: Text(
              'what is already here, so a word can come off without searching for it',
              style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted, height: 1.6),
            ),
          );
        }
        return row(i - 1);
      },
    );
  }
}

/// 30dp circle: outlined `+` off the shelf, `primaryContainer` with a
/// `primary` tick on it. The row it sits in is the tap target.
class _Tick extends StatelessWidget {
  const _Tick({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return AnimatedContainer(
      duration: Motion.of(context, Motion.instant),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? c.primaryContainer : Colors.transparent,
        border: Border.all(color: on ? c.primary : c.outline, width: 1.5),
      ),
      child: Icon(
        on ? Icons.check_rounded : Icons.add_rounded,
        size: 16,
        color: on ? c.primary : c.onSurfaceVariant,
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.addedNow, required this.total, required this.onDone});

  final int addedNow;
  final int total;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, Space.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  addedNow == 0 ? 'nothing added yet' : '$addedNow added just now',
                  style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant),
                ),
                Text(
                  '$total on the shelf',
                  style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                ),
              ],
            ),
          ),
          AppButton(
            label: 'Done',
            type: addedNow > 0 ? AppButtonType.primary : AppButtonType.outlined,
            onPressed: onDone,
          ),
        ],
      ),
    );
  }
}
