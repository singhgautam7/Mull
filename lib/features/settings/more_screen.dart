import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/mix_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_header.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';

/// Perch's structure, Mull's entries. Settings, Collections, Mixes; YOUR
/// DATA (Stats, Export, Permissions); ABOUT MULL (Privacy, Dictionary info,
/// About). Version line centred below. Lists are collections now, so the
/// saved mixes take that row.
class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  int _versionTaps = 0;

  static String _modeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final AppSettings s = ref.watch(settingsProvider);
    final int collections = ref.watch(collectionsProvider).length;
    final int mixes = (ref.watch(mixesProvider).value ?? const <MixSpec>[]).where((MixSpec m) => !m.isPreset).length;
    final int entries = ref.watch(dictProvider).headwordCount;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const AppHeader(title: 'More'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.bottomSafe),
                children: <Widget>[
                  SettingsGroup(
                    label: 'General',
                    children: <Widget>[
                      SettingsRow(icon: Icons.grid_view_rounded, label: 'Shelves', value: '$collections', onTap: () => context.push(Routes.collections)),
                      SettingsRow(icon: Icons.shuffle_rounded, label: 'Mixes', value: '$mixes', onTap: () => context.push(Routes.mixes)),
                      SettingsRow(icon: Icons.tune_rounded, label: 'Settings', value: '${s.dynamicColor ? 'Wallpaper' : s.family.name} · ${_modeLabel(s.themeMode)}', onTap: () => context.push(Routes.settings)),
                    ],
                  ),
                  SettingsGroup(
                    label: 'Your data',
                    children: <Widget>[
                      SettingsRow(icon: Icons.bar_chart_rounded, label: 'Stats', onTap: () => context.push(Routes.stats)),
                      SettingsRow(icon: Icons.key_outlined, label: 'Permissions', value: 'Notifications', onTap: () => context.push(Routes.permissions)),
                      SettingsRow(icon: Icons.storage_rounded, label: 'Data', onTap: () => context.push(Routes.data)),
                    ],
                  ),
                  SettingsGroup(
                    label: 'About Mull',
                    children: <Widget>[
                      SettingsRow(icon: Icons.shield_outlined, label: 'Privacy', value: 'Offline only', onTap: () => context.push(Routes.privacy)),
                      SettingsRow(icon: Icons.menu_book_outlined, label: 'Dictionary info', value: '${grouped(entries)} entries', onTap: () => context.push(Routes.dictionary)),
                      SettingsRow(icon: Icons.info_outline_rounded, label: 'About', onTap: () => context.push(Routes.about)),
                    ],
                  ),
                  // Seven taps on the version line opens the debug route.
                  GestureDetector(
                    onTap: () {
                      setState(() => _versionTaps++);
                      if (_versionTaps >= 7) {
                        _versionTaps = 0;
                        context.push(Routes.debug);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Mull 0.1.0 · build 1', textAlign: TextAlign.center, style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
