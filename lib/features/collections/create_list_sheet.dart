import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/fields.dart';

/// Create sheet: name field, six colour swatches, Create. Creates a `user`
/// collection and returns its slug, so it appears wherever collections are
/// read: the Collections page, Home, the mix sheet.
Future<String?> showCreateListSheet(BuildContext context, {String? renameSlug, String? initialName, int? initialColor}) {
  return showAppBottomSheet<String>(
    context: context,
    title: renameSlug == null ? 'New list' : 'Rename list',
    builder: (BuildContext ctx) => _CreateListSheet(renameSlug: renameSlug, initialName: initialName, initialColor: initialColor),
  );
}

class _CreateListSheet extends ConsumerStatefulWidget {
  const _CreateListSheet({this.renameSlug, this.initialName, this.initialColor});

  final String? renameSlug;
  final String? initialName;
  final int? initialColor;

  @override
  ConsumerState<_CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends ConsumerState<_CreateListSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.initialName);
  int? _color;

  @override
  void initState() {
    super.initState();
    _color = widget.initialColor;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String name = _name.text.trim();
    if (name.isEmpty) return;
    final String slug;
    if (widget.renameSlug != null) {
      slug = widget.renameSlug!;
      await ref.read(userRepositoryProvider).renameCollection(slug, name);
      await ref.read(userRepositoryProvider).setCollectionColor(slug, _color);
    } else {
      slug = await ref.read(userRepositoryProvider).createCollection(name, color: _color);
    }
    if (mounted) Navigator.of(context).pop(slug);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LabelledField(
          label: 'Name',
          controller: _name,
          autofocus: true,
          hint: 'Words for the viva',
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: Space.lg),
        ColorSwatchRow(selected: _color, onChanged: (int? v) => setState(() => _color = v)),
        const SizedBox(height: Space.xl),
        AppButton(
          label: widget.renameSlug == null ? 'Create list' : 'Rename',
          fullWidth: true,
          onPressed: _name.text.trim().isEmpty ? null : _submit,
        ),
      ],
    );
  }
}
