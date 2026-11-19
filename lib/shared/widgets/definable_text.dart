import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/motion/motion.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/platform_surfaces.dart';
import 'app_snackbar.dart';

/// A definition's text, selectable: a long press selects the word (handles
/// drag to extend) and the menu offers `Define "word"` when the selection is
/// an entry, and Copy. Nothing else: no Share, web search or Select all.
///
/// Used wherever a definition is shown (the word card, the word sheet, the
/// idiom sheet), never for a headword, an example or a search row. Define goes
/// through [PlatformSurfaces.defineText], the same entry point as a "Define
/// in Mull" arrival, plus lemmas and phrase entries.
class DefinableText extends ConsumerStatefulWidget {
  const DefinableText(this.text, {required this.style, super.key});

  final String text;
  final TextStyle style;

  @override
  ConsumerState<DefinableText> createState() => _DefinableTextState();
}

class _DefinableTextState extends ConsumerState<DefinableText> {
  /// Longest selection looked up; the longest phrase entry is far shorter.
  static const int _kMaxLookup = 100;

  bool _selected = false;
  String? _lookedUp;
  bool _isEntry = false;

  /// The settled selection's lookup: exact, alias, phrase or lemma, never
  /// fuzzy. A handful of indexed point queries, so it stays on this isolate,
  /// and it is remembered per text so a handle drag over one word asks once.
  bool _entryFor(String text) {
    if (text == _lookedUp) return _isEntry;
    _lookedUp = text;
    _isEntry = false;
    if (text.length <= _kMaxLookup) {
      final ({DictionaryWord? word, Idiom? idiom}) hit = ref
          .read(dictProvider)
          .resolveSelection(text, phrases: true, lemma: true);
      _isEntry = hit.word != null || hit.idiom != null;
    }
    return _isEntry;
  }

  String _clean(String s) => s
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true), '');

  void _changed(TextSelection sel, SelectionChangedCause? cause) {
    final bool had = _selected;
    _selected = sel.isValid && !sel.isCollapsed;
    if (!_selected) return;
    if (!had && cause == SelectionChangedCause.longPress) MullHaptics.longPress();
    _entryFor(_clean(sel.textInside(widget.text)));
  }

  Widget _menu(BuildContext context, EditableTextState state) {
    final TextSelection sel = state.textEditingValue.selection;
    if (!sel.isValid || sel.isCollapsed) return const SizedBox.shrink();
    final String picked = _clean(sel.textInside(state.textEditingValue.text));
    final bool define = picked.isNotEmpty && _entryFor(picked);
    return _DefineMenu(
      anchors: state.contextMenuAnchors,
      onDefine: define
          ? () {
              state.hideToolbar();
              state.userUpdateTextEditingValue(
                state.textEditingValue.copyWith(
                  selection: TextSelection.collapsed(offset: sel.end),
                ),
                SelectionChangedCause.toolbar,
              );
              PlatformSurfaces.defineText(
                this.context,
                ref,
                picked,
                fromDefinition: true,
              );
            }
          : null,
      defineLabel: 'Define "$picked"',
      onCopy: () async {
        state.copySelection(SelectionChangedCause.toolbar);
        // Android 13 and later confirm a copy themselves.
        final int? sdk = await PlatformSurfaces.sdkInt();
        if (mounted && (sdk == null || sdk < 33)) {
          AppSnackbar.info(this.context, 'Copied');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => SelectableText(
    widget.text,
    key: ValueKey<String>(widget.text),
    style: widget.style,
    // The field's own scrollable would take every vertical drag (the Mull
    // tab's page swipe, the sheet's scroll); the text never scrolls itself.
    scrollPhysics: const NeverScrollableScrollPhysics(),
    contextMenuBuilder: _menu,
    onSelectionChanged: _changed,
  );
}

/// The selection menu: a surface card above the selection (below it when
/// there is no room), 48dp rows. Opens on springFast scale and fade at
/// Expressive, a fade at Subtle, at once at Off.
class _DefineMenu extends StatelessWidget {
  const _DefineMenu({
    required this.anchors,
    required this.onDefine,
    required this.defineLabel,
    required this.onCopy,
  });

  final TextSelectionToolbarAnchors anchors;
  final VoidCallback? onDefine;
  final String defineLabel;
  final VoidCallback onCopy;

  static const double _kScaleFrom = 0.9;
  static const double _kMaxWidth = 260;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final MotionLevel level = Motion.levelOf(context);
    final Widget card = Material(
      color: c.surface,
      elevation: 8,
      shadowColor: c.shadow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.cardR,
        side: BorderSide(color: c.outline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 140, maxWidth: _kMaxWidth),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (onDefine != null)
                _MenuItem(label: defineLabel, onTap: onDefine!),
              _MenuItem(label: 'Copy', onTap: onCopy),
            ],
          ),
        ),
      ),
    );

    final Widget animated = switch (level) {
      MotionLevel.expressive => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: Motion.fastCurve.settle,
        curve: Motion.fastCurve,
        child: card,
        builder: (BuildContext _, double v, Widget? child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: _kScaleFrom + (1 - _kScaleFrom) * v,
            child: child,
          ),
        ),
      ),
      MotionLevel.subtle => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: Motion.fxFast,
        curve: Motion.curveEffects,
        child: card,
        builder: (BuildContext _, double v, Widget? child) =>
            Opacity(opacity: v, child: child),
      ),
      MotionLevel.off => card,
    };

    return TextFieldTapRegion(
      child: CustomSingleChildLayout(
        delegate: _MenuLayout(
          above: anchors.primaryAnchor,
          below: anchors.secondaryAnchor ?? anchors.primaryAnchor,
          top: MediaQuery.paddingOf(context).top + Space.sm,
        ),
        child: animated,
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        kind: PressKind.row,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MullType.label.copyWith(color: c.onSurface).weight(500),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centres the card over [above], flips it under [below] when the top of the
/// screen is in the way, and keeps it inside the screen's sides.
class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout({
    required this.above,
    required this.below,
    required this.top,
  });

  final Offset above;
  final Offset below;
  final double top;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double x = (above.dx - childSize.width / 2).clamp(
      Space.sm,
      math.max(Space.sm, size.width - childSize.width - Space.sm),
    );
    final double y = above.dy - childSize.height >= top
        ? above.dy - childSize.height
        : below.dy;
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout old) =>
      above != old.above || below != old.below || top != old.top;
}
