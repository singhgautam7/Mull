import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/user_db.dart';
import '../../core/motion/pressable.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/shelf_icons.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/fields.dart';
import '../../shared/widgets/icon_color_picker_sheet.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/shelf_icon.dart';

const int _nameMax = 80;
const int _noteMax = 500;

/// The fade where the form ends above the button.
const double _fade = 24;

/// Opens the shelf editor: new when [slug] is null, else edit. On create the
/// editor replaces itself with the new shelf when [openAfterCreate], and
/// otherwise pops with its slug. Edit pops with the slug. Null when backed out
/// (or when it went on to the new shelf).
Future<String?> openShelfEditor(BuildContext context, {String? slug, bool openAfterCreate = true}) {
  final String path = slug == null ? Routes.newShelf : Routes.editShelf(slug);
  return context.push<String?>(path, extra: openAfterCreate);
}

/// Create or edit a user shelf, full screen (Kuber's add or edit category
/// screen). `slug == null` creates.
class ShelfEditScreen extends ConsumerStatefulWidget {
  const ShelfEditScreen({this.slug, super.key});

  final String? slug;

  @override
  ConsumerState<ShelfEditScreen> createState() => _ShelfEditScreenState();
}

class _ShelfEditScreenState extends ConsumerState<ShelfEditScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String? _icon;
  int? _color;
  bool _loaded = false;
  bool _saving = false;

  bool get _editing => widget.slug != null;
  bool get _canSave => !_saving && _name.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_editing) {
      unawaited(_load());
    } else {
      _loaded = true;
    }
  }

  Future<void> _load() async {
    final UserCollection? row = await ref.read(userRepositoryProvider).collection(widget.slug!);
    if (!mounted) return;
    // The shelf went while the editor opened (deleted elsewhere): nothing
    // to edit, so leave rather than show a blank form whose save matches
    // no row.
    if (row == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      {
        _name.text = row.name;
        _note.text = row.note ?? '';
        _icon = row.icon;
        _color = row.color;
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    FocusScope.of(context).unfocus();
    final ({String? icon, int? color})? r = await showIconColorPicker(context: context, icon: _icon, color: _color);
    if (r != null && mounted) {
      setState(() {
        _icon = r.icon;
        _color = r.color;
      });
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final repo = ref.read(userRepositoryProvider);
    final String name = _name.text.trim();
    final String? note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final String slug;
    try {
      if (_editing) {
        slug = widget.slug!;
        await repo.updateCollection(slug, name: name, color: _color, icon: _icon, note: note);
      } else {
        slug = await repo.createCollection(name, color: _color, icon: _icon, note: note);
      }
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackbar.info(context, 'Could not save the shelf');
      }
      return;
    }
    if (!mounted) return;
    // openShelfEditor passes `openAfterCreate` as the route's extra.
    if (!_editing && GoRouterState.of(context).extra != false) {
      context.pushReplacement(Routes.collection(slug));
    } else {
      context.pop(slug);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Scaffold(
      body: HeaderPage(
        header: AppHeader(
          title: _editing ? 'Edit shelf' : 'New shelf',
          onBack: () => unawaited(Navigator.of(context).maybePop()),
          backIcon: Icons.close_rounded,
          backLabel: 'Close',
        ),
        body: !_loaded
            ? const SizedBox.shrink()
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).unfocus(),
                // Kuber's `KuberFormScaffold`: the button sits in the layout, not over
                // the form, so a focused field scrolls to just above it and it rides
                // on the keyboard. The fade at the end of the list is all there is
                // between them.
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: Stack(
                        children: <Widget>[
                          ListView(
                            padding: const EdgeInsets.fromLTRB(Space.screen, Space.xs, Space.screen, _fade),
                            children: <Widget>[
                              HeaderPage.gap(),
                              LabelledField(
                                label: 'Name',
                                controller: _name,
                                autofocus: !_editing,
                                hint: 'Example: Viva Words',
                                onChanged: (String v) {
                                  if (v.length > _nameMax) {
                                    _name.text = v.substring(0, _nameMax);
                                    _name.selection = const TextSelection.collapsed(offset: _nameMax);
                                  }
                                  setState(() {});
                                },
                              ),
                              const SizedBox(height: Space.lg),
                              const _FieldLabel('Icon & colour'),
                              _PickerRow(icon: _icon, color: _color, onTap: _pick),
                              const SizedBox(height: Space.lg),
                              _NoteField(controller: _note),
                              if (!_editing) ...<Widget>[
                                const SizedBox(height: Space.md),
                                const InfoNote('You can add words or phrases to this shelf once you have created it.'),
                              ],
                            ],
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: _fade,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: <Color>[c.surface.withValues(alpha: 0), c.surface],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      // On top of the system bar's inset, not instead of it.
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.lg),
                        child: AppButton(
                          label: _editing ? 'Save' : 'Create shelf',
                          fullWidth: true,
                          onPressed: _canSave ? _save : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// The title over a field, as [LabelledField] draws its own.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Text(
      label.toUpperCase(),
      style: MullType.sectionHeader.copyWith(color: context.colors.onSurfaceVariant),
    ),
  );
}

/// Kuber's `KuberPickerRow`: 72dp, surface-container card, 1dp outline.
class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.icon, required this.color, required this.onTap});

  final String? icon;
  final int? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final String colour = MullColors.tagName(color);
    return Pressable(
      kind: PressKind.card,
      child: Material(
        color: c.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.cardR,
          side: BorderSide(color: c.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.md, Space.sm),
            child: Row(
              spacing: Space.lg,
              children: <Widget>[
                ShelfIcon(icon: icon, color: color),
                Expanded(
                  child: Text(
                    '${ShelfIcons.labelOf(icon)} · $colour',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MullType.titleMedium.copyWith(color: c.onSurface),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: c.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `NOTE`, a few lines. Same box as [LabelledField], which is single line.
class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _FieldLabel('Note (optional)'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: Radii.thumbR,
            border: Border.all(color: c.outline),
          ),
          child: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            maxLength: _noteMax,
            buildCounter: (BuildContext _, {required int currentLength, required bool isFocused, int? maxLength}) =>
                null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: MullType.body.copyWith(color: c.onSurface),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              hintText: 'What this shelf is for',
              hintStyle: MullType.body.copyWith(color: c.onSurfaceMuted),
            ),
          ),
        ),
      ],
    );
  }
}
