import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'app_icon_button.dart';

/// `NAME` over a box with a plain text field in it.
class LabelledField extends StatelessWidget {
  const LabelledField({
    required this.label,
    required this.controller,
    this.hint,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: Space.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: Radii.thumbR,
            border: Border.all(color: c.outline),
          ),
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textCapitalization: TextCapitalization.sentences,
            style: MullType.body.copyWith(color: c.onSurface),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              hintText: hint,
              hintStyle: MullType.body.copyWith(color: c.onSurfaceMuted),
            ),
          ),
        ),
      ],
    );
  }
}

/// `COLOUR` over six 30dp swatches. Stores an index into `MullColors.tagHues`.
class ColorSwatchRow extends StatelessWidget {
  const ColorSwatchRow({required this.selected, required this.onChanged, super.key});

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('COLOUR', style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: Space.sm),
        Row(
          spacing: Space.row,
          children: <Widget>[
            for (int i = 0; i < 6; i++)
              Semantics(
                button: true,
                selected: selected == i,
                label: 'Colour ${i + 1}',
                child: InkWell(
                  onTap: () => onChanged(i),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c.tagColor(i),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: selected == i ? c.onSurface : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The pill search field: `surfaceContainer`, 1px outline, a leading glyph
/// and a clear button once there is text. Search, and the shelf pickers.
class SearchField extends StatelessWidget {
  const SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.fullR,
        border: Border.all(color: c.outline),
      ),
      child: Row(
        spacing: 11,
        children: <Widget>[
          Icon(Icons.search_rounded, size: 18, color: c.iconMuted),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              style: MullType.body.copyWith(fontSize: 14, color: c.onSurface),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintText: hint,
                hintStyle: MullType.body.copyWith(fontSize: 14, color: c.onSurfaceMuted),
              ),
            ),
          ),
          // The clear button's slot is always laid out, so the field is the
          // same height empty and filled: its 48dp tap target would otherwise
          // grow the row the moment the first letter lands.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (BuildContext context, TextEditingValue value, Widget? _) =>
                Visibility(
                  visible: value.text.isNotEmpty,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: AppIconButton(
                    icon: Icons.close_rounded,
                    size: 30,
                    glyphSize: 16,
                    filled: false,
                    semanticLabel: 'Clear',
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
