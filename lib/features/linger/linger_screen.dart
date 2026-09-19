import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/mix_repository.dart';
import '../../core/database/user_db.dart';
import '../../core/database/user_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/pronunciation.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_menu.dart';
import '../../shared/widgets/linger_background.dart';
import '../dictionary/add_to_list_sheet.dart';
import '../dictionary/note_sheet.dart';
import '../dictionary/word_sheet.dart';
import '../settings/settings_controller.dart';
import 'linger_rules.dart';
import 'mix_sheet.dart';
import 'queue_builder.dart';
import 'word_card.dart';

/// The Mull tab. Plays the active mix on arrival, no picker on entry, ever.
/// One card per word, vertical paging, finite, a real end card. Scoped play
/// from a collection card plays that collection only and never writes to
/// the saved mix.
class LingerScreen extends ConsumerStatefulWidget {
  const LingerScreen({this.scope, this.mixId, super.key});

  /// A collection slug, built-in or the user's own: scoped play.
  final String? scope;

  /// A saved mix to make active and play.
  final int? mixId;

  @override
  ConsumerState<LingerScreen> createState() => _LingerScreenState();
}

class _CardData {
  const _CardData(this.word, this.examples, this.synonyms);

  final DictionaryWord word;
  final List<String> examples;
  final List<String> synonyms;
}

class _LingerScreenState extends ConsumerState<LingerScreen> with WidgetsBindingObserver {
  final PageController _pager = PageController();
  MixSpec? _mix;
  String? _scope;
  List<String> _queue = <String>[];
  final Set<String> _served = <String>{};
  final Map<String, _CardData> _cards = <String, _CardData>{};
  Set<String> _seenBefore = <String>{};
  Set<String> _noted = <String>{};
  bool _exhausted = false;
  bool _loading = true;
  int _index = 0;
  DateTime _enteredAt = DateTime.now();
  final DateTime _sessionStart = DateTime.now();
  bool _softStopShown = false;
  bool _chipFaded = false;
  bool _extending = false;

  static const Duration _kSoftStop = Duration(minutes: 30);

  // Read once: dispose() writes seen state and clears the scope, and ref is
  // not safe to use once the widget is unmounting.
  late final UserRepository _user;
  late final MixRepository _mixes;
  late final DictionaryDb _dict;

