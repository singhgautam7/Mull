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
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_snackbar.dart';

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

// autoDispose: keyed by word or phrase, so without it every entry ever opened
// would keep a live query for the rest of the process.
final StreamProvider<String?> Function(String) noteProvider = StreamProvider.autoDispose.family<String?, String>(
  (Ref ref, String key) => ref.watch(userRepositoryProvider).watchNote(key),
);

/// The note on a word or phrase as it sits on its sheet. With a note: a card
/// with Edit and Delete (48dp each); Delete removes it at once and a toast
/// offers Undo, the app's pattern for a destructive action. Without one:
/// "Add a note" when [showAdd], else nothing.
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
    final MullColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.sm, Space.lg),
        decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: Radii.cardR),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text('YOUR NOTE', style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant))),
                AppIconButton(icon: Icons.edit_rounded, size: 48, glyphSize: 18, filled: false, semanticLabel: 'Edit note', onPressed: edit),
                AppIconButton(
                  icon: Icons.delete_outline_rounded,
                  size: 48,
                  glyphSize: 18,
                  filled: false,
                  tint: c.danger,
                  semanticLabel: 'Delete note',
                  onPressed: () {
                    final UserRepository user = ref.read(userRepositoryProvider);
                    unawaited(user.putNote(noteKey, ''));
                    AppSnackbar.undo(context, 'Note deleted', () => unawaited(user.putNote(noteKey, note)));
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: Space.md),
              child: Text(note, style: MullType.note.copyWith(color: c.onSurface)),
            ),
          ],
        ),
      ),
    );
  }
}
