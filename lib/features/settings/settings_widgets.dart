import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_header.dart';

/// Kuber's list row geometry. Mull has no 12 dp radius token: the icon tile
/// takes `Radii.thumb` (14), the nearest.
const double _kRowInset = 4;
const double _kRowMinHeight = 56;
const double _kRowMinHeightSub = 72;

/// A titled group of rows, drawn as one rounded card with hairlines between
/// them. [danger] draws the well in `dangerContainer`.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    required this.label,
    required this.children,
    this.danger = false,
    super.key,
  });

  final String label;
  final List<Widget> children;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Semantics(
              header: true,
              child: Text(
                label.toUpperCase(),
                style: MullType.sectionHeader.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
            ),
          ),
          // A Material, so each row's ink shows above the card's fill.
          Material(
            color: danger ? c.dangerContainer : c.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: Radii.cardR,
              side: BorderSide(color: danger ? c.dangerContainer : c.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < children.length; i++) ...<Widget>[
                  if (i > 0)
                    Divider(
                      color: danger
                          ? c.onDangerContainer.withValues(alpha: 0.15)
                          : c.divider,
                      height: 1,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The tinted tile that leads a row: 40 dp, a 22 dp glyph.
class SettingsIconTile extends StatelessWidget {
  const SettingsIconTile({required this.icon, this.danger = false, super.key});

  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: danger
              ? c.onDangerContainer.withValues(alpha: 0.12)
              : c.primaryContainer,
          borderRadius: Radii.thumbR,
        ),
        child: Icon(
          icon,
          size: 22,
          color: danger ? c.onDangerContainer : c.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// One row: a tinted icon tile, a title, an optional line under it, its
/// current value on the right and a chevron if it leads somewhere.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.label,
    this.icon,
    this.value,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.danger = false,
    super.key,
  });

  final IconData? icon;
  final String label;
  final String? value;

  /// A line under the label ("Vibrate on taps and swipes").
  final String? subtitle;
  final VoidCallback? onTap;

  /// Replaces the value and chevron: a switch, or a toggle.
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final Color fg = danger ? c.onDangerContainer : c.onSurface;
    final Color sub = danger ? c.onDangerContainer : c.onSurfaceVariant;
    final bool tappable = onTap != null;
    final double inset = tappable ? _kRowInset : 0;
    final Widget body = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Space.lg - inset,
        vertical: Space.md - inset,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) => Row(
          spacing: Space.lg,
          children: <Widget>[
            if (icon != null) SettingsIconTile(icon: icon!, danger: danger),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: MullType.titleMedium.copyWith(color: fg),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: MullType.note.copyWith(height: 1.3, color: sub),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else ...<Widget>[
              // Bounded, not flexed: a flex share would leave free space
              // after a short value and push the chevron off the edge.
              if (value != null)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth * 0.4),
                  child: Text(
                    value!,
                    style: MullType.note.copyWith(height: 1.3, color: sub),
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (tappable)
                Icon(Icons.chevron_right_rounded, size: 20, color: sub),
            ],
          ],
        ),
      ),
    );
    final Widget row = Container(
      constraints: BoxConstraints(
        minHeight: subtitle == null ? _kRowMinHeight : _kRowMinHeightSub,
      ),
      padding: EdgeInsets.all(inset),
      alignment: Alignment.center,
      child: tappable
          ? InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: body,
            )
          : body,
    );
    if (!tappable) return MergeSemantics(child: row);
    return Semantics(
      button: true,
      label: <String?>[label, value, subtitle].whereType<String>().join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(kind: PressKind.row, child: row),
    );
  }
}

/// A switch row. The whole row toggles it.
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
    this.subtitle,
    super.key,
  });

  final IconData? icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  void _set(bool v) {
    MullHaptics.tick();
    onChanged(v);
  }

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      toggled: value,
      label: label,
      child: SettingsRow(
        icon: icon,
        label: label,
        subtitle: subtitle,
        onTap: () => _set(!value),
        trailing: ExcludeSemantics(
          child: Switch.adaptive(value: value, onChanged: _set),
        ),
      ),
    ),
  );
}

/// The standard sub-page: the one header with a back button over a scrolling
/// list, floating like every other page.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    required this.title,
    required this.children,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: HeaderPage(
      header: AppHeader(
        title: title,
        onBack: () => unawaited(Navigator.of(context).maybePop()),
        actions: actions,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.screen,
          Space.xs,
          Space.screen,
          Space.bottomSafe,
        ),
        children: <Widget>[HeaderPage.gap(), ...children],
      ),
    ),
  );
}

/// A paragraph on an info page.
class InfoParagraph extends StatelessWidget {
  const InfoParagraph({required this.text, this.title, super.key});

  final String? title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(
              title!.toUpperCase(),
              style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant),
            ),
            const SizedBox(height: Space.sm),
          ],
          Text(text, style: MullType.body.copyWith(color: c.onSurface)),
        ],
      ),
    );
  }
}
