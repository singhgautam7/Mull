import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// The five destination glyphs, drawn rather than taken from an icon font
/// because their geometry is specified: 1.75 stroke, rounded, in a 20x16 box.
/// Home = rounded rectangle over a short underline; Mull = one upright card;
/// Collections = stacked cards; Search = magnifier; More = two sliders.
enum MullGlyph { home, mull, collections, search, more }

class MullIcon extends StatelessWidget {
  const MullIcon(this.glyph, {required this.color, this.background, super.key});

  final MullGlyph glyph;
  final Color color;

  /// What the More knobs and Collections front card are punched out of.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 16,
      child: Center(
        child: switch (glyph) {
          MullGlyph.home => _Home(color: color),
          MullGlyph.mull => _Card(color: color),
          MullGlyph.collections => _Collections(color: color, background: background ?? Theme.of(context).colorScheme.surface),
          MullGlyph.search => CustomPaint(size: const Size(20, 16), painter: _SearchPainter(color)),
          MullGlyph.more => _More(color: color, background: background ?? Theme.of(context).colorScheme.surface),
        },
      ),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 18,
        height: 11,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: IconSpec.stroke),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
      ),
      const SizedBox(height: 2),
      Container(
        width: 10,
        height: IconSpec.stroke,
        decoration: BoxDecoration(color: color, borderRadius: Radii.fullR),
      ),
    ],
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 16,
    decoration: BoxDecoration(
      border: Border.all(color: color, width: IconSpec.stroke),
      borderRadius: const BorderRadius.all(Radius.circular(4)),
    ),
  );
}

class _SearchPainter extends CustomPainter {
  _SearchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = IconSpec.stroke
      ..strokeCap = StrokeCap.round;
    final Offset center = Offset(size.width * 0.42, size.height * 0.44);
    const double radius = 5.2;
    canvas.drawCircle(center, radius, paint);
    const double d = 0.70710678;
    canvas.drawLine(
      Offset(center.dx + radius * d, center.dy + radius * d),
      Offset(center.dx + (radius + 4.5) * d, center.dy + (radius + 4.5) * d),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SearchPainter oldDelegate) => oldDelegate.color != color;
}

class _More extends StatelessWidget {
  const _More({required this.color, required this.background});

  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    Widget slider({required bool knobOnLeft}) => SizedBox(
      width: 19,
      height: 8,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          Container(width: 19, height: 2, decoration: BoxDecoration(color: color, borderRadius: Radii.fullR)),
          Positioned(
            left: knobOnLeft ? 3 : null,
            right: knobOnLeft ? null : 3,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: background,
                border: Border.all(color: color, width: IconSpec.stroke),
                borderRadius: const BorderRadius.all(Radius.circular(3)),
              ),
            ),
          ),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[slider(knobOnLeft: true), slider(knobOnLeft: false)],
    );
  }
}

class _Collections extends StatelessWidget {
  const _Collections({required this.color, required this.background});

  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 20,
    height: 16,
    child: Stack(
      children: <Widget>[
        Positioned(
          right: 1,
          top: 0,
          child: Container(
            width: 12,
            height: 14,
            decoration: BoxDecoration(
              border: Border.all(color: color, width: IconSpec.stroke),
              borderRadius: const BorderRadius.all(Radius.circular(3)),
            ),
          ),
        ),
        Positioned(
          left: 1,
          bottom: 0,
          child: Container(
            width: 12,
            height: 14,
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: color, width: IconSpec.stroke),
              borderRadius: const BorderRadius.all(Radius.circular(3)),
            ),
          ),
        ),
      ],
    ),
  );
}

