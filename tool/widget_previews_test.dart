// Draws the launcher-picker previews for the two widgets to
// android/app/src/main/res/drawable-nodpi/, in Mull's default light palette,
// at the sizes the picker shows them: 4x1 for search, 4x2 for word of the
// day. Run: flutter test tool/widget_previews_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/theme/palette.dart';

void main() {
  const double scale = 3;

  setUpAll(() async {
    // The bundled typeface, or the test font draws text as blocks.
    final ByteData font = ByteData.sublistView(File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync());
    await (FontLoader('Instrument Sans')..addFont(Future<ByteData>.value(font))).load();
  });
  final MullColors c = ThemeFamily.mull.colors(Tone.light);

  Future<void> write(String name, Size dp, void Function(Canvas) draw) async {
    final ui.PictureRecorder rec = ui.PictureRecorder();
    final Canvas canvas = Canvas(rec, Rect.fromLTWH(0, 0, dp.width * scale, dp.height * scale));
    canvas.scale(scale);
    draw(canvas);
    final ui.Image img = await rec.endRecording().toImage((dp.width * scale).round(), (dp.height * scale).round());
    final ByteData? bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final File out = File('android/app/src/main/res/drawable-nodpi/$name.png');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(bytes!.buffer.asUint8List());
  }

  void panel(Canvas canvas, Size dp) {
    final RRect r = RRect.fromRectAndRadius(Rect.fromLTWH(0.5, 0.5, dp.width - 1, dp.height - 1), const Radius.circular(26));
    canvas.drawRRect(r, Paint()..color = c.surfaceContainer);
    canvas.drawRRect(r, Paint()..color = c.outline..style = PaintingStyle.stroke);
  }

  void text(Canvas canvas, String s, Offset at, double size, Color color, {FontWeight weight = FontWeight.w400, double maxWidth = 400}) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: 'Instrument Sans', fontSize: size, color: color, fontWeight: weight, fontVariations: <FontVariation>[FontVariation('wght', weight == FontWeight.w700 ? 600 : 400)])),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, at);
  }

  test('search widget preview', () async {
    const Size dp = Size(344, 60);
    await write('search_widget_preview', dp, (Canvas canvas) {
      // No panel: the pill and the buttons float on the wallpaper.
      const double y = 6;
      const double h = 48;
      final Paint stroke = Paint()..color = c.onSurfaceVariant..style = PaintingStyle.stroke..strokeWidth = 1.75..strokeCap = StrokeCap.round;
      // The field.
      final RRect field = RRect.fromRectAndRadius(const Rect.fromLTWH(8, y, 344 - 8 - 8 - 56 - 56, h), const Radius.circular(24));
      canvas.drawRRect(field, Paint()..color = c.surfaceContainer);
      canvas.drawRRect(field, Paint()..color = c.outline..style = PaintingStyle.stroke);
      canvas.drawCircle(const Offset(8 + 16 + 7.4, y + 24 - 1.6), 5.2, stroke);
      canvas.drawLine(const Offset(8 + 16 + 11.1, y + 24 + 2.1), const Offset(8 + 16 + 15.4, y + 24 + 6.4), stroke);
      text(canvas, 'Search Mull', const Offset(8 + 16 + 18 + 10, y + 14), 14, c.onSurfaceVariant);
      // The two buttons.
      final Paint glyph = Paint()..color = c.onPrimary..style = PaintingStyle.stroke..strokeWidth = 1.75;
      for (final (double x, bool shelves) in <(double, bool)>[(344 - 8 - 48 - 8 - 48, false), (344 - 8 - 48, true)]) {
        canvas.drawCircle(Offset(x + 24, y + 24), 24, Paint()..color = c.primary);
        if (!shelves) {
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 18, y + 16, 12, 16), const Radius.circular(4)), glyph);
        } else {
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 20, y + 14, 10, 14), const Radius.circular(3)), glyph);
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 16, y + 18, 10, 14), const Radius.circular(3)), Paint()..color = c.primary);
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 16, y + 18, 10, 14), const Radius.circular(3)), glyph);
        }
      }
    });
  });

  test('word of the day widget preview', () async {
    const Size dp = Size(344, 160);
    await write('word_of_day_widget_preview', dp, (Canvas canvas) {
      panel(canvas, dp);
      text(canvas, 'MULL · 2026-09-21', const Offset(16, 16), 11, c.onSurfaceVariant, weight: FontWeight.w700);
      text(canvas, 'serendipity', const Offset(16, 34), 30, c.onSurface, weight: FontWeight.w700);
      text(canvas, 'noun · known by 92%', const Offset(16, 76), 13, c.onSurfaceVariant);
      text(canvas, 'The phenomenon of making an unplanned, fortunate discovery through a combination of luck and insight.', const Offset(16, 100), 14.5, c.onSurfaceVariant, maxWidth: 312);
    });
  });
}
