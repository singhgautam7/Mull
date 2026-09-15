import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/user_db.dart';
import '../../core/database/user_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/dashed_border.dart';
import '../lists/create_list_sheet.dart';

/// Checkbox rows, 22dp square, radius 6. "From my reading" is pre-checked
/// when the word arrived from a search result. Last row is "New list".
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
  Set<int>? _checked;
  bool _bookmarked = false;

  UserRepository get _user => ref.read(userRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final Set<int> checked = await _user.listsContaining(widget.wordKey);
    final bool bookmarked = await _user.isBookmarked(widget.wordKey);
    if (widget.fromSearch) {
      final WordList reading = await _user.readingList();
      if (!checked.contains(reading.id)) {
        checked.add(reading.id);
        await _user.addToList(reading.id, widget.wordKey);
      }
    }
    if (mounted) {
      setState(() {
        _checked = checked;
        _bookmarked = bookmarked;
      });
    }
  }

  Future<void> _toggle(int listId, bool on) async {
    setState(() => on ? _checked!.add(listId) : _checked!.remove(listId));
    if (on) {
      await _user.addToList(listId, widget.wordKey);
    } else {
      await _user.removeFromList(listId, widget.wordKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final List<WordList> lists = ref.watch(listsProvider).value ?? const <WordList>[];
    final Map<int, int> counts = ref.watch(listCountsProvider).value ?? const <int, int>{};
    if (_checked == null) return const SizedBox(height: 120);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Row(
          label: 'Bookmarks',
          count: null,
          checked: _bookmarked,
          onChanged: (bool v) async {
            setState(() => _bookmarked = v);
            if (v) {
              await _user.addBookmark(widget.wordKey);
            } else {
              await _user.removeBookmark(widget.wordKey);
            }
          },
        ),
        for (final WordList l in lists)
          _Row(
            label: l.name,
            count: counts[l.id] ?? 0,
            swatch: c.tagColor(l.color),
            checked: _checked!.contains(l.id),
            onChanged: (bool v) => _toggle(l.id, v),
          ),
        const SizedBox(height: Space.sm),
        CustomPaint(
          foregroundPainter: DashedBorderPainter(c.outline, radius: Radii.thumb),
          child: InkWell(
            onTap: () async {
              final int? id = await showCreateListSheet(context);
              if (id != null) await _toggle(id, true);
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
