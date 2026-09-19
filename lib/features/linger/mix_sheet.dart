import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/mix_repository.dart';
import '../../core/database/dictionary_db.dart';
import '../../core/database/user_db.dart';
import '../../core/database/user_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/chips.dart';
import '../../shared/widgets/fields.dart';
import 'linger_rules.dart';
import 'queue_builder.dart';

/// The familiarity labels, HANDOFF 11.1, over the seen policy the data layer
/// stores.
String familiarityLabel(SeenPolicy p) => switch (p) {
  SeenPolicy.unseenOnly => 'New only',
  SeenPolicy.light => 'A few familiar',
  SeenPolicy.mixed => 'Half familiar',
  SeenPolicy.reviewOnly => 'Familiar only',
};

String presetDescription(String name) => switch (name) {
  MixRepository.presetAnything => "Everything in the dictionary's shelves, in no particular order.",
  MixRepository.presetQuickWins => 'Short words, short definitions, nothing rare.',
  MixRepository.presetStretchMe => 'Longer words you are unlikely to know yet.',
  MixRepository.presetReview => 'Only words you have already seen.',
  _ => '',
};

/// What the sheet hands back: the mix to play (a saved one by id, or an
/// unsaved selection).
class MixChoice {
  const MixChoice({this.mixId, this.sources, this.policy});

  final int? mixId;
  final List<String>? sources;
  final SeenPolicy? policy;
}

/// HANDOFF 11.2, the mix sheet. Presets in a row, HOW FAMILIAR, sources by
/// band, topic, then the user's own lists, a live pool readout, "Mull these"
/// and, once the selection differs from the active preset, "Save as mix".
Future<MixChoice?> showMixSheet(BuildContext context, {required MixSpec active}) {
  return showAppBottomSheet<MixChoice>(
    context: context,
    title: 'What you are mulling',
    expand: true,
    builder: (BuildContext ctx) => _MixSheet(active: active),
  );
}

class _MixSheet extends ConsumerStatefulWidget {
  const _MixSheet({required this.active});

  final MixSpec active;

  @override
  ConsumerState<_MixSheet> createState() => _MixSheetState();
}

class _MixSheetState extends ConsumerState<_MixSheet> {
  late Set<String> _sources = widget.active.sources.toSet();
  late SeenPolicy _policy = widget.active.seenPolicy;
  int? _presetId;
  int _total = 0;
  int _new = 0;
  List<String> _wrongQuizKeys = <String>[];
  int _quizCount = 0;

  @override
  void initState() {
    super.initState();
    _presetId = widget.active.isPreset ? widget.active.id : null;
    unawaited(_recount());
    unawaited(_loadQuizStats());
  }

  Future<void> _loadQuizStats() async {
    final UserRepository user = ref.read(userRepositoryProvider);
    final List<String> wrong = await user.wrongQuizKeys();
    final int quizzes = await user.completedQuizCount();
    if (mounted) {
      setState(() {
        _wrongQuizKeys = wrong;
        _quizCount = quizzes;
      });
    }
  }

  Future<void> _recount() async {
    final List<String> keys = await ref.read(queueBuilderProvider).poolFor(_sources.toList());
    final Map<String, SeenWord> seen = await ref.read(userRepositoryProvider).seenStates(keys);
    if (mounted) {
      setState(() {
        _total = keys.length;
        _new = keys.length - seen.length;
      });
    }
  }

  void _pickPreset(MixSpec p) {
    setState(() {
      _presetId = p.id;
      _sources = p.sources.toSet();
      _policy = p.seenPolicy;
    });
    unawaited(_recount());
  }

  void _toggleSource(String slug) {
    setState(() {
      _presetId = null;
      _sources.contains(slug) ? _sources.remove(slug) : _sources.add(slug);
    });
    unawaited(_recount());
  }

  bool get _dirty {
    final MixSpec a = widget.active;
    return _presetId == null && (a.sources.toSet() != _sources || a.seenPolicy != _policy || !a.isPreset && false);
  }

