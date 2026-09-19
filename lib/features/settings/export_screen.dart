import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_button.dart';
import 'settings_widgets.dart';

/// The portable whole-app backup. The dictionary is deliberately excluded:
/// user data refers to its stable string keys and the database ships in-app.
class ExportScreen extends ConsumerWidget {
  const ExportScreen({super.key});

  Future<void> _export(WidgetRef ref) async {
    final transfer = ref.read(dataTransferRepositoryProvider);
    final String json = await transfer.exportJson();
    final String stamp = DateTime.now().toIso8601String().substring(0, 10);
    final Directory directory = await getTemporaryDirectory();
    final File file = File(p.join(directory.path, 'mull-backup-$stamp.json'));
    await file.writeAsString(json);
    await transfer.markExported();
    await SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(file.path)], text: 'Mull backup'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => SettingsScaffold(
    title: 'Export app data',
    children: <Widget>[
      const InfoParagraph(
        text: 'One JSON file with your shelves, notes, bookmarks, progress, contexts, mixes, quiz history and settings. The dictionary is not included because Mull installs it separately.',
      ),
      const SizedBox(height: Space.lg),
      AppButton(
        label: 'Export',
        fullWidth: true,
        onPressed: () => _export(ref),
      ),
    ],
  );
}
