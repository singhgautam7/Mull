import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import 'settings_widgets.dart';

/// HANDOFF 3.13. A legal surface designed as content: edition, entry count,
/// idiom count, size, then each source with its licence.
class DictionaryInfoScreen extends ConsumerWidget {
  const DictionaryInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    final DictionaryDb dict = ref.watch(dictProvider);
    final int size = ref.watch(_dbSizeProvider).value ?? 0;
    Widget fact(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(k, style: MullType.titleMedium.copyWith(color: c.onSurface))),
          Text(v, style: MullType.monoTabular.copyWith(color: c.onSurfaceVariant)),
        ],
      ),
    );
    return SettingsScaffold(
      title: 'Dictionary',
      children: <Widget>[
        Text('Everything here was made by other people first.', style: MullType.display.copyWith(fontSize: 28, color: c.onSurface)),
        const SizedBox(height: Space.xl),
        fact('Edition', 'UK · ${dict.version}'),
        fact('Entries', grouped(dict.headwordCount)),
        fact('Senses', grouped(dict.entryCount)),
        fact('Idioms', grouped(dict.idiomCount)),
        fact('Database size', '${(size / 1e6).toStringAsFixed(size > 0 ? 1 : 0)} MB'),
        const SizedBox(height: Space.section),
        Text('SOURCES AND LICENCES', style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: Space.lg),
        const InfoParagraph(title: 'Wiktionary (English), via Kaikki.org', text: 'Definitions, senses, examples, pronunciation and idioms. Text is available under CC BY-SA 4.0. Modifications: senses trimmed to a short form for the cards, examples selected, British spellings preferred.'),
        const InfoParagraph(title: 'SUBTLEX-UK and the British National Corpus', text: 'Word frequencies, which decide the bands and the spoken-versus-written balance of the themed shelves.'),
        const InfoParagraph(title: 'Open English WordNet 2024', text: 'Synonyms only. CC BY 4.0.'),
        Text(
          'Mull is distributed under the same terms as the text it carries. The full licence travels with the app and with any export you make.',
          style: MullType.note.copyWith(color: c.onSurfaceVariant),
        ),
      ],
    );
  }
}

final FutureProvider<int> _dbSizeProvider = FutureProvider<int>((Ref ref) async {
  final String path = ref.watch(installerProvider).dbPath;
  return (await File(path).stat()).size;
});

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return SettingsScaffold(
      title: 'About',
      children: <Widget>[
        Text('A dictionary, and somewhere to put it when you are idle.', style: MullType.display.copyWith(fontSize: 28, color: c.onSurface)),
        const SizedBox(height: Space.xl),
        const InfoParagraph(title: 'Privacy', text: 'Mull is local-first. There are no accounts and no network calls. The dictionary is unpacked once on your phone and everything you make stays on it.'),
        const InfoParagraph(title: 'How to', text: 'Look a word up in Search. Or open Mull and swipe through a mix of shelves one card at a time. Bookmark what you like, add a note, organize on shelves.'),
        const InfoParagraph(title: 'Made with', text: 'Wiktionary, SUBTLEX-UK, the British National Corpus and Open English WordNet. See Dictionary info for the licences.'),
        Text('Mull 0.1.0 · build 1', style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
      ],
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return SettingsScaffold(
      title: 'Privacy',
      children: <Widget>[
        Text('Offline only.', style: MullType.display.copyWith(fontSize: 28, color: c.onSurface)),
        const SizedBox(height: Space.xl),
        const InfoParagraph(text: 'Mull declares no network permission. It cannot make a request even if it wanted to. There is no account, no sync, no analytics, no crash reporting and no advertising.'),
        const InfoParagraph(title: 'What is stored', text: 'The dictionary, read-only. Your bookmarks, notes, lists, mixes and which words you have seen, in a second file only this app can read. Settings.'),
        const InfoParagraph(title: 'What leaves the phone', text: 'Only what you export or share yourself, through the Android share sheet, to an app you choose.'),
      ],
    );
  }
}

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return SettingsScaffold(
      title: 'Permissions',
      children: <Widget>[
        const InfoParagraph(title: 'Notifications', text: 'Asked for only if you turn on Word of the day, and used for nothing else. One quiet notification at the time you choose.'),
        const InfoParagraph(title: 'Internet', text: 'Not requested. Mull cannot reach the network.'),
        Text('Change either at any time in Android settings.', style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
      ],
    );
  }
}
