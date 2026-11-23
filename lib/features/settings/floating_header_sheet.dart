import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_icon_button.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';

/// The Floating header sheet: the on/off switch and when the pill shows, each
/// choice with a live mini page. Applies at once; the sheet stays open.
Future<void> showFloatingHeaderSheet(BuildContext context) => showAppBottomSheet<void>(
  context: context,
  title: 'Floating header',
  description: 'The header follows you as you scroll',
  builder: (BuildContext _) => const _FloatingHeaderBody(),
);

const List<(PillMode, String)> _modes = <(PillMode, String)>[
  (PillMode.always, 'Always'),
  (PillMode.scrollUp, 'When scrolling up'),
  (PillMode.scrollStop, 'When scrolling stops'),
];

class _FloatingHeaderBody extends ConsumerStatefulWidget {
  const _FloatingHeaderBody();

  @override
  ConsumerState<_FloatingHeaderBody> createState() => _FloatingHeaderBodyState();
}

class _FloatingHeaderBodyState extends ConsumerState<_FloatingHeaderBody> with SingleTickerProviderStateMixin {
  /// One clock for every preview. Its ticker is muted by `TickerMode` when
  /// the sheet is covered, so nothing runs while it is not visible.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _scriptMs),
  );
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Still under the phone's Remove animations.
    _still = MediaQuery.disableAnimationsOf(context) || Motion.levelOf(context) == MotionLevel.off;
    if (_still) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final AppSettings s = ref.watch(settingsProvider);
    final SettingsController ctl = ref.read(settingsProvider.notifier);
    final bool on = s.floatingHeader;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsGroup(
          label: 'Header',
          children: <Widget>[
            SettingsSwitch(
              label: 'Floating header',
              subtitle: on ? 'Becomes a pill as you scroll' : 'Scrolls away with the page',
              value: on,
              onChanged: (bool v) {
                MullHaptics.tick();
                ctl.setFloatingHeader(value: v);
              },
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: Text(
            'SHOW THE PILL',
            style: MullType.sectionHeader.copyWith(fontSize: 10.5, color: c.onSurfaceVariant),
          ),
        ),
        for (final (PillMode m, String label) in _modes) ...<Widget>[
          _OptionCard(
            label: label,
            selected: on && s.pillMode == m,
            enabled: on,
            onTap: () {
              if (s.pillMode != m) MullHaptics.tick();
              ctl.setPillMode(m);
            },
            preview: _MiniPage(floating: on, pill: m, loop: _loop, still: _still),
          ),
          const SizedBox(height: Space.sm),
        ],
        const SizedBox(height: Space.lg),
      ],
    );
  }
}

/// A radio card: label on top, the live preview under it.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.preview,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: Semantics(
        container: true,
        excludeSemantics: true,
        button: true,
        enabled: enabled,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        label: '$label, preview',
        onTap: enabled ? onTap : null,
        child: Pressable(
          kind: PressKind.card,
          enabled: enabled,
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.instant),
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: selected ? c.primaryContainer : c.surfaceContainer,
              borderRadius: Radii.cardR,
              border: Border.all(color: selected ? c.primary : c.outline, width: selected ? 1.5 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: IconSpec.tapTarget - Space.lg),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                        size: 22,
                        color: selected ? c.primary : c.onSurfaceVariant,
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Text(
                          label,
                          style: MullType.titleMedium.copyWith(color: selected ? c.onPrimaryContainer : c.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.sm),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: preview),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kuber's 5550 ms script: wait, scroll down to 300, hold, up to 220, hold,
/// back to 0. `(end ms, offset)`.
const int _scriptMs = 5550;
const List<(int, double)> _script = <(int, double)>[
  (500, 0),
  (1600, 300),
  (2500, 300),
  (2950, 220),
  (3850, 220),
  (4850, 0),
  (5550, 0),
];

double _scriptOffset(double t) {
  final double ms = t * _scriptMs;
  int t0 = 0;
  double y0 = 0;
  for (final (int t1, double y1) in _script) {
    if (ms <= t1) {
      if (y1 == y0) return y0;
      return y0 + (y1 - y0) * Curves.easeInOutCubic.transform((ms - t0) / (t1 - t0));
    }
    t0 = t1;
    y0 = y1;
  }
  return 0;
}

/// A real [HeaderPage] on a 360 x 553 canvas, scaled to 300 x 72, whose list
/// is scrolled by the script. Not interactive, not in the semantics tree.
class _MiniPage extends StatefulWidget {
  const _MiniPage({required this.floating, required this.pill, required this.loop, required this.still});

  final bool floating;
  final PillMode pill;
  final Animation<double> loop;
  final bool still;

  @override
  State<_MiniPage> createState() => _MiniPageState();
}

class _MiniPageState extends State<_MiniPage> {
  final ScrollController _sc = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.loop.addListener(_tick);
    if (widget.still) _settle();
  }

  @override
  void didUpdateWidget(_MiniPage old) {
    super.didUpdateWidget(old);
    if (widget.still && !old.still) _settle();
  }

  /// Remove animations: the state the first scroll down ends in.
  void _settle() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && widget.still && _sc.hasClients) _sc.jumpTo(300);
  });

  void _tick() {
    if (!widget.still && _sc.hasClients) _sc.jumpTo(_scriptOffset(widget.loop.value));
  }

  @override
  void dispose() {
    widget.loop.removeListener(_tick);
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    const EdgeInsets top = EdgeInsets.only(top: Space.lg);
    final MediaQueryData mq = MediaQuery.of(context);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Container(
          width: 300,
          height: 72,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: Radii.thumbR,
            border: Border.all(color: c.outline),
          ),
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 360,
            maxWidth: 360,
            minHeight: 553,
            maxHeight: 553,
            child: Transform.scale(
              scale: 300 / 360,
              alignment: Alignment.topLeft,
              child: MediaQuery(
                data: mq.copyWith(
                  size: const Size(360, 553),
                  padding: top,
                  viewPadding: top,
                  viewInsets: EdgeInsets.zero,
                  textScaler: TextScaler.noScaling,
                ),
                child: Material(
                  color: c.surface,
                  child: HeaderPage(
                    preview: HeaderPreview(floating: widget.floating, pill: widget.pill),
                    header: AppHeader(
                      title: 'Shelves',
                      onBack: () {},
                      actions: <Widget>[
                        AppIconButton(icon: Icons.search_rounded, semanticLabel: '', onPressed: () {}),
                        AppIconButton(icon: Icons.more_vert_rounded, semanticLabel: '', onPressed: () {}),
                      ],
                    ),
                    body: ListView(
                      controller: _sc,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                      children: <Widget>[HeaderPage.gap(), for (int i = 0; i < 12; i++) _row(c, i)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _row(MullColors c, int i) => Container(
    height: 64,
    margin: const EdgeInsets.only(bottom: Space.sm),
    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
    decoration: BoxDecoration(
      color: c.surfaceContainer,
      borderRadius: Radii.cardR,
      border: Border.all(color: c.outline),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: c.primaryContainer, borderRadius: Radii.thumbR),
        ),
        const SizedBox(width: Space.lg),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FractionallySizedBox(
                widthFactor: (60 + (i * 37) % 40) / 100,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(color: c.onSurface.withValues(alpha: 0.7), borderRadius: Radii.fullR),
                ),
              ),
              const SizedBox(height: Space.sm),
              FractionallySizedBox(
                widthFactor: 0.4,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.onSurfaceVariant.withValues(alpha: 0.5),
                    borderRadius: Radii.fullR,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
