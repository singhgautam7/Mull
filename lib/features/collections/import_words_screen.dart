import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/user_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/dashed_border.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/states.dart';
import 'import_table.dart';

enum _Step { input, columns, review }

/// HANDOFF 16.4 to 16.6: paste or pick a table, map its columns, review the
/// matches, then create the shelf (or add to [targetShelfSlug]). Nothing is
/// written before the last button, and the import never ends on a toast.
class ImportWordsScreen extends ConsumerStatefulWidget {
  const ImportWordsScreen({this.targetShelfSlug, super.key});

  final String? targetShelfSlug;

  @override
  ConsumerState<ImportWordsScreen> createState() => _ImportWordsScreenState();
}

class _ImportWordsScreenState extends ConsumerState<ImportWordsScreen> {
  _Step _step = _Step.input;
  String _pastedText = '';
  ImportTable _table = ImportTable.empty;
  Map<int, ColumnRole> _roles = <int, ColumnRole>{};

  List<WordMatch> _matches = const <WordMatch>[];
  final Set<int> _accepted = <int>{};
  final Set<int> _rejected = <int>{};
  bool _matchedExpanded = false;
  final TextEditingController _shelfName = TextEditingController();
  bool _submitting = false;
  bool _matching = false;

  @override
  void dispose() {
    _shelfName.dispose();
    super.dispose();
  }

  void _load(String raw) {
    final ImportTable table = ImportTable.parse(raw);
    setState(() {
      _pastedText = raw.trim();
      _table = table;
      _roles = table.defaultRoles;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData('text/plain');
    if (data?.text != null) _load(data!.text!);
  }

  Future<void> _pickFile() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['csv', 'tsv', 'txt'],
    );
    if (files.isEmpty) return;
    final PlatformFile file = files.single;
    _load(utf8.decode(await file.readAsBytes()));
    final String base = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    if (base.isNotEmpty && _shelfName.text.isEmpty) _shelfName.text = base;
  }

  Future<void> _runMatching() async {
    if (_matching) return;
    setState(() => _matching = true);
    final List<WordMatch> matches = await ref
        .read(dictProvider)
        .matchWords(_table.records(_roles));
    if (!mounted) return;
    setState(() {
      _matching = false;
      _matches = matches;
      _accepted.clear();
      _rejected.clear();
      _step = _Step.review;
    });
  }

  List<String> get _keysToAdd => <String>[
    for (final (int i, WordMatch m) in _matches.indexed)
      if (m.isMatched || (m.isNearMatch && _accepted.contains(i)))
        m.word!.wordKey,
  ];

