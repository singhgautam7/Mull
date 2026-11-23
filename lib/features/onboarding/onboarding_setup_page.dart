import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/onboarding_spec.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/chips.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_widgets.dart';
import 'onboarding_widgets.dart';

/// The last page, which every install passes: the reminder, then the look.
/// Each choice is saved the moment it is made, through `settingsProvider`.
class OnboardingSetupPage extends ConsumerStatefulWidget {
  const OnboardingSetupPage({super.key});

  @override
  ConsumerState<OnboardingSetupPage> createState() => _OnboardingSetupPageState();
}

class _OnboardingSetupPageState extends ConsumerState<OnboardingSetupPage> {
  // Where the finger last went down: the theme ripple reveals from there.
  Offset _down = Offset.zero;

  Future<void> _pickTime(BuildContext context, SettingsController ctl, bool enabled, int minutes) async {
    final TimeOfDay? t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (t != null) await ctl.setWotd(enabled: enabled, minutes: t.hour * 60 + t.minute);
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final SettingsController ctl = ref.read(settingsProvider.notifier);
    final bool wotd = ref.watch(settingsProvider.select((AppSettings s) => s.wotdEnabled));
    final int minutes = ref.watch(settingsProvider.select((AppSettings s) => s.wotdMinutes));
    final ThemeMode mode = ref.watch(settingsProvider.select((AppSettings s) => s.themeMode));
    // At the largest font the page scrolls: fade its last 24dp so nothing is cut hard.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect r) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const <Color>[Colors.black, Colors.black, Colors.transparent],
        stops: <double>[0, (1 - Space.xl / r.height).clamp(0, 1), 1],
      ).createShader(r),
      child: SingleChildScrollView(
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
                  Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (PointerDownEvent e) => _down = e.position,
                    child: SegmentedToggle<ThemeMode>(
                      options: const <(ThemeMode, String)>[(ThemeMode.light, 'Light'), (ThemeMode.dark, 'Dark'), (ThemeMode.system, 'System')],
                      selected: mode,
                      onChanged: (ThemeMode m) => unawaited(ThemeRipple.of(context).run(_down, () => ctl.setThemeMode(m))),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
          ],
        ),
      ),
    );
  }
}
