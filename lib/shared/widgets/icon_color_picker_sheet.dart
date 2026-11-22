import 'package:flutter/material.dart';

import '../../core/motion/haptics.dart';
import '../../core/motion/pressable.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/shelf_icons.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';
import 'chips.dart';
import 'shelf_icon.dart';

enum IconColorTab { icon, colour }

/// The Icon / Colour sheet (Kuber's `showIconColorPicker`): a live preview, an
/// Icon | Colour toggle and Done. Picks stay local until Done; closing
/// discards them. Returns null when closed without Done.
Future<({String? icon, int? color})?> showIconColorPicker({
  required BuildContext context,
  required String? icon,
  required int? color,
  IconColorTab initialTab = IconColorTab.icon,
}) => showAppBottomSheet<({String? icon, int? color})>(
  context: context,
  builder: (BuildContext ctx) => _IconColorBody(icon: icon, color: color, initialTab: initialTab),
);

class _IconColorBody extends StatefulWidget {
  const _IconColorBody({required this.icon, required this.color, required this.initialTab});

  final String? icon;
  final int? color;
  final IconColorTab initialTab;

  @override
  State<_IconColorBody> createState() => _IconColorBodyState();
}

class _IconColorBodyState extends State<_IconColorBody> {
  late IconColorTab _tab = widget.initialTab;
  late String _icon = widget.icon ?? ShelfIcons.defaultId;
  late int? _color = widget.color;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          spacing: Space.lg,
          children: <Widget>[
            ShelfIcon(icon: _icon, color: _color, size: 48),
            Expanded(
              child: Text(
                _tab == IconColorTab.icon ? 'Choose icon' : 'Choose colour',
                style: MullType.sheetTitle.copyWith(color: c.onSurface),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        SegmentedToggle<IconColorTab>(
          options: const <(IconColorTab, String)>[(IconColorTab.icon, 'Icon'), (IconColorTab.colour, 'Colour')],
          selected: _tab,
          onChanged: (IconColorTab t) => setState(() => _tab = t),
        ),
        const SizedBox(height: Space.lg),
        if (_tab == IconColorTab.icon)
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.36,
            child: CustomScrollView(
              slivers: <Widget>[
                SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: Space.sm,
                    crossAxisSpacing: Space.sm,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: ShelfIcons.keys.length,
                  itemBuilder: (BuildContext _, int i) {
                    final String key = ShelfIcons.keys[i];
                    return _IconCell(
                      id: key,
                      selected: key == _icon,
                      onTap: () => setState(() => _icon = key),
                    );
                  },
                ),
              ],
            ),
          )
        else
          // Kuber's banks (Vibrant, Muted, Neutral), six to a row, after the
          // theme's own accent.
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.36,
            child: CustomScrollView(
              slivers: <Widget>[
                for (final (String label, List<int?> swatches) in <(String, List<int?>)>[
                  ('Theme', const <int?>[null]),
                  ('Vibrant', MullColors.tagBanks[TagBank.vibrant]!),
                  ('Muted', MullColors.tagBanks[TagBank.muted]!),
                  ('Neutral', MullColors.tagBanks[TagBank.neutral]!),
                ]) ...<Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: Text(label.toUpperCase(), style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant)),
                    ),
                  ),
                  SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: Space.md,
                      crossAxisSpacing: Space.md,
                    ),
                    itemCount: swatches.length,
                    itemBuilder: (BuildContext _, int k) => _SwatchCell(
                      index: swatches[k],
                      selected: swatches[k] == _color,
                      onTap: () => setState(() => _color = swatches[k]),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: Space.lg)),
                ],
              ],
            ),
          ),
        const SizedBox(height: Space.xl),
        AppButton(
          label: 'Done',
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop((icon: _icon, color: _color)),
        ),
      ],
    );
  }
}

class _IconCell extends StatelessWidget {
  const _IconCell({required this.id, required this.selected, required this.onTap});

  final String id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Tooltip(
      message: ShelfIcons.labelOf(id),
      triggerMode: TooltipTriggerMode.longPress,
      child: Pressable(
        kind: PressKind.card,
        child: Material(
          color: selected ? c.primaryContainer : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: Radii.mediumR,
            side: BorderSide(color: selected ? c.primary : c.outline, width: selected ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (!selected) MullHaptics.tick();
              onTap();
            },
            child: Center(
              child: Icon(
                ShelfIcons.of(id),
                size: 22,
                color: selected ? c.onPrimaryContainer : c.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A colour circle: the accent for null, else a tag hue. Selected is a 2dp
/// primary ring and a check (Kuber's `_SwatchCell`).
class _SwatchCell extends StatelessWidget {
  const _SwatchCell({required this.index, required this.selected, required this.onTap});

  final int? index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final String name = MullColors.tagName(index);
    final Color swatch = c.tagSwatch(index);
    // Kuber: a dark tick on a light swatch, a light one on a dark swatch.
    final Color tick = ThemeData.estimateBrightnessForColor(swatch) == Brightness.light
        ? (c.isDark ? c.surface : c.onSurface)
        : (c.isDark ? c.onSurface : c.surface);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: Pressable(
        kind: PressKind.card,
        child: Material(
          color: Colors.transparent,
          shape: CircleBorder(side: BorderSide(color: selected ? c.primary : Colors.transparent, width: 2)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              if (!selected) MullHaptics.tick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(Space.xs),
              child: Ink(
                decoration: BoxDecoration(color: swatch, shape: BoxShape.circle),
                child: selected
                    ? Center(child: Icon(Icons.check_rounded, size: 18, color: tick))
                    : const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