  Future<void> _createShelf() async {
    if (_submitting) return;
    final List<String> keys = _keysToAdd;
    if (keys.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final UserRepository user = ref.read(userRepositoryProvider);
      final String name = _shelfName.text.trim();
      final String slug =
          widget.targetShelfSlug ??
          await user.createCollection(name.isEmpty ? 'Imported shelf' : name);
      await user.addAllToCollection(slug, keys);
      if (!mounted) return;
      if (widget.targetShelfSlug != null) {
        context.pop();
      } else {
        context.pushReplacement(Routes.collection(slug));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _back() {
    switch (_step) {
      case _Step.input:
        context.pop();
      case _Step.columns:
        setState(() => _step = _Step.input);
      case _Step.review:
        setState(
          () => _step = _table.columnCount > 1 ? _Step.columns : _Step.input,
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppHeader(
            title: switch (_step) {
              _Step.input => 'Import words',
              _Step.columns => 'Columns',
              _Step.review => 'Review the import',
            },
            onBack: _back,
          ),
          LoadingHairline(visible: _matching),
          Expanded(
            child: switch (_step) {
              _Step.input => _InputStep(
                pastedText: _pastedText,
                table: _table,
                onPaste: _pasteFromClipboard,
                onPickFile: _pickFile,
                onClear: () => _load(''),
                onContinue: _table.columnCount > 1
                    ? () => setState(() => _step = _Step.columns)
                    : _runMatching,
              ),
              _Step.columns => _ColumnsStep(
                table: _table,
                roles: _roles,
                onRole: (int column, ColumnRole role) => setState(() {
                  if (role == ColumnRole.word) {
                    // Only one column holds the words.
                    _roles.updateAll(
                      (_, ColumnRole r) =>
                          r == ColumnRole.word ? ColumnRole.ignore : r,
                    );
                  }
                  _roles[column] = role;
                }),
                onContinue: _runMatching,
              ),
              _Step.review => _buildReview(context),
            },
          ),
        ],
      ),
    ),
  );

  Widget _buildReview(BuildContext context) {
    final MullColors c = context.colors;
    final List<WordMatch> matched = _matches
        .where((WordMatch m) => m.isMatched)
        .toList();
    final List<(int, WordMatch)> near = <(int, WordMatch)>[
      for (final (int i, WordMatch m) in _matches.indexed)
        if (m.isNearMatch) (i, m),
    ];
    final List<String> notFound = <String>[
      for (final WordMatch m in _matches)
        if (m.isNotFound) m.rawWord,
    ];
    final int total = _keysToAdd.length;
    final bool mostlyFailed = _matches.length >= 5 && total < _matches.length / 2;

    return ListView(
      padding: const EdgeInsets.all(Space.screen),
      children: <Widget>[
        Text(
          '${plural(_matches.length, 'row')} · ${matched.length} matched · ${near.length} near matches · ${notFound.length} not found',
          style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: Space.lg),
        if (near.isEmpty && notFound.isEmpty && matched.isNotEmpty) ...<Widget>[
          _Card(
            tinted: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'All ${plural(matched.length, 'word')} matched',
                  style: MullType.titleMedium.copyWith(
                    color: c.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  'Mull had every word in your table. Nothing was dropped and nothing needs a decision.',
                  style: MullType.note.copyWith(color: c.onPrimaryContainer),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
        ],
        if (mostlyFailed) ...<Widget>[
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Most of this table is not in Mull',
                  style: MullType.titleMedium.copyWith(color: c.onSurface),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  "Mull's learning set is about 7,000 curated words, not all of English. If your table is technical terms or names, most of it will not be here.",
                  style: MullType.note.copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
        ],
        if (matched.isNotEmpty) ...<Widget>[
          InkWell(
            onTap: () => setState(() => _matchedExpanded = !_matchedExpanded),
            borderRadius: Radii.cardR,
            child: _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Matched · ${matched.length}',
                        style: MullType.titleMedium.copyWith(
                          color: c.onSurface,
                        ),
                      ),
                      Icon(
                        _matchedExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: c.onSurfaceVariant,
                      ),
                    ],
                  ),
                  Text(
                    _matchedExpanded
                        ? 'going on the shelf as they are'
                        : 'going on the shelf as they are · tap to read through them',
                    style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                  ),
                  if (_matchedExpanded) ...<Widget>[
                    const SizedBox(height: Space.md),
                    for (final WordMatch m in matched)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: Space.xs),
                        child: Text(
                          '${m.word!.headword} · ${posLabel(m.word!.pos)} · ${m.word!.definitionShort}',
                          style: MullType.body.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.md),
        ],
        if (near.isNotEmpty) ...<Widget>[
          SectionHeader(
            label: 'Near matches · ${near.length}',
            inset: false,
            trailing: AppButton(
              label: 'Accept all',
              type: AppButtonType.secondary,
              compact: true,
              onPressed: () => setState(() {
                for (final (int i, _) in near) {
                  _accepted.add(i);
                  _rejected.remove(i);
                }
              }),
            ),
          ),
          Text(
            'Mull has a close word for these. Take it or leave the row out.',
            style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
          ),
          const SizedBox(height: Space.sm),
          for (final (int i, WordMatch m) in near) ...<Widget>[
            _NearMatchCard(
              raw: m.rawWord,
              pastedDefinition: m.pastedDefinition,
              word: m.word!,
              accepted: _accepted.contains(i),
              rejected: _rejected.contains(i),
              onAccept: () => setState(() {
                _accepted.add(i);
                _rejected.remove(i);
              }),
              onReject: () => setState(() {
                _rejected.add(i);
                _accepted.remove(i);
              }),
              onUndo: () => setState(() {
                _accepted.remove(i);
                _rejected.remove(i);
              }),
            ),
            const SizedBox(height: Space.xs),
          ],
          const SizedBox(height: Space.md),
        ],
        if (notFound.isNotEmpty) ...<Widget>[
          SectionHeader(
            label: 'Not found · ${notFound.length}',
            inset: false,
            trailing: AppButton(
              label: 'Copy the list',
              type: AppButtonType.secondary,
              compact: true,
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: notFound.join('\n')),
                );
                if (context.mounted) {
                  AppSnackbar.info(context, 'Copied ${plural(notFound.length, 'word')}');
                }
              },
            ),
          ),
          Text(
            "Not in Mull's dictionary, so nothing was added for these. The list is here in full so you can see exactly what did not make it.",
            style: MullType.note.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: Space.sm),
          _Card(
            child: Text(
              notFound.join('\n'),
              style: MullType.monoLabel.copyWith(
                color: c.onSurfaceMuted,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
        ],
        if (widget.targetShelfSlug == null) ...<Widget>[
          LabelledField(
            label: 'SHELF NAME',
            controller: _shelfName,
            hint: 'e.g. History terms',
          ),
          const SizedBox(height: Space.xl),
        ],
        AppButton(
          label: widget.targetShelfSlug == null
              ? 'Create shelf with ${plural(total, 'word')}'
              : 'Add ${plural(total, 'word')} to the shelf',
          fullWidth: true,
          onPressed: _submitting || total == 0 ? null : _createShelf,
        ),
        if (mostlyFailed) ...<Widget>[
          const SizedBox(height: Space.sm),
          AppButton(
            label: 'Discard this import',
            type: AppButtonType.outlined,
            fullWidth: true,
            onPressed: () => context.pop(),
          ),
        ],
      ],
    );
  }
}

class _InputStep extends StatelessWidget {
  const _InputStep({
    required this.pastedText,
    required this.table,
    required this.onPaste,
    required this.onPickFile,
    required this.onClear,
    required this.onContinue,
  });

  final String pastedText;
  final ImportTable table;
  final VoidCallback onPaste;
  final VoidCallback onPickFile;
  final VoidCallback onClear;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(Space.screen),
      children: <Widget>[
        Text(
          'Paste a table. Mull reads one word per row and works out the columns afterwards.',
          style: MullType.body.copyWith(color: c.onSurface),
        ),
        const SizedBox(height: Space.xs),
        Text(
          'Copy straight out of Notion, Google Sheets, Excel or a table on a web page. Tabs or commas, either way.',
          style: MullType.note.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: Space.lg),
        if (pastedText.isEmpty) ...<Widget>[
          CustomPaint(
            foregroundPainter: DashedBorderPainter(
              c.outline,
              radius: Radii.card,
            ),
            child: Container(
              height: 180,
              padding: const EdgeInsets.all(Space.md),
              decoration: BoxDecoration(
                color: c.surfaceContainer,
                borderRadius: Radii.cardR,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'word\tdefinition\texample\nserendipity\ta happy accident\ta moment of serendipity\nquixotic\tidealistic\ta quixotic venture',
                    style: MullType.monoLabel.copyWith(
                      color: c.onSurfaceMuted,
                      height: 1.8,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'A CSV Mull exported earlier comes back in whole, columns and all.',
                    style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
          AppButton(
            label: 'Paste from clipboard',
            fullWidth: true,
            onPressed: onPaste,
          ),
          const SizedBox(height: Space.md),
          Row(
            children: <Widget>[
              Expanded(child: Divider(color: c.divider)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: Text(
                  'OR',
                  style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                ),
              ),
              Expanded(child: Divider(color: c.divider)),
            ],
          ),
          const SizedBox(height: Space.md),
          AppButton(
            label: 'Pick a CSV file',
            type: AppButtonType.outlined,
            fullWidth: true,
            onPressed: onPickFile,
          ),
        ] else if (table.isEmpty) ...<Widget>[
          EmptyState(
            title: 'Nothing to import',
            message:
                'No rows were found in what you pasted. Mull needs one word per line, with tabs or commas between the columns.',
            actionLabel: 'Back to the paste box',
            onAction: onClear,
          ),
        ] else ...<Widget>[
          _Card(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Text(
                  pastedText,
                  style: MullType.monoLabel.copyWith(
                    color: c.onSurface,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${plural(table.rows.length, 'row')} · ${plural(table.columnCount, 'column')} detected',
                style: MullType.monoLabel.copyWith(color: c.onSurfaceVariant),
              ),
              AppButton(
                label: 'Clear',
                type: AppButtonType.secondary,
                compact: true,
                onPressed: onClear,
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Header rows are skipped automatically. Blank rows are ignored.',
            style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
          ),
          const SizedBox(height: Space.xl),
          AppButton(
            label: 'Continue',
            fullWidth: true,
            onPressed: onContinue,
          ),
        ],
      ],
    );
  }
}

class _ColumnsStep extends StatelessWidget {
  const _ColumnsStep({
    required this.table,
    required this.roles,
    required this.onRole,
    required this.onContinue,
  });

  final ImportTable table;
  final Map<int, ColumnRole> roles;
  final void Function(int column, ColumnRole role) onRole;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final bool hasWord = roles.values.contains(ColumnRole.word);
    return ListView(
      padding: const EdgeInsets.all(Space.screen),
      children: <Widget>[
        Text(
          'This is how Mull read your table.',
          style: MullType.body.copyWith(color: c.onSurface),
        ),
        const SizedBox(height: Space.xs),
        Text(
          "Imported words use Mull's own definitions. What you pasted is kept only for words Mull has no entry for.",
          style: MullType.note.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: Space.lg),
        if (!hasWord) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: c.dangerContainer,
              borderRadius: Radii.cardR,
            ),
            child: Text(
              'No column is set as the word. Pick the one holding the words themselves.',
              style: MullType.note.copyWith(color: c.onDangerContainer),
            ),
          ),
          const SizedBox(height: Space.md),
        ],
        for (int col = 0; col < table.columnCount; col++) ...<Widget>[
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(label: 'Column ${col + 1}', inset: false),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: <Widget>[
                    for (final ColumnRole r in ColumnRole.values)
                      PillChip(
                        label: switch (r) {
                          ColumnRole.word => 'Word',
                          ColumnRole.definition => 'Definition',
                          ColumnRole.example => 'Example',
                          ColumnRole.ignore => 'Ignore this column',
                        },
                        selected: roles[col] == r,
                        onTap: () => onRole(col, r),
                      ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                for (final List<String> row in table.rows.take(3))
                  Text(
                    col < row.length && row[col].isNotEmpty ? row[col] : '·',
                    style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.sm),
        ],
        const SizedBox(height: Space.lg),
        AppButton(
          label: 'Looks right, continue',
          fullWidth: true,
          onPressed: hasWord ? onContinue : null,
        ),
      ],
    );
  }
}

class _NearMatchCard extends StatelessWidget {
  const _NearMatchCard({
    required this.raw,
    required this.pastedDefinition,
    required this.word,
    required this.accepted,
    required this.rejected,
    required this.onAccept,
    required this.onReject,
    required this.onUndo,
  });

  final String raw;
  final String? pastedDefinition;
  final DictionaryWord word;
  final bool accepted;
  final bool rejected;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    if (accepted || rejected) {
      return _Card(
        child: Row(
          children: <Widget>[
            Text(raw, style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                accepted ? 'accepted · ${word.headword}' : 'left out',
                style: MullType.monoLabel.copyWith(
                  color: accepted ? c.success : c.onSurfaceMuted,
                ),
              ),
            ),
            AppButton(
              label: 'Undo',
              type: AppButtonType.secondary,
              compact: true,
              onPressed: onUndo,
            ),
          ],
        ),
      );
    }
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.sm,
            children: <Widget>[
              Text(
                raw,
                style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
              ),
              Icon(Icons.arrow_forward_rounded, size: 16, color: c.primary),
              Text(
                word.headword,
                style: MullType.titleMedium.copyWith(
                  fontSize: 16,
                  color: c.onSurface,
                ),
              ),
              Text(
                posLabel(word.pos),
                style: MullType.note.copyWith(
                  color: c.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            word.definitionShort,
            style: MullType.body.copyWith(color: c.onSurfaceVariant),
          ),
          if (pastedDefinition != null) ...<Widget>[
            const SizedBox(height: Space.xs),
            Text(
              'your table said: $pastedDefinition',
              style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: Space.sm),
          Row(
            spacing: Space.sm,
            children: <Widget>[
              AppButton(
                label: 'Use ${word.headword}',
                type: AppButtonType.secondary,
                onPressed: onAccept,
              ),
              AppButton(
                label: 'Leave out',
                type: AppButtonType.outlined,
                onPressed: onReject,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The outlined `surfaceContainer` card every group on these pages sits in.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.tinted = false});

  final Widget child;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: tinted ? c.primaryContainer : c.surfaceContainer,
        borderRadius: Radii.cardR,
        border: tinted ? null : Border.all(color: c.outline),
      ),
      child: child,
    );
  }
}
