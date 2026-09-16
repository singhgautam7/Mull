import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_header.dart';

/// A titled group of rows, drawn as one rounded container with hairlines
/// between them. [danger] draws the well in `dangerContainer`.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.label, required this.children, this.danger = false, super.key});

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
            child: Text(label.toUpperCase(), style: MullType.sectionHeader.copyWith(fontSize: 10.5, color: c.onSurfaceVariant)),
          ),
          Container(
            decoration: BoxDecoration(
              color: danger ? c.dangerContainer : c.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: danger ? c.dangerContainer : c.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < children.length; i++) ...<Widget>[
                  if (i > 0) Divider(color: danger ? c.onDangerContainer.withValues(alpha: 0.15) : c.divider, height: 1),
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

/// One row: an icon, a label, its current value in mono on the right, and a
/// chevron if it leads somewhere. Most questions are answered without opening
/// anything.
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

  /// A `bodySmall` line under the label ("Mull uses it regardless").
  final String? subtitle;
  final VoidCallback? onTap;

  /// Replaces the value and chevron: a switch, or a slider.
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final Color fg = danger ? c.onDangerContainer : c.onSurface;
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) => Row(
          spacing: 13,
          children: <Widget>[
            if (icon != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.lg),
                child: Icon(icon, size: 20, color: danger ? c.onDangerContainer : c.icon),
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: MullType.titleMedium.copyWith(color: fg), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle != null)
                    Text(subtitle!, style: MullType.bodySmall.copyWith(fontSize: 11.5, color: danger ? c.onDangerContainer : c.onSurfaceVariant)),
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
                  constraints: BoxConstraints(maxWidth: box.maxWidth * 0.45),
                  child: Text(
                    value!,
                    style: MullType.monoLabel.copyWith(fontSize: 11.5, color: c.onSurfaceVariant),
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (onTap != null) Icon(Icons.chevron_right_rounded, size: 20, color: danger ? c.onDangerContainer : c.onSurfaceMuted),
            ],
          ],
          ),
        ),
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value',
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// A switch row.
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({required this.label, required this.value, required this.onChanged, this.icon, this.subtitle, super.key});

  final IconData? icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SettingsRow(
    icon: icon,
    label: label,
    subtitle: subtitle,
    trailing: Switch.adaptive(value: value, onChanged: onChanged),
  );
}

/// The standard sub-page: the one header with a back button over a scrolling
/// list.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({required this.title, required this.children, this.actions = const <Widget>[], super.key});

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppHeader(title: title, onBack: () => context.pop(), actions: actions),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.screen, Space.xs, Space.screen, Space.bottomSafe),
              children: children,
            ),
          ),
        ],
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
            Text(title!.toUpperCase(), style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: Space.sm),
          ],
          Text(text, style: MullType.body.copyWith(color: c.onSurface)),
        ],
      ),
    );
  }
}
