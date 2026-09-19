import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/chips.dart';

/// HANDOFF section 2, the headword card. Radius 28, `surfaceContainer`, 1px
/// outline. Headword, IPA + speaker, part of speech, definition, example with
/// the headword at `accent` 600, an optional synonyms row. Seen-before is a
/// 7dp `primary` dot; bookmarked tints the container `primaryContainer`.
///
/// Nothing here may overflow, at any font size, for any word. The body
/// flexes: a long definition steps the headword down one size first; if the
/// text still does not fit, the body scrolls and the action row stays put.
class WordCard extends StatefulWidget {
  const WordCard({
    required this.word,
    required this.examples,
    required this.synonyms,
    required this.seenBefore,
    required this.bookmarked,
    required this.hasNote,
    required this.onNote,
    required this.onBookmark,
    required this.onOpenEntry,
    required this.onOverflow,
    required this.onSpeak,
    this.onShare,
    this.onNextCard,
    this.onPreviousCard,
    this.headwordOverride,
    this.softStop = false,
    super.key,
  });

  final DictionaryWord word;
  final List<String> examples;
  final List<String> synonyms;
  final bool seenBefore;
  final bool bookmarked;
  final bool hasNote;
  final VoidCallback onNote;
  final VoidCallback onBookmark;
  final VoidCallback onOpenEntry;
  final VoidCallback? onShare;
  final void Function(BuildContext anchor) onOverflow;
  final VoidCallback onSpeak;
  final VoidCallback? onNextCard;
  final VoidCallback? onPreviousCard;

  /// The American spelling when that setting is on.
  final String? headwordOverride;

  /// "You have been here a while." after thirty minutes in one sitting.
  final bool softStop;

  /// A definition this long steps the headword down one size, by count so
  /// it is stable between renders (the headword rule, HANDOFF 1.4).
  static const int kLongDefinition = 70;

