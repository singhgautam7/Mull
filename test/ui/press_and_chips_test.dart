import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/motion/motion.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/shared/widgets/app_button.dart';
import 'package:mull/shared/widgets/app_icon_button.dart';
import 'package:mull/shared/widgets/chips.dart';

/// Press morph (circle to squircle and back) and the filter chip shapes.
Widget _app(MotionLevel level, Widget child) => MaterialApp(
  theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
  home: MotionScope(level: level, systemOff: false, child: Scaffold(body: Center(child: child))),
);

Material _m(WidgetTester t, Finder of) =>
    t.widgetList<Material>(find.descendant(of: of, matching: find.byType(Material))).firstWhere((Material m) => m.shape is OutlinedBorder);

double _r(Material m) => ((m.shape! as RoundedRectangleBorder).borderRadius as BorderRadius).topLeft.x;

class _Chips extends StatefulWidget {
  const _Chips();
  @override
  State<_Chips> createState() => _ChipsState();
}

class _ChipsState extends State<_Chips> {
  int v = 0;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (int i = 0; i < 2; i++) PillChip(label: 'Chip $i', selected: v == i, onTap: () => setState(() => v = i)),
    ],
  );
}

void main() {
  final Finder iconButton = find.byType(AppIconButton);
  final Finder button = find.byType(AppButton);
  final Finder chips = find.byType(PillChip);
  final Widget icon = AppIconButton(icon: Icons.search_rounded, semanticLabel: 'Search', onPressed: () {});

  testWidgets('AppIconButton and AppButton Materials do not tween their own shape', (WidgetTester tester) async {
    await tester.pumpWidget(_app(MotionLevel.expressive, Column(mainAxisSize: MainAxisSize.min, children: <Widget>[icon, AppButton(label: 'Go', onPressed: () {})])));
    expect(_m(tester, iconButton).animationDuration, Duration.zero);
    expect(tester.widget<Material>(find.descendant(of: button, matching: find.byType(Material)).first).animationDuration, Duration.zero);
  });

  testWidgets('a held press turns the circle into a squircle at Expressive and back on release', (WidgetTester tester) async {
    await tester.pumpWidget(_app(MotionLevel.expressive, icon));
    expect(_r(_m(tester, iconButton)), 20);
    final TestGesture g = await tester.startGesture(tester.getCenter(iconButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(_r(_m(tester, iconButton)), closeTo(12, 0.01));
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(_r(_m(tester, iconButton)), closeTo(20, 0.01));
  });

  testWidgets('at Off the shape never morphs', (WidgetTester tester) async {
    await tester.pumpWidget(_app(MotionLevel.off, icon));
    final TestGesture g = await tester.startGesture(tester.getCenter(iconButton));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_r(_m(tester, iconButton)), 20);
    await g.up();
  });

  testWidgets('PillChip: selected squircle 12, unselected stadium with a border; the shape follows a toggle', (WidgetTester tester) async {
    await tester.pumpWidget(_app(MotionLevel.expressive, const _Chips()));
    await tester.pumpAndSettle();
    final Material sel = _m(tester, chips.at(0));
    expect(_r(sel), 12);
    expect((sel.shape! as RoundedRectangleBorder).side.color, Colors.transparent);
    expect(sel.color, isNot(Colors.transparent));
    final Material un = _m(tester, chips.at(1));
    expect(un.shape, isA<StadiumBorder>());
    expect((un.shape! as StadiumBorder).side.width, 1);
    expect(un.color, Colors.transparent);
    await tester.tap(find.text('Chip 1'));
    await tester.pumpAndSettle();
    expect(_m(tester, chips.at(0)).shape, isA<StadiumBorder>());
    expect(_r(_m(tester, chips.at(1))), 12);
  });

  testWidgets('a tap-only PillChip looks unselected and has a 48dp hit region', (WidgetTester tester) async {
    await tester.pumpWidget(_app(MotionLevel.expressive, PillChip(label: 'syn', onTap: () {})));
    expect(_m(tester, chips).shape, isA<StadiumBorder>());
    expect(tester.getSize(chips).height, greaterThanOrEqualTo(48));
  });
}
