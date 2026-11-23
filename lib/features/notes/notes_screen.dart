import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/user_db.dart';
import '../../core/motion/pressable.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/states.dart';
import '../dictionary/idiom_sheet.dart';
import '../dictionary/note_sheet.dart';
import '../dictionary/word_sheet.dart';

final StreamProvider<List<Note>> _notesProvider = StreamProvider.autoDispose<List<Note>>(
  (Ref ref) => ref.watch(userRepositoryProvider).watchAllNotes(),
);

/// Resolved once per set of keys: editing a note's text keeps the same keys,
/// so it never asks the dictionary again.
final FutureProvider<ShelfRows> _rowsProvider = FutureProvider.autoDispose<ShelfRows>((Ref ref) {
  final String? joined = ref.watch(
    _notesProvider.select((AsyncValue<List<Note>> a) {
      final List<String>? keys = a.value?.map((Note n) => n.wordKey).toList()?..sort();
      return keys?.join('\n');
    }),
  );
  if (joined == null || joined.isEmpty) return Future<ShelfRows>.value(ShelfRows.empty);
  return ref.watch(dictProvider).shelfRows(joined.split('\n'));
});

/// Every note on any word or phrase, newest first.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MullColors c = context.colors;
    final List<Note>? notes = ref.watch(_notesProvider).value;
    final ShelfRows? rows = ref.watch(_rowsProvider).value;
    final bool ready = notes != null && rows != null;
    final Map<String, DictionaryWord> words = <String, DictionaryWord>{
      for (final DictionaryWord w in rows?.words ?? const <DictionaryWord>[]) w.wordKey: w,
    };
    final Map<String, Phrase> phrases = <String, Phrase>{
      for (final Phrase p in rows?.phrases ?? const <Phrase>[]) p.phraseKey: p,
    };

    return Scaffold(
      body: HeaderPage(
        header: AppHeader(title: 'Notes', onBack: () => context.pop()),
        body: !ready
            ? const SizedBox.shrink()
            : notes.isEmpty
            ? const EmptyState(
                title: 'No notes yet',
                message: 'Open any word and tap the note button to write one.',
              )
            : CustomScrollView(
                slivers: <Widget>[
                  HeaderPage.sliverGap(),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(Space.screen, Space.xs, Space.screen, Space.md),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        plural(notes.length, 'note'),
                        style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.bottomSafe),
                    sliver: SliverList.separated(
                      itemCount: notes.length,
                      separatorBuilder: (BuildContext _, int i) => const SizedBox(height: Space.md),
                      itemBuilder: (BuildContext context, int i) =>
                          _NoteCard(note: notes[i], word: words[notes[i].wordKey], phrase: phrases[notes[i].wordKey]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

const List<String> _months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _date(DateTime d) {
  final String day = '${d.day} ${_months[d.month - 1]}';
  return d.year == DateTime.now().year ? day : '$day ${d.year}';
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, this.word, this.phrase});

  final Note note;
  final DictionaryWord? word;
  final Phrase? phrase;

  String get _title => word?.headword ?? phrase?.phrase ?? note.wordKey.split('|').first;

  void _open(BuildContext context) {
    if (word != null) {
      showWordSheet(context, wordKey: note.wordKey);
    } else if (phrase != null) {
      final Phrase p = phrase!;
      showIdiomSheet(
        context,
        idiom: Idiom(
          idiomKey: p.phraseKey,
          phrase: p.phrase,
          meaning: p.meaning,
          example: p.example,
          register: p.register,
        ),
      );
    } else {
      showNoteSheet(context, wordKey: note.wordKey, headword: _title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Pressable(
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: Radii.cardR,
          border: Border.all(color: c.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text.rich(
              TextSpan(
                text: _title,
                style: MullType.titleMedium.copyWith(color: c.onSurface),
                children: <InlineSpan>[
                  if (word != null)
                    TextSpan(
                      text: '  ${posLabel(word!.pos)}',
                      style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
            Text(
              note.body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: MullType.note.copyWith(color: c.onSurfaceVariant),
            ),
            const SizedBox(height: Space.md),
            Text(_date(note.updatedAt), style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
          ],
        ),
      ),
    );
  }
}
