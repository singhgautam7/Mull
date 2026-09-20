import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/router/router.dart';
import '../../core/utils/format.dart';
import '../../core/utils/platform_surfaces.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/states.dart';
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

/// The installed version, read once from the package.
final FutureProvider<String?> appVersionProvider = FutureProvider<String?>(
  (Ref ref) => PlatformSurfaces.appVersion(),
);

/// About Mull: a note from the developer, what it stands for as four tiles,
/// what it is in a paragraph, the version, the privacy policy, and the ways
/// out to the developer. Every block sits on the settings card.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const String portfolio = 'https://singhgautam.com';
  static const String moreApps = 'https://play.google.com/store/apps/developer?id=Gautam+Rajeev+Singh';
  static const String listing = 'https://play.google.com/store/apps/details?id=com.grs.dictionary';

  static const List<(IconData, String, String)> _pillars = <(IconData, String, String)>[
    (Icons.text_fields_rounded, 'Anywhere', 'Select a word in any app and choose Define in Mull. The entry opens right there.'),
    (Icons.swipe_vertical_rounded, 'Swipe', 'Open the Mull tab and swipe through words one card at a time, the way you would a feed.'),
    (Icons.shelves, 'Shelves', 'Words for work, for reading, for saying more than very. Make your own for anything.'),
    (Icons.lock_outline_rounded, 'Offline', 'No ads, no account, no network. The dictionary lives on the phone.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    final String? version = ref.watch(appVersionProvider).value;
    return SettingsScaffold(
      title: 'About Mull',
      children: <Widget>[
        _AboutCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _Eyebrow('A note from the developer'),
              const SizedBox(height: Space.md),
              Text('A dictionary you can read sideways.', style: MullType.sheetTitle.copyWith(color: c.onSurface)),
              const SizedBox(height: Space.lg),
              Text(
                'Hey there,\n\n'
                'Thank you for installing Mull.\n\n'
                'I wanted a dictionary that could define a word from any screen on my phone, '
                'not one I had to open, type into and close again. And I wanted the other half too: '
                'a way to just scroll through words when I had a minute, the way you scroll through '
                'shorts, and come away with one or two.\n\n'
                'The vocabulary apps I tried were either dated or full of ads and streaks. So I built '
                'the one I wanted. Modern, quiet, no ads, and with shelves for different moments: '
                'words for work, words for reading, words that say more than very.\n\n'
                'I hope a few of them stay with you.',
                style: MullType.body.copyWith(height: 1.7, color: c.onSurface),
              ),
              const SizedBox(height: Space.xl),
              Text('Gautam Rajeev Singh', style: MullType.titleMedium.copyWith(color: c.onSurface)),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => unawaited(PlatformSurfaces.openUrl(portfolio)),
                child: Text('singhgautam.com', style: MullType.bodySmall.copyWith(color: c.onSurfaceVariant)),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        const MadeInIndia(),
        const SizedBox(height: Space.xl),
        const Padding(padding: EdgeInsets.only(left: 4, bottom: Space.sm), child: _Eyebrow('What it stands for')),
        for (int row = 0; row < _pillars.length; row += 2) ...<Widget>[
          if (row > 0) const SizedBox(height: Space.row),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Space.row,
              children: <Widget>[
                for (int i = row; i < row + 2; i++) Expanded(child: _Tile(_pillars[i])),
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.xl),
        _AboutCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _Eyebrow('What it is'),
              const SizedBox(height: Space.md),
              Text(
                'An offline English dictionary of about 136,000 headwords, built from Wiktionary, with a '
                'curated set of a few thousand words worth learning. Look a word up in Search, or open the '
                'Mull tab and swipe through a mix of shelves one card at a time. Bookmark what you like, '
                'add a note, put it on a shelf, quiz yourself later.',
                style: MullType.body.copyWith(height: 1.6, color: c.onSurfaceVariant),
              ),
              const SizedBox(height: Space.md),
              Text(
                'There is no like count, streak, level or red dot anywhere in it.',
                style: MullType.body.copyWith(height: 1.6, color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        _AboutCard(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.xl, Space.md),
          child: Row(
            children: <Widget>[
              Expanded(child: Text('Version', style: MullType.titleMedium.copyWith(color: c.onSurface))),
              PillChip(label: version ?? '…'),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        SettingsGroup(
          label: 'Legal',
          children: <Widget>[
            SettingsRow(icon: Icons.shield_outlined, label: 'Privacy policy', value: 'Offline only', onTap: () => context.push(Routes.privacy)),
            SettingsRow(icon: Icons.menu_book_outlined, label: 'Dictionary licences', onTap: () => context.push(Routes.dictionary)),
          ],
        ),
        const SizedBox(height: Space.xl),
        SettingsGroup(
          label: 'The developer',
          children: <Widget>[
            SettingsRow(icon: Icons.person_outline_rounded, label: 'Gautam Rajeev Singh', subtitle: 'singhgautam.com', onTap: () => unawaited(PlatformSurfaces.openUrl(portfolio))),
            SettingsRow(icon: Icons.apps_rounded, label: 'More apps', subtitle: 'Everything else on Google Play', onTap: () => unawaited(PlatformSurfaces.openUrl(moreApps))),
            SettingsRow(icon: Icons.star_outline_rounded, label: 'Rate Mull', subtitle: 'Helps others find it', onTap: () => unawaited(PlatformSurfaces.openUrl(listing))),
          ],
        ),
        const SizedBox(height: Space.lg),
        Text('No account. No server. Nothing leaves the phone.', textAlign: TextAlign.center, style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
      ],
    );
  }
}

/// The line under the More screen and on About.
class MadeInIndia extends StatelessWidget {
  const MadeInIndia({super.key});

  @override
  Widget build(BuildContext context) => Text(
    'Made with \u2764\ufe0f in India',
    textAlign: TextAlign.center,
    style: MullType.monoLabel.copyWith(color: context.colors.onSurfaceMuted),
  );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: MullType.sectionHeader.copyWith(color: context.colors.onSurfaceVariant));
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.child, this.padding = const EdgeInsets.all(Space.xl)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: Radii.cardR, border: Border.all(color: c.outline)),
      child: child,
    );
  }
}

/// One pillar: the glyph, then the title and line at the foot. As tall as
/// its row needs, so nothing clips at any text size.
class _Tile extends StatelessWidget {
  const _Tile(this.tile);

  final (IconData, String, String) tile;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final (IconData icon, String title, String line) = tile;
    return _AboutCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: c.iconMuted),
          const SizedBox(height: Space.xl),
          Text(title, style: MullType.titleMedium.copyWith(color: c.onSurface)),
          const SizedBox(height: 6),
          Text(line, style: MullType.bodySmall.copyWith(height: 1.4, color: c.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// The privacy policy, rendered from the same PRIVACY_POLICY.md that sits in
/// the repository, so the app and the store listing never say different
/// things. The file uses headings, paragraphs, bullets, bold and one table;
/// that is all the renderer knows.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return SettingsScaffold(
      title: 'Privacy policy',
      children: <Widget>[
        FutureBuilder<String>(
          future: rootBundle.loadString('PRIVACY_POLICY.md'),
          builder: (BuildContext context, AsyncSnapshot<String> snap) {
            final String? md = snap.data;
            if (md == null) return const LoadingHairline(visible: true);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[for (final Widget w in _renderMarkdown(md, c)) w],
            );
          },
        ),
      ],
    );
  }

  static List<Widget> _renderMarkdown(String md, MullColors c) {
    final List<Widget> out = <Widget>[];
    final List<String> paragraph = <String>[];
    void flush() {
      if (paragraph.isEmpty) return;
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: Space.md),
        child: _rich(paragraph.join(' '), MullType.body.copyWith(height: 1.6, color: c.onSurfaceVariant), c),
      ));
      paragraph.clear();
    }

    for (final String raw in md.split('\n')) {
      final String line = raw.trimRight();
      if (line.isEmpty || line == '---') {
        flush();
        continue;
      }
      if (line.startsWith('# ')) {
        flush();
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: Space.lg),
          child: Text(line.substring(2), style: MullType.display.copyWith(fontSize: 28, color: c.onSurface)),
        ));
      } else if (line.startsWith('## ')) {
        flush();
        out.add(Padding(
          padding: const EdgeInsets.only(top: Space.md, bottom: Space.sm),
          child: Text(line.substring(3), style: MullType.sheetTitle.copyWith(color: c.onSurface)),
        ));
      } else if (line.startsWith('### ')) {
        flush();
        out.add(Padding(
          padding: const EdgeInsets.only(top: Space.xs, bottom: Space.xs),
          child: Text(line.substring(4), style: MullType.titleMedium.copyWith(color: c.onSurface)),
        ));
      } else if (line.startsWith('- ')) {
        flush();
        out.add(Padding(
          padding: const EdgeInsets.only(left: Space.md, bottom: Space.xs),
          child: _rich('\u2022  ${line.substring(2)}', MullType.body.copyWith(height: 1.6, color: c.onSurfaceVariant), c),
        ));
      } else if (line.startsWith('> ')) {
        flush();
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: _rich(line.substring(2), MullType.body.copyWith(height: 1.6, fontStyle: FontStyle.italic, color: c.onSurfaceVariant), c),
        ));
      } else if (line.startsWith('|')) {
        // A table row: the header and the rule are skipped, each other row
        // becomes "cell one" over "cell two".
        flush();
        final List<String> cells = line.split('|').map((String s) => s.trim()).where((String s) => s.isNotEmpty).toList();
        if (cells.length < 2 || cells.first.startsWith(':-') || cells.first == 'Permission') continue;
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(cells[0].replaceAll('`', ''), style: MullType.monoLabel.copyWith(color: c.onSurface)),
              const SizedBox(height: 2),
              _rich(cells[1], MullType.body.copyWith(height: 1.6, color: c.onSurfaceVariant), c),
            ],
          ),
        ));
      } else {
        paragraph.add(line);
      }
    }
    flush();
    return out;
  }

  /// `**bold**` and `` `code` `` inside a line; nothing else.
  static Widget _rich(String text, TextStyle base, MullColors c) {
    final List<InlineSpan> spans = <InlineSpan>[];
    final RegExp marks = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');
    int at = 0;
    for (final RegExpMatch m in marks.allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: base.copyWith(fontWeight: FontWeight.w600, color: c.onSurface)));
      } else {
        spans.add(TextSpan(text: m.group(2), style: MullType.monoLabel.copyWith(color: c.onSurface)));
      }
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(TextSpan(style: base, children: spans));
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
