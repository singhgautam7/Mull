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
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/states.dart';
import '../dictionary/idiom_sheet.dart';
import '../dictionary/search_screen.dart';
import '../dictionary/word_sheet.dart';
import 'create_list_sheet.dart';
import '../settings/settings_controller.dart';

enum WordSort {
  az('az', 'A–Z'),
  frequency('frequency', 'frequency'),
  recent('recent', 'recently added'),
  bookmarked('bookmarked', 'bookmarked first');

  const WordSort(this.key, this.label);

  final String key;
  final String label;

  static WordSort fromKey(String k) => values.firstWhere((WordSort s) => s.key == k, orElse: () => WordSort.az);
}

/// HANDOFF 3.3, less the lens toggle. The table is the three-column view
/// with "Mull these" (the Mull tab scoped to the collection) and Hide defs
/// above it, sort in the overflow, count and sort pinned at the bottom. One of the user's own
/// collections opens in the same view, with multi-select.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({required this.slug, super.key});

  /// A dictionary slug or one of the user's (`bookmarks`, `reading`, `u{n}`).
  final String slug;

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  String get _scopeKey => widget.slug;
  late bool _hideDefs = ref.read(settingsProvider.notifier).hideDefs(_scopeKey);
  late WordSort _sort = WordSort.fromKey(ref.read(settingsProvider.notifier).sort(_scopeKey));
  String? _revealed;
  final Set<String> _selected = <String>{};
  bool _selecting = false;

  UserRepository get _user => ref.read(userRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_user.setAppState(UserRepository.kLastOpened, widget.slug));
  }

  void _openCards() {
    unawaited(ref.read(settingsProvider.notifier).setLens(_scopeKey, 'cards'));
    context.go(Routes.scoped(widget.slug));
  }

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
    AppSnackbar.undo(context, 'Removed ${removed.length} words', () async {
      for (final String k in removed) {
        await _user.addToCollection(widget.slug, k);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final DictionaryDb dict = ref.watch(dictProvider);
    final Set<String> bookmarks = ref.watch(bookmarksProvider).value ?? const <String>{};
    final Map<String, SeenWord> seen = ref.watch(seenMapProvider).value ?? const <String, SeenWord>{};

    final Collection? collection = ref.watch(collectionBySlugProvider)[widget.slug];
    // The user's own collections are live; "recently added" is their order.
    final bool own = collection?.isUsers ?? false;
    final List<String> ownKeys = own ? ref.watch(collectionKeysProvider)[widget.slug] ?? const <String>[] : const <String>[];
    final String title = collection?.title ?? '';

    if (collection?.kind == 'idiom') return _idioms(context, dict, collection!);

    List<DictionaryWord> words = own ? dict.byKeys(ownKeys) : dict.collectionWords(widget.slug);
    if (own) {
      final Map<String, int> order = <String, int>{for (int i = 0; i < ownKeys.length; i++) ownKeys[i]: i};
      words.sort((DictionaryWord a, DictionaryWord b) => order[a.wordKey]!.compareTo(order[b.wordKey]!));
    }
    words = switch (_sort) {
      WordSort.az => words..sort((DictionaryWord a, DictionaryWord b) => a.headword.compareTo(b.headword)),
      WordSort.frequency => words..sort((DictionaryWord a, DictionaryWord b) => a.freqRank.compareTo(b.freqRank)),
      WordSort.recent => words,
      WordSort.bookmarked => words
        ..sort((DictionaryWord a, DictionaryWord b) {
          final int ba = bookmarks.contains(a.wordKey) ? 0 : 1;
          final int bb = bookmarks.contains(b.wordKey) ? 0 : 1;
          return ba != bb ? ba.compareTo(bb) : a.headword.compareTo(b.headword);
        }),
    };
    final int seenCount = words.where((DictionaryWord w) => seen.containsKey(w.wordKey)).length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
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
                onDelete: own ? () => _deleteSelected(_selected.toList()) : null,
              )
            else
              AppHeader(
                title: title,
                onBack: () => context.pop(),
                actions: <Widget>[
                  Builder(
                    builder: (BuildContext anchor) => AppIconButton(
                      icon: Icons.more_horiz_rounded,
                      semanticLabel: 'More',
                      onPressed: () => unawaited(_overflow(anchor, collection)),
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.md),
              child: Row(
                spacing: Space.md,
                children: <Widget>[
                  Expanded(child: AppButton(label: 'Mull these', fullWidth: true, onPressed: words.isEmpty ? null : _openCards)),
                  PillChip(
                    label: _hideDefs ? 'Definitions hidden' : 'Hide defs',
                    selected: _hideDefs,
                    onTap: () {
                      setState(() {
                        _hideDefs = !_hideDefs;
                        _revealed = null;
                      });
                      unawaited(ref.read(settingsProvider.notifier).setHideDefs(_scopeKey, value: _hideDefs));
                    },
                  ),
                ],
              ),
            ),
            if (_hideDefs)
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.sm),
                child: Text('tap a row to reveal one', style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
              ),
            Expanded(
              child: words.isEmpty
                  ? EmptyState(
                      title: 'No words in here yet',
                      message: 'Add a word from a search result, the table, or the Mull tab. Both lenses work as soon as there is something to look at.',
                      actionLabel: 'Search for a word',
                      onAction: () => context.go(Routes.search),
                    )
                  : Stack(
                      children: <Widget>[
                        CustomScrollView(
                          slivers: <Widget>[
                            SliverPersistentHeader(pinned: true, delegate: _TableHeader(c)),
                            SliverList.builder(
                              itemCount: words.length,
                              itemBuilder: (BuildContext context, int i) {
                                final DictionaryWord w = words[i];
                                return WordTableRow(
                                  word: w,
                                  example: dict.examples(w.wordKey).firstOrNull,
                                  bookmarked: bookmarks.contains(w.wordKey),
                                  hideDefs: _hideDefs,
                                  revealed: _revealed == w.wordKey,
                                  selecting: _selecting,
                                  selected: _selected.contains(w.wordKey),
                                  onTap: () {
                                    if (_selecting) {
                                      setState(() => _selected.contains(w.wordKey) ? _selected.remove(w.wordKey) : _selected.add(w.wordKey));
                                    } else if (_hideDefs) {
                                      setState(() => _revealed = _revealed == w.wordKey ? null : w.wordKey);
                                    } else {
                                      showWordSheet(context, wordKey: w.wordKey);
                                    }
                                  },
                                  onLongPress: () async {
                                    // Row long-press: one haptic tick, the bookmark dot fades in at the word.
                                    if (ref.read(settingsProvider).haptics) unawaited(HapticFeedback.lightImpact());
                                    if (own) {
                                      setState(() {
                                        _selecting = true;
                                        _selected.add(w.wordKey);
                                      });
                                    } else {
                                      final bool on = await _user.toggleBookmark(w.wordKey);
                                      if (!on && context.mounted) {
                                        AppSnackbar.undo(context, 'Removed bookmark', () => _user.addBookmark(w.wordKey));
                                      }
                                    }
                                  },
                                );
                              },
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: Space.bottomSafe + 24)),
                          ],
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: Space.bottomSafe - 48,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 6),
                              color: c.surface,
                              child: Row(
                              children: <Widget>[
                                Expanded(child: Text('${grouped(words.length)} words · ${grouped(seenCount)} seen', style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted))),
                                Text('Sort: ${_sort.label}', style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
                              ],
                            ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _overflow(BuildContext anchor, Collection? collection) async {
    final bool own = collection?.isUsers ?? false;
    final String? action = await showAppMenu<String>(
      context: context,
      anchorContext: anchor,
      entries: <AppMenuEntry<String>>[
        for (final WordSort s in WordSort.values)
          if (own || s != WordSort.recent)
            AppMenuEntry<String>(value: 'sort:${s.key}', label: 'Sort: ${s.label}', radio: true, selected: _sort == s),
        if (own) ...<AppMenuEntry<String>>[
          const AppMenuEntry<String>.divider(),
          const AppMenuEntry<String>(value: 'select', label: 'Select words', icon: Icons.checklist_rounded),
        ],
        // System collections keep their names and cannot be deleted.
        if (collection?.kind == 'user') ...<AppMenuEntry<String>>[
          const AppMenuEntry<String>(value: 'rename', label: 'Rename', icon: Icons.edit_outlined),
          const AppMenuEntry<String>(value: 'delete', label: 'Delete list', icon: Icons.delete_outline_rounded, danger: true),
        ],
      ],
    );
    if (action == null || !mounted) return;
    if (action.startsWith('sort:')) {
      setState(() => _sort = WordSort.fromKey(action.substring(5)));
      unawaited(ref.read(settingsProvider.notifier).setSort(_scopeKey, _sort.key));
      return;
    }
    switch (action) {
      case 'select':
        setState(() => _selecting = true);
      case 'rename':
        await showCreateListSheet(context, renameSlug: widget.slug, initialName: collection!.title, initialColor: collection.color);
      case 'delete':
        final bool ok = await confirmDialog(context, title: 'Delete ${collection!.title}?', message: 'The words stay in the dictionary. Only the list is removed.', confirmLabel: 'Delete');
        if (ok) {
          await _user.deleteCollection(widget.slug);
          if (mounted) context.pop();
        }
    }
  }

  Widget _idioms(BuildContext context, DictionaryDb dict, Collection collection) {
    final List<Idiom> idioms = dict.collectionIdioms(collection.slug);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppHeader(title: collection.title, onBack: () => context.pop()),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.bottomSafe),
                itemCount: idioms.length,
                separatorBuilder: (BuildContext _, int _) => const SizedBox(height: Space.row),
                itemBuilder: (BuildContext context, int i) => IdiomCard(idiom: idioms[i], query: '', onTap: () => showIdiomSheet(context, idiom: idioms[i])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Multi-select: the header turns `primaryContainer`, shows "{n} selected"
/// and bookmark/delete actions.
class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({required this.count, required this.onClose, required this.onBookmark, this.onDelete});

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
          AppIconButton(icon: Icons.close_rounded, semanticLabel: 'Cancel selection', onPressed: onClose, tint: c.onPrimaryContainer, background: Colors.transparent),
          const SizedBox(width: 6),
          Expanded(child: Text('$count selected', style: MullType.headerTitle.copyWith(color: c.onPrimaryContainer))),
          AppIconButton(icon: Icons.bookmark_border_rounded, semanticLabel: 'Bookmark selected', onPressed: count == 0 ? null : onBookmark, tint: c.onPrimaryContainer, background: Colors.transparent),
          if (onDelete != null)
            AppIconButton(icon: Icons.delete_outline_rounded, semanticLabel: 'Remove selected', onPressed: count == 0 ? null : onDelete, tint: c.onPrimaryContainer, background: Colors.transparent),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: Space.screen),
    decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.divider))),
    child: Row(
      children: <Widget>[
        SizedBox(width: 82, child: Text('WORD', style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant))),
        const SizedBox(width: Space.sm),
        Expanded(flex: 11, child: Text('DEFINITION', style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant))),
        const SizedBox(width: Space.sm),
        Expanded(flex: 10, child: Text('EXAMPLE', style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant))),
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

/// Three columns in one 48dp-minimum row: word (82dp, `titleMedium`),
/// definition (flex 1.1, `tableCell`), example (flex 1, italic). Bookmarked:
/// a 5dp `primary` dot after the word. Definitions-hidden: a 9dp
/// `surfaceContainerHigh` bar at 64 to 94% width by definition length; a
/// revealed row shows its definition in `accent` on `surfaceContainer`.
class WordTableRow extends StatelessWidget {
  const WordTableRow({
    required this.word,
    required this.example,
    required this.bookmarked,
    required this.hideDefs,
    required this.revealed,
    required this.onTap,
    required this.onLongPress,
    this.selecting = false,
    this.selected = false,
    super.key,
  });

  final DictionaryWord word;
  final String? example;
  final bool bookmarked;
  final bool hideDefs;
  final bool revealed;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final bool hidden = hideDefs && !revealed;
    final double barFraction = 0.64 + 0.30 * (word.definitionShort.length.clamp(20, 90) - 20) / 70;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: Space.screen, vertical: 9),
        decoration: BoxDecoration(
          color: revealed || selected ? c.surfaceContainer : null,
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
                  border: Border.all(color: selected ? c.primary : c.outline, width: 1.5),
                ),
                child: selected ? Icon(Icons.check_rounded, size: 15, color: c.onPrimary) : null,
              ),
              const SizedBox(width: Space.md),
            ],
            SizedBox(
              width: 82,
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(text: word.headword),
                    if (bookmarked)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(left: 5, bottom: 4),
                          decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
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
              child: hidden
                  ? FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: barFraction,
                      child: Container(height: 9, decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: Radii.fullR)),
                    )
                  : Text(
                      word.definitionShort,
                      style: MullType.tableCell.copyWith(color: revealed ? c.accent : c.onSurface),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              flex: 10,
              child: Text(
                example ?? '',
                style: MullType.tableCell.copyWith(color: c.onSurfaceVariant, fontStyle: FontStyle.italic),
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
