import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/database/dictionary_db.dart';
import '../../core/database/user_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/selectable_card.dart';

enum ShelfExportFormat { csv, pdf }

Future<void> showShelfExportSheet(
  BuildContext context, {
  required String slug,
  required String shelfTitle,
}) {
  return showAppBottomSheet<void>(
    context: context,
    title: 'Export this shelf',
    builder: (BuildContext ctx) => _ShelfExportSheet(
      slug: slug,
      shelfTitle: shelfTitle,
    ),
  );
}

class _ShelfExportSheet extends ConsumerStatefulWidget {
  const _ShelfExportSheet({
    required this.slug,
    required this.shelfTitle,
  });

  final String slug;
  final String shelfTitle;

  @override
  ConsumerState<_ShelfExportSheet> createState() => _ShelfExportSheetState();
}

class _ShelfExportSheetState extends ConsumerState<_ShelfExportSheet> {
  ShelfExportFormat _format = ShelfExportFormat.csv;
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final UserRepository userRepo = ref.read(userRepositoryProvider);
      final DictionaryDb dict = ref.read(dictProvider);
      final List<String> keys = ref.read(collectionKeysProvider)[widget.slug] ?? const <String>[];
      final List<DictionaryWord> words = dict.byKeys(keys);
      final Map<String, String> notes = await userRepo.allNotes();
      final Map<String, DateTime> added = await userRepo.collectionAddedDates(
        widget.slug,
      );

      final String stamp = DateTime.now().toIso8601String().substring(0, 10);
      final String safeSlug = widget.slug.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final Directory dir = await getTemporaryDirectory();

      final File file;
      if (_format == ShelfExportFormat.csv) {
        final List<List<dynamic>> rows = <List<dynamic>>[
          <String>['word', 'pos', 'definition', 'example', 'date_added', 'note'],
          for (final DictionaryWord w in words)
            <dynamic>[
              w.headword,
              w.pos,
              w.definitionShort,
              dict.examples(w.wordKey).firstOrNull ?? '',
              added[w.wordKey]?.toIso8601String().substring(0, 10) ?? '',
              notes[w.wordKey] ?? '',
            ],
        ];
        final String csv = const ListToCsvConverter().convert(rows);
        file = File(p.join(dir.path, '$safeSlug-$stamp.csv'));
        await file.writeAsString(csv);
      } else {
        final pw.Document pdf = pw.Document();
        const double margin = 18 * PdfPageFormat.mm;

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.copyWith(
              marginTop: margin,
              marginBottom: margin,
              marginLeft: margin,
              marginRight: margin,
            ),
            header: (pw.Context ctx) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(width: 1.5, color: PdfColors.black),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: <pw.Widget>[
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text(
                        widget.shelfTitle,
                        style: pw.TextStyle(
                          fontSize: 23,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        '${words.length} words · exported $stamp',
                        style: const pw.TextStyle(fontSize: 10.5),
                      ),
                    ],
                  ),
                  pw.Text(
                    'MULL',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            footer: (pw.Context ctx) => pw.Container(
              margin: const pw.EdgeInsets.only(top: 12),
              padding: const pw.EdgeInsets.only(top: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(width: 1, color: PdfColors.black),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: <pw.Widget>[
                  pw.Text(
                    widget.shelfTitle,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    '${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            build: (pw.Context ctx) => <pw.Widget>[
              for (int i = 0; i < words.length; i++) ...<pw.Widget>[
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: <pw.Widget>[
                          pw.Text(
                            words[i].headword,
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            words[i].pos,
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        words[i].definitionShort,
                        style: const pw.TextStyle(fontSize: 13, lineSpacing: 1.5),
                      ),
                      if (dict.examples(words[i].wordKey).isNotEmpty) ...<pw.Widget>[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          dict.examples(words[i].wordKey).first,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontStyle: pw.FontStyle.italic,
                            color: const PdfColor.fromInt(0xFF555555),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (i < words.length - 1)
                  pw.Container(
                    height: 1,
                    color: PdfColors.grey300,
                  ),
              ],
            ],
          ),
        );

        file = File(p.join(dir.path, '$safeSlug-$stamp.pdf'));
        await file.writeAsBytes(await pdf.save());
      }

      if (mounted) Navigator.of(context).pop();
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          text: 'Mull shelf export: ${widget.shelfTitle}',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MullColors c = context.colors;
    final List<String> keys = ref.watch(collectionKeysProvider)[widget.slug] ?? const <String>[];
    final int wordCount = keys.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '${widget.shelfTitle} · $wordCount words',
          style: MullType.monoLabel.copyWith(color: c.onSurfaceMuted),
        ),
        const SizedBox(height: Space.lg),
        SelectableCard(
          title: 'CSV',
          description: 'Word, definition and example, one row each. Opens in Excel, Sheets or Numbers, and imports back into Mull as it is.',
          selected: _format == ShelfExportFormat.csv,
          onTap: () => setState(() => _format = ShelfExportFormat.csv),
        ),
        const SizedBox(height: Space.sm),
        SelectableCard(
          title: 'PDF',
          description: 'A printable list in one column, for reading or marking up on paper. A4, 12pt.',
          selected: _format == ShelfExportFormat.pdf,
          onTap: () => setState(() => _format = ShelfExportFormat.pdf),
        ),
        const SizedBox(height: Space.xl),
        AppButton(
          label: 'Export',
          fullWidth: true,
          onPressed: _busy || wordCount == 0 ? null : _export,
        ),
        const SizedBox(height: Space.sm),
        AppButton(
          label: 'Cancel',
          type: AppButtonType.secondary,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
