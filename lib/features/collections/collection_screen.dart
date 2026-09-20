import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/user_db.dart';
import '../../core/database/user_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_menu.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/states.dart';
import '../dictionary/idiom_sheet.dart';
import '../dictionary/search_screen.dart';
import '../dictionary/word_sheet.dart';
import '../settings/settings_controller.dart';
import 'create_list_sheet.dart';
import '../quiz/quiz_screen.dart';
import 'shelf_export_sheet.dart';

enum SortCriterion {
  name('name', 'Name'),
  frequency('frequency', 'Frequency'),
  bookmarked('bookmarked', 'Bookmark first');

  const SortCriterion(this.key, this.label);

  final String key;
  final String label;

  static SortCriterion fromKey(String k) => switch (k) {
    'frequency' => SortCriterion.frequency,
    'bookmarked' => SortCriterion.bookmarked,
    _ => SortCriterion.name,
  };
}

enum CollectionViewMode {
  card('card', 'Card view'),
  table('table', 'Table view');

  const CollectionViewMode(this.key, this.label);

  final String key;
  final String label;
}

/// Unified entry wrapping a word, phrase or legacy idiom.
class CollectionEntry {
  CollectionEntry.word(this.word) : phrase = null, idiom = null;
  CollectionEntry.phrase(this.phrase) : word = null, idiom = null;
  CollectionEntry.idiom(this.idiom) : word = null, phrase = null;

  final DictionaryWord? word;
  final Phrase? phrase;
  final Idiom? idiom;

  bool get isWord => word != null;
  String get key => word?.wordKey ?? phrase?.phraseKey ?? idiom!.idiomKey;
  String get title => word?.headword ?? phrase?.phrase ?? idiom!.phrase;
  String get definition =>
      word?.definitionShort ?? phrase?.meaning ?? idiom!.meaning;
  String? get example =>
      word != null ? null : (phrase?.example ?? idiom?.example);
  String get chip => word != null
      ? bandLabel(word!.band)
      : (phrase?.register ?? idiom!.register);
  String? get pos =>
      word != null ? posLabel(word!.pos) : (phrase?.type ?? 'phrase');
  int get freqRank => word?.freqRank ?? phrase?.freqRank ?? 999999;

  SearchResult toSearchResult() {
    if (word != null) return SearchResult.word(word!);
    if (phrase != null) return SearchResult.phrase(phrase!);
    return SearchResult.idiom(idiom!);
  }
}

/// A shelf's rows in shelf order, read from the dictionary once per change
/// of its keys and never in `build()`: a 1,600-word shelf costs 100 ms cold
/// to materialise, and the screen rebuilds on every scroll-direction change,
/// filter keystroke and seen write. Rebuilds only sort and filter this.
final Provider<List<CollectionEntry>> Function(String) shelfEntriesProvider =
    Provider.autoDispose.family<List<CollectionEntry>, String>((
      Ref ref,
      String slug,
    ) {
      final DictionaryDb dict = ref.watch(dictProvider);
      final List<String> keys =
          ref.watch(
            collectionKeysProvider.select(
              (Map<String, List<String>> m) => m[slug],
            ),
          ) ??
          const <String>[];
      final String? kind = ref.watch(
        collectionBySlugProvider.select(
          (Map<String, Collection> m) => m[slug]?.kind,
        ),
      );
      final Map<String, DictionaryWord> wordsByKey = <String, DictionaryWord>{
        for (final DictionaryWord w in dict.byKeys(keys)) w.wordKey: w,
      };
      final Map<String, Phrase> phrasesByKey = <String, Phrase>{
        for (final Phrase p in dict.phrasesByKeys(keys)) p.phraseKey: p,
      };
      final List<CollectionEntry> entries = <CollectionEntry>[
        for (final String k in keys)
          if (wordsByKey[k] case final DictionaryWord w)
            CollectionEntry.word(w)
          else if (phrasesByKey[k] case final Phrase p)
            CollectionEntry.phrase(p),
      ];
      if (entries.isEmpty && kind == 'idiom') {
        for (final Idiom i in dict.collectionIdioms(slug)) {
          entries.add(CollectionEntry.idiom(i));
        }
      }
      return entries;
    });

