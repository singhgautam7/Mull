import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/user_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';

/// The note sheet: plain text, autosaves on pause (600 ms debounce), "SAVED"
/// in `monoLabel` at top right. No formatting toolbar. Done dismisses; the
/// note is already saved.
Future<void> showNoteSheet(BuildContext context, {required String wordKey, required String headword}) {
  return showAppBottomSheet<void>(
    context: context,
    showClose: false,
    scrollable: false,
    builder: (BuildContext ctx) => _NoteSheet(wordKey: wordKey, headword: headword),
  );
}

class _NoteSheet extends ConsumerStatefulWidget {
  const _NoteSheet({required this.wordKey, required this.headword});

  final String wordKey;
  final String headword;

  @override
  ConsumerState<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends ConsumerState<_NoteSheet> {
  final TextEditingController _text = TextEditingController();
  Timer? _debounce;
  bool _saved = false;

  static const Duration _kAutosave = Duration(milliseconds: 600);

  UserRepository get _user => ref.read(userRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final String existing = await _user.note(widget.wordKey) ?? '';
    if (mounted && _text.text.isEmpty) {
      _text.text = existing;
      _text.selection = TextSelection.collapsed(offset: existing.length);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_user.putNote(widget.wordKey, _text.text));
    _text.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    if (_saved) setState(() => _saved = false);
    _debounce = Timer(_kAutosave, () async {
      await _user.putNote(widget.wordKey, _text.text);
      if (mounted) setState(() => _saved = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Note on ${widget.headword}', style: MullType.sheetTitle.copyWith(color: c.onSurface)),
            ),
            AnimatedOpacity(
              duration: Motion.of(context, Motion.fast),
              opacity: _saved ? 1 : 0,
              child: Text('SAVED', style: MullType.monoLabel.copyWith(color: c.accent)),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        Container(
          constraints: const BoxConstraints(minHeight: 140),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: Radii.cardR,
            border: Border.all(color: c.outline),
          ),
          child: TextField(
            controller: _text,
            autofocus: true,
            maxLines: null,
            minLines: 4,
            onChanged: _onChanged,
            textCapitalization: TextCapitalization.sentences,
            style: MullType.note.copyWith(fontSize: 15, color: c.onSurface),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: 'Keep typing. It saves itself.',
              hintStyle: MullType.note.copyWith(fontSize: 15, color: c.onSurfaceMuted),
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        Text('Plain text. No formatting.', style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
        const SizedBox(height: Space.lg),
        AppButton(label: 'Done', fullWidth: true, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
