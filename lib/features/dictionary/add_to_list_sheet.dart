import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/user_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/dashed_border.dart';
import '../collections/create_list_sheet.dart';

/// Checkbox rows, 22dp square, radius 6, one per collection of the user's
/// own: Bookmarks, From my reading, then created lists. "From my reading"
/// is pre-checked when the word arrived from a search result. Last row is
/// "New list".
Future<void> showAddToListSheet(
  BuildContext context, {
  required String wordKey,
  required String headword,
  bool fromSearch = false,
}) {
  return showAppBottomSheet<void>(
    context: context,
    title: 'Add $headword to',
    builder: (BuildContext ctx) => _AddToListSheet(wordKey: wordKey, fromSearch: fromSearch),
  );
}

class _AddToListSheet extends ConsumerStatefulWidget {
  const _AddToListSheet({required this.wordKey, required this.fromSearch});

  final String wordKey;
  final bool fromSearch;

  @override
  ConsumerState<_AddToListSheet> createState() => _AddToListSheetState();
}

class _AddToListSheetState extends ConsumerState<_AddToListSheet> {
  Set<String>? _checked;

  UserRepository get _user => ref.read(userRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final Set<String> checked = await _user.collectionsContaining(widget.wordKey);
    if (widget.fromSearch && checked.add(UserRepository.readingSlug)) {
      await _user.addToCollection(UserRepository.readingSlug, widget.wordKey);
    }
    if (mounted) setState(() => _checked = checked);
  }

  Future<void> _toggle(String slug, bool on) async {
    setState(() => on ? _checked!.add(slug) : _checked!.remove(slug));
    if (on) {
      await _user.addToCollection(slug, widget.wordKey);
    } else {
      await _user.removeFromCollection(slug, widget.wordKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final List<Collection> own = ref.watch(collectionsProvider).where((Collection x) => x.isUsers).toList();
    if (_checked == null) return const SizedBox(height: 120);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final Collection l in own)
          _Row(
            label: l.title,
            count: l.wordCount,
            swatch: l.kind == 'user' ? c.tagColor(l.color) : null,
            checked: _checked!.contains(l.slug),
            onChanged: (bool v) => _toggle(l.slug, v),
          ),
        const SizedBox(height: Space.sm),
        CustomPaint(
          foregroundPainter: DashedBorderPainter(c.outline, radius: Radii.thumb),
          child: InkWell(
            onTap: () async {
              final String? slug = await showCreateListSheet(context);
              if (slug != null) await _toggle(slug, true);
            },
            borderRadius: Radii.thumbR,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: Space.sm,
                children: <Widget>[
                  Icon(Icons.add_rounded, size: 18, color: c.accent),
                  Text('New list', style: MullType.titleMedium.copyWith(color: c.accent)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        AppButton(label: 'Done', fullWidth: true, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.count,
    required this.checked,
    required this.onChanged,
    this.swatch,
  });

  final String label;
  final int? count;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Semantics(
      checked: checked,
      label: label,
      child: InkWell(
        onTap: () => onChanged(!checked),
        borderRadius: Radii.thumbR,
        child: SizedBox(
          height: 48,
          child: Row(
            spacing: Space.md,
            children: <Widget>[
              AnimatedContainer(
                duration: Motion.of(context, Motion.instant),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: checked ? c.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: checked ? c.primary : c.outline, width: 1.5),
                ),
                child: checked ? Icon(Icons.check_rounded, size: 15, color: c.onPrimary) : null,
              ),
              if (swatch != null)
                Container(width: 10, height: 10, decoration: BoxDecoration(color: swatch, shape: BoxShape.circle)),
              Expanded(child: Text(label, style: MullType.titleMedium.copyWith(color: c.onSurface))),
              if (count != null) Text('$count', style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
