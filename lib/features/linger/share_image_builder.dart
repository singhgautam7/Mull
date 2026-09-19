import 'package:flutter/material.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';

/// HANDOFF 21.4: 1:1 1080×1080 PNG share card.
///
/// Designed on a 360×360 canvas with 34dp padding and 14dp radius, rendered
/// with a 3.0 pixel ratio to produce an exact 1080×1080 image. Pass the
/// family's dark palette rather than its AMOLED one (see [shareColors]) so
/// the crop reads as a card, not a hole, away from the app.
class ShareImageCard extends StatelessWidget {
  const ShareImageCard({
    required this.word,
    required this.colors,
    this.example,
    super.key,
  });

  static const double side = 360;
  static const double pixelRatio = 3;

  final DictionaryWord word;
  final String? example;
  final MullColors colors;

  /// The palette the image is drawn in: the current one, except that AMOLED
  /// steps back to the family's plain dark surface.
  static MullColors shareColors(MullColors current, ThemeFamily family) =>
      current.tone == Tone.amoled ? family.colors(Tone.dark) : current;

  @override
  Widget build(BuildContext context) {
    final Color bg = colors.surface;

    final String ipaPos = word.ipa != null && word.ipa!.isNotEmpty
        ? '${word.ipa} · ${posLabel(word.pos)}'
        : posLabel(word.pos);

    return Container(
      width: side,
      height: side,
      padding: const EdgeInsets.all(34),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // HANDOFF 21.4 asks for 46; the headword rule steps long words down
          // by grapheme count so the longest entry still fits without a cut.
          Text(
            word.headword,
            style: MullType.headword(word.headword).copyWith(
              fontSize: 46.0 - 8 * MullType.headwordStep(word.headword),
              color: colors.onSurface,
              height: 1.1,
            ),
            maxLines: 2,
            softWrap: true,
          ),
          const SizedBox(height: Space.xs),
          Text(
            ipaPos,
            style: MullType.monoTabular.copyWith(
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Flexible(
                  flex: 3,
                  child: Text(
                    word.definitionShort.isNotEmpty
                        ? word.definitionShort
                        : word.definitionFull,
                    style: MullType.body.copyWith(
                      fontSize: 20,
                      height: 1.4,
                      color: colors.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (example != null && example!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Space.sm),
                  Flexible(
                    flex: 2,
                    child: Text(
                      example!,
                      style: MullType.body.copyWith(
                        fontSize: 14,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                        color: colors.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: <Widget>[
              Text(
                'MULL',
                style: MullType.monoLabel.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                'offline dictionary',
                style: MullType.monoLabel.copyWith(
                  fontSize: 12,
                  color: colors.onSurfaceMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
