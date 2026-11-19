import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/selectable_card.dart';
import 'settings_controller.dart';

/// Name of a level.
String motionLevelName(MotionLevel level) => switch (level) {
  MotionLevel.expressive => 'Expressive',
  MotionLevel.subtle => 'Subtle',
  MotionLevel.off => 'Off',
};

/// What the Motion row shows: "Auto (Expressive)", "Subtle", "Off (phone
/// setting)". [systemOff] is the phone's Remove animations.
String motionRowValue(MotionPreference pref, DeviceClass device, {required bool systemOff}) {
  if (systemOff) return 'Off (phone setting)';
  return switch (pref) {
    MotionPreference.auto => 'Auto (${motionLevelName(resolveMotionLevel(MotionPreference.auto, device))})',
    MotionPreference.expressive => 'Expressive',
    MotionPreference.subtle => 'Subtle',
    MotionPreference.off => 'Off',
  };
}

/// The Motion sheet: a card that reacts to a tap with the chosen level's
/// press response, and four choices. A choice applies at once. With the
/// phone's Remove animations on, Expressive and Subtle are disabled and a
/// note says why.
Future<void> showMotionSheet(BuildContext context) => showAppBottomSheet<void>(
  context: context,
  title: 'Motion',
  description: 'How much Mull moves as you tap and swipe',
  builder: (BuildContext _) => const _MotionBody(),
);

class _MotionBody extends ConsumerWidget {
  const _MotionBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    final MotionPreference pref = ref.watch(settingsProvider.select((AppSettings s) => s.motionPreference));
    final DeviceClass device = ref.watch(settingsProvider.select((AppSettings s) => s.deviceClass));
    final bool sys = systemMotionOff(context);
    final MotionLevel level = resolveMotionLevel(pref, device, systemOff: sys);
    final MotionLevel auto = resolveMotionLevel(MotionPreference.auto, device, systemOff: sys);
    final String autoWhy = sys
        ? 'Remove animations is on in your phone settings'
        : auto == MotionLevel.subtle
        ? 'This phone has under 4 GB of memory'
        : 'This phone can take the full effect';
    // With the phone's setting on, Off is what is really in use.
    final MotionPreference shown = sys ? MotionPreference.off : pref;

    Widget option(MotionPreference p, String title, String desc, {bool disabled = false}) => Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Opacity(
        opacity: disabled ? 0.38 : 1,
        child: IgnorePointer(
          ignoring: disabled,
          child: SelectableCard(
            title: title,
            description: desc,
            selected: shown == p,
            onTap: () => ref.read(settingsProvider.notifier).setMotionPreference(p),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, Space.xs, Space.screen, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MotionPreviewCard(level: level),
          const SizedBox(height: Space.md),
          option(MotionPreference.auto, 'Auto (${motionLevelName(auto)})', autoWhy),
          option(MotionPreference.expressive, 'Expressive', 'Springy and fluid, the full effect', disabled: sys),
          option(MotionPreference.subtle, 'Subtle', 'Short fades and small moves, no bounce', disabled: sys),
          option(MotionPreference.off, 'Off', 'No movement, a quick fade instead'),
          if (sys)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text(
                'Remove animations is on in your phone settings, so Mull uses Off.',
                style: MullType.note.copyWith(color: c.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

/// A card that answers a tap with the press response of [level]: Expressive
/// scales it and morphs its corners, Subtle scales a little, Off shows
/// nothing. It runs no ticker at rest, so nothing animates unseen.
class _MotionPreviewCard extends StatelessWidget {
  const _MotionPreviewCard({required this.level});

  final MotionLevel level;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Semantics(
      container: true,
      label: 'Preview. Tap the card to feel this level.',
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: Radii.cardR,
          border: Border.all(color: c.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MotionScope(
              level: level,
              systemOff: false,
              child: Pressable(
                kind: PressKind.card,
                morphCorners: true,
                restRadius: Radii.card,
                pressedRadius: Radii.thumb,
                haptic: false,
                builder: (BuildContext context, double radius, double pressed) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.lerp(c.surfaceContainerHigh, c.primaryContainer, pressed.clamp(0.0, 1.0)),
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: c.outline),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                    child: Row(
                      spacing: Space.lg,
                      children: <Widget>[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: c.primaryContainer, borderRadius: Radii.thumbR),
                          child: Icon(Icons.menu_book_rounded, size: 22, color: c.onPrimaryContainer),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('abate', style: MullType.titleMedium.copyWith(color: c.onSurface)),
                              Text('To become less intense', style: MullType.note.copyWith(color: c.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.sm),
            Text(
              'Tap the card to feel this level',
              textAlign: TextAlign.center,
              style: MullType.bodySmall.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