  @override
  void initState() {
    super.initState();
    _user = ref.read(userRepositoryProvider);
    _mixes = ref.read(mixRepositoryProvider);
    _dict = ref.read(dictProvider);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(LingerScreen old) {
    super.didUpdateWidget(old);
    if (old.scope != widget.scope || old.mixId != widget.mixId) unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app counts as leaving the card.
    if (state == AppLifecycleState.paused) unawaited(_exitCard(_index));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_exitCard(_index));
    if (_scope != null) unawaited(_mixes.clearScoped());
    _pager.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _exhausted = false;
      _queue = <String>[];
      _served.clear();
      _index = 0;
      _chipFaded = false;
    });
    MixSpec? active = await _mixes.active();
    if (widget.mixId != null && widget.mixId != active?.id) {
      final MixSpec? m = await _mixes.byId(widget.mixId!);
      if (m != null) {
        await _mixes.setActive(m.id!);
        active = m;
      }
    }
    _scope = widget.scope;
    if (_scope != null) {
      await _mixes.setScoped(_scope!);
      await _user.setAppState(UserRepository.kLastOpened, _scope);
      _mix = MixSpec.scoped(_scope!, active?.seenPolicy ?? SeenPolicy.light);
    } else {
      await _mixes.clearScoped();
      _mix = active;
    }
    _noted = (await _user.allNotes()).keys.toSet();
    await _extend();
    if (mounted) {
      setState(() {
        _loading = false;
        _enteredAt = DateTime.now();
      });
      if (_pager.hasClients) _pager.jumpToPage(0);
    }
  }

  /// Plays an unsaved selection from the mix sheet.
  Future<void> _playCustom(List<String> sources, SeenPolicy policy) async {
    _scope = null;
    await _mixes.clearScoped();
    _mix = MixSpec(id: null, name: 'Custom mix', isPreset: false, sources: sources, seenPolicy: policy);
    setState(() {
      _queue = <String>[];
      _served.clear();
      _index = 0;
      _exhausted = false;
    });
    await _extend();
    if (mounted) setState(() => _enteredAt = DateTime.now());
    if (_pager.hasClients) _pager.jumpToPage(0);
  }

  /// Appends the next batch. The queue is never loaded whole.
  Future<void> _extend() async {
    if (_extending || _mix == null) return;
    _extending = true;
    final QueueBuilder builder = ref.read(queueBuilderProvider);
    final List<String> batch = await builder.build(_mix!, exclude: _served);
    final Map<String, SeenWord> seen = await _user.seenStates(batch);
    for (final String key in batch) {
      final DictionaryWord? w = _dict.byKey(key);
      if (w == null) continue;
      _cards[key] = _CardData(w, _dict.examples(key), _dict.synonyms(key));
    }
    if (!mounted) {
      _extending = false;
      return;
    }
    setState(() {
      _seenBefore = <String>{..._seenBefore, ...seen.keys};
      _served.addAll(batch);
      _queue = <String>[..._queue, ...batch.where(_cards.containsKey)];
      if (batch.isEmpty && _queue.isEmpty) _exhausted = true;
    });
    _extending = false;
  }

  /// Seen is written on card exit, after the dwell threshold, never on entry.
  Future<void> _exitCard(int i) async {
    if (i < 0 || i >= _queue.length) return;
    final Duration dwell = DateTime.now().difference(_enteredAt);
    if (dwell < kSeenDwellThreshold) return;
    await _user.markSeen(_queue[i]);
  }

  void _onPage(int i) {
    unawaited(_exitCard(_index));
    if (ref.read(settingsProvider).haptics) unawaited(HapticFeedback.selectionClick());
    setState(() {
      _index = i;
      _enteredAt = DateTime.now();
      if (!_chipFaded) _chipFaded = true;
      if (!_softStopShown && DateTime.now().difference(_sessionStart) >= _kSoftStop) _softStopShown = true;
    });
    if (i >= _queue.length - 5 && !_exhausted) unawaited(_extend());
  }

  Future<void> _openMixSheet() async {
    final MixSpec? current = _scope != null ? await _mixes.active() : _mix;
    if (current == null || !mounted) return;
    final MixChoice? choice = await showMixSheet(context, active: current);
    if (choice == null || !mounted) return;
    if (choice.mixId != null) {
      if (_scope != null || choice.mixId != _mix?.id) {
        context.go(Routes.playMix(choice.mixId!));
      } else {
        // "Mull these" on the same mix rebuilds the queue.
        await _load();
      }
    } else {
      await _playCustom(choice.sources!, choice.policy!);
    }
  }

  void _goToNextCard() {
    if (_index < _queue.length && _pager.hasClients) {
      _pager.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goToPreviousCard() {
    if (_index > 0 && _pager.hasClients) {
      _pager.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _overflow(BuildContext anchor, DictionaryWord word) async {
    final String? action = await showAppMenu<String>(
      context: context,
      anchorContext: anchor,
      entries: const <AppMenuEntry<String>>[
        AppMenuEntry<String>(value: 'share', label: 'Share', icon: Icons.ios_share_rounded),
        AppMenuEntry<String>(value: 'collection', label: 'Add to shelf', icon: Icons.playlist_add_rounded),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'share':
        unawaited(SharePlus.instance.share(
          ShareParams(text: '${word.headword}: ${word.definitionFull}'),
        ));
      case 'collection':
        await showAddToListSheet(context, wordKey: word.wordKey, headword: word.headword);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final AppSettings s = ref.watch(settingsProvider);
    final Set<String> bookmarks = ref.watch(bookmarksProvider).value ?? const <String>{};
    final String? scopeTitle = _scope == null ? null : ref.watch(collectionBySlugProvider)[_scope!]?.title;
    final EdgeInsets pad = MediaQuery.paddingOf(context);

    return LingerBackground(
      active: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              top: pad.top + 96 - 34,
              child: _loading
                  ? const SizedBox.shrink()
                  : _exhausted
                      ? _endCard(scopeTitle)
                      : PageView.builder(
                          controller: _pager,
                          scrollDirection: Axis.vertical,
                          physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
                          onPageChanged: _onPage,
                          itemCount: _queue.length + 1,
                          itemBuilder: (BuildContext context, int i) {
                            if (i == _queue.length) return _endCard(scopeTitle);
                            final _CardData data = _cards[_queue[i]]!;
                            return AnimatedBuilder(
                              animation: _pager,
                              builder: (BuildContext context, Widget? child) {
                                final double page = _pager.hasClients && _pager.position.haveDimensions ? _pager.page ?? _index.toDouble() : _index.toDouble();
                                final double t = (page - i).abs().clamp(0.0, 1.0);
                                // Outgoing drops to 96%; incoming arrives at 96% and springs to full.
                                return Transform.scale(scale: 1 - 0.04 * t, child: child);
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 34, 14, 104),
                                child: WordCard(
                                  word: data.word,
                                  examples: data.examples,
                                  synonyms: s.showSynonyms ? data.synonyms : const <String>[],
                                  seenBefore: _seenBefore.contains(data.word.wordKey),
                                  bookmarked: bookmarks.contains(data.word.wordKey),
                                  hasNote: _noted.contains(data.word.wordKey),
                                  headwordOverride: s.spelling == Spelling.american ? _dict.usSpelling(data.word.wordKey) : null,
                                  softStop: _softStopShown && i == _index,
                                  onSpeak: () => unawaited(ref.read(pronunciationProvider).speak(data.word.headword, rate: s.ttsRate)),
                                  onOpenEntry: () => showWordSheet(context, wordKey: data.word.wordKey),
                                  onNextCard: _goToNextCard,
                                  onPreviousCard: _goToPreviousCard,
                                  onNote: () async {
                                    await showNoteSheet(context, wordKey: data.word.wordKey, headword: data.word.headword);
                                    final String? n = await _user.note(data.word.wordKey);
                                    if (mounted) setState(() => n == null ? _noted.remove(data.word.wordKey) : _noted.add(data.word.wordKey));
                                  },
                                  onBookmark: () async {
                                    // `bookmark.confirm`: icon fills, one haptic tick.
                                    if (s.haptics) unawaited(HapticFeedback.lightImpact());
                                    await _user.toggleBookmark(data.word.wordKey);
                                  },
                                  onOverflow: (BuildContext anchor) => unawaited(_overflow(anchor, data.word)),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            // The mix chip, or the tinted, closable scope chip. They must
            // never look alike.
            Positioned(
              left: Space.screen,
              top: pad.top + 22,
              child: _scope != null
                  ? _ScopeChip(
                      title: scopeTitle ?? _scope!,
                      onClose: () => context.go(Routes.mull),
                    )
                  : AnimatedOpacity(
                      duration: Motion.of(context, Motion.fast),
                      opacity: _chipFaded ? 0.34 : 1,
                      child: _MixChip(
                        name: _mix?.name ?? '',
                        onTap: () {
                          setState(() => _chipFaded = false);
                          unawaited(_openMixSheet());
                        },
                      ),
                    ),
            ),
            if (_loading)
              Center(child: Text('', style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted))),
          ],
        ),
      ),
    );
  }

  Widget _endCard(String? scopeTitle) {
    final MullColors c = context.colors;
    final Set<String> bookmarks = ref.watch(bookmarksProvider).value ?? const <String>{};
    final int total = _mix == null ? 0 : (ref.watch(collectionKeysProvider)[_scope]?.length ?? _served.length);
    final int bookmarked = _served.where(bookmarks.contains).length;
    final MixSpec? review = (ref.watch(mixesProvider).value ?? const <MixSpec>[])
        .where((MixSpec m) => m.isPreset && m.name == MixRepository.presetReview)
        .firstOrNull;
    final List<Collection> all = ref.watch(collectionsProvider);
    final int at = all.indexWhere((Collection x) => x.slug == _scope);
    final Collection? next = at >= 0 && at + 1 < all.length && all[at + 1].isMixable ? all[at + 1] : null;

    final bool scoped = _scope != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 34, 14, 104),
      child: Container(
        padding: const EdgeInsets.all(Space.xl),
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: Radii.wordCardR,
          border: Border.all(color: c.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              scoped ? 'That is all of ${scopeTitle ?? _scope}.' : 'You have seen every word in ${_mix?.name ?? 'this mix'}.',
              style: MullType.display.copyWith(fontSize: 34, color: c.onSurface),
            ),
            const SizedBox(height: Space.lg),
            Text(
              scoped
                  ? '${grouped(total)} words, $bookmarked bookmarked along the way. Nothing loops back round.'
                  : '${grouped(_served.length)} words, $bookmarked bookmarked. Fold familiar words back in, or narrow the mix and go again.',
              style: MullType.body.copyWith(color: c.onSurfaceVariant),
            ),
            const SizedBox(height: Space.xl),
            if (scoped) ...<Widget>[
              if (review != null && bookmarked > 0)
                AppButton(label: 'Review the $bookmarked bookmarked', fullWidth: true, onPressed: () => context.go(Routes.playMix(review.id!))),
              if (next != null) ...<Widget>[
                const SizedBox(height: Space.sm),
                AppButton(label: 'Start ${next.title}', type: AppButtonType.outlined, fullWidth: true, onPressed: () => context.go(Routes.scoped(next.slug))),
              ],
              const SizedBox(height: Space.sm),
              AppButton(label: 'Back to Home', type: AppButtonType.outlined, fullWidth: true, onPressed: () => context.go(Routes.home)),
            ] else ...<Widget>[
              AppButton(
                label: 'Mull familiar words again',
                fullWidth: true,
                onPressed: () => _playCustom(_mix!.sources, SeenPolicy.reviewOnly),
              ),
              const SizedBox(height: Space.sm),
              AppButton(label: 'Change the mix', type: AppButtonType.outlined, fullWidth: true, onPressed: _openMixSheet),
              if (review != null && bookmarks.isNotEmpty) ...<Widget>[
                const SizedBox(height: Space.sm),
                AppButton(label: 'Review the ${bookmarks.length} bookmarked', type: AppButtonType.outlined, fullWidth: true, onPressed: () => context.go(Routes.playMix(review.id!))),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// 32dp, `surfaceContainerHigh` at 78%, 1px outline, a shuffle glyph, the
/// mix name, a chevron. Neutral, never a play button.
class _MixChip extends StatelessWidget {
  const _MixChip({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Semantics(
      button: true,
      label: 'Mix: $name',
      child: Material(
        color: c.surfaceContainerHigh.withValues(alpha: 0.78),
        shape: StadiumBorder(side: BorderSide(color: c.outline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: <Widget>[
                  Icon(Icons.shuffle_rounded, size: 15, color: c.iconMuted),
                  Text(name, style: MullType.titleSmall.copyWith(color: c.onSurface)),
                  Icon(Icons.expand_more_rounded, size: 18, color: c.iconMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tinted and closable: `primaryContainer` fill, "{collection} only", a 22dp
/// close button whose label is "Back to {mix}".
class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Material(
      color: c.primaryContainer,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 32,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: <Widget>[
              Text('$title only', style: MullType.titleSmall.copyWith(color: c.onPrimaryContainer)),
              Semantics(
                button: true,
                label: 'Back to the mix',
                child: InkWell(
                  onTap: onClose,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Icon(Icons.close_rounded, size: 15, color: c.onPrimaryContainer),
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
