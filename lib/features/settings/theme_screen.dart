import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/wallpaper_seed.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/family_card.dart';
import '../../shared/widgets/two_column_grid.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';

/// HANDOFF 3.11, ordered as Kuber's theme page: mode, Expressive colours,
/// Pure black, the family grid, the wallpaper row, a live preview. Every
/// control applies its change through the theme ripple from where the finger
/// went down.
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
    // The swatches preview the dark ramp, or the light one, as it will be.
    final Tone previewTone = darkInEffect
        ? (s.amoled ? Tone.amoled : Tone.dark)
        : Tone.light;
    final bool x = s.expressiveColors;
    final Color? seed = ref.watch(wallpaperSeedProvider).value;
    final MullColors? wallpaper = seed == null
        ? null
        : ThemeFamily.fromSeed(seed).colors(tone, expressive: x);

    // Every theme change reveals from where the finger last went down.
    Offset down = Offset.zero;
    void change(FutureOr<void> Function() apply) {
      MullHaptics.tick();
      unawaited(ThemeRipple.of(context).run(down, apply));
    }

    final bool light = s.themeMode == ThemeMode.light;

    return SettingsScaffold(
      title: 'Theme',
      children: <Widget>[
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (PointerDownEvent e) => down = e.position,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SegmentedToggle<ThemeMode>(
                options: const <(ThemeMode, String)>[
                  (ThemeMode.light, 'Light'),
                  (ThemeMode.dark, 'Dark'),
                  (ThemeMode.system, 'System'),
                ],
                selected: s.themeMode,
                onChanged: (ThemeMode m) => change(() => ctl.setThemeMode(m)),
              ),
              const SizedBox(height: Space.md),
              _OptionRow(
                leading: _HalfSwatch(
                  left: ThemeFamily.mull
                      .colors(previewTone, expressive: true)
                      .surfaceContainerHigh,
                  right: ThemeFamily.mull
                      .colors(previewTone, expressive: false)
                      .surfaceContainerHigh,
                ),
                title: 'Expressive colours',
                subtitle: 'Tint backgrounds with your theme colour',
                value: x,
                onChanged: (bool v) => change(() => ctl.setExpressiveColors(value: v)),
              ),
              const SizedBox(height: Space.md),
              Semantics(
                label: light ? 'Pure black, unavailable in light mode' : null,
                excludeSemantics: light,
                child: _OptionRow(
                  enabled: !light,
                  leading: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: MullColors.pureBlack,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: c.outline),
                    ),
                  ),
                  title: 'Pure black',
                  subtitle: 'Black background in dark mode. Saves battery on OLED screens.',
                  value: s.amoled && !light,
                  onChanged: (bool v) => change(() => ctl.setAmoled(value: v)),
                ),
              ),
              if (s.themeMode == ThemeMode.system)
                Padding(
                  padding: const EdgeInsets.only(left: Space.lg, top: Space.sm),
                  child: Row(
                    spacing: 6,
                    children: <Widget>[
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: c.onSurfaceVariant,
                      ),
                      Expanded(
                        child: Text(
                          'Applies when your phone is in dark mode',
                          style: MullType.monoLabel.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Space.lg),
              TwoColumnGrid(
                children: <Widget>[
                  for (final ThemeFamily f in ThemeFamily.all)
                    FamilyCard(
                      family: f,
                      colors: f.colors(previewTone, expressive: x),
                      selected: !s.dynamicColor && s.familyId == f.id,
                      onTap: () => change(() async {
                        await ctl.setDynamicColor(value: false);
                        await ctl.setFamily(f.id);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: Space.lg),
              _OptionRow(
                highlighted: s.dynamicColor,
                leading: wallpaper == null
                    ? Icon(Icons.wallpaper_rounded, color: c.onSurfaceVariant)
                    : Row(
                        spacing: 4,
                        children: <Widget>[
                          ThemeDot(wallpaper.primary, size: 26),
                          ThemeDot(wallpaper.primaryContainer, size: 26),
                        ],
                      ),
                title: 'From your wallpaper',
                subtitle: 'Dynamic colour, Android 12+',
                value: s.dynamicColor,
                onChanged: seed == null
                    ? null
                    : (bool v) => change(() => ctl.setDynamicColor(value: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.section),
        Text(
          'PREVIEW',
          style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: Space.sm),
        Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: Radii.cardR,
            border: Border.all(color: c.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'petrichor',
                style: MullType.headwordL.copyWith(
                  fontSize: 36,
                  color: c.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'The smell of rain falling on dry earth.',
                style: MullType.body.copyWith(color: c.onSurface),
              ),
              const SizedBox(height: Space.lg),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: <Widget>[
                  AppButton(label: 'Primary', onPressed: () {}),
                  AppButton(
                    label: 'Outlined',
                    type: AppButtonType.outlined,
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A switch row in a bordered card: a leading swatch, title, one line of help.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.highlighted = false,
    this.enabled = true,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool highlighted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Space.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.cardR,
        border: Border.all(
          color: highlighted ? c.primary : c.outline,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.38,
        duration: Motion.of(context, Motion.fast),
        child: Row(
          spacing: Space.md,
          children: <Widget>[
            leading,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: MullType.titleMedium.copyWith(color: c.onSurface),
                  ),
                  Text(
                    subtitle,
                    style: MullType.monoLabel.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A 30dp rounded swatch split down the middle.
class _HalfSwatch extends StatelessWidget {
  const _HalfSwatch({required this.left, required this.right});

  final Color left;
  final Color right;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: context.colors.outline),
    ),
    child: Row(
      children: <Widget>[
        Expanded(child: ColoredBox(color: left)),
        Expanded(child: ColoredBox(color: right)),
      ],
    ),
  );
}
