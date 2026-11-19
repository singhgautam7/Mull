import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/definable_text.dart';

/// HANDOFF 3.6. IDIOM label, the phrase at 36, register chip, then WHAT IT
/// MEANS and IN CONTEXT. No IPA, no sense numbering, no POS: the field set is
/// visibly different from a word.
Future<void> showIdiomSheet(BuildContext context, {required Idiom idiom}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (BuildContext ctx) => _IdiomSheet(idiom: idiom),
  );
}

/// The idioms that share the phrase's longest word, found off the main
/// isolate (an FTS query). Keyed by (idiom key, phrase); autoDispose, so a
/// sheet closed leaves nothing behind.
final FutureProvider<List<Idiom>> Function((String, String)) _relatedIdiomsProvider =
    FutureProvider.autoDispose.family<List<Idiom>, (String, String)>(
      (Ref ref, (String, String) key) => relatedIdioms(ref.watch(dictProvider), key.$1, key.$2),
    );

/// A plain function so the closure sent to the worker carries two strings
/// and nothing else.
@visibleForTesting
Future<List<Idiom>> relatedIdioms(DictionaryDb dict, String idiomKey, String phrase) {
  final String longest = phrase.split(' ').reduce((String a, String b) => a.length >= b.length ? a : b);
  return dict.compute(
    (DictionaryDb db) =>
        db.searchIdioms(longest).where((Idiom i) => i.idiomKey != idiomKey).take(3).toList(),
  );
}

class _IdiomSheet extends ConsumerWidget {
  const _IdiomSheet({required this.idiom});

  final Idiom idiom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    final List<Idiom> related =
        ref.watch(_relatedIdiomsProvider((idiom.idiomKey, idiom.phrase))).value ?? const <Idiom>[];
    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm),
      child: Text(t, style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('IDIOM', style: MullType.sectionHeader.copyWith(color: c.accent)),
        const SizedBox(height: Space.sm),
        Text(idiom.phrase, style: MullType.headwordS.copyWith(fontSize: 36, color: c.onSurface)),
        const SizedBox(height: Space.md),
        BandChip(idiom.register),
        label('WHAT IT MEANS'),
        DefinableText(idiom.meaning, style: MullType.body.copyWith(color: c.onSurface)),
        if (idiom.example != null) ...<Widget>[
          label('IN CONTEXT'),
          Container(
            padding: const EdgeInsets.only(left: Space.md),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: c.primary, width: 2))),
            child: Text(
              idiom.example!,
              style: MullType.body.copyWith(color: c.onSurfaceVariant, fontStyle: FontStyle.italic),
            ),
          ),
        ],
        if (related.isNotEmpty) ...<Widget>[
          label('SEE ALSO'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: <Widget>[
              for (final Idiom r in related)
                PillChip(
                  label: r.phrase,
                  onTap: () {
                    Navigator.of(context).pop();
                    showIdiomSheet(context, idiom: r);
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: Space.lg),
      ],
    );
  }
}
