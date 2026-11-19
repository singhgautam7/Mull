import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/mix_repository.dart';
import '../../core/motion/motion.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_menu.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/how_to_use_sheet.dart';
import '../../shared/widgets/states.dart';
import 'mix_sheet.dart';

/// "Your mixes". A mix row's subtitle is its sources and familiarity, not a
/// count of words owned, because a mix is a query and a list is a collection
/// of words.
class SavedMixesScreen extends ConsumerStatefulWidget {
  const SavedMixesScreen({super.key});

  @override
  ConsumerState<SavedMixesScreen> createState() => _SavedMixesScreenState();
}

class _SavedMixesScreenState extends ConsumerState<SavedMixesScreen> {
  /// A mix being deleted: id to (position, mix). It stays in the list while
  /// it shrinks out, after the data has already dropped it.
  final Map<int, (int, MixSpec)> _leaving = <int, (int, MixSpec)>{};

  @override
  Widget build(BuildContext context) {
    final List<MixSpec> saved = (ref.watch(mixesProvider).value ?? const <MixSpec>[])
        .where((MixSpec m) => !m.isPreset)
        .toList();
    for (final MapEntry<int, (int, MixSpec)> g in (_leaving.entries.toList()
      ..sort((MapEntry<int, (int, MixSpec)> a, MapEntry<int, (int, MixSpec)> b) => a.value.$1.compareTo(b.value.$1)))) {
      if (saved.any((MixSpec m) => m.id == g.key)) continue;
      saved.insert(saved.length < g.value.$1 ? saved.length : g.value.$1, g.value.$2);
    }
    return Scaffold(
      body: HeaderPage(
        header: AppHeader(
          title: 'Your mixes',
          onBack: () => context.pop(),
          actions: <Widget>[
            Builder(
              builder: (BuildContext anchor) => AppIconButton(
                icon: Icons.more_horiz_rounded,
                semanticLabel: 'More',
                onPressed: () async {
                  final String? action = await showAppMenu<String>(
                    context: context,
                    anchorContext: anchor,
                    minWidth: 180,
                    entries: const <AppMenuEntry<String>>[
                      AppMenuEntry<String>(
                        value: 'how_to_use',
                        label: 'How to use',
                        icon: Icons.help_outline_rounded,
                      ),
                    ],
                  );
                  if (action == 'how_to_use' && context.mounted) {
                    await showHowToUseMixesSheet(context);
                  }
                },
              ),
            ),
          ],
        ),
        body: saved.isEmpty
            ? Column(
                children: <Widget>[
                  HeaderPage.gap(),
                  const Expanded(
                    child: EmptyState(
                      title: 'No mixes saved yet',
                      message: 'Change the sources on the Mull tab and save the selection. It will appear here and in the mix sheet.',
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.bottomSafe),
                itemCount: saved.length + 1,
                itemBuilder: (BuildContext context, int i) {
                  if (i == 0) return HeaderPage.gap();
                  final MixSpec m = saved[i - 1];
                  // The gap below a row is part of it, so it shrinks away with it.
                  return MotionListItem(
                    key: ValueKey<int?>(m.id),
                    present: !_leaving.containsKey(m.id),
                    onRemoved: () => setState(() => _leaving.remove(m.id)),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: Space.row),
                      child: MixRow(
                        mix: m,
                        onDeleting: () => setState(() => _leaving[m.id!] = (i - 1, m)),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// One saved mix: name, `{n} topics · {familiarity} · {n} words`, a small
/// pool warning, and a long-press menu.
class MixRow extends ConsumerWidget {
  const MixRow({required this.mix, this.filled = false, this.onDeleting, super.key});

  final MixSpec mix;
  final bool filled;

  /// Called once the delete is confirmed, just before the mix is removed, so
  /// a list can keep the row long enough to animate it out.
  final VoidCallback? onDeleting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    final Map<String, List<String>> keys = ref.watch(collectionKeysProvider);
    final int words = <String>{for (final String s in mix.sources) ...?keys[s]}.length;
    final String subtitle = '${plural(mix.sources.length, 'topic')} · ${familiarityLabel(mix.seenPolicy).toLowerCase()} · ${grouped(words)} words';

    Future<void> menu(Offset at) async {
      final String? action = await showAppMenu<String>(
        context: context,
        globalPosition: at,
        entries: const <AppMenuEntry<String>>[
          AppMenuEntry<String>(value: 'play', label: 'Play this mix', icon: Icons.play_arrow_rounded),
          AppMenuEntry<String>(value: 'edit', label: 'Edit sources', icon: Icons.tune_rounded),
          AppMenuEntry<String>(value: 'rename', label: 'Rename', icon: Icons.edit_outlined),
          AppMenuEntry<String>.divider(),
          AppMenuEntry<String>(value: 'delete', label: 'Delete mix', icon: Icons.delete_outline_rounded, danger: true),
        ],
      );
      if (!context.mounted) return;
      final MixRepository repo = ref.read(mixRepositoryProvider);
      switch (action) {
        case 'play':
          context.go(Routes.playMix(mix.id!));
        case 'edit':
          final MixChoice? choice = await showMixSheet(context, active: mix);
          if (choice?.sources != null) await repo.update(mix.id!, sources: choice!.sources!, seenPolicy: choice.policy!);
        case 'rename':
          final TextEditingController name = TextEditingController(text: mix.name);
          final bool? ok = await showAppBottomSheet<bool>(
            context: context,
            title: 'Rename',
            builder: (BuildContext ctx) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LabelledField(label: 'Name', controller: name, autofocus: true),
                const SizedBox(height: Space.xl),
                AppButton(label: 'Rename', fullWidth: true, onPressed: () => Navigator.of(ctx).pop(true)),
              ],
            ),
          );
          if (ok == true && name.text.trim().isNotEmpty) await repo.rename(mix.id!, name.text.trim());
        case 'delete':
          final bool ok = await confirmDialog(
            context,
            title: 'Delete ${mix.name}?',
            message: 'The words stay where they are. Only the mix is removed.',
            confirmLabel: 'Delete',
          );
          if (ok) {
            onDeleting?.call();
            await repo.delete(mix.id!);
          }
      }
    }

    return Semantics(
      button: true,
      label: '${mix.name}, $subtitle',
      child: Pressable(
        kind: PressKind.card,
        child: InkWell(
        onTap: () => context.go(Routes.playMix(mix.id!)),
        onLongPress: () => unawaited(menu(Offset.zero)),
        onTapDown: (_) {},
        borderRadius: Radii.cardR,
        child: Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: Radii.cardR,
            border: filled ? null : Border.all(color: c.outline),
          ),
          child: Row(
            spacing: Space.md,
            children: <Widget>[
              Icon(Icons.shuffle_rounded, size: 20, color: c.icon),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(mix.name, style: MullType.titleMedium.copyWith(color: c.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                    if (words < 50) ...<Widget>[
                      const SizedBox(height: 4),
                      Text('${mix.name} has $words words. It will end quickly.', style: MullType.bodySmall.copyWith(color: c.onSurfaceMuted)),
                    ],
                  ],
                ),
              ),
              Builder(
                builder: (BuildContext anchor) => AppIconButton(
                  onPressed: () {
                    final RenderBox box = anchor.findRenderObject()! as RenderBox;
                    unawaited(menu(box.localToGlobal(Offset(0, box.size.height))));
                  },
                  icon: Icons.more_vert_rounded,
                  filled: false,
                  tint: c.iconMuted,
                  semanticLabel: 'Mix options',
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}
