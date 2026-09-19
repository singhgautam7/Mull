import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';

/// One step or feature item in a How To Use sheet.
class HowToItem {
  const HowToItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

/// Generic sheet displaying how a feature works and how to use it.
Future<void> showHowToUseSheet(
  BuildContext context, {
  required String title,
  required String description,
  required List<HowToItem> steps,
  String? tip,
}) {
  return showAppBottomSheet<void>(
    context: context,
    title: title,
    description: description,
    actions: AppButton(
      label: 'Done',
      fullWidth: true,
      onPressed: () => Navigator.of(context).pop(),
    ),
    builder: (BuildContext context) {
      final MullColors c = context.colors;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final HowToItem step in steps) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.outline),
                  ),
                  child: Icon(step.icon, size: 18, color: c.primary),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        step.title,
                        style: MullType.label.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        step.description,
                        style: MullType.body.copyWith(
                          fontSize: 13,
                          height: 1.45,
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
          ],
          if (tip != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surfaceContainer,
                borderRadius: Radii.cardR,
                border: Border.all(color: c.outline),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.lightbulb_outline_rounded, size: 18, color: c.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: MullType.body.copyWith(
                        fontSize: 12.5,
                        height: 1.45,
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
          ],
        ],
      );
    },
  );
}

/// Explains how shelves work and how to browse, inspect, mull, and create them.
Future<void> showHowToUseShelvesSheet(BuildContext context) {
  return showHowToUseSheet(
    context,
    title: 'How to use shelves',
    description: 'Organize words and phrases into focused groups for your study.',
    steps: const <HowToItem>[
      HowToItem(
        icon: Icons.filter_list_rounded,
        title: 'Browse and filter',
        description:
            'Switch between topics, frequency bands, idioms, or your own shelves using the filter chips above.',
      ),
      HowToItem(
        icon: Icons.view_agenda_outlined,
        title: 'Inspect words in detail',
        description:
            'Open any shelf to view definitions, examples, and progress. Switch between cards and table view depending on how you like to read.',
      ),
      HowToItem(
        icon: Icons.play_arrow_rounded,
        title: 'Mull a shelf',
        description:
            'Tap the Mull button on any shelf to practice its entries card by card with audio pronunciation.',
      ),
      HowToItem(
        icon: Icons.add_rounded,
        title: 'Create your own shelves',
        description:
            'Tap the plus button to start a personal shelf. Add words from search or directly from word cards.',
      ),
    ],
    tip: 'Tip: You can select multiple items on your own shelves to quickly bookmark or clean them up.',
  );
}

/// Explains how mixes work and how to configure sources, familiarity, and save them.
Future<void> showHowToUseMixesSheet(BuildContext context) {
  return showHowToUseSheet(
    context,
    title: 'How to use mixes',
    description: 'Mixes decide which cards appear on the Mull tab.',
    steps: const <HowToItem>[
      HowToItem(
        icon: Icons.tune_rounded,
        title: 'Choose your sources',
        description:
            'Combine topics, vocabulary bands, and your own shelves into a single deck.',
      ),
      HowToItem(
        icon: Icons.history_rounded,
        title: 'Set familiarity',
        description:
            'Pick whether you want to see brand new words, review words you have seen before, or keep a balanced mix.',
      ),
      HowToItem(
        icon: Icons.play_arrow_rounded,
        title: 'Play anytime',
        description:
            'Tap any saved mix here to immediately start practicing those cards on the Mull tab.',
      ),
      HowToItem(
        icon: Icons.bookmark_border_rounded,
        title: 'Save favorites',
        description:
            'Tune your sources on the Mull tab and tap Save as mix to keep combinations you visit often.',
      ),
    ],
    tip: 'Tip: If your mix has few words left, add another source topic or change the familiarity setting.',
  );
}
