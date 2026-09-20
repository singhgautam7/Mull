import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/wallpaper_seed.dart';
import '../../shared/widgets/family_card.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/chips.dart';
import 'settings_controller.dart';
import '../../shared/widgets/two_column_grid.dart';
import 'settings_widgets.dart';

/// HANDOFF 3.11. Light / Dark / System; a 2x2 grid of family cards with
/// three 34dp circles each; a dynamic-colour row; a live preview card.
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    final AppSettings s = ref.watch(settingsProvider);
    final SettingsController ctl = ref.read(settingsProvider.notifier);
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final Tone tone = s.toneFor(brightness);
    final bool darkInEffect = switch (s.themeMode) {
      ThemeMode.light => false,
      ThemeMode.dark => true,
      ThemeMode.system => brightness == Brightness.dark,
    };
    final Color? seed = ref.watch(wallpaperSeedProvider).value;
    final MullColors? dynamic = seed == null ? null : ThemeFamily.fromSeed(seed).colors(tone);

    return SettingsScaffold(
      title: 'Theme',
      children: <Widget>[
        SegmentedToggle<ThemeMode>(
          options: const <(ThemeMode, String)>[(ThemeMode.light, 'Light'), (ThemeMode.dark, 'Dark'), (ThemeMode.system, 'System')],
          selected: s.themeMode,
          onChanged: ctl.setThemeMode,
        ),
        if (darkInEffect && (s.dynamicColor || s.family.hasAmoled)) ...<Widget>[
          const SizedBox(height: Space.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Space.md),
            decoration: BoxDecoration(
              color: c.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.outline),
            ),
            child: Row(
              spacing: Space.md,
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF000000),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: c.outline),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('True black (AMOLED)', style: MullType.titleMedium.copyWith(color: c.onSurface)),
                      Text('Appears only while dark is active', style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: s.amoled,
                  onChanged: (bool v) => ctl.setAmoled(value: v),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.lg),
        TwoColumnGrid(
          children: <Widget>[
            for (final ThemeFamily f in ThemeFamily.all)
              FamilyCard(
                family: f,
                colors: f.colors(f.hasAmoled ? tone : (tone == Tone.amoled ? Tone.dark : tone)),
                selected: !s.dynamicColor && s.familyId == f.id,
                onTap: () async {
                  await ctl.setDynamicColor(value: false);
                  await ctl.setFamily(f.id);
                },
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Space.md),
          decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(18), border: Border.all(color: s.dynamicColor ? c.primary : c.outline, width: s.dynamicColor ? 2 : 1)),
          child: Row(
            spacing: Space.md,
            children: <Widget>[
              if (dynamic != null)
                Row(
                  spacing: 4,
                  children: <Widget>[
                    ThemeDot(dynamic.primary, size: 26),
                    ThemeDot(dynamic.primaryContainer, size: 26),
                  ],
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('From your wallpaper', style: MullType.titleMedium.copyWith(color: c.onSurface)),
                    Text('dynamic colour, Android 12+', style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
              ),
              Switch.adaptive(value: s.dynamicColor, onChanged: seed == null ? null : (bool v) => ctl.setDynamicColor(value: v)),
            ],
          ),
        ),
        const SizedBox(height: Space.section),
        Text('PREVIEW', style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: Space.sm),
        Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: Radii.cardR, border: Border.all(color: c.outline)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('petrichor', style: MullType.headwordL.copyWith(fontSize: 36, color: c.onSurface)),
              const SizedBox(height: 4),
              Text('The smell of rain falling on dry earth.', style: MullType.body.copyWith(color: c.onSurface)),
              const SizedBox(height: Space.lg),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: <Widget>[
                  AppButton(label: 'Primary', onPressed: () {}),
                  AppButton(label: 'Outlined', type: AppButtonType.outlined, onPressed: () {}),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
