import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/user_db.dart';
import '../../core/database/user_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_button.dart';
import 'settings_widgets.dart';

/// Notes, bookmarks and lists as Markdown or CSV, handed to the Android
/// share sheet. The licence notice travels with every export.
class ExportScreen extends ConsumerWidget {
  const ExportScreen({super.key});

  static const String _licence =
      'Definitions from Wiktionary via Kaikki.org, CC BY-SA 4.0. Exported from Mull.';

  Future<void> _export(WidgetRef ref, {required bool markdown}) async {
    final UserRepository user = ref.read(userRepositoryProvider);
    final DictionaryDb dict = ref.read(dictProvider);
    final Map<String, String> notes = await user.allNotes();
    final List<String> bookmarks = await user.bookmarkedKeys();
    // Bookmarks have their own section; every other collection follows.
    final List<UserCollection> lists = (await user.collections()).where((UserCollection l) => l.slug != UserRepository.bookmarksSlug).toList();
    final StringBuffer out = StringBuffer();

    String head(String key) => dict.byKey(key)?.headword ?? key;
    String def(String key) => dict.byKey(key)?.definitionShort ?? '';

    if (markdown) {
      out.writeln('# Mull export\n\n$_licence\n');
      out.writeln('## Bookmarks\n');
      for (final String k in bookmarks) {
        out.writeln('- **${head(k)}**: ${def(k)}');
      }
      out.writeln('\n## Notes\n');
      for (final MapEntry<String, String> n in notes.entries) {
        out.writeln('### ${head(n.key)}\n\n${n.value}\n');
      }
      for (final UserCollection l in lists) {
        out.writeln('## ${l.name}\n');
        for (final String k in await user.collectionWordKeys(l.slug)) {
          out.writeln('- **${head(k)}**: ${def(k)}');
        }
        out.writeln();
      }
    } else {
      String q(String s) => '"${s.replaceAll('"', '""')}"';
      out.writeln('kind,list,word,word_key,definition,note');
      for (final String k in bookmarks) {
        out.writeln('bookmark,,${q(head(k))},$k,${q(def(k))},${q(notes[k] ?? '')}');
      }
      for (final MapEntry<String, String> n in notes.entries) {
        out.writeln('note,,${q(head(n.key))},${n.key},${q(def(n.key))},${q(n.value)}');
      }
      for (final UserCollection l in lists) {
        for (final String k in await user.collectionWordKeys(l.slug)) {
          out.writeln('list,${q(l.name)},${q(head(k))},$k,${q(def(k))},${q(notes[k] ?? '')}');
        }
      }
      out.writeln('# $_licence');
    }
    final Directory dir = await getTemporaryDirectory();
    final File f = File(p.join(dir.path, markdown ? 'mull-export.md' : 'mull-export.csv'));
    await f.writeAsString(out.toString());
    await SharePlus.instance.share(ShareParams(files: <XFile>[XFile(f.path)], text: 'Mull export'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    return SettingsScaffold(
      title: 'Export',
      children: <Widget>[
        const InfoParagraph(text: 'Your bookmarks, notes and lists, with each word\'s short definition, as one file. It goes wherever the share sheet sends it and nowhere else.'),
        Row(
          spacing: Space.sm,
          children: <Widget>[
            AppButton(label: 'Markdown', onPressed: () => _export(ref, markdown: true)),
            AppButton(label: 'CSV', type: AppButtonType.outlined, onPressed: () => _export(ref, markdown: false)),
          ],
        ),
        const SizedBox(height: Space.xl),
        Text(_licence, style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
      ],
    );
  }
}
