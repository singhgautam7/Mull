import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/chips.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';

/// HANDOFF 3.10. APPEARANCE, LINGER, DICTIONARY, WORD OF THE DAY, DATA (in
/// the danger well). "Default collection" and "Mix in words you have seen"
/// are superseded by the mix (addendum v2) and are not here.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static String _modeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    final AppSettings s = ref.watch(settingsProvider);
    final SettingsController ctl = ref.read(settingsProvider.notifier);

    return SettingsScaffold(
      title: 'Settings',
      children: <Widget>[
        SettingsGroup(
          label: 'Appearance',
          children: <Widget>[
            SettingsRow(label: 'Theme', value: '${s.dynamicColor ? 'Wallpaper' : s.family.name} · ${_modeLabel(s.themeMode)}', onTap: () => context.push(Routes.theme)),
            SettingsSwitch(label: 'Use wallpaper colours', value: s.dynamicColor, onChanged: (bool v) => ctl.setDynamicColor(value: v)),
            SettingsSwitch(
              label: 'True black in dark mode',
              subtitle: 'Mull uses it regardless',
              value: s.amoled,
              onChanged: (bool v) => ctl.setAmoled(value: v),
            ),
            SettingsRow(
              label: 'Text size',
              value: s.textScale == 1.0 ? 'Default' : '${(s.textScale * 100).round()}%',
              trailing: SizedBox(
                width: 150,
                child: Slider(
                  value: s.textScale,
                  min: 0.85,
                  max: 1.3,
                  divisions: 9,
                  label: s.textScale == 1.0 ? 'Default' : '${(s.textScale * 100).round()}%',
                  onChanged: (double v) => ctl.setTextScale(double.parse(v.toStringAsFixed(2))),
                ),
              ),
            ),
          ],
        ),
        SettingsGroup(
          label: 'Linger',
          children: <Widget>[
            SettingsSwitch(label: 'Show synonyms row', value: s.showSynonyms, onChanged: (bool v) => ctl.setShowSynonyms(value: v)),
            SettingsSwitch(label: 'Haptics on swipe', value: s.haptics, onChanged: (bool v) => ctl.setHaptics(value: v)),
          ],
        ),
        SettingsGroup(
          label: 'Dictionary',
          children: <Widget>[
            SettingsRow(
              label: 'Spelling shown',
              trailing: SizedBox(
                width: 170,
                child: SegmentedToggle<Spelling>(
                  compact: true,
                  options: const <(Spelling, String)>[(Spelling.british, 'British'), (Spelling.american, 'American')],
                  selected: s.spelling,
                  onChanged: ctl.setSpelling,
                ),
              ),
            ),
            SettingsRow(
              label: 'Pronunciation',
              value: 'UK voice · ${s.ttsRate.toStringAsFixed(1)}×',
              trailing: SizedBox(
                width: 150,
                child: Slider(
                  value: s.ttsRate,
                  min: 0.5,
                  max: 1.2,
                  divisions: 7,
                  onChanged: (double v) => ctl.setTtsRate(double.parse(v.toStringAsFixed(1))),
                ),
              ),
            ),
          ],
        ),
        SettingsGroup(
          label: 'Word of the day',
          children: <Widget>[
            SettingsSwitch(label: 'Word of the day', value: s.wotdEnabled, onChanged: (bool v) => ctl.setWotd(enabled: v)),
            SettingsRow(
              label: 'Arrives at',
              value: clock(s.wotdMinutes),
              onTap: () async {
                final TimeOfDay? t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: s.wotdMinutes ~/ 60, minute: s.wotdMinutes % 60),
                );
                if (t != null) await ctl.setWotd(enabled: s.wotdEnabled, minutes: t.hour * 60 + t.minute);
              },
            ),
          ],
        ),
        SettingsGroup(
          label: 'Data',
          danger: true,
          children: <Widget>[
            SettingsRow(label: 'Export notes and lists', danger: true, onTap: () => context.push(Routes.export)),
            SettingsRow(
              label: 'Clear notes',
              danger: true,
              onTap: () async {
                final bool ok = await confirmDialog(context, title: 'Clear notes?', message: 'Every note is removed. Lists and seen history are not affected.', confirmLabel: 'Clear');
                if (ok) await ref.read(userRepositoryProvider).clearNotes();
              },
            ),
            SettingsRow(
              label: 'Clear seen history',
              danger: true,
              onTap: () async {
                final bool ok = await confirmDialog(context, title: 'Clear seen history?', message: 'Every word will count as unseen again. Notes and lists are not affected.', confirmLabel: 'Clear');
                if (ok) await ref.read(userRepositoryProvider).clearSeen();
              },
            ),
            SettingsRow(
              label: 'Reset everything',
              danger: true,
              onTap: () async {
                final bool ok = await confirmDialog(context, title: 'Reset everything?', message: 'Notes, lists, bookmarks, mixes and seen history are all removed. The dictionary stays.', confirmLabel: 'Reset');
                if (!ok) return;
                await ref.read(userRepositoryProvider).resetAll();
                ref.invalidate(dictionaryProvider);
                if (context.mounted) unawaited(ref.read(settingsProvider.notifier).setOnboarded(value: false));
              },
            ),
          ],
        ),
        Text('Mull keeps everything on this phone. Nothing here leaves it.', style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
      ],
    );
  }
}
