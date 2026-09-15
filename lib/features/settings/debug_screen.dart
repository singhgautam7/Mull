import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/mix_repository.dart';
import '../../core/database/user_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/linger_background.dart';
import '../linger/queue_builder.dart';

/// Proves the data layer end to end. Not a real screen; it will be removed
/// when the feature UI lands.
///
/// Installs the DB, reports version and count, searches, opens a word,
/// bookmarks it, adds a note, and reads both back. After a hot restart the
/// bookmark and note checks report what was persisted by the previous run.
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _Check {
  _Check(this.label, this.detail, {required this.ok});

  final String label;
  final String detail;
  final bool ok;
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  final List<_Check> _checks = <_Check>[];
  bool _running = false;
  bool _linger = false;

  static const String _noteText = 'Written by the debug route.';

  Future<void> _run(DictionaryDb dict) async {
    setState(() {
      _running = true;
      _checks.clear();
    });
    final UserRepository user = ref.read(userRepositoryProvider);
    final MixRepository mixes = ref.read(mixRepositoryProvider);
    final QueueBuilder queue = ref.read(queueBuilderProvider);

    void add(String label, String detail, {required bool ok}) =>
        setState(() => _checks.add(_Check(label, detail, ok: ok)));

    add(
      'Dictionary installed',
      'version ${dict.version}, ${dict.entryCount} senses, '
          '${dict.headwordCount} headwords, ${dict.idiomCount} idioms',
      ok: dict.entryCount > 0,
    );

    final List<DictionaryWord> pool = dict.collectionWords('core');
    final DictionaryWord probe = pool.isEmpty ? dict.search('a').first : pool[pool.length ~/ 3];
    final Stopwatch sw = Stopwatch()..start();
    final List<DictionaryWord> results = dict.search(probe.headword.substring(0, 3));
    sw.stop();
    add(
      'Search',
      '"${probe.headword.substring(0, 3)}" gave ${results.length} results in ${sw.elapsedMicroseconds / 1000} ms',
      ok: results.isNotEmpty && sw.elapsedMilliseconds < 50,
    );

    final DictionaryWord? word = dict.byKey(probe.wordKey);
    final List<String> examples = dict.examples(probe.wordKey);
    add(
      'Open word',
      word == null
          ? 'no row for ${probe.wordKey}'
          : '${word.headword} (${word.pos}) ${word.ipa ?? ''}: ${word.definitionShort} '
                '[${examples.length} examples]',
      ok: word != null,
    );

    final bool wasBookmarked = await user.isBookmarked(probe.wordKey);
    if (!wasBookmarked) await user.toggleBookmark(probe.wordKey);
    add(
      'Bookmark',
      wasBookmarked
          ? 'already bookmarked from an earlier run (persisted)'
          : 'bookmarked ${probe.wordKey}',
      ok: await user.isBookmarked(probe.wordKey),
    );

    final String? existingNote = await user.note(probe.wordKey);
    if (existingNote == null) await user.putNote(probe.wordKey, _noteText);
    final String? readBack = await user.note(probe.wordKey);
    add(
      'Note',
      existingNote != null
          ? 'note read back from an earlier run: "$existingNote"'
          : 'wrote and read back: "$readBack"',
      ok: readBack == _noteText,
    );

    final List<MixSpec> all = await mixes.all();
    final MixSpec? active = await mixes.active();
    add(
      'Presets',
      '${all.where((MixSpec m) => m.isPreset).length} presets; active: ${active?.name} '
          '(${active?.sources.length} sources, ${active?.seenPolicy.name})',
      ok: all.where((MixSpec m) => m.isPreset).length == 4 && active != null,
    );

    if (active != null) {
      final List<String> keys = await queue.build(active);
      add(
        'Queue',
        '${keys.length} cards, ${keys.toSet().length} distinct: ${keys.take(4).join(', ')}',
        ok: keys.isNotEmpty && keys.length == keys.toSet().length,
      );
    }
    setState(() => _running = false);
  }

  Future<void> _reset() async {
    final UserRepository user = ref.read(userRepositoryProvider);
    for (final String k in await user.bookmarkedKeys()) {
      await user.putNote(k, '');
      await user.toggleBookmark(k);
    }
    setState(_checks.clear);
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final AsyncValue<DictionaryDb> dict = ref.watch(dictionaryProvider);
    return LingerBackground(
      active: _linger,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.screen,
              Space.lg,
              Space.screen,
              Space.bottomSafe,
            ),
            children: <Widget>[
              Text('Debug', style: MullType.headerTitle.copyWith(color: c.onSurface)),
              const SizedBox(height: Space.sm),
              Text(
                'DATA LAYER',
                style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant),
              ),
              const SizedBox(height: Space.md),
              switch (dict) {
                AsyncData<DictionaryDb>(:final DictionaryDb value) => Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: <Widget>[
                    FilledButton(
                      onPressed: _running ? null : () => unawaited(_run(value)),
                      child: const Text('Run checks'),
                    ),
                    OutlinedButton(
                      onPressed: _running ? null : () => unawaited(_reset()),
                      child: const Text('Reset user data'),
                    ),
                    OutlinedButton(
                      onPressed: () => setState(() => _linger = !_linger),
                      child: Text(_linger ? 'Leave Mull' : 'Enter Mull'),
                    ),
                  ],
                ),
                AsyncError<DictionaryDb>(:final Object error) => Text(
                  'Install failed: $error',
                  style: MullType.body.copyWith(color: c.danger),
                ),
                _ => Text(
                  'Installing the dictionary…',
                  style: MullType.body.copyWith(color: c.onSurfaceVariant),
                ),
              },
              const SizedBox(height: Space.section),
              for (final _Check ch in _checks)
                Container(
                  margin: const EdgeInsets.only(bottom: Space.row),
                  padding: const EdgeInsets.all(Space.lg),
                  decoration: BoxDecoration(
                    color: c.surfaceContainer,
                    borderRadius: Radii.cardR,
                    border: Border.all(color: c.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        spacing: Space.sm,
                        children: <Widget>[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ch.ok ? c.success : c.danger,
                            ),
                          ),
                          Text(
                            ch.label,
                            style: MullType.titleMedium.copyWith(color: c.onSurface),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        ch.detail,
                        style: MullType.note.copyWith(color: c.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