  @override
  State<WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<WordCard> {
  final ScrollController _scroll = ScrollController();

  /// True once layout shows the body taller than its box. Until then the
  /// body does not scroll, so a vertical drag pages the card as usual.
  bool _overflows = false;
  double _accumulatedOverscroll = 0;
  DateTime? _lastPageTrigger;

  static const double _kOverscrollThreshold = 40.0;
  static const Duration _kPageCooldown = Duration(milliseconds: 500);

  @override
  void didUpdateWidget(WordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.wordKey != widget.word.wordKey) {
      _accumulatedOverscroll = 0;
      if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _checkOverflow() {
    if (!mounted || !_scroll.hasClients) return;
    final bool now = _scroll.position.maxScrollExtent > 0;
    if (now != _overflows) setState(() => _overflows = now);
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (!_overflows) return false;

    if (n is OverscrollNotification) {
      _accumulatedOverscroll += n.overscroll;
    } else if (n is ScrollUpdateNotification) {
      if (n.scrollDelta != null && n.scrollDelta != 0) {
        // If user scrolls back inside bounds, clear overscroll
        _accumulatedOverscroll = 0;
      }
    } else if (n is ScrollEndNotification) {
      final DateTime now = DateTime.now();
      final bool cooledDown = _lastPageTrigger == null ||
          now.difference(_lastPageTrigger!) > _kPageCooldown;

      if (cooledDown) {
        if (_accumulatedOverscroll >= _kOverscrollThreshold) {
          _accumulatedOverscroll = 0;
          _lastPageTrigger = now;
          widget.onNextCard?.call();
          return false;
        } else if (_accumulatedOverscroll <= -_kOverscrollThreshold) {
          _accumulatedOverscroll = 0;
          _lastPageTrigger = now;
          widget.onPreviousCard?.call();
          return false;
        }
      }
      _accumulatedOverscroll = 0;
    } else if (n is UserScrollNotification) {
      if (n.direction == ScrollDirection.idle) {
        _accumulatedOverscroll = 0;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final bool bookmarked = widget.bookmarked;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());

    return Container(
      decoration: BoxDecoration(
        color: bookmarked ? c.primaryContainer : c.surfaceContainer,
        borderRadius: Radii.wordCardR,
        border: Border.all(color: c.outline),
      ),
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) =>
                  NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: SingleChildScrollView(
                  controller: _scroll,
                  physics: _overflows
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: _body(context),
                  ),
                ),
              ),
            ),
          ),
          if (widget.softStop) ...<Widget>[
            const SizedBox(height: Space.sm),
            Text('You have been here a while.', style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
          ],
          const SizedBox(height: Space.md),
          _actions(c),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final MullColors c = context.colors;
    final DictionaryWord word = widget.word;
    final String headword = widget.headwordOverride ?? word.headword;
    final bool hasExample = widget.examples.isNotEmpty;
    // At a large OS text scale the synonyms row drops first, then the
    // example, then the definition steps down once. The headword never
    // shrinks for font scale; it steps down once for a long definition.
    final double scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final bool showSynonyms = widget.synonyms.isNotEmpty && scale <= 1.3;
    final bool showExample = hasExample && scale <= 1.6;
    final int step = MullType.headwordStep(headword) + (word.definitionShort.length > WordCard.kLongDefinition ? 1 : 0);
    final TextStyle definition = (hasExample ? MullType.cardDefinition : MullType.cardDefinition.copyWith(fontSize: 30, height: 1.3))
        .copyWith(fontSize: scale > 1.6 ? 22 : null, color: c.onSurface);

    return Column(
      mainAxisAlignment: hasExample ? MainAxisAlignment.start : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The step comes from the count, never from measuring; the fit is
        // only a guard for a wide word on a narrow phone, and it never
        // enlarges. Step S wraps instead.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(text: headword),
              if (widget.seenBefore)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Semantics(
                    label: 'Seen before',
                    child: Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(left: 10, bottom: 8),
                      decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                    ),
                  ),
                ),
            ],
          ),
          // Never ellipsised, never hyphenated; the step is by grapheme
          // count and only headwordS wraps.
          style: MullType.headwordAt(step).copyWith(color: c.onSurface),
          textScaler: TextScaler.noScaling,
          softWrap: false,
          overflow: TextOverflow.visible,
        ),
        ),
        const SizedBox(height: Space.sm),
        Row(
          spacing: Space.sm,
          children: <Widget>[
            if (word.ipa != null) ...<Widget>[
              Flexible(
                child: Text(
                  word.ipa!,
                  style: MullType.monoTabular.copyWith(color: c.onSurfaceVariant),
                ),
              ),
              AppIconButton(
                icon: Icons.volume_up_rounded,
                size: 30,
                glyphSize: 16,
                semanticLabel: 'Pronounce $headword',
                onPressed: widget.onSpeak,
              ),
            ],
          ],
        ),
        Text(
          word.ipa == null ? '${posLabel(word.pos)} · no pronunciation recorded' : posLabel(word.pos),
          style: MullType.label.copyWith(fontStyle: FontStyle.italic, color: c.onSurfaceMuted),
        ),
        const SizedBox(height: Space.lg),
        Text(word.definitionShort, style: definition),
        if (showExample) ...<Widget>[
          const SizedBox(height: Space.md),
          _Example(text: widget.examples.first, headword: word.headwordNorm, headwordShown: headword),
        ],
        if (showSynonyms) ...<Widget>[
          const SizedBox(height: Space.lg),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text('also:', style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
              for (final String s in widget.synonyms.take(4)) PillChip(label: s),
            ],
          ),
        ],
      ],
    );
  }

  /// Pinned under the body; it never moves. Tap targets are 52dp circles,
  /// 12dp apart.
  Widget _actions(MullColors c) {
    final bool bookmarked = widget.bookmarked;
    final bool hasNote = widget.hasNote;
    return Row(
      spacing: Space.md,
      children: <Widget>[
        AppIconButton(
          icon: Icons.menu_book_rounded,
          size: 52,
          semanticLabel: 'Open full entry',
          onPressed: widget.onOpenEntry,
          background: bookmarked ? c.surfaceContainer : null,
        ),
        AppIconButton(
          icon: bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          size: 52,
          active: bookmarked,
          semanticLabel: bookmarked ? 'Remove bookmark' : 'Bookmark',
          onPressed: widget.onBookmark,
          background: bookmarked ? c.surface : null,
        ),
        AppIconButton(
          icon: hasNote ? Icons.sticky_note_2_rounded : Icons.sticky_note_2_outlined,
          size: 52,
          active: hasNote,
          semanticLabel: hasNote ? 'Edit note' : 'Add note',
          onPressed: widget.onNote,
          background: bookmarked && !hasNote ? c.surfaceContainer : null,
        ),
        const Spacer(),
        Builder(
          builder: (BuildContext anchor) => AppIconButton(
            icon: Icons.more_horiz_rounded,
            size: 52,
            semanticLabel: 'More',
            onPressed: () => widget.onOverflow(anchor),
            background: bookmarked ? c.surfaceContainer : null,
          ),
        ),
      ],
    );
  }
}

/// The example, italic in `onSurfaceVariant`, the headword inside it at
/// `accent` weight 600 (any inflection of it counts).
class _Example extends StatelessWidget {
  const _Example({required this.text, required this.headword, required this.headwordShown});

  final String text;
  final String headword;
  final String headwordShown;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final TextStyle base = MullType.body.copyWith(fontStyle: FontStyle.italic, color: c.onSurfaceVariant);
    final String stem = headword.length > 4 ? headword.substring(0, headword.length - 1) : headword;
    final RegExp re = RegExp('\\b(${RegExp.escape(headwordShown)}|${RegExp.escape(stem)})[a-z]*', caseSensitive: false);
    final List<InlineSpan> spans = <InlineSpan>[];
    int last = 0;
    for (final RegExpMatch m in re.allMatches(text)) {
      spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(TextSpan(text: m.group(0), style: base.weight(600).copyWith(color: c.accent)));
      last = m.end;
    }
    spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(children: spans), style: base);
  }
}