/// Shelf screen supporting Card and Table views, real-time filtering,
/// sort menu, view switcher, and overflow menu with "Mull these".
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({required this.slug, super.key});

  /// A dictionary slug or one of the user's (`bookmarks`, `reading`, `u{n}`).
  final String slug;

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  String get _scopeKey => widget.slug;
  late SortCriterion _sortCriterion = SortCriterion.fromKey(
    ref.read(settingsProvider.notifier).sort(_scopeKey),
  );
  late bool _sortAscending = ref
      .read(settingsProvider.notifier)
      .sortAscending(_scopeKey);
  late CollectionViewMode _viewMode =
      ref.read(settingsProvider.notifier).lens(_scopeKey) == 'table'
      ? CollectionViewMode.table
      : CollectionViewMode.card;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';

  final Set<String> _selected = <String>{};
  bool _selecting = false;

  bool _buttonsVisible = true;
  double _scrollTravel = 0.0;

  /// False until the push transition has played. Reading a 1,600-row shelf
  /// costs 100 ms or more on a phone; done during the route's first frame it
  /// swallows the whole 240 ms `page.push`, so skeletons hold the space
  /// until the animation is over.
  bool _ready = false;

  UserRepository get _user => ref.read(userRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_user.setAppState(UserRepository.kLastOpened, widget.slug));
    unawaited(_user.recordCollectionOpened(widget.slug));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final Animation<double>? push = ModalRoute.of(context)?.animation;
      if (push == null || push.isCompleted) {
        setState(() => _ready = true);
        return;
      }
      void onStatus(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        push.removeStatusListener(onStatus);
        if (mounted) setState(() => _ready = true);
      }
      push.addStatusListener(onStatus);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openCards() {
    unawaited(ref.read(settingsProvider.notifier).setLens(_scopeKey, 'cards'));
    context.go(Routes.scoped(widget.slug));
  }

  void _openAdd({bool phrases = false}) =>
      unawaited(context.push(Routes.shelfAdd(widget.slug, phrases: phrases)));

  Future<void> _deleteSelected(List<String> keys) async {
    final List<String> removed = keys.toList();
    for (final String k in removed) {
      await _user.removeFromCollection(widget.slug, k);
    }
    setState(() {
      _selected.clear();
      _selecting = false;
    });
    if (!mounted) return;
    AppSnackbar.undo(context, 'Removed ${removed.length} items', () async {
      for (final String k in removed) {
        await _user.addToCollection(widget.slug, k);
      }
    });
  }

  void _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final double delta = notification.scrollDelta ?? 0;
      final ScrollMetrics metrics = notification.metrics;
      if (!metrics.hasContentDimensions ||
          metrics.maxScrollExtent <= 0 ||
          metrics.pixels <= metrics.minScrollExtent) {
        if (!_buttonsVisible) setState(() => _buttonsVisible = true);
        return;
      }
      if (delta == 0) return;
      if (delta.sign != _scrollTravel.sign) _scrollTravel = 0;
      _scrollTravel += delta;
      if (_scrollTravel > 24 && _buttonsVisible) {
        setState(() => _buttonsVisible = false);
      } else if (_scrollTravel < -24 && !_buttonsVisible) {
        setState(() => _buttonsVisible = true);
      }
    }
  }

  Future<void> _showAddMenu(BuildContext anchor) async {
    final String? action = await showAppMenu<String>(
      context: anchor,
      anchorContext: anchor,
      entries: const <AppMenuEntry<String>>[
        AppMenuEntry<String>(
          value: 'add_words',
          label: 'Add words',
          icon: Icons.add_rounded,
        ),
        AppMenuEntry<String>(
          value: 'add_phrases',
          label: 'Add phrases',
          icon: Icons.add_rounded,
        ),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'add_words':
        _openAdd();
      case 'add_phrases':
        _openAdd(phrases: true);
    }
  }

  Future<void> _overflow(
    BuildContext anchor,
    Collection? collection,
    List<CollectionEntry> allEntries,
  ) async {
    final bool own = collection?.isUsers ?? false;
    final int wordCount = allEntries
        .where((CollectionEntry entry) => entry.isWord)
        .length;
    final String? action = await showAppMenu<String>(
      context: anchor,
      anchorContext: anchor,
      minWidth: 220,
      entries: <AppMenuEntry<String>>[
        // Segment 1: Mull these.
        if (allEntries.isNotEmpty) ...<AppMenuEntry<String>>[
          const AppMenuEntry<String>(
            value: 'mull',
            label: 'Mull these',
            icon: Icons.play_arrow_rounded,
          ),
          AppMenuEntry<String>(
            value: 'quiz',
            label: 'Quiz',
            subtitle: wordCount >= QuizScreen.minimumWords
                ? '10 questions from this shelf'
                : 'needs ${QuizScreen.minimumWords} words · this shelf has $wordCount',
            icon: Icons.quiz_outlined,
            enabled: wordCount >= QuizScreen.minimumWords,
          ),
          const AppMenuEntry<String>.divider(),
        ],

        // Segment 2: Add words, Add phrases
        const AppMenuEntry<String>(
          value: 'add_words',
          label: 'Add words',
          icon: Icons.add_rounded,
        ),
        const AppMenuEntry<String>(
          value: 'add_phrases',
          label: 'Add phrases',
          icon: Icons.add_rounded,
        ),
        if (own)
          const AppMenuEntry<String>(
            value: 'select',
            label: 'Select words',
            icon: Icons.checklist_rounded,
          ),

        // Segment 3: Import words, Export this shelf
        const AppMenuEntry<String>.divider(),
        const AppMenuEntry<String>(
          value: 'import_words',
          label: 'Import words',
          subtitle: 'paste a table or pick a CSV',
          icon: Icons.file_upload_outlined,
        ),
        const AppMenuEntry<String>(
          value: 'export_shelf',
          label: 'Export this shelf',
          subtitle: 'CSV or PDF',
          icon: Icons.ios_share_rounded,
        ),

        // Segment 4: Shelf stats
        const AppMenuEntry<String>.divider(),
        const AppMenuEntry<String>(
          value: 'shelf_stats',
          label: 'Shelf stats',
          icon: Icons.query_stats_rounded,
        ),

        // Segment 3: Sort: Name, sort: Frequency, Sort: Bookmark first
        const AppMenuEntry<String>.divider(),
        AppMenuEntry<String>(
          value: 'sort_name',
          label: 'Sort: Name',
          icon: Icons.sort_by_alpha_rounded,
          selected: _sortCriterion == SortCriterion.name,
        ),
        AppMenuEntry<String>(
          value: 'sort_frequency',
          label: 'Sort: Frequency',
          icon: Icons.bar_chart_rounded,
          selected: _sortCriterion == SortCriterion.frequency,
        ),
        AppMenuEntry<String>(
          value: 'sort_bookmarked',
          label: 'Sort: Bookmark first',
          icon: Icons.bookmark_border_rounded,
          selected: _sortCriterion == SortCriterion.bookmarked,
        ),

        // Segment 4: Order: ASCENDING, Order: DESCENDING
        const AppMenuEntry<String>.divider(),
        AppMenuEntry<String>(
          value: 'order_asc',
          label: 'Order: ASCENDING',
          icon: Icons.arrow_upward_rounded,
          selected: _sortAscending,
        ),
        AppMenuEntry<String>(
          value: 'order_desc',
          label: 'Order: DESCENDING',
          icon: Icons.arrow_downward_rounded,
          selected: !_sortAscending,
        ),

        // Segment 5: View mode: Cards, View mode: Table
        const AppMenuEntry<String>.divider(),
        AppMenuEntry<String>(
          value: 'view_card',
          label: 'View mode: Cards',
          icon: Icons.view_agenda_outlined,
          selected: _viewMode == CollectionViewMode.card,
        ),
        AppMenuEntry<String>(
          value: 'view_table',
          label: 'View mode: Table',
          icon: Icons.table_rows_outlined,
          selected: _viewMode == CollectionViewMode.table,
        ),

        // Segment 6: Delete in red just like in perch long press menu.
        if (collection?.kind == 'user') ...<AppMenuEntry<String>>[
          const AppMenuEntry<String>.divider(),
          const AppMenuEntry<String>(
            value: 'rename',
            label: 'Rename',
            icon: Icons.edit_outlined,
          ),
          const AppMenuEntry<String>(
            value: 'delete',
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            danger: true,
          ),
        ],
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'mull':
        _openCards();
      case 'quiz':
        unawaited(context.push(Routes.quiz(widget.slug)));
      case 'add_words':
        _openAdd();
      case 'add_phrases':
        _openAdd(phrases: true);
      case 'import_words':
        unawaited(context.push('${Routes.importWords}?target=${widget.slug}'));
      case 'export_shelf':
        unawaited(
          showShelfExportSheet(
            context,
            slug: widget.slug,
            shelfTitle: collection?.title ?? widget.slug,
          ),
        );
      case 'shelf_stats':
        unawaited(context.push(Routes.shelfStats(widget.slug)));
      case 'select':
        setState(() => _selecting = true);
      case 'sort_name':
        setState(() => _sortCriterion = SortCriterion.name);
        unawaited(
          ref.read(settingsProvider.notifier).setSort(_scopeKey, 'name'),
        );
      case 'sort_frequency':
        setState(() => _sortCriterion = SortCriterion.frequency);
        unawaited(
          ref.read(settingsProvider.notifier).setSort(_scopeKey, 'frequency'),
        );
      case 'sort_bookmarked':
        setState(() => _sortCriterion = SortCriterion.bookmarked);
        unawaited(
          ref.read(settingsProvider.notifier).setSort(_scopeKey, 'bookmarked'),
        );
      case 'order_asc':
        setState(() => _sortAscending = true);
        unawaited(
          ref
              .read(settingsProvider.notifier)
              .setSortAscending(_scopeKey, value: true),
        );
      case 'order_desc':
        setState(() => _sortAscending = false);
        unawaited(
          ref
              .read(settingsProvider.notifier)
              .setSortAscending(_scopeKey, value: false),
        );
      case 'view_card':
        setState(() => _viewMode = CollectionViewMode.card);
        unawaited(
          ref.read(settingsProvider.notifier).setLens(_scopeKey, 'cards'),
        );
      case 'view_table':
        setState(() => _viewMode = CollectionViewMode.table);
        unawaited(
          ref.read(settingsProvider.notifier).setLens(_scopeKey, 'table'),
        );
      case 'rename':
        await showCreateListSheet(
          context,
          renameSlug: widget.slug,
          initialName: collection!.title,
          initialColor: collection.color,
        );
      case 'delete':
        final bool ok = await confirmDialog(
          context,
          title: 'Delete ${collection!.title}?',
          message:
              'The words stay in the dictionary. Only the shelf is removed.',
          confirmLabel: 'Delete',
        );
        if (ok) {
          await _user.deleteCollection(widget.slug);
          if (mounted) context.pop();
        }
    }
  }

  void _handleItemTap(CollectionEntry entry) {
    if (_selecting) {
      setState(() {
        if (_selected.contains(entry.key)) {
          _selected.remove(entry.key);
        } else {
          _selected.add(entry.key);
        }
      });
    } else if (entry.isWord) {
      showWordSheet(context, wordKey: entry.key);
    } else if (entry.phrase != null) {
      showIdiomSheet(
        context,
        idiom: Idiom(
          idiomKey: entry.phrase!.phraseKey,
          phrase: entry.phrase!.phrase,
          meaning: entry.phrase!.meaning,
          example: entry.phrase!.example,
          register: entry.phrase!.register,
        ),
      );
    } else if (entry.idiom != null) {
      showIdiomSheet(context, idiom: entry.idiom!);
    }
  }

  void _handleItemLongPress(CollectionEntry entry, bool own) async {
    if (ref.read(settingsProvider).haptics) {
      unawaited(HapticFeedback.lightImpact());
    }
    if (own) {
      setState(() {
        _selecting = true;
        _selected.add(entry.key);
      });
    } else {
      final bool on = await _user.toggleBookmark(entry.key);
      if (!on && mounted) {
        AppSnackbar.undo(
          context,
          'Removed bookmark',
          () => _user.addBookmark(entry.key),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final DictionaryDb dict = ref.watch(dictProvider);
    final Set<String> bookmarks =
        ref.watch(bookmarksProvider).value ?? const <String>{};
    final Map<String, SeenWord> seen =
        ref.watch(seenMapProvider).value ?? const <String, SeenWord>{};

    final Collection? collection = ref.watch(
      collectionBySlugProvider,
    )[widget.slug];
    final bool own = collection?.isUsers ?? false;
    final String title = collection?.title ?? '';

    final List<CollectionEntry> rawEntries = _ready
        ? ref.watch(shelfEntriesProvider(widget.slug))
        : const <CollectionEntry>[];

    // Sort entries
    List<CollectionEntry> sortedEntries = List<CollectionEntry>.of(rawEntries);
    switch (_sortCriterion) {
      case SortCriterion.name:
        sortedEntries.sort(
          (CollectionEntry a, CollectionEntry b) => a.title.compareTo(b.title),
        );
      case SortCriterion.frequency:
        sortedEntries.sort(
          (CollectionEntry a, CollectionEntry b) =>
              a.freqRank.compareTo(b.freqRank),
        );
      case SortCriterion.bookmarked:
        sortedEntries.sort((CollectionEntry a, CollectionEntry b) {
          final int ba = bookmarks.contains(a.key) ? 0 : 1;
          final int bb = bookmarks.contains(b.key) ? 0 : 1;
          return ba != bb ? ba.compareTo(bb) : a.title.compareTo(b.title);
        });
    }
    if (!_sortAscending) {
      sortedEntries = sortedEntries.reversed.toList();
    }

    // Real-time filter
    final String q = _searchQuery.trim().toLowerCase();
    final List<CollectionEntry> displayItems = q.isEmpty
        ? sortedEntries
        : sortedEntries.where((CollectionEntry e) {
            return e.title.toLowerCase().contains(q) ||
                e.definition.toLowerCase().contains(q);
          }).toList();

    final int seenCount = rawEntries
        .where((CollectionEntry e) => seen.containsKey(e.key))
        .length;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_selecting)
                    _SelectionHeader(
                      count: _selected.length,
                      onClose: () => setState(() {
                        _selecting = false;
                        _selected.clear();
                      }),
                      onBookmark: () async {
                        for (final String k in _selected) {
                          await _user.addBookmark(k);
                        }
                        setState(() {
                          _selecting = false;
                          _selected.clear();
                        });
                      },
                      onDelete: own
                          ? () => _deleteSelected(_selected.toList())
                          : null,
                    )
                  else
                    AppHeader(
                      title: title,
                      onBack: () => context.pop(),
                      actions: <Widget>[
                        Builder(
                          builder: (BuildContext anchor) => AppIconButton(
                            icon: Icons.add_rounded,
                            semanticLabel: 'Add',
                            onPressed: () => unawaited(_showAddMenu(anchor)),
                          ),
                        ),
                        Builder(
                          builder: (BuildContext anchor) => AppIconButton(
                            icon: Icons.more_horiz_rounded,
                            semanticLabel: 'More',
                            onPressed: () => unawaited(
                              _overflow(anchor, collection, rawEntries),
                            ),
                          ),
                        ),
                      ],
                    ),

                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification n) {
                        _onScroll(n);
                        return false;
                      },
                      child: CustomScrollView(
                        slivers: <Widget>[
                          // Top row: Search bar + info row
                          SliverToBoxAdapter(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Space.screen,
                                  ),
                                  child: Container(
                                    height: 44,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.surfaceContainer,
                                      borderRadius: Radii.fullR,
                                      border: Border.all(color: c.outline),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.search_rounded,
                                          size: 18,
                                          color: c.iconMuted,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: _searchController,
                                            focusNode: _searchFocus,
                                            autofocus: false,
                                            onChanged: (String val) => setState(
                                              () => _searchQuery = val,
                                            ),
                                            style: MullType.body.copyWith(
                                              fontSize: 14,
                                              color: c.onSurface,
                                            ),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              border: InputBorder.none,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                  ),
                                              hintText: 'Search shelf',
                                              hintStyle: MullType.body.copyWith(
                                                fontSize: 14,
                                                color: c.onSurfaceMuted,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (_searchQuery.isNotEmpty)
                                          AppIconButton(
                                            icon: Icons.close_rounded,
                                            size: 28,
                                            glyphSize: 16,
                                            filled: false,
                                            semanticLabel: 'Clear',
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _searchQuery = '');
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    Space.screen,
                                    Space.sm,
                                    Space.screen,
                                    Space.xs,
                                  ),
                                  child: Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: Space.sm,
                                    runSpacing: Space.xs,
                                    children: <Widget>[
                                      Text(
                                        // The collection's own count while the rows are still to come.
                                        '${_ready ? displayItems.length : collection?.wordCount ?? 0} items · $seenCount seen',
                                        style: MullType.monoLabel.copyWith(
                                          color: c.onSurfaceMuted,
                                        ),
                                      ),
                                      Text(
                                        'Sort: ${_sortCriterion.label} (${_sortAscending ? 'ASC' : 'DESC'})',
                                        style: MullType.monoLabel.copyWith(
                                          color: c.onSurfaceMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_ready)
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                Space.screen,
                                Space.sm,
                                Space.screen,
                                Space.bottomSafe + 48,
                              ),
                              sliver: SliverList.separated(
                                itemCount: 6,
                                separatorBuilder: (BuildContext _, int _) =>
                                    const SizedBox(height: Space.row),
                                itemBuilder: (BuildContext _, int _) =>
                                    _viewMode == CollectionViewMode.card
                                    ? const SkeletonCard()
                                    : const SkeletonRow(),
                              ),
                            )
                          else if (displayItems.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: rawEntries.isEmpty
                                  ? EmptyState(
                                      title: 'No items on this shelf yet',
                                      message: 'Add words or phrases from the overflow, or paste a table.',
                                      actionLabel: 'Add words to it',
                                      onAction: () =>
                                          _openAdd(),
                                    )
                                  : Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(
                                          Space.screen,
                                        ),
                                        child: Text(
                                          'No results for "$_searchQuery"',
                                          style: MullType.body.copyWith(
                                            color: c.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                            )
                          else if (_viewMode == CollectionViewMode.card)
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                Space.screen,
                                Space.sm,
                                Space.screen,
                                Space.bottomSafe + 48,
                              ),
                              sliver: SliverList.separated(
                                itemCount: displayItems.length,
                                separatorBuilder: (BuildContext _, int _) =>
                                    const SizedBox(height: Space.row),
                                itemBuilder: (BuildContext context, int i) {
                                  final CollectionEntry item = displayItems[i];
                                  return SearchResultCard(
                                    result: item.toSearchResult(),
                                    query: _searchQuery,
                                    selecting: _selecting,
                                    selected: _selected.contains(item.key),
                                    onTap: () => _handleItemTap(item),
                                    onLongPress: () =>
                                        _handleItemLongPress(item, own),
                                  );
                                },
                              ),
                            )
                          else ...<Widget>[
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _TableHeader(c),
                            ),
                            SliverList.builder(
                              itemCount: displayItems.length,
                              itemBuilder: (BuildContext context, int i) {
                                final CollectionEntry item = displayItems[i];
                                final String? ex =
                                    item.example ??
                                    (item.isWord
                                        ? dict.examples(item.key).firstOrNull
                                        : null);
                                return WordTableRow(
                                  title: item.title,
                                  definition: item.definition,
                                  example: ex,
                                  bookmarked: bookmarks.contains(item.key),
                                  selecting: _selecting,
                                  selected: _selected.contains(item.key),
                                  onTap: () => _handleItemTap(item),
                                  onLongPress: () =>
                                      _handleItemLongPress(item, own),
                                );
                              },
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: Space.bottomSafe + 48),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (!_selecting)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: !_buttonsVisible,
                    child: AnimatedSlide(
                      duration: Motion.navHide,
                      curve: Motion.curveOf(context, Motion.standard),
                      offset: _buttonsVisible
                          ? Offset.zero
                          : const Offset(0, 1.2),
                      child: AnimatedOpacity(
                        duration: Motion.fast,
                        curve: Motion.curveOf(context, Motion.standard),
                        opacity: _buttonsVisible ? 1.0 : 0.0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                c.surface.withValues(alpha: 0),
                                c.surface.withValues(alpha: 0.85),
                                c.surface,
                              ],
                              stops: const <double>[0, 0.4, 1],
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                Space.screen,
                                Space.md,
                                Space.screen,
                                Space.md,
                              ),
                              child: Center(
                                child: AppButton(
                                  label: 'Mull',
                                  icon: Icons.play_arrow_rounded,
                                  type: AppButtonType.primary,
                                  fullWidth: false,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Space.xl,
                                    vertical: Space.xs,
                                  ),
                                  onPressed: rawEntries.isEmpty
                                      ? null
                                      : _openCards,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Multi-select: the header turns `primaryContainer`, shows "{n} selected"
/// and bookmark/delete actions.
class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({
    required this.count,
    required this.onClose,
    required this.onBookmark,
    this.onDelete,
  });

  final int count;
  final VoidCallback onClose;
  final VoidCallback onBookmark;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Container(
      color: c.primaryContainer,
      padding: const EdgeInsets.fromLTRB(Space.lg, 14, Space.lg, Space.md),
      child: Row(
        children: <Widget>[
          AppIconButton(
            icon: Icons.close_rounded,
            semanticLabel: 'Cancel selection',
            onPressed: onClose,
            tint: c.onPrimaryContainer,
            background: Colors.transparent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$count selected',
              style: MullType.headerTitle.copyWith(color: c.onPrimaryContainer),
            ),
          ),
          AppIconButton(
            icon: Icons.bookmark_border_rounded,
            semanticLabel: 'Bookmark selected',
            onPressed: count == 0 ? null : onBookmark,
            tint: c.onPrimaryContainer,
            background: Colors.transparent,
          ),
          if (onDelete != null)
            AppIconButton(
              icon: Icons.delete_outline_rounded,
              semanticLabel: 'Remove selected',
              onPressed: count == 0 ? null : onDelete,
              tint: c.onPrimaryContainer,
              background: Colors.transparent,
            ),
        ],
      ),
    );
  }
}

/// Sticky three-column header: WORD / DEFINITION / EXAMPLE.
class _TableHeader extends SliverPersistentHeaderDelegate {
  _TableHeader(this.c);

  final MullColors c;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: Space.screen),
    decoration: BoxDecoration(
      color: c.surface,
      border: Border(bottom: BorderSide(color: c.divider)),
    ),
    child: Row(
      children: <Widget>[
        SizedBox(
          width: 82,
          child: Text(
            'WORD',
            style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: Space.sm),
        Expanded(
          flex: 11,
          child: Text(
            'DEFINITION',
            style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: Space.sm),
        Expanded(
          flex: 10,
          child: Text(
            'EXAMPLE',
            style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant),
          ),
        ),
      ],
    ),
  );

  @override
  double get maxExtent => 32;
  @override
  double get minExtent => 32;
  @override
  bool shouldRebuild(_TableHeader old) => old.c != c;
}

/// Three columns in one 48dp-minimum row: word/phrase title (82dp, `titleMedium`),
/// definition (flex 1.1, `tableCell`), example (flex 1, italic). Bookmarked:
/// a 5dp `primary` dot after the word.
class WordTableRow extends StatelessWidget {
  const WordTableRow({
    required this.title,
    required this.definition,
    required this.example,
    required this.bookmarked,
    required this.onTap,
    required this.onLongPress,
    this.selecting = false,
    this.selected = false,
    super.key,
  });

  final String title;
  final String definition;
  final String? example;
  final bool bookmarked;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.screen,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selected ? c.surfaceContainer : null,
          border: Border(bottom: BorderSide(color: c.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (selecting) ...<Widget>[
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? c.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selected ? c.primary : c.outline,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 15, color: c.onPrimary)
                    : null,
              ),
              const SizedBox(width: Space.md),
            ],
            SizedBox(
              width: 82,
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(text: title),
                    if (bookmarked)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(left: 5, bottom: 4),
                          decoration: BoxDecoration(
                            color: c.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                style: MullType.titleMedium.copyWith(color: c.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              flex: 11,
              child: Text(
                definition,
                style: MullType.tableCell.copyWith(color: c.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              flex: 10,
              child: Text(
                example ?? '',
                style: MullType.tableCell.copyWith(
                  color: c.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
