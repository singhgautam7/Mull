import 'package:flutter/material.dart';

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
class WordCard extends StatelessWidget {
  const WordCard({
    required this.word,
    required this.examples,
    required this.synonyms,
    required this.seenBefore,
    required this.bookmarked,
    required this.hasNote,
    required this.onNote,
    required this.onBookmark,
    required this.onShare,
    required this.onOverflow,
    required this.onSpeak,
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
  final VoidCallback onShare;
  final void Function(BuildContext anchor) onOverflow;
  final VoidCallback onSpeak;

  /// The American spelling when that setting is on.
  final String? headwordOverride;

  /// "You have been here a while." after thirty minutes in one sitting.
  final bool softStop;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final String headword = headwordOverride ?? word.headword;
    final bool hasExample = examples.isNotEmpty;
    // At a large OS text scale the synonyms row drops first, then the
    // example, then the definition steps down once. The headword never does.
    final double scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final bool showSynonyms = synonyms.isNotEmpty && scale <= 1.3;
    final bool showExample = hasExample && scale <= 1.6;
    final TextStyle definition = (hasExample ? MullType.cardDefinition : MullType.cardDefinition.copyWith(fontSize: 30, height: 1.3))
        .copyWith(fontSize: scale > 1.6 ? 22 : null, color: c.onSurface);

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
            child: Column(
              mainAxisAlignment: hasExample ? MainAxisAlignment.start : MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(text: headword),
                      if (seenBefore)
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
                  // Never ellipsised, never hyphenated; the step is by
                  // grapheme count and only headwordS wraps.
                  style: MullType.headword(headword).copyWith(color: c.onSurface),
                  textScaler: TextScaler.noScaling,
                  softWrap: headword.characters.length >= 20,
                  overflow: TextOverflow.visible,
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
                        onPressed: onSpeak,
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
                  _Example(text: examples.first, headword: word.headwordNorm, headwordShown: headword),
                ],
                if (showSynonyms) ...<Widget>[
                  const SizedBox(height: Space.lg),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text('also:', style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
                      for (final String s in synonyms.take(4)) PillChip(label: s),
                    ],
                  ),
                ],
                if (softStop) ...<Widget>[
                  const Spacer(),
                  Text('You have been here a while.', style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          // Tap targets in the action row are 52dp circles, 12dp apart.
          Row(
            spacing: Space.md,
            children: <Widget>[
              AppIconButton(
                icon: hasNote ? Icons.sticky_note_2_rounded : Icons.sticky_note_2_outlined,
                size: 52,
                active: hasNote,
                semanticLabel: hasNote ? 'Edit note' : 'Add a note',
                onPressed: onNote,
                background: bookmarked && !hasNote ? c.surfaceContainer : null,
              ),
              AppIconButton(
                icon: bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                size: 52,
                active: bookmarked,
                semanticLabel: bookmarked ? 'Remove bookmark' : 'Bookmark',
                onPressed: onBookmark,
                background: bookmarked ? c.surface : null,
              ),
              AppIconButton(
                icon: Icons.ios_share_rounded,
                size: 52,
                semanticLabel: 'Share',
                onPressed: onShare,
                background: bookmarked ? c.surfaceContainer : null,
              ),
              const Spacer(),
              Builder(
                builder: (BuildContext anchor) => AppIconButton(
                  icon: Icons.more_horiz_rounded,
                  size: 52,
                  semanticLabel: 'More',
                  onPressed: () => onOverflow(anchor),
                  background: bookmarked ? c.surfaceContainer : null,
                ),
              ),
            ],
          ),
        ],
      ),
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
