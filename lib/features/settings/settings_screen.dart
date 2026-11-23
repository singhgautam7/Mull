import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/chips.dart';
import '../../core/motion/motion.dart';
import 'floating_header_sheet.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';

/// HANDOFF 3.10, regrouped the way Kuber does it: a hub that opens clear
/// pages (Look and feel, Words, Reminders), every setting on exactly one.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static String _modeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };

  static Future<void> _pickSearchStyle(
    BuildContext context,
    SearchStyle current,
    ValueChanged<SearchStyle> onPick,
  ) {
    const List<(SearchStyle, String, String)> options =
        <(SearchStyle, String, String)>[
          (
            SearchStyle.card,
            'Card',
            'Large headword, meaning beneath it, a register chip. A phrase is never mistaken for a headword.',
          ),
          (
            SearchStyle.table,
            'Table',
            'Headword left, part of speech and a short definition right. Ten rows scannable at once.',
          ),
        ];
    return showAppBottomSheet<void>(
      context: context,
      title: 'Search results',
      builder: (BuildContext ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (SearchStyle value, String label, String description)
              in options)
            _OptionRow(
              label: label,
              description: description,
              selected: value == current,
              onTap: () {
                onPick(value);
                Navigator.of(ctx).pop();
              },
            ),
        ],
      ),
    );
  }

  static Future<void> _showTextSizeSheet(BuildContext context) {
    return showAppBottomSheet<void>(
      context: context,
      title: 'Text size',
      showClose: true,
      actions: AppButton(
        label: 'Done',
        fullWidth: true,
        onPressed: () => Navigator.of(context).pop(),
      ),
      builder: (BuildContext sheetContext) {
        return Consumer(
          builder: (BuildContext context, WidgetRef ref, _) {
            final MullColors c = context.colors;
            final AppSettings s = ref.watch(settingsProvider);
            final SettingsController ctl = ref.read(settingsProvider.notifier);
            final String label = s.textScale == 1.0
                ? 'Default'
                : '${(s.textScale * 100).round()}%';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.screen),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Scale',
                        style: MullType.titleMedium.copyWith(
                          color: c.onSurface,
                        ),
                      ),
                      Text(
                        label,
                        style: MullType.monoLabel.copyWith(color: c.primary),
                      ),
                    ],
                  ),
                  Slider(
                    value: s.textScale,
                    min: 0.85,
                    max: 1.3,
                    divisions: 9,
                    label: label,
                    onChanged: (double v) =>
                        ctl.setTextScale(double.parse(v.toStringAsFixed(2))),
                  ),
                  const SizedBox(height: Space.md),
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
                          'PREVIEW',
                          style: MullType.monoLabel.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'The smell of rain falling on dry earth after a summer drought.',
                          style: MullType.body.copyWith(
                            fontSize: MullType.body.fontSize! * s.textScale,
                            color: c.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.md),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> _showPronunciationSheet(BuildContext context) {
    return showAppBottomSheet<void>(
      context: context,
      title: 'Pronunciation speed',
      showClose: true,
      actions: AppButton(
        label: 'Done',
        fullWidth: true,
        onPressed: () => Navigator.of(context).pop(),
      ),
      builder: (BuildContext sheetContext) {
        return Consumer(
          builder: (BuildContext context, WidgetRef ref, _) {
            final MullColors c = context.colors;
            final AppSettings s = ref.watch(settingsProvider);
            final SettingsController ctl = ref.read(settingsProvider.notifier);
            final String label = '${s.ttsRate.toStringAsFixed(1)}×';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.screen),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Speed',
                        style: MullType.titleMedium.copyWith(
                          color: c.onSurface,
                        ),
                      ),
                      Text(
                        label,
                        style: MullType.monoLabel.copyWith(color: c.primary),
                      ),
                    ],
                  ),
                  Slider(
                    value: s.ttsRate,
                    min: 0.5,
                    max: 1.2,
                    divisions: 7,
                    label: label,
                    onChanged: (double v) =>
                        ctl.setTtsRate(double.parse(v.toStringAsFixed(1))),
                  ),
                  const SizedBox(height: Space.md),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String themeSummary(AppSettings s) =>
      '${s.dynamicColor ? 'Wallpaper' : s.family.name} · ${_modeLabel(s.themeMode)}';

  static String floatingSummary(AppSettings s) => !s.floatingHeader
      ? 'Off'
      : switch (s.pillMode) {
          PillMode.always => 'Always',
          PillMode.scrollUp => 'When scrolling up',
          PillMode.scrollStop => 'When scrolling stops',
        };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings s = ref.watch(settingsProvider);
    return SettingsScaffold(
      title: 'Settings',
      children: <Widget>[
        SettingsGroup(
          label: 'Make it yours',
          children: <Widget>[
            SettingsRow(
              icon: Icons.palette_outlined,
              label: 'Look and feel',
              subtitle: themeSummary(s),
              onTap: () => _open(context, const LookSettingsScreen()),
            ),
            SettingsRow(
              icon: Icons.menu_book_outlined,
              label: 'Words',
              subtitle:
                  '${s.spelling == Spelling.british ? 'British' : 'American'} spelling, UK voice',
              onTap: () => _open(context, const WordsSettingsScreen()),
            ),
            SettingsRow(
              icon: Icons.notifications_none_rounded,
              label: 'Reminders',
              subtitle: s.wotdEnabled
                  ? 'Word of the day at ${clock(s.wotdMinutes)}'
                  : 'Word of the day is off',
              onTap: () => _open(context, const RemindersSettingsScreen()),
            ),
          ],
        ),
        Text(
          'Everything stays on this phone',
          style: MullType.monoLabel.copyWith(
            color: context.colors.onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}

Future<void> _open(BuildContext context, Widget page) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (BuildContext _) => page));

/// Theme, floating header, text size, search results and haptics.
class LookSettingsScreen extends ConsumerWidget {
  const LookSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings s = ref.watch(settingsProvider);
    final SettingsController ctl = ref.read(settingsProvider.notifier);
    return SettingsScaffold(
      title: 'Look and feel',
      children: <Widget>[
        SettingsGroup(
          label: 'Appearance',
          children: <Widget>[
            SettingsRow(
              icon: Icons.palette_outlined,
              label: 'Theme',
              value: SettingsScreen.themeSummary(s),
              onTap: () => context.push(Routes.theme),
            ),
            SettingsRow(
              icon: Icons.view_agenda_outlined,
              label: 'Floating header',
              value: SettingsScreen.floatingSummary(s),
              onTap: () => unawaited(showFloatingHeaderSheet(context)),
            ),
            SettingsRow(
              icon: Icons.format_size_rounded,
              label: 'Text size',
              value: s.textScale == 1.0
                  ? 'Default'
                  : '${(s.textScale * 100).round()}%',
              onTap: () =>
                  unawaited(SettingsScreen._showTextSizeSheet(context)),
            ),
            SettingsRow(
              icon: Icons.view_list_outlined,
              label: 'Search results',
              value: s.searchStyle == SearchStyle.card ? 'Card' : 'Table',
              onTap: () => unawaited(
                SettingsScreen._pickSearchStyle(
                  context,
                  s.searchStyle,
                  ctl.setSearchStyle,
                ),
              ),
            ),
          ],
        ),
        SettingsGroup(
          label: 'Feel',
          children: <Widget>[
            SettingsSwitch(
              icon: Icons.vibration_rounded,
              label: 'Haptics',
              subtitle: 'A light tap on swipes and switches',
              value: s.haptics,
              onChanged: (bool v) => ctl.setHaptics(value: v),
            ),
          ],
        ),
      ],
    );
  }
}

/// The Mull tab's card, spelling and pronunciation.
class WordsSettingsScreen extends ConsumerWidget {
  const WordsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings s = ref.watch(settingsProvider);
    final SettingsController ctl = ref.read(settingsProvider.notifier);
    return SettingsScaffold(
      title: 'Words',
      children: <Widget>[
        SettingsGroup(
          label: 'Mull tab',
          children: <Widget>[
            SettingsSwitch(
              icon: Icons.short_text_rounded,
              label: 'Show synonyms',
              subtitle: 'A row of similar words on each card',
              value: s.showSynonyms,
              onChanged: (bool v) => ctl.setShowSynonyms(value: v),
            ),
          ],
        ),
        SettingsGroup(
          label: 'Dictionary',
          children: <Widget>[
            // No tile: the toggle needs the room on a 360 dp phone.
            SettingsRow(
              label: 'Spelling',
              trailing: SizedBox(
                width: 170,
                child: SegmentedToggle<Spelling>(
                  compact: true,
                  options: const <(Spelling, String)>[
                    (Spelling.british, 'British'),
                    (Spelling.american, 'American'),
                  ],
                  selected: s.spelling,
                  onChanged: ctl.setSpelling,
                ),
              ),
            ),
            SettingsRow(
              icon: Icons.record_voice_over_outlined,
              label: 'Pronunciation speed',
              value: 'UK voice · ${s.ttsRate.toStringAsFixed(1)}×',
              onTap: () =>
                  unawaited(SettingsScreen._showPronunciationSheet(context)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Word of the day.
class RemindersSettingsScreen extends ConsumerWidget {
  const RemindersSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings s = ref.watch(settingsProvider);
    final SettingsController ctl = ref.read(settingsProvider.notifier);
    return SettingsScaffold(
      title: 'Reminders',
      children: <Widget>[
        SettingsGroup(
          label: 'Word of the day',
          children: <Widget>[
            SettingsSwitch(
              icon: Icons.notifications_none_rounded,
              label: 'Word of the day',
              subtitle: 'One quiet notification a day',
              value: s.wotdEnabled,
              onChanged: (bool v) => ctl.setWotd(enabled: v),
            ),
            SettingsRow(
              icon: Icons.schedule_rounded,
              label: 'Arrives at',
              value: clock(s.wotdMinutes),
              onTap: () async {
                final TimeOfDay? t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: s.wotdMinutes ~/ 60,
                    minute: s.wotdMinutes % 60,
                  ),
                );
                if (t != null) {
                  await ctl.setWotd(
                    enabled: s.wotdEnabled,
                    minutes: t.hour * 60 + t.minute,
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// One choice in a picker sheet: label, a one-line description, a check on
/// the selected one. 48dp minimum.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Pressable(
        kind: PressKind.row,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.thumbR,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Row(
              spacing: Space.md,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: MullType.titleMedium.copyWith(
                          color: c.onSurface,
                        ),
                      ),
                      Text(
                        description,
                        style: MullType.bodySmall.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: selected ? c.primary : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
