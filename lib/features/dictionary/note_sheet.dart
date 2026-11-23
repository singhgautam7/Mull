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
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/quote_block.dart';
import '../../shared/widgets/section_header.dart';

/// A note on a word or a phrase: [wordKey] is its `word_key` or `idiom_key`
/// (the notes table keys both the same way), [headword] the title.
///
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
  bool _loaded = false;

  static const Duration _kAutosave = Duration(milliseconds: 600);

  // Held in a field: `ref` is unsafe to read in dispose().
  late final UserRepository _user;

  @override
  void initState() {
    super.initState();
    _user = ref.read(userRepositoryProvider);
    unawaited(_load());
  }

  Future<void> _load() async {
    final String existing = await _user.note(widget.wordKey) ?? '';
    _loaded = true;
    if (mounted && _text.text.isEmpty) {
      _text.text = existing;
      _text.selection = TextSelection.collapsed(offset: existing.length);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Closed before the note was read: an empty field is not an empty note.
    if (_loaded || _text.text.isNotEmpty) unawaited(_user.putNote(widget.wordKey, _text.text));
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

  void _clear() {
    final String old = _text.text;
    _debounce?.cancel();
    _text.clear();
    unawaited(_user.putNote(widget.wordKey, ''));
    if (_saved) setState(() => _saved = false);
    AppSnackbar.undo(context, 'Note cleared', () => unawaited(_restore(old)));
  }

  /// Undo may come after the sheet has closed, or after more was typed: that
  /// is kept, under the restored text.
  Future<void> _restore(String old) async {
    final String now = mounted ? _text.text : await _user.note(widget.wordKey) ?? '';
    final String text = now.trim().isEmpty ? old : '$old\n$now';
    if (mounted) {
      _debounce?.cancel();
      _text.text = text;
    }
    await _user.putNote(widget.wordKey, text);
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
              child: Text.rich(
                TextSpan(
                  text: 'Your note on ',
                  children: <InlineSpan>[
                    TextSpan(text: '\u201c${widget.headword}\u201d', style: TextStyle(color: c.accent)),
                  ],
                ),
                style: MullType.sheetTitle.copyWith(color: c.onSurface),
              ),
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
        Row(
          spacing: Space.md,
          children: <Widget>[
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _text,
                builder: (BuildContext context, TextEditingValue v, Widget? _) => AppButton(
                  label: 'Clear all',
                  type: AppButtonType.danger,
                  fullWidth: true,
                  onPressed: v.text.trim().isEmpty ? null : _clear,
                ),
              ),
            ),
            Expanded(
              child: AppButton(label: 'Done', fullWidth: true, onPressed: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ],
    );
  }
}

// autoDispose: keyed by word or phrase, so without it every entry ever opened
// would keep a live query for the rest of the process.
final StreamProvider<String?> Function(String) noteProvider = StreamProvider.autoDispose.family<String?, String>(
  (Ref ref, String key) => ref.watch(userRepositoryProvider).watchNote(key),
);

/// The note on a word or phrase as it sits on its sheet: a quote under its
/// title, with Edit on the right (the note sheet, which also clears it).
/// Without one: "Add a note" when [showAdd], else nothing.
class NoteSection extends ConsumerWidget {
  const NoteSection({required this.noteKey, required this.title, this.showAdd = true, super.key});

  final String noteKey;
  final String title;
  final bool showAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String?> async = ref.watch(noteProvider(noteKey));
    if (!async.hasValue) return const SizedBox.shrink();
    final String? note = async.value;
    void edit() => showNoteSheet(context, wordKey: noteKey, headword: title);
    if (note == null) {
      if (!showAdd) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: Space.xl),
        child: AppButton(label: 'Add a note', icon: Icons.sticky_note_2_outlined, type: AppButtonType.dotted, fullWidth: true, onPressed: edit),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The action's 48dp hit region is the rest of the gap above and below.
        const SizedBox(height: Space.sm),
        SectionHeader(
          label: 'Your note',
          inset: false,
          trailing: SectionHeaderAction(label: 'Edit', icon: Icons.edit_outlined, semanticLabel: 'Edit note', onTap: edit),
        ),
        QuoteBlock(
          child: Text(note, style: MullType.body.copyWith(color: context.colors.onSurfaceVariant)),
        ),
      ],
    );
  }
}
