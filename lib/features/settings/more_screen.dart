import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/mix_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_header.dart';
import 'info_screens.dart';
import 'settings_controller.dart';
import 'settings_screen.dart';
import 'settings_widgets.dart';

/// Kuber's structure, Mull's entries. Browse (Shelves, Mixes, Stats), Yours
/// (Settings, Data, Permissions), About (Privacy, Dictionary, About Mull).
/// Each destination appears once. The line under it opens debug on seven taps.
class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  int _versionTaps = 0;

  @override
  Widget build(BuildContext context) {
    final AppSettings s = ref.watch(settingsProvider);
    final int collections = ref.watch(collectionsProvider).length;
    final int mixes = (ref.watch(mixesProvider).value ?? const <MixSpec>[]).where((MixSpec m) => !m.isPreset).length;
    final int entries = ref.watch(dictProvider).headwordCount;
    final String? version = ref.watch(appVersionProvider).value;

    return Scaffold(
      body: HeaderPage(
        header: const AppHeader(title: 'More'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, Space.xs, Space.screen, Space.bottomSafe),
          children: <Widget>[
            HeaderPage.gap(),
            SettingsGroup(
              label: 'Browse',
              children: <Widget>[
                SettingsRow(icon: Icons.grid_view_rounded, label: 'Shelves', value: '$collections', onTap: () => context.push(Routes.collections)),
                SettingsRow(icon: Icons.shuffle_rounded, label: 'Mixes', value: '$mixes', onTap: () => context.push(Routes.mixes)),
                SettingsRow(icon: Icons.bar_chart_rounded, label: 'Stats', subtitle: 'Words seen and revisited', onTap: () => context.push(Routes.stats)),
              ],
            ),
            SettingsGroup(
              label: 'Yours',
              children: <Widget>[
                SettingsRow(icon: Icons.tune_rounded, label: 'Settings', value: SettingsScreen.themeSummary(s), onTap: () => context.push(Routes.settings)),
                SettingsRow(icon: Icons.storage_rounded, label: 'Data', subtitle: 'Export, import and reset', onTap: () => context.push(Routes.data)),
                SettingsRow(icon: Icons.key_outlined, label: 'Permissions', value: 'Notifications', onTap: () => context.push(Routes.permissions)),
              ],
            ),
            SettingsGroup(
              label: 'About',
              children: <Widget>[
                SettingsRow(icon: Icons.shield_outlined, label: 'Privacy', value: 'Offline only', onTap: () => context.push(Routes.privacy)),
                SettingsRow(icon: Icons.menu_book_outlined, label: 'Dictionary', value: '${grouped(entries)} entries', onTap: () => context.push(Routes.dictionary)),
                SettingsRow(icon: Icons.info_outline_rounded, label: 'About Mull', value: version, onTap: () => context.push(Routes.about)),
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
