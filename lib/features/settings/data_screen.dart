import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';

/// Data settings: export, clear notes, clear seen history, and reset.
class DataScreen extends ConsumerWidget {
  const DataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;

    return SettingsScaffold(
      title: 'Data',
      children: <Widget>[
        SettingsGroup(
          label: 'Export',
          children: <Widget>[
            SettingsRow(
              icon: Icons.ios_share_rounded,
              label: 'Export notes and shelves',
              value: 'Markdown · CSV',
              onTap: () => context.push(Routes.export),
            ),
          ],
        ),
        SettingsGroup(
          label: 'Data management',
          danger: true,
          children: <Widget>[
            SettingsRow(
              label: 'Clear notes',
              danger: true,
              onTap: () async {
                final bool ok = await confirmDialog(
                  context,
                  title: 'Clear notes?',
                  message: 'Every note is removed. Shelves and seen history are not affected.',
                  confirmLabel: 'Clear',
                );
                if (ok) await ref.read(userRepositoryProvider).clearNotes();
              },
            ),
            SettingsRow(
              label: 'Clear seen history',
              danger: true,
              onTap: () async {
                final bool ok = await confirmDialog(
                  context,
                  title: 'Clear seen history?',
                  message: 'Every word will count as unseen again. Notes and shelves are not affected.',
                  confirmLabel: 'Clear',
                );
                if (ok) await ref.read(userRepositoryProvider).clearSeen();
              },
            ),
            SettingsRow(
              label: 'Reset everything',
              danger: true,
              onTap: () async {
                final bool ok = await confirmDialog(
                  context,
                  title: 'Reset everything?',
                  message: 'Notes, shelves, bookmarks, mixes and seen history are all removed. The dictionary stays.',
                  confirmLabel: 'Reset',
                );
                if (!ok) return;
                await ref.read(userRepositoryProvider).resetAll();
                ref.invalidate(dictionaryProvider);
                if (context.mounted) {
                  unawaited(ref.read(settingsProvider.notifier).setOnboarded(value: false));
                }
              },
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(
          'Mull keeps everything on this phone. Nothing here leaves it.',
          style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
        ),
      ],
    );
  }
}
