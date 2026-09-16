@Tags(<String>['tool'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Draws the launcher icon from the mockup's icon board (pass 03, book +
/// bookmark + /m/) and writes the PNGs `flutter_launcher_icons` and
/// `flutter_native_splash` consume. Re-run with:
/// `flutter test tool/generate_icons_test.dart`, then
/// `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.
///
/// Every number is the board's, on its 144px canvas, scaled to the output:
/// ground `#08222a`; the closed book at (46, 42.5) 52x64 with corners
/// 3/8/8/3, page `#f4fafb`, a 7px `#007890` spine; the ribbon at
/// (60.25, 37.5) 9x21 in `#62b9ce` with its tip notched at 76%; the mark in
/// JetBrains Mono 20/500, slashes `#2f6f80`, the m `#0b2e36`.
void main() {
  const double board = 144;
  const double out = 1024;
  const double s = out / board;

  const ui.Color ground = ui.Color(0xFF08222A);
  const ui.Color page = ui.Color(0xFFF4FAFB);
  const ui.Color spineTeal = ui.Color(0xFF007890);
  const ui.Color ribbonTeal = ui.Color(0xFF62B9CE);
  const ui.Color slash = ui.Color(0xFF2F6F80);
  const ui.Color mInk = ui.Color(0xFF0B2E36);

  setUpAll(() async {
    final ByteData font = ByteData.sublistView(File('tool/fonts/JetBrainsMono-Medium.ttf').readAsBytesSync());
    final FontLoader loader = FontLoader('JetBrains Mono')..addFont(Future<ByteData>.value(font));
    await loader.load();
  });

  void drawBook(
    ui.Canvas canvas, {
    required ui.Color pageColor,
    required ui.Color spineColor,
    required ui.Color ribbon,
    required ui.Color slashColor,
    required ui.Color mColor,
    bool shadow = true,
    ui.Offset offset = ui.Offset.zero,
    double scale = 1,
  }) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    const ui.Rect cover = ui.Rect.fromLTWH(46 * s, 42.5 * s, 52 * s, 64 * s);
    final ui.RRect coverR = ui.RRect.fromRectAndCorners(
      cover,
      topLeft: const ui.Radius.circular(3 * s),
      bottomLeft: const ui.Radius.circular(3 * s),
      topRight: const ui.Radius.circular(8 * s),
      bottomRight: const ui.Radius.circular(8 * s),
    );
    if (shadow) {
      // 0 5px 14px rgba(0,0,0,.35)
      canvas.drawRRect(
        coverR.shift(const ui.Offset(0, 5 * s)),
        ui.Paint()
          ..color = const ui.Color(0x59000000)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7 * s),
      );
    }
    canvas.drawRRect(coverR, ui.Paint()..color = pageColor);
    canvas.save();
    canvas.clipRRect(coverR);
    canvas.drawRect(const ui.Rect.fromLTWH(46 * s, 42.5 * s, 7 * s, 64 * s), ui.Paint()..color = spineColor);
    canvas.restore();

    // The mark, centred in the page area right of the spine.
    final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontFamily: 'JetBrains Mono', fontSize: 20 * s, fontWeight: ui.FontWeight.w500, textAlign: ui.TextAlign.center),
    )
      ..pushStyle(ui.TextStyle(color: slashColor, fontFamily: 'JetBrains Mono'))
      ..addText('/')
      ..pushStyle(ui.TextStyle(color: mColor, fontFamily: 'JetBrains Mono'))
      ..addText('m')
      ..pushStyle(ui.TextStyle(color: slashColor, fontFamily: 'JetBrains Mono'))
      ..addText('/');
    const double areaLeft = (46 + 7) * s, areaWidth = 45 * s;
    final ui.Paragraph p = pb.build()..layout(const ui.ParagraphConstraints(width: areaWidth));
    canvas.drawParagraph(p, ui.Offset(areaLeft, cover.center.dy - p.height / 2));

    // The ribbon, notched: polygon(0 0, 100% 0, 100% 100%, 50% 76%, 0 100%).
    const double rl = 60.25 * s, rt = 37.5 * s, rw = 9 * s, rh = 21 * s;
    final ui.Path ribbonPath = ui.Path()
      ..moveTo(rl, rt)
      ..lineTo(rl + rw, rt)
      ..lineTo(rl + rw, rt + rh)
      ..lineTo(rl + rw / 2, rt + rh * 0.76)
      ..lineTo(rl, rt + rh)
      ..close();
    canvas.drawPath(ribbonPath, ui.Paint()..color = ribbon);
    canvas.restore();
  }

  void drawStencil(ui.Canvas canvas) {
    const ui.Rect cover = ui.Rect.fromLTWH(46 * s, 42.5 * s, 52 * s, 64 * s);
    final ui.RRect coverR = ui.RRect.fromRectAndCorners(
      cover,
      topLeft: const ui.Radius.circular(3 * s),
      bottomLeft: const ui.Radius.circular(3 * s),
      topRight: const ui.Radius.circular(8 * s),
      bottomRight: const ui.Radius.circular(8 * s),
    );
    const double rl = 60.25 * s, rt = 37.5 * s, rw = 9 * s, rh = 21 * s;
    final ui.Path ribbonPath = ui.Path()
      ..moveTo(rl, rt)
      ..lineTo(rl + rw, rt)
      ..lineTo(rl + rw, rt + rh)
      ..lineTo(rl + rw / 2, rt + rh * 0.76)
      ..lineTo(rl, rt + rh)
      ..close();
    final ui.Paint solid = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    final ui.Paint clear = ui.Paint()..blendMode = ui.BlendMode.clear;
    final ui.Paint clearStroke = ui.Paint()
      ..blendMode = ui.BlendMode.clear
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.6 * s;

    canvas.saveLayer(const ui.Rect.fromLTWH(0, 0, out, out), ui.Paint());
    // Launchers draw a themed icon smaller than the colour one, so the
    // stencil is drawn larger: the launcher's own inset brings it back to
    // the colour book's size, and the cut-outs survive the downscale.
    canvas.translate(out / 2, out / 2);
    canvas.scale(1.45);
    canvas.translate(-out / 2, -out / 2);
    canvas.drawPath(ribbonPath, solid);
    canvas.drawRRect(coverR, solid);
    // The spine, as a gap half its width, so the cover still reads as one
    // object.
    canvas.drawRect(const ui.Rect.fromLTWH((46 + 7) * s, 42.5 * s, 3.5 * s, 64 * s), clear);
    // The ribbon inside the cover.
    canvas.save();
    canvas.clipRRect(coverR);
    canvas.drawPath(ribbonPath, clear);
    canvas.restore();
    // The mark, a touch heavier than the colour version so the cut-out
    // survives the launcher's downscale.
    const double areaLeft = (46 + 7) * s, areaWidth = 45 * s;
    for (final ui.Paint paint in <ui.Paint>[clear, clearStroke]) {
      final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(fontFamily: 'JetBrains Mono', fontSize: 20 * s, fontWeight: ui.FontWeight.w500, textAlign: ui.TextAlign.center),
      )
        ..pushStyle(ui.TextStyle(fontFamily: 'JetBrains Mono', foreground: paint))
        ..addText('/m/');
      final ui.Paragraph p = pb.build()..layout(const ui.ParagraphConstraints(width: areaWidth));
      canvas.drawParagraph(p, ui.Offset(areaLeft, cover.center.dy - p.height / 2));
    }
    canvas.restore();
  }

  Future<void> save(String name, void Function(ui.Canvas canvas) paint) async {
    final ui.PictureRecorder rec = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(rec, const ui.Rect.fromLTWH(0, 0, out, out));
    paint(canvas);
    final ui.Image img = await rec.endRecording().toImage(out.toInt(), out.toInt());
    final ByteData? bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    await File('assets/icon/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  }

  test('draws the launcher icon art', () async {
    // Legacy square icon: the board's 34/144 corner on the ground.
    await save('icon', (ui.Canvas c) {
      c.drawRRect(
        ui.RRect.fromRectAndRadius(const ui.Rect.fromLTWH(0, 0, out, out), const ui.Radius.circular(34 * s)),
        ui.Paint()..color = ground,
      );
      drawBook(c, pageColor: page, spineColor: spineTeal, ribbon: ribbonTeal, slashColor: slash, mColor: mInk);
    });
    // Adaptive layers: the ground flat, the book as foreground. The 52x69
    // group sits inside the 88px safe circle, so any mask keeps it whole.
    await save('background', (ui.Canvas c) => c.drawRect(const ui.Rect.fromLTWH(0, 0, out, out), ui.Paint()..color = ground));
    await save('foreground', (ui.Canvas c) => drawBook(c, pageColor: page, spineColor: spineTeal, ribbon: ribbonTeal, slashColor: slash, mColor: mInk));
    // Themed monochrome. Android keeps only the alpha of this layer and
    // tints it one colour over a container colour, so the layer is a
    // stencil: the page is solid, and the spine, the mark and the ribbon
    // are cut out of it so they read in the container colour. Only the
    // ribbon's tip above the cover is solid.
    await save('monochrome', drawStencil);
    // Splash: Android 12 masks the icon to a circle, so the book sits smaller
    // on the same ground.
    await save('splash', (ui.Canvas c) => drawBook(
      c,
      pageColor: page,
      spineColor: spineTeal,
      ribbon: ribbonTeal,
      slashColor: slash,
      mColor: mInk,
      offset: const ui.Offset(out * 0.15, out * 0.15),
      scale: 0.7,
    ));
    expect(File('assets/icon/icon.png').existsSync(), isTrue);
  });
}
