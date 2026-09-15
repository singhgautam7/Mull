import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// `surfaceContainerHigh`, radius 8, `monoLabel` uppercase. COMMON / UNCOMMON /
/// RARE, or FORMAL / INFORMAL / DATED / NEUTRAL for idioms. Never a number.
class BandChip extends StatelessWidget {
  const BandChip(this.label, {this.tinted = false, super.key});

  final String label;

  /// `primaryContainer` fill, for the matched run on an idiom card.
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: tinted ? c.primaryContainer : c.surfaceContainerHigh,
        borderRadius: Radii.chipR,
      ),
      child: Text(
        label.toUpperCase(),
        style: MullType.monoLabel.copyWith(
          color: tinted ? c.onPrimaryContainer : c.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A synonym chip on the card, or a filter chip on the browse screen.
class PillChip extends StatelessWidget {
  const PillChip({
    required this.label,
    this.onTap,
    this.selected = false,
    this.count,
    this.trailing,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final Color fg = selected ? c.onPrimaryContainer : c.onSurface;
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: selected ? c.primaryContainer : c.surfaceContainerHigh,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: <Widget>[
                Text(label, style: MullType.label.copyWith(fontSize: 13, color: fg).weight(selected ? 600 : 500)),
                if (count != null)
                  Text('$count', style: MullType.monoLabel.copyWith(color: selected ? c.onPrimaryContainer : c.onSurfaceVariant)),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Height 38 (34 collapsed), `surfaceContainerHigh` track, 4dp padding,
/// selected thumb = `surface` + 1px outline, label `titleSmall`. Counts sit
/// inside the label in `monoLabel`. Cards/Table, Words/Idioms, Light/Dark/System.
class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.counts = const <Object?, int>{},
    this.compact = false,
    super.key,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final Map<Object?, int> counts;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Container(
      height: compact ? 34 : 38,
      padding: const EdgeInsets.all(Space.xs),
      decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: Radii.fullR),
      child: Row(
        children: <Widget>[
          for (final (T value, String label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                child: InkWell(
                  onTap: () => onChanged(value),
                  borderRadius: Radii.fullR,
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.lensSwap),
                    curve: Motion.curveOf(context, Motion.spring),
                    decoration: BoxDecoration(
                      color: value == selected ? c.surface : Colors.transparent,
                      borderRadius: Radii.fullR,
                      border: Border.all(color: value == selected ? c.outline : Colors.transparent),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: <Widget>[
                        Text(
                          label,
                          style: MullType.titleSmall.copyWith(
                            color: value == selected ? c.onSurface : c.onSurfaceVariant,
                          ),
                        ),
                        if (counts[value] != null)
                          Text(
                            '${counts[value]}',
                            style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
