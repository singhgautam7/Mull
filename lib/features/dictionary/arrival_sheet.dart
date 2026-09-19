import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/user_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/platform_surfaces.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/chips.dart';
import 'word_sheet.dart';

/// Formats an Android package name into a human-readable app name.
String formatAppName(String? packageName) {
  if (packageName == null || packageName.isEmpty) return 'app';
  final List<String> parts = packageName.split('.');
  final String last = parts.last;
  if (last.isEmpty) return 'app';
  return last[0].toUpperCase() + last.substring(1);
}

/// HANDOFF 21.2: the top row of every sheet opened from outside Mull: a
/// labelled `Back to {app}` chip (never a bare chevron) and `IN MULL`.
class ArrivalTopRow extends StatelessWidget {
  const ArrivalTopRow({required this.sourceHint, super.key});

  final String? sourceHint;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        InkWell(
          onTap: () {
            Navigator.of(context).pop();
            unawaited(SystemNavigator.pop());
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            decoration: BoxDecoration(
              color: c.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.chevron_left_rounded, size: 20, color: c.onSurface),
                const SizedBox(width: Space.xs),
                Text(
                  'Back to ${formatAppName(sourceHint)}',
                  style: MullType.label.copyWith(color: c.onSurface),
                ),
              ],
            ),
          ),
        ),
        Text(
          'IN MULL',
          style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
        ),
      ],
    );
  }
}

/// HANDOFF 21.2: Arrival sheet for an unknown word.
Future<void> showUnknownWordSheet(
  BuildContext context, {
  required String text,
  DictionaryWord? nearMatch,
  String? sourceHint,
}) {
  return showAppBottomSheet<void>(
    context: context,
    expand: false,
    showClose: false,
    builder: (BuildContext ctx) => _UnknownWordArrivalSheet(
      text: text,
      nearMatch: nearMatch,
      sourceHint: sourceHint,
    ),
  );
}

class _UnknownWordArrivalSheet extends ConsumerWidget {
  const _UnknownWordArrivalSheet({
    required this.text,
    this.nearMatch,
    this.sourceHint,
  });

  final String text;
  final DictionaryWord? nearMatch;
  final String? sourceHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ArrivalTopRow(sourceHint: sourceHint),
        const SizedBox(height: Space.xl),
        Text(
          text,
          style: MullType.display.copyWith(
            fontSize: 30,
            color: c.onSurface,
          ),
        ),
        const SizedBox(height: Space.sm),
        Text(
          'Not in Mull. The dictionary holds about 136,000 headwords, and this is not one of them.',
          style: MullType.body.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: Space.xl),
        if (nearMatch != null) ...<Widget>[
          Text(
            'CLOSEST ENTRY',
            style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: Space.sm),
          InkWell(
            onTap: () {
              Navigator.of(context).pop();
              showWordSheet(
                context,
                wordKey: nearMatch!.wordKey,
                fromOutside: true,
                sourceHint: sourceHint,
              );
            },
            borderRadius: Radii.cardR,
            child: Container(
              padding: const EdgeInsets.all(Space.lg),
              decoration: BoxDecoration(
                color: c.surfaceContainerHigh,
                borderRadius: Radii.cardR,
                border: Border.all(color: c.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        nearMatch!.headword,
                        style: MullType.headwordM.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: c.onSurface,
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      BandChip(bandLabel(nearMatch!.band)),
                      const Spacer(),
                      Text(
                        posLabel(nearMatch!.pos),
                        style: MullType.label.copyWith(
                          fontStyle: FontStyle.italic,
                          color: c.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    nearMatch!.definitionShort,
                    style: MullType.body.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.xl),
        ],
        AppButton(
          label: 'Search Mull for it',
          fullWidth: true,
          onPressed: () {
            Navigator.of(context).pop();
            context.go('${Routes.search}?q=${Uri.encodeComponent(text)}');
          },
        ),
        const SizedBox(height: Space.sm),
        AppButton(
          label: 'Not now',
          type: AppButtonType.secondary,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// HANDOFF 21.2: Arrival sheet for several words selected.
Future<void> showMultipleWordsArrivalSheet(
  BuildContext context, {
  required String text,
  required List<WordMatch> matches,
  String? sourceHint,
}) {
  return showAppBottomSheet<void>(
    context: context,
    expand: false,
    showClose: false,
    builder: (BuildContext ctx) => _MultipleWordsArrivalSheet(
      text: text,
      matches: matches,
      sourceHint: sourceHint,
    ),
  );
}

class _MultipleWordsArrivalSheet extends ConsumerWidget {
  const _MultipleWordsArrivalSheet({
    required this.text,
    required this.matches,
    this.sourceHint,
  });

  final String text;
  final List<WordMatch> matches;
  final String? sourceHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    final List<String> tokens = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((String t) => t.isNotEmpty)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ArrivalTopRow(sourceHint: sourceHint),
        const SizedBox(height: Space.lg),
        Text(
          'You sent ${tokens.length} words',
          style: MullType.title.copyWith(color: c.onSurface),
        ),
        const SizedBox(height: Space.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: c.surfaceContainerHigh,
            borderRadius: Radii.cardR,
          ),
          child: Text(
            '"$text"',
            style: MullType.body.copyWith(
              fontStyle: FontStyle.italic,
              color: c.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        if (matches.isNotEmpty) ...<Widget>[
          Text(
            'MULL HAS ${matches.length} OF THEM',
            style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Pick one to read, or keep the whole sentence and sort it out later.',
            style: MullType.note.copyWith(color: c.onSurfaceMuted),
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: <Widget>[
              for (final WordMatch m in matches)
                PillChip(
                    label: m.word!.headword,
                    onTap: () {
                      final UserRepository user = ref.read(userRepositoryProvider);
                      unawaited(user.recordLookup(m.word!.wordKey));
                      unawaited(
                        user.addContext(
                          m.word!.wordKey,
                          PlatformSurfaces.sentenceAround(text, m.rawWord),
                          sourceHint: sourceHint,
                        ),
                      );
                      Navigator.of(context).pop();
                      showWordSheet(
                        context,
                        wordKey: m.word!.wordKey,
                        fromOutside: true,
                        sourceHint: sourceHint,
                      );
                    },
                  ),
            ],
          ),
          const SizedBox(height: Space.xl),
          AppButton(
            label: 'Save to From my reading',
            fullWidth: true,
            onPressed: () async {
              final UserRepository user = ref.read(userRepositoryProvider);
              const String shelfSlug = UserRepository.readingSlug;
              await user.addAllToCollection(
                shelfSlug,
                matches.map((WordMatch m) => m.word!.wordKey),
              );
              for (final WordMatch m in matches) {
                await user.addContext(
                  m.word!.wordKey,
                  PlatformSurfaces.sentenceAround(text, m.rawWord),
                  sourceHint: sourceHint,
                );
              }
              if (context.mounted) {
                Navigator.of(context).pop();
                AppSnackbar.info(
                  context,
                  'Saved ${matches.length} words to From my reading',
                );
              }
            },
          ),
        ] else ...<Widget>[
          Text(
            'Not in Mull. The dictionary holds about 136,000 headwords, and this is not one of them.',
            style: MullType.body.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: Space.xl),
          AppButton(
            label: 'Search Mull for it',
            fullWidth: true,
            onPressed: () {
              Navigator.of(context).pop();
              context.go(Routes.search);
            },
          ),
        ],
        const SizedBox(height: Space.sm),
      ],
    );
  }
}
