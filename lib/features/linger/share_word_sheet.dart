import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/wallpaper_seed.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/chips.dart';
import '../settings/settings_controller.dart';
import 'share_image_builder.dart';

/// Opens the share bottom sheet for a word entry, offering an image or text.
Future<void> showShareWordSheet(
  BuildContext context, {
  required DictionaryWord word,
  String? example,
}) {
  return showAppBottomSheet<void>(
    context: context,
    showClose: true,
    builder: (BuildContext ctx) => _ShareSheet(word: word, example: example),
  );
}

enum _ShareMode { image, text }

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.word, this.example});

  final DictionaryWord word;
  final String? example;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  _ShareMode _mode = _ShareMode.image;
  final GlobalKey _boundaryKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final BuildContext? boundaryContext = _boundaryKey.currentContext;
      if (boundaryContext == null) return;
      final RenderRepaintBoundary boundary =
          boundaryContext.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(
        pixelRatio: ShareImageCard.pixelRatio,
      );
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = p.join(
        tempDir.path,
        'mull-${widget.word.headwordNorm}.png',
      );
      final File file = File(filePath);
      await file.writeAsBytes(pngBytes, flush: true);

      if (!mounted) return;
      Navigator.of(context).pop();
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'image/png')],
          text: '${widget.word.headword}: ${widget.word.definitionShort}',
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _shareText() async {
    Navigator.of(context).pop();
    final String text = widget.example != null && widget.example!.isNotEmpty
        ? '${widget.word.headword} (${widget.word.pos})\n${widget.word.definitionFull}\n\n"${widget.example}"'
        : '${widget.word.headword} (${widget.word.pos})\n${widget.word.definitionFull}';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final AppSettings s = ref.watch(settingsProvider);
    final Color? seed = s.dynamicColor
        ? ref.watch(wallpaperSeedProvider).value
        : null;
    final MullColors imageColors = ShareImageCard.shareColors(
      c,
      seed == null ? s.family : ThemeFamily.fromSeed(seed),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentedToggle<_ShareMode>(
          options: const <(_ShareMode, String)>[
            (_ShareMode.image, 'As an image'),
            (_ShareMode.text, 'As text'),
          ],
          selected: _mode,
          onChanged: (_ShareMode mode) => setState(() => _mode = mode),
        ),
        const SizedBox(height: Space.md),
        Text(
          _mode == _ShareMode.image
              ? '1080 × 1080 PNG · current theme'
              : 'Text format · simple and compact',
          style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Space.lg),
        if (_mode == _ShareMode.image) ...<Widget>[
          // Preview scaled down to fit
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: c.shadow,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: FittedBox(
                fit: BoxFit.contain,
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: ShareImageCard(
                    word: widget.word,
                    example: widget.example,
                    colors: imageColors,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.xl),
          AppButton(
            label: _sharing ? 'Preparing...' : 'Share',
            fullWidth: true,
            onPressed: _sharing ? null : _shareImage,
          ),
        ] else ...<Widget>[
          Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(
              color: c.surfaceContainerHigh,
              borderRadius: Radii.cardR,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.word.headword,
                  style: MullType.headwordM.copyWith(color: c.onSurface),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  widget.word.definitionFull,
                  style: MullType.body.copyWith(color: c.onSurfaceVariant),
                ),
                if (widget.example != null &&
                    widget.example!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Space.sm),
                  Text(
                    widget.example!,
                    style: MullType.note.copyWith(
                      color: c.onSurfaceMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          AppButton(
            label: 'Share',
            fullWidth: true,
            onPressed: _shareText,
          ),
        ],
        const SizedBox(height: Space.sm),
      ],
    );
  }
}
