import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/data_transfer_repository.dart';
import '../../core/database/user_db.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';

/// Data settings: export, clear notes, clear seen history, and reset.
class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  int _noteCount = 0;
  bool _dismissedThisMonth = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  /// HANDOFF 16.1: a dismissed reminder stays hidden for the calendar month.
  static const String _dismissedKey = 'data.backup_dismissed_month';
  static String get _thisMonth => DateTime.now().toIso8601String().substring(0, 7);

  Future<void> _loadState() async {
    final bool dismissed = ref.read(prefsProvider).getString(_dismissedKey) == _thisMonth;
    final int count = await ref.read(userRepositoryProvider).noteCount();
    if (!mounted) return;
    setState(() {
      _noteCount = count;
      _dismissedThisMonth = dismissed;
    });
  }

  void _dismissReminder() {
    unawaited(ref.read(prefsProvider).setString(_dismissedKey, _thisMonth));
    setState(() => _dismissedThisMonth = true);
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final DataTransferRepository transfer = ref.watch(dataTransferRepositoryProvider);
    final List<UserCollection> shelves = ref.watch(userCollectionsProvider).value ?? const <UserCollection>[];
    final int userShelfCount = shelves.where((UserCollection s) => s.kind == 'user').length;

    final DateTime? lastExport = transfer.lastExportedAt;
    final bool hasDataWorthSaving = _noteCount > 0 || userShelfCount > 0;
    final bool exportStale = lastExport == null ||
        DateTime.now().difference(lastExport).inDays >= 30;
    final bool showReminder = hasDataWorthSaving && exportStale && !_dismissedThisMonth;

    return SettingsScaffold(
      title: 'Data',
      children: <Widget>[
        if (showReminder) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: c.surfaceContainer,
              borderRadius: Radii.cardR,
              border: Border.all(color: c.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  lastExport == null
                      ? 'BACKUP · NEVER EXPORTED'
                      : 'LAST EXPORT · ${lastExport.toLocal().toIso8601String().substring(0, 10)}',
                  style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  'There is no account and no sync, so an export is the only copy of your notes and shelves.',
                  style: MullType.note.copyWith(color: c.onSurface),
                ),
                const SizedBox(height: Space.md),
                Row(
                  children: <Widget>[
                    AppButton(
                      label: 'Export now',
                      type: AppButtonType.secondary,
                      onPressed: () => context.push(Routes.export),
                    ),
                    const SizedBox(width: Space.sm),
                    TextButton(
                      onPressed: _dismissReminder,
                      child: Text('Not now', style: MullType.body.copyWith(color: c.onSurfaceVariant)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
        ],
        SettingsGroup(
          label: 'IMPORT AND EXPORT',
          children: <Widget>[
            SettingsRow(
              icon: Icons.ios_share_rounded,
              label: 'Export app data',
              value: 'JSON · everything but the dictionary',
              onTap: () => context.push(Routes.export),
            ),
            SettingsRow(
              icon: Icons.file_open_outlined,
              label: 'Import app data',
              value: 'From a Mull export · merge or replace',
              onTap: () => context.push(Routes.importData),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: Space.lg),
          child: Text(
            'a single shelf is exported from its own overflow, not from here',
            style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
          ),
        ),
        SettingsGroup(
          label: 'CLEAR AND RESET',
          danger: true,
          children: <Widget>[
            SettingsRow(
              label: 'Clear seen history',
              value: 'every word counts as unseen again',
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
              label: 'Clear notes',
              value: _noteCount > 0 ? '$_noteCount notes' : 'no notes yet',
              danger: true,
              onTap: () async {
                final bool ok = await confirmDialog(
                  context,
                  title: 'Clear notes?',
                  message: 'Every note and reading context is removed. Shelves and seen history are not affected.',
                  confirmLabel: 'Clear',
                );
                if (ok) {
                  await ref.read(userRepositoryProvider).clearNotes();
                  if (mounted) setState(() => _noteCount = 0);
                }
              },
            ),
            SettingsRow(
              label: 'Reset everything',
              value: 'shelves, notes, bookmarks, mixes, quiz history',
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
                  unawaited(
                    ref
                        .read(settingsProvider.notifier)
                        .setOnboarded(value: false),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(
          'Mull keeps everything on this phone. Nothing here leaves it unless you export it.',
          style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
        ),
      ],
    );
  }
}

