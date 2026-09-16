@Tags(<String>['tool'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Previews the adaptive icon the way a launcher shows it: the background
/// and foreground layers composed on the 108dp canvas with the foreground
/// inset `flutter_launcher_icons` applies, then masked to a circle, a
/// squircle and a rounded square, plus the monochrome layer tinted the way
/// Android 13+ themed icons tint it. Writes to `build/icon_preview/`; run
/// with `flutter test tool/icon_masks_test.dart` and look.
void main() {
  const double canvas = 432; // 108dp at xxxhdpi
  const double inset = 0.16; // pubspec: adaptive_icon_foreground_inset (default)
  const double visible = 72 / 108;

  Future<ui.Image> load(String path) async {
    final ui.Codec codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
    return (await codec.getNextFrame()).image;
  }

  ui.Path squircle(ui.Rect r, {double n = 4}) {
    final ui.Path p = ui.Path();
    final double a = r.width / 2, b = r.height / 2;
    for (int i = 0; i <= 360; i += 2) {
      final double t = i * math.pi / 180;
      final double x = a * math.pow(math.cos(t).abs(), 2 / n) * math.cos(t).sign;
      final double y = b * math.pow(math.sin(t).abs(), 2 / n) * math.sin(t).sign;
      i == 0 ? p.moveTo(r.center.dx + x, r.center.dy + y) : p.lineTo(r.center.dx + x, r.center.dy + y);
    }
    return p..close();
  }

  Future<void> save(String name, void Function(ui.Canvas c) paint) async {
    final ui.PictureRecorder rec = ui.PictureRecorder();
    paint(ui.Canvas(rec, const ui.Rect.fromLTWH(0, 0, canvas, canvas)));
    final ui.Image img = await rec.endRecording().toImage(canvas.toInt(), canvas.toInt());
    final ByteData? bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/icon_preview').createSync(recursive: true);
    await File('build/icon_preview/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  }

  test('renders the launcher masks', () async {
    final ui.Image bg = await load('assets/icon/background.png');
    final ui.Image fg = await load('assets/icon/foreground.png');
    final ui.Image mono = await load('assets/icon/monochrome.png');
    const ui.Rect full = ui.Rect.fromLTWH(0, 0, canvas, canvas);
    final ui.Rect insetRect = full.deflate(canvas * inset);
    final ui.Rect shown = ui.Rect.fromCenter(center: full.center, width: canvas * visible, height: canvas * visible);

    void layers(ui.Canvas c, ui.Image ground, ui.Image top, {ui.Color? tint, ui.Color? container}) {
      if (container != null) {
        c.drawRect(full, ui.Paint()..color = container);
      } else {
        c.drawImageRect(ground, ui.Rect.fromLTWH(0, 0, ground.width.toDouble(), ground.height.toDouble()), full, ui.Paint());
      }
      final ui.Paint p = ui.Paint();
      if (tint != null) p.colorFilter = ui.ColorFilter.mode(tint, ui.BlendMode.srcIn);
      c.drawImageRect(top, ui.Rect.fromLTWH(0, 0, top.width.toDouble(), top.height.toDouble()), insetRect, p);
    }

    final Map<String, ui.Path> masks = <String, ui.Path>{
      'circle': ui.Path()..addOval(shown),
      'squircle': squircle(shown),
      'rounded': ui.Path()..addRRect(ui.RRect.fromRectAndRadius(shown, ui.Radius.circular(shown.width * 0.24))),
    };
    for (final MapEntry<String, ui.Path> m in masks.entries) {
      await save(m.key, (ui.Canvas c) {
        c.clipPath(m.value);
        layers(c, bg, fg);
      });
      // Themed: Material You tints the monochrome alpha over a container.
      await save('themed_${m.key}', (ui.Canvas c) {
        c.clipPath(m.value);
        layers(c, bg, mono, tint: const ui.Color(0xFF0B2E35), container: const ui.Color(0xFFA0D9E7));
      });
      await save('themed_dark_${m.key}', (ui.Canvas c) {
        c.clipPath(m.value);
        layers(c, bg, mono, tint: const ui.Color(0xFFC0E6EF), container: const ui.Color(0xFF0B2E35));
      });
    }
    // The safe zone: the inner 66dp circle every mask keeps.
    await save('safe_zone', (ui.Canvas c) {
      layers(c, bg, fg);
      c.drawOval(
        ui.Rect.fromCenter(center: full.center, width: canvas * 66 / 108, height: canvas * 66 / 108),
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const ui.Color(0xFFFF4081),
      );
      c.drawRect(shown, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = 2..color = const ui.Color(0xFFFFC107));
    });
    // One sheet of all of them, for a glance.
    final List<String> names = <String>[
      'circle', 'squircle', 'rounded', 'safe_zone',
      'themed_circle', 'themed_squircle', 'themed_rounded', 'themed_dark_squircle',
    ];
    final List<ui.Image> tiles = <ui.Image>[for (final String n in names) await load('build/icon_preview/$n.png')];
    final ui.PictureRecorder rec = ui.PictureRecorder();
    final ui.Canvas c = ui.Canvas(rec, const ui.Rect.fromLTWH(0, 0, canvas * 4, canvas * 2));
    c.drawRect(const ui.Rect.fromLTWH(0, 0, canvas * 4, canvas * 2), ui.Paint()..color = const ui.Color(0xFF808080));
    for (int i = 0; i < tiles.length; i++) {
      c.drawImage(tiles[i], ui.Offset((i % 4) * canvas, (i ~/ 4) * canvas), ui.Paint());
    }
    final ui.Image sheet = await rec.endRecording().toImage((canvas * 4).toInt(), (canvas * 2).toInt());
    final ByteData? bytes = await sheet.toByteData(format: ui.ImageByteFormat.png);
    await File('build/icon_preview/sheet.png').writeAsBytes(bytes!.buffer.asUint8List());
    expect(File('build/icon_preview/circle.png').existsSync(), isTrue);
  });
}
