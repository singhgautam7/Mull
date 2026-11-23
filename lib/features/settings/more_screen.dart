import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/nav_bar.dart';
import '../../core/database/dictionary_db.dart';
import '../../core/motion/pressable.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_header.dart';
import 'info_screens.dart';
import 'settings_widgets.dart';

/// The distinct headword count, read once per open dictionary on the worker.
/// Built in a synchronous function so the closure is sendable.
Future<int> moreHeadwordCount(DictionaryDb dict) =>
    dict.compute((DictionaryDb db) => db.headwordCount);

final FutureProvider<int> _headwordCountProvider = FutureProvider<int>(
  (Ref ref) => moreHeadwordCount(ref.watch(dictProvider)),
);

/// A More entry's icon: a 40 dp tonal disc, glyph 22. Mull has no secondary
/// container roles; `primaryContainer` / `onPrimaryContainer` stand in for
/// Kuber's `secondaryContainer` / `onSecondaryContainer`.
class MoreIconDisc extends StatelessWidget {
  const MoreIconDisc({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.primaryContainer,
          borderRadius: Radii.mediumR,
        ),
        child: Icon(icon, size: 22, color: c.onPrimaryContainer),
      ),
    );
  }
}

/// One More row, every row alike: disc, title, a line under it, chevron.
class MoreEntryRow extends StatelessWidget {
  const MoreEntryRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  static const double _inset = 4;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final Widget body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg - _inset,
        vertical: Space.sm - _inset,
      ),
      child: Row(
        children: <Widget>[
          MoreIconDisc(icon: icon),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MullType.titleMedium.copyWith(color: c.onSurface),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MullType.note.copyWith(
                    height: 1.3,
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Icon(Icons.chevron_right_rounded, size: 20, color: c.onSurfaceVariant),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        kind: PressKind.row,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(_inset),
          alignment: Alignment.center,
          child: InkWell(
            borderRadius: Radii.largeR,
            onTap: onTap,
            child: body,
          ),
        ),
      ),
    );
  }
}

/// Kuber's classic More. Tools (Stats), Manage (Data, Permissions), About
/// (Settings, Privacy, Dictionary, About Mull). Shelves has its own tab and
/// mixes live on the Mull tab. The line under the groups opens debug on seven
/// taps.
class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  int _versionTaps = 0;

  @override
  Widget build(BuildContext context) {
    final int? entries = ref.watch(_headwordCountProvider).value;
    final String? version = ref.watch(appVersionProvider).value;

    return Scaffold(
      body: HeaderPage(
        header: const AppHeader(title: 'More'),
        body: ListView(
          padding: EdgeInsets.fromLTRB(Space.screen, Space.xs, Space.screen, Space.bottomSafe + MullNavPill.liftOf(context)),
          children: <Widget>[
            HeaderPage.gap(),
            SettingsGroup(
              label: 'Tools',
              gap: Space.section,
              children: <Widget>[
                MoreEntryRow(icon: Icons.sticky_note_2_outlined, title: 'Notes', subtitle: 'Everything you wrote on a word', onTap: () => unawaited(context.push(Routes.notes))),
                MoreEntryRow(icon: Icons.bar_chart_rounded, title: 'Stats', subtitle: 'Words seen and revisited', onTap: () => unawaited(context.push(Routes.stats))),
              ],
            ),
            SettingsGroup(
              label: 'Manage',
              gap: Space.section,
              children: <Widget>[
                MoreEntryRow(icon: Icons.storage_rounded, title: 'Data', subtitle: 'Export, import and reset', onTap: () => unawaited(context.push(Routes.data))),
                MoreEntryRow(icon: Icons.key_outlined, title: 'Permissions', subtitle: 'Notifications', onTap: () => unawaited(context.push(Routes.permissions))),
              ],
            ),
            SettingsGroup(
              label: 'About',
              gap: Space.section,
              children: <Widget>[
                MoreEntryRow(icon: Icons.tune_rounded, title: 'Settings', subtitle: 'Look, haptics, words, reminders', onTap: () => unawaited(context.push(Routes.settings))),
                MoreEntryRow(icon: Icons.shield_outlined, title: 'Privacy', subtitle: 'Offline only', onTap: () => unawaited(context.push(Routes.privacy))),
                MoreEntryRow(icon: Icons.menu_book_outlined, title: 'Dictionary', subtitle: entries == null ? 'Entries' : '${grouped(entries)} entries', onTap: () => unawaited(context.push(Routes.dictionary))),
                MoreEntryRow(icon: Icons.info_outline_rounded, title: 'About Mull', subtitle: version ?? 'Version', onTap: () => unawaited(context.push(Routes.about))),
              ],
            ),
            // Seven taps on the footer line opens the debug route.
            Semantics(
              label: 'Made with love in India',
              child: GestureDetector(
                onTap: () {
                  setState(() => _versionTaps++);
                  if (_versionTaps >= 7) {
                    _versionTaps = 0;
                    context.push(Routes.debug);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: Space.sm),
                  child: ExcludeSemantics(child: MadeInIndia()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
