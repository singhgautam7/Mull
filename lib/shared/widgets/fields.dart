import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

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
