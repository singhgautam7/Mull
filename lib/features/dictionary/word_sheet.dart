import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/user_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/pronunciation.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/chips.dart';
import '../settings/settings_controller.dart';
import 'add_to_list_sheet.dart';
import 'note_sheet.dart';

/// HANDOFF 3.5, the word detail sheet. Opened from a search row, a table
/// row, or the Mull tab's overflow. One sense and eight senses use the same
/// layout.
Future<void> showWordSheet(
  BuildContext context, {
  required String wordKey,
  bool fromSearch = false,
}) {
  return showAppBottomSheet<void>(
    context: context,
    expand: true,
    showClose: false,
    scrollable: false,
    builder: (BuildContext ctx) =>
        _WordSheet(wordKey: wordKey, fromSearch: fromSearch),
  );
}

class _WordSheet extends ConsumerWidget {
  const _WordSheet({required this.wordKey, required this.fromSearch});

  final String wordKey;
  final bool fromSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    final DictionaryDb dict = ref.watch(dictProvider);
    final DictionaryWord? word = dict.byKey(wordKey);
    if (word == null) {
      return Text(
        'No entry for $wordKey',
        style: MullType.body.copyWith(color: c.onSurfaceVariant),
      );
    }
    final List<DictionaryWord> senses = dict.senses(word.headwordNorm);
    final String? us = dict.usSpelling(senses.first.wordKey);
    final List<String> inflections = dict.inflections(senses.first.wordKey);
    final AppSettings s = ref.watch(settingsProvider);
    final String headword = s.spelling == Spelling.american && us != null
        ? us
        : word.headword;
    final bool bookmarked =
        ref.watch(bookmarksProvider).value?.contains(wordKey) ?? false;
    final UserRepository user = ref.read(userRepositoryProvider);
    final String? note = ref.watch(_noteProvider(wordKey)).value;

    // Senses grouped by part of speech, in dictionary order.
    final Map<String, List<DictionaryWord>> byPos =
        <String, List<DictionaryWord>>{};
    for (final DictionaryWord w in senses) {
      byPos.putIfAbsent(w.pos, () => <DictionaryWord>[]).add(w);
    }
    final Set<String> synonyms = <String>{
      for (final DictionaryWord w in senses) ...dict.synonyms(w.wordKey),
    };
    final List<String> plural = inflections
        .where(
          (String f) =>
              f.endsWith('s') && f.length == word.headwordNorm.length + 1 ||
              f.endsWith('es'),
        )
        .toList();

    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (note != null) ...<Widget>[
                  _NoteCard(
                    note: note,
                    onTap: () => showNoteSheet(
                      context,
                      wordKey: wordKey,
                      headword: word.headword,
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: Space.md,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        headword,
                        style: MullType.headwordL.copyWith(
                          fontSize: 46,
                          color: c.onSurface,
                        ),
                        softWrap: true,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: BandChip(bandLabel(word.band)),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (word.ipa != null) ...<Widget>[
                      Text(
                        word.ipa!,
                        style: MullType.monoTabular.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                      AppIconButton(
                        icon: Icons.volume_up_rounded,
                        size: 30,
                        glyphSize: 16,
                        semanticLabel: 'Pronounce ${word.headword}',
                        onPressed: () => unawaited(
                          ref
                              .read(pronunciationProvider)
                              .speak(word.headword, rate: s.ttsRate),
                        ),
                      ),
                    ] else
                      Text(
                        'no pronunciation recorded',
                        style: MullType.monoLabel.copyWith(
                          color: c.onSurfaceMuted,
                        ),
                      ),
                    if (plural.isNotEmpty)
                      Text(
                        'plural ${plural.first}',
                        style: MullType.monoLabel.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Space.xl),
                for (final MapEntry<String, List<DictionaryWord>> group
                    in byPos.entries) ...<Widget>[
                  Text(
                    posLabel(group.key).toUpperCase(),
                    style: MullType.sectionHeader.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  for (final DictionaryWord sense in group.value) ...<Widget>[
                    _Sense(
                      sense: sense,
                      examples: dict.examples(sense.wordKey),
                    ),
                    const SizedBox(height: Space.lg),
                  ],
                  const SizedBox(height: Space.sm),
                ],
                if (synonyms.isNotEmpty) ...<Widget>[
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: <Widget>[
                      for (final String sy in synonyms.take(8))
                        PillChip(label: sy),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                ],
                Text(
                  us == null
                      ? 'British spelling shown · US form identical'
                      : (s.spelling == Spelling.american
                            ? 'British spelling: ${word.headword}'
                            : 'American spelling: $us'),
                  style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                ),
                const SizedBox(height: Space.lg),
              ],
            ),
          ),
        ),
        // Actions pinned at the bottom, outside the scroll.
        const SizedBox(height: Space.md),
        _actions(context, ref, dict, word, bookmarked, user),
      ],
    );
  }

  Widget _actions(
    BuildContext context,
    WidgetRef ref,
    DictionaryDb dict,
    DictionaryWord word,
    bool bookmarked,
    UserRepository user,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          spacing: Space.md,
          children: <Widget>[
            Expanded(
              child: AppButton(
                label: 'See in Mull',
                fullWidth: true,
                onPressed: () {
                  final List<String> slugs = dict.collectionsOf(word.wordKey);
                  Navigator.of(context).pop();
                  context.go(
                    slugs.isEmpty ? Routes.mull : Routes.scoped(slugs.first),
                  );
                },
              ),
            ),
            AppIconButton(
              icon: bookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              active: bookmarked,
              size: 48,
              semanticLabel: bookmarked ? 'Remove bookmark' : 'Bookmark',
              onPressed: () => unawaited(user.toggleBookmark(wordKey)),
            ),
            AppIconButton(
              icon: Icons.playlist_add_rounded,
              size: 48,
              semanticLabel: 'Add to a shelf',
              onPressed: () => showAddToListSheet(
                context,
                wordKey: wordKey,
                headword: word.headword,
                fromSearch: fromSearch,
              ),
            ),
            AppIconButton(
              icon: Icons.ios_share_rounded,
              size: 48,
              semanticLabel: 'Share',
              onPressed: () => unawaited(
                SharePlus.instance.share(
                  ShareParams(text: '${word.headword}: ${word.definitionFull}'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

final StreamProvider<String?> Function(String) _noteProvider =
    StreamProvider.family<String?, String>(
      (Ref ref, String key) => ref.watch(userRepositoryProvider).watchNote(key),
    );

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap});

  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Semantics(
      button: true,
      label: 'Your note',
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.cardR,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: c.surfaceContainerHigh,
            borderRadius: Radii.cardR,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'YOUR NOTE',
                style: MullType.sectionHeader.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Space.sm),
              Text(note, style: MullType.note.copyWith(color: c.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sense extends StatelessWidget {
  const _Sense({required this.sense, required this.examples});

  final DictionaryWord sense;
  final List<String> examples;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.md,
      children: <Widget>[
        SizedBox(
          width: 18,
          child: Text(
            '${sense.senseIndex}',
            style: MullType.monoTabular.copyWith(color: c.accent),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                sense.definitionFull,
                style: MullType.body.copyWith(color: c.onSurface),
              ),
              for (final String ex in examples) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  ex,
                  style: MullType.note.copyWith(
                    color: c.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
