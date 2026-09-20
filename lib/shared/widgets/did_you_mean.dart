import 'package:flutter/material.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import 'chips.dart';

/// The one "Did you mean" block: a section header and the nearest headwords
/// as chips, closest first. Fed by `DictionaryDb.suggestions`, shown wherever
/// a lookup came back empty (the Search tab, an arrival from another app).
/// Nothing when there is nothing near.
class DidYouMean extends StatelessWidget {
  const DidYouMean({
    required this.words,
    required this.onPick,
    this.label = 'DID YOU MEAN',
    super.key,
  });

  final List<DictionaryWord> words;
  final ValueChanged<DictionaryWord> onPick;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) return const SizedBox.shrink();
    final MullColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: <Widget>[
            for (final DictionaryWord w in words)
              PillChip(
                label: '${w.headword} · ${posLabel(w.pos)}',
                onTap: () => onPick(w),
              ),
          ],
        ),
      ],
    );
  }
}
