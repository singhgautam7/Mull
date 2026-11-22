import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/motion/motion.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/shared/widgets/chips.dart';

/// Single-choice groups: the selected item is a 12dp squircle, the others a
/// pill, and how the change is drawn depends on the motion level.
Widget _app(MotionLevel level, Widget child) => MaterialApp(
  theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
  home: MotionScope(level: level, systemOff: false, child: Scaffold(body: Center(child: child))),
);

Material _material(WidgetTester t, Finder of, int i) =>
    t.widgetList<Material>(find.descendant(of: of, matching: find.byType(Material))).elementAt(i);

double _r(Material m) => ((m.shape! as RoundedRectangleBorder).borderRadius as BorderRadius).topLeft.x;

class _Toggle extends StatefulWidget {
  const _Toggle();
  @override
  State<_Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<_Toggle> {
  int v = 0;
  @override
  Widget build(BuildContext context) => SegmentedToggle<int>(
    options: const <(int, String)>[(0, 'A'), (1, 'B'), (2, 'C')],
    selected: v,
    onChanged: (int x) => setState(() => v = x),
  );
}

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
  final Finder toggle = find.byType(SegmentedToggle<int>);
  final Finder chips = find.byType(PillChip);
  final List<Object?> ticks = <Object?>[];

  setUp(() {
    ticks.clear();
    MullHaptics.enabled = true;
    MullHaptics.reset();
  });
  tearDown(() {
    MullHaptics.enabled = false;
    MullHaptics.reset();
  });

  void listen(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall c) async {
      if (c.method == 'HapticFeedback.vibrate') ticks.add(c.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  }

  testWidgets('SegmentedToggle at Expressive: selected 12, unselected height/2, springs on change', (WidgetTester tester) async {
    await tester.pumpWidget(_app(MotionLevel.expressive, const _Toggle()));
    await tester.pumpAndSettle();
    expect(_r(_material(tester, toggle, 0)), 12);
    expect(_r(_material(tester, toggle, 1)), 19);
    await tester.tap(find.text('B'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_r(_material(tester, toggle, 1)), inExclusiveRange(12, 19), reason: 'the shape animates');
    await tester.pumpAndSettle();
    expect(_r(_material(tester, toggle, 0)), 19);
    expect(_r(_material(tester, toggle, 1)), 12);
  });

  testWidgets('SegmentedToggle at Subtle: the shape jumps, the fill fades', (WidgetTester tester) async {
    await tester.pumpWidget(_app(MotionLevel.subtle, const _Toggle()));
    await tester.pumpAndSettle();
    final Color before = _material(tester, toggle, 1).color!;
    await tester.tap(find.text('B'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_r(_material(tester, toggle, 1)), 12, reason: 'no morph');
    final Color mid = _material(tester, toggle, 1).color!;
    expect(mid, isNot(before));
    await tester.pumpAndSettle();
    expect(_material(tester, toggle, 1).color, isNot(mid), reason: 'the fill was still fading');
  });

  testWidgets('SegmentedToggle at Off: instant', (WidgetTester tester) async {
    await tester.pumpWidget(_app(MotionLevel.off, const _Toggle()));
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(_r(_material(tester, toggle, 1)), 12);
    expect(_r(_material(tester, toggle, 0)), 19);
  });

  testWidgets('SegmentedToggle ticks once per changed selection, not for the selected item', (WidgetTester tester) async {
    listen(tester);
    await tester.pumpWidget(_app(MotionLevel.expressive, const _Toggle()));
    await tester.tap(find.text('B'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(ticks.length, 1);
    await tester.tap(find.text('B'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(ticks.length, 1);
  });

  testWidgets('PillChip group: selected squircle, unselected pill', (WidgetTester tester) async {
    await tester.pumpWidget(_app(MotionLevel.expressive, const _Chips()));
    await tester.pumpAndSettle();
    expect(_r(_material(tester, chips.at(0), 0)), 12);
    expect(_material(tester, chips.at(1), 0).shape, isA<StadiumBorder>());
    await tester.tap(find.text('Chip 1'));
    await tester.pumpAndSettle();
    expect(_material(tester, chips.at(0), 0).shape, isA<StadiumBorder>());
    expect(_r(_material(tester, chips.at(1), 0)), 12);
  });

  testWidgets('a plain PillChip stays a pill', (WidgetTester tester) async {
    await tester.pumpWidget(_app(MotionLevel.expressive, PillChip(label: 'syn', onTap: () {})));
    final Material m = _material(tester, chips, 0);
    expect(m.shape, isA<StadiumBorder>());
  });

  testWidgets('PillChip ticks once when the selection changes', (WidgetTester tester) async {
    listen(tester);
    await tester.pumpWidget(_app(MotionLevel.expressive, const _Chips()));
    await tester.tap(find.text('Chip 1'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(ticks.length, 1);
  });
}
