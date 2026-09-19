import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/data_transfer_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/selectable_card.dart';
import 'settings_widgets.dart';

/// HANDOFF 16.3: pick a Mull export, preview what is in it, then merge or
/// replace. Nothing is written until the last button.
class ImportAppDataScreen extends ConsumerStatefulWidget {
  const ImportAppDataScreen({super.key});

  @override
  ConsumerState<ImportAppDataScreen> createState() =>
      _ImportAppDataScreenState();
}

class _ImportAppDataScreenState extends ConsumerState<ImportAppDataScreen> {
  ImportPreview? _preview;
  String? _error;
  ImportMode _mode = ImportMode.merge;
  bool _busy = false;

  Future<void> _pick() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
    );
    if (files.isEmpty) return;
    final PlatformFile file = files.single;
    try {
      final String source = utf8.decode(await file.readAsBytes());
      setState(() {
        _preview = ref
            .read(dataTransferRepositoryProvider)
            .parse(source, fileName: file.name);
        _error = null;
      });
    } on DataTransferException catch (error) {
      setState(() {
        _preview = null;
        _error = error.message;
      });
    }
  }

  Future<void> _apply() async {
    final ImportPreview? preview = _preview;
    if (preview == null) return;
    if (_mode == ImportMode.replace) {
      final int notes = await ref.read(userRepositoryProvider).noteCount();
      if (!mounted) return;
      final bool proceed = await confirmDialog(
        context,
        title: 'Replace everything on this phone?',
        message:
            'Shelves, notes, bookmarks, mixes, contexts and quiz history not in this file are lost, including your ${plural(notes, 'note')}.',
        confirmLabel: 'Replace',
      );
      if (!proceed) return;
    }
    setState(() => _busy = true);
    try {
      final ImportResult outcome = await ref
          .read(dataTransferRepositoryProvider)
          .apply(preview, mode: _mode);
      if (!mounted) return;
      context.pop();
      AppSnackbar.info(
        context,
        outcome.unresolvedCount == 0
            ? 'Imported ${preview.fileName}'
            : 'Imported. ${plural(outcome.unresolvedCount, 'word')} not in this dictionary kept as unresolved',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final ImportPreview? preview = _preview;
    return SettingsScaffold(
      title: 'Import app data',
      children: <Widget>[
        if (preview == null && _error == null)
          AppButton(
            label: 'Pick a Mull export',
            fullWidth: true,
            onPressed: _busy ? null : _pick,
          ),
        if (preview != null) ...<Widget>[
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
                  preview.fileName,
                  style: MullType.titleMedium.copyWith(color: c.onSurface),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  preview.exportedAt == null
                      ? 'export date unknown'
                      : 'exported ${preview.exportedAt!.toLocal().toIso8601String().substring(0, 10)}',
                  style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.section),
          SettingsGroup(
            label: 'WHAT IS IN THE FILE',
            children: <Widget>[
              SettingsRow(
                label: 'Shelves',
                value: '${preview.count('collections')}',
              ),
              SettingsRow(label: 'Notes', value: '${preview.count('notes')}'),
              SettingsRow(
                label: 'Progress',
                value: '${preview.count('progress')}',
              ),
              SettingsRow(label: 'Mixes', value: '${preview.count('mixes')}'),
            ],
          ),
          Text(
            'HOW TO BRING IT IN',
            style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: Space.sm),
          SelectableCard(
            title: 'Merge',
            description:
                'Keeps everything on this phone and adds what is missing. Where both have a note on the same word, both are kept. Nothing is removed.',
            selected: _mode == ImportMode.merge,
            onTap: () => setState(() => _mode = ImportMode.merge),
          ),
          const SizedBox(height: Space.sm),
          SelectableCard(
            title: 'Replace',
            description:
                'Clears what is on this phone first, then writes the file. Anything not in the file is lost.',
            selected: _mode == ImportMode.replace,
            danger: true,
            onTap: () => setState(() => _mode = ImportMode.replace),
          ),
          const SizedBox(height: Space.xl),
          AppButton(
            label: _mode == ImportMode.merge
                ? 'Merge this file'
                : 'Replace everything on this phone',
            type: _mode == ImportMode.merge
                ? AppButtonType.primary
                : AppButtonType.danger,
            fullWidth: true,
            onPressed: _busy ? null : _apply,
          ),
        ],
        if (_error != null) ...<Widget>[
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
                  _error!,
                  style: MullType.titleMedium.copyWith(color: c.onSurface),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  'An app export is a .json written by Export app data. To bring in a list of words instead, use Import words on a shelf.',
                  style: MullType.note.copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          AppButton(
            label: 'Pick another file',
            fullWidth: true,
            onPressed: _pick,
          ),
          const SizedBox(height: Space.sm),
          AppButton(
            label: 'Import words into a shelf instead',
            type: AppButtonType.outlined,
            fullWidth: true,
            onPressed: () => context.pushReplacement(Routes.importWords),
          ),
        ],
      ],
    );
  }
}
