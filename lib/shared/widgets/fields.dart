import 'dart:math' as math;

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

/// The pill search field: `surfaceContainer`, 1px outline, a leading glyph
/// and a clear button once there is text. Search, and the shelf pickers.
/// The search bar, ported from Kuber's `KuberSearchPill` (M3): a 48dp
/// full-radius pill in `surfaceContainerHigh`, no border, a leading search
/// glyph (or [leading], e.g. a back button) in a 48dp slot, the field in the
/// 16sp body style, and a clear button that scales in once there is text.
/// Shelves and Search use the same bar.
class SearchField extends StatelessWidget {
  const SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.focusNode,
    this.autofocus = false,
    this.leading,
    this.bare = false,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  /// Replaces the search glyph (Kuber puts its back button here).
  final Widget? leading;

  /// No pill of its own: a [HeaderSearchBar] draws it.
  final bool bare;

  /// Kuber's pill height.
  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final TextStyle text = MullType.body.copyWith(fontSize: 16);
    final double line = MediaQuery.textScalerOf(context).scale(16) * (text.height ?? 1.25);
    return Container(
      height: height,
      decoration: bare ? null : BoxDecoration(color: c.surfaceContainerHigh, borderRadius: Radii.fullR),
      child: Row(
        children: <Widget>[
          leading ??
              SizedBox(
                width: IconSpec.tapTarget,
                height: IconSpec.tapTarget,
                child: Icon(Icons.search_rounded, size: 20, color: c.onSurfaceVariant),
              ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              cursorColor: c.primary,
              style: text.copyWith(color: c.onSurface),
              decoration: InputDecoration(
                isCollapsed: true,
                // Fills the pill, so all of it takes the tap, not just the line.
                contentPadding: EdgeInsets.symmetric(vertical: math.max(0, (height - line) / 2)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: hint,
                hintStyle: text.copyWith(color: c.onSurfaceVariant),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (BuildContext context, TextEditingValue v, Widget? _) => AnimatedSwitcher(
              duration: Motion.of(context, Motion.fxFast),
              transitionBuilder: (Widget child, Animation<double> a) => ScaleTransition(scale: a, child: child),
              child: v.text.isEmpty
                  ? const SizedBox(width: Space.sm, key: ValueKey<String>('none'))
                  : AppIconButton(
                      key: const ValueKey<String>('clear'),
                      icon: Icons.close_rounded,
                      kind: AppIconButtonKind.plain,
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
