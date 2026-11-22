import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/onboarding_spec.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/family_card.dart';
import '../../shared/widgets/two_column_grid.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_widgets.dart';
import 'onboarding_widgets.dart';

/// The last page, which every install passes: the reminder, then the look.
/// Each choice is saved the moment it is made, through `settingsProvider`.
class OnboardingSetupPage extends ConsumerWidget {
  const OnboardingSetupPage({super.key});

  Future<void> _pickTime(BuildContext context, SettingsController ctl, bool enabled, int minutes) async {
    final TimeOfDay? t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (t != null) await ctl.setWotd(enabled: enabled, minutes: t.hour * 60 + t.minute);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    final SettingsController ctl = ref.read(settingsProvider.notifier);
    final bool wotd = ref.watch(settingsProvider.select((AppSettings s) => s.wotdEnabled));
    final int minutes = ref.watch(settingsProvider.select((AppSettings s) => s.wotdMinutes));
    final ThemeMode mode = ref.watch(settingsProvider.select((AppSettings s) => s.themeMode));
    final String familyId = ref.watch(settingsProvider.select((AppSettings s) => s.familyId));
    final bool dynamic = ref.watch(settingsProvider.select((AppSettings s) => s.dynamicColor));
    final Brightness platform = MediaQuery.platformBrightnessOf(context);
    final Tone tone = ref.watch(settingsProvider.select((AppSettings s) => s.toneFor(platform)));
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen, vertical: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          OnboardingEntrance(
            delay: OnboardingSpec.delayArt,
            child: Text('Make it yours', style: MullType.display.copyWith(color: c.onSurface)),
          ),
          const SizedBox(height: Space.sm),
          OnboardingEntrance(
            delay: OnboardingSpec.delayTitle,
            child: Text('You can change all of this later in Settings.', style: MullType.body.copyWith(color: c.onSurfaceVariant)),
          ),
          const SizedBox(height: Space.xl),
          OnboardingEntrance(
            delay: OnboardingSpec.delayBody,
            child: SettingsGroup(
              label: 'Word of the day',
              children: <Widget>[
                SettingsSwitch(
                  icon: Icons.notifications_none_rounded,
                  label: 'Word of the day',
                  subtitle: 'One quiet notification a day',
                  value: wotd,
                  onChanged: (bool v) => ctl.setWotd(enabled: v),
                ),
                Opacity(
                  opacity: wotd ? 1 : 0.5,
                  child: SettingsRow(
                    icon: Icons.schedule_rounded,
                    label: 'Arrives at',
                    value: clock(minutes),
                    onTap: wotd ? () => _pickTime(context, ctl, wotd, minutes) : null,
                  ),
                ),
              ],
            ),
          ),
          OnboardingEntrance(
            delay: OnboardingSpec.delayBody,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Text('LOOK', style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant)),
                ),
                SegmentedToggle<ThemeMode>(
                  options: const <(ThemeMode, String)>[(ThemeMode.light, 'Light'), (ThemeMode.dark, 'Dark'), (ThemeMode.system, 'System')],
                  selected: mode,
                  onChanged: ctl.setThemeMode,
                ),
                const SizedBox(height: Space.lg),
                TwoColumnGrid(
                  children: <Widget>[
                    for (final ThemeFamily f in ThemeFamily.all)
                      FamilyCard(
                        family: f,
                        colors: f.colors(f.hasAmoled ? tone : (tone == Tone.amoled ? Tone.dark : tone)),
                        selected: !dynamic && familyId == f.id,
                        onTap: () async {
                          await ctl.setDynamicColor(value: false);
                          await ctl.setFamily(f.id);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
        ],
      ),
    );
  }
}