  Future<void> _save() async {
    final TextEditingController name = TextEditingController();
    final bool? ok = await showAppBottomSheet<bool>(
      context: context,
      title: 'Save as mix',
      builder: (BuildContext ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LabelledField(label: 'Name', controller: name, autofocus: true, hint: 'Before the viva'),
          const SizedBox(height: Space.xl),
          AppButton(label: 'Save', fullWidth: true, onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty || !mounted) return;
    final int id = await ref.read(mixRepositoryProvider).create(
      name: name.text.trim(),
      sources: _sources.toList(),
      seenPolicy: _policy,
    );
    if (mounted) Navigator.of(context).pop(MixChoice(mixId: id));
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final List<MixSpec> mixes = ref.watch(mixesProvider).value ?? const <MixSpec>[];
    final List<Collection> collections = ref.watch(mixSourceCollectionsProvider);
    final List<MixSpec> presets = mixes.where((MixSpec m) => m.isPreset).toList();
    final List<MixSpec> saved = mixes.where((MixSpec m) => !m.isPreset).toList();
    final MixSpec? preset = _presetId == null ? null : mixes.where((MixSpec m) => m.id == _presetId).firstOrNull;

    Widget sectionLabel(String t) => Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.row),
      child: Text(t, style: MullType.sectionHeader.copyWith(color: c.onSurfaceVariant)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: Space.sm,
            children: <Widget>[
              for (final MixSpec p in <MixSpec>[...presets, ...saved])
                PillChip(label: p.name, selected: _presetId == p.id, onTap: () => _pickPreset(p)),
            ],
          ),
        ),
        if (preset != null) ...<Widget>[
          const SizedBox(height: Space.md),
          Text(
            preset.isPreset ? presetDescription(preset.name) : '${plural(preset.sources.length, 'source')} · ${familiarityLabel(preset.seenPolicy).toLowerCase()}',
            style: MullType.note.copyWith(color: c.onSurfaceVariant),
          ),
        ],
        sectionLabel('HOW FAMILIAR'),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: <Widget>[
            for (final SeenPolicy p in SeenPolicy.values)
              PillChip(
                label: familiarityLabel(p),
                selected: _policy == p,
                onTap: () => setState(() {
                  _policy = p;
                  if (preset != null && preset.seenPolicy != p) _presetId = null;
                }),
              ),
          ],
        ),
        if (!(preset?.includeBookmarkedOnly ?? false)) ...<Widget>[
          sectionLabel('SOURCES · BANDS'),
          for (final Collection col in collections.where((Collection x) => x.kind == 'band'))
            _SourceRow.collection(col, checked: _sources.contains(col.slug), onTap: () => _toggleSource(col.slug)),
          sectionLabel('SOURCES · TOPICS'),
          for (final Collection col in collections.where((Collection x) => x.kind == 'topic'))
            _SourceRow.collection(col, checked: _sources.contains(col.slug), onTap: () => _toggleSource(col.slug)),
          sectionLabel('SOURCES · YOUR SHELVES'),
          for (final Collection col in collections.where((Collection x) => x.isUsers))
            _SourceRow.collection(col, checked: _sources.contains(col.slug), onTap: () => _toggleSource(col.slug)),
          // HANDOFF 20: present even when empty, so the user learns where it fills from.
          _SourceRow(
            title: 'Words I got wrong',
            count: _wrongQuizKeys.length,
            subtitle: _wrongQuizKeys.isEmpty
                ? 'nothing here yet · words you miss in a quiz land here'
                : 'from ${plural(_quizCount, 'quiz', 'quizzes')} · right twice running and a word leaves',
            checked: _sources.contains(QueueBuilder.wrongQuizSource),
            onTap: _wrongQuizKeys.isEmpty ? null : () => _toggleSource(QueueBuilder.wrongQuizSource),
          ),
        ],
        const SizedBox(height: Space.xl),
        if (_total < 50 && !(preset?.includeBookmarkedOnly ?? false)) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(
              color: c.surfaceContainer,
              borderRadius: Radii.cardR,
              border: Border.all(color: c.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${preset?.name ?? 'This mix'} has ${grouped(_total)} words', style: MullType.titleMedium.copyWith(color: c.onSurface)),
                const SizedBox(height: 4),
                Text('It will end quickly. Add another source if you would rather it ran on.', style: MullType.note.copyWith(color: c.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
        ],
        Text(
          '${grouped(_total)} words · ${grouped(_new)} new to you',
          style: MullType.monoTabular.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: Space.md),
        AppButton(
          label: 'Mull these',
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(
            _presetId != null
                ? MixChoice(mixId: _presetId)
                : MixChoice(sources: _sources.toList(), policy: _policy),
          ),
        ),
        if (_dirty) ...<Widget>[
          const SizedBox(height: Space.sm),
          AppButton(label: 'Save as mix', type: AppButtonType.outlined, fullWidth: true, onPressed: _save),
        ],
        const SizedBox(height: Space.lg),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.title,
    required this.count,
    required this.checked,
    required this.onTap,
    this.subtitle,
  });

  _SourceRow.collection(
    Collection collection, {
    required this.checked,
    required this.onTap,
  }) : title = collection.title,
       count = collection.wordCount,
       subtitle = null;

  final String title;
  final int count;
  final String? subtitle;
  final bool checked;

  /// Null renders the row muted and unselectable (an empty source).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final bool enabled = onTap != null;
    return Semantics(
      checked: checked,
      enabled: enabled,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.thumbR,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
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
                  border: Border.all(
                    color: checked ? c.primary : (enabled ? c.outline : c.divider),
                    width: 1.5,
                  ),
                ),
                child: checked ? Icon(Icons.check_rounded, size: 15, color: c.onPrimary) : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: MullType.titleMedium.copyWith(color: enabled ? c.onSurface : c.onSurfaceMuted),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted)),
                  ],
                ),
              ),
              Text(
                grouped(count),
                style: MullType.monoLabel.copyWith(color: enabled ? c.onSurfaceVariant : c.onSurfaceMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
