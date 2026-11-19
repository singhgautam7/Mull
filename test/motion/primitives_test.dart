import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/motion/motion.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/core/theme/tokens.dart';
import 'package:mull/shared/widgets/app_icon_button.dart';
import 'package:mull/shared/widgets/app_snackbar.dart';
import 'package:mull/shared/widgets/rolling_number.dart';

/// The motion primitives and the shared widgets built on them, at each level.
Widget _app(MotionLevel level, Widget child) => MaterialApp(
  theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
  home: MotionScope(
    level: level,
    systemOff: false,
    child: Scaffold(body: Center(child: child)),
  ),
);

double _scaleOf(WidgetTester t, Finder of) =>
    t.widget<Transform>(find.descendant(of: of, matching: find.byType(Transform)).first).transform.storage[0];

double _radiusOf(WidgetTester t, Finder of) {
  final Material m = t.widget<Material>(find.descendant(of: of, matching: find.byType(Material)).first);
  return ((m.shape! as RoundedRectangleBorder).borderRadius as BorderRadius).topLeft.x;
}

void main() {
  tearDown(() {
    MullHaptics.enabled = false;
    MullHaptics.reset();
  });

  group('Pressable scale', () {
    for (final (MotionLevel l, double want) in <(MotionLevel, double)>[
      (MotionLevel.expressive, Motion.pressScaleCard),
      (MotionLevel.subtle, Motion.pressScaleSubtle),
      (MotionLevel.off, 1.0),
    ]) {
      testWidgets('card at $l scales to $want while pressed and returns', (WidgetTester tester) async {
        await tester.pumpWidget(_app(l, const Pressable(kind: PressKind.card, child: SizedBox(width: 80, height: 80))));
        final Finder p = find.byType(Pressable);
        final TestGesture g = await tester.startGesture(tester.getCenter(p));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(_scaleOf(tester, p), closeTo(want, 0.002));
        await g.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        expect(_scaleOf(tester, p), closeTo(1.0, 0.001));
      });
    }
  });

  group('AppIconButton corner morph', () {
    for (final (MotionLevel l, double want) in <(MotionLevel, double)>[
      (MotionLevel.expressive, 12),
      (MotionLevel.subtle, 20),
      (MotionLevel.off, 20),
    ]) {
      testWidgets('at $l the pressed radius is $want and rest is 20', (WidgetTester tester) async {
        await tester.pumpWidget(
          _app(l, AppIconButton(icon: Icons.add, semanticLabel: 'Add', onPressed: () {})),
        );
        final Finder b = find.byType(AppIconButton);
        expect(_radiusOf(tester, b), 20);
        final TestGesture g = await tester.startGesture(tester.getCenter(find.byIcon(Icons.add)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(_radiusOf(tester, b), closeTo(want, 0.05));
        await g.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        expect(_radiusOf(tester, b), closeTo(20, 0.05));
      });
    }
  });

  group('Pressable tap haptic', () {
    Future<int> taps(WidgetTester tester, {required bool enabled}) async {
      final List<Object?> calls = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall c) async {
        if (c.method == 'HapticFeedback.vibrate') calls.add(c.arguments);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      MullHaptics.enabled = enabled;
      MullHaptics.reset();
      await tester.pumpWidget(_app(MotionLevel.expressive, const Pressable(child: SizedBox(width: 80, height: 80))));
      await tester.tap(find.byType(Pressable));
      await tester.pump(const Duration(milliseconds: 600));
      return calls.length;
    }

    testWidgets('fires one tick when Haptics is on', (WidgetTester tester) async {
      expect(await taps(tester, enabled: true), 1);
    });
    testWidgets('is silent when Haptics is off', (WidgetTester tester) async {
      expect(await taps(tester, enabled: false), 0);
    });
  });

  group('MotionListItem', () {
    for (final (MotionLevel l, int ms) in <(MotionLevel, int)>[
      (MotionLevel.expressive, 1500),
      (MotionLevel.off, 200),
    ]) {
      testWidgets('removal calls onRemoved within ${ms}ms at $l', (WidgetTester tester) async {
        bool removed = false;
        Widget build({required bool present}) => _app(
          l,
          MotionListItem(
            present: present,
            onRemoved: () => removed = true,
            child: const SizedBox(width: 60, height: 40, child: Text('row')),
          ),
        );
        await tester.pumpWidget(build(present: true));
        await tester.pumpAndSettle();
        expect(find.text('row'), findsOneWidget);
        await tester.pumpWidget(build(present: false));
        await tester.pump();
        await tester.pump();
        await tester.pump(Duration(milliseconds: ms));
        if (l == MotionLevel.expressive) await tester.pumpAndSettle();
        expect(removed, isTrue);
      });
    }

    testWidgets('insert animates in and ends at full size', (WidgetTester tester) async {
      await tester.pumpWidget(
        _app(MotionLevel.expressive, const MotionListItem(animateIn: true, child: SizedBox(width: 60, height: 40, child: Text('row')))),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(MotionListItem)).height, 40);
    });
  });

  group('SkeletonCrossFade', () {
    testWidgets('swaps to the content and the leaving placeholder ignores pointers', (WidgetTester tester) async {
      Widget build(bool loading) => _app(
        MotionLevel.expressive,
        SkeletonCrossFade(loading: loading, placeholder: const Text('skeleton'), child: const Text('content')),
      );
      await tester.pumpWidget(build(true));
      expect(find.text('skeleton'), findsOneWidget);
      expect(find.text('content'), findsNothing);
      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(milliseconds: 40));
      final IgnorePointer ip = tester.widget<IgnorePointer>(
        find.ancestor(of: find.text('skeleton'), matching: find.byType(IgnorePointer)).first,
      );
      expect(ip.ignoring, isTrue);
      expect(find.text('content'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('skeleton'), findsNothing);
    });
  });

  testWidgets('ShapeLoader runs no ticker at Off', (WidgetTester tester) async {
    await tester.pumpWidget(_app(MotionLevel.off, const ShapeLoader()));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('ExpandCollapse opens and closes', (WidgetTester tester) async {
    Widget build(bool open) => _app(MotionLevel.expressive, ExpandCollapse(expanded: open, child: const SizedBox(height: 50, width: 50)));
    await tester.pumpWidget(build(false));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ExpandCollapse)).height, 0);
    await tester.pumpWidget(build(true));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ExpandCollapse)).height, 50);
  });

  testWidgets('AnimatedWeight eases to the active weight', (WidgetTester tester) async {
    Widget build(bool a) => _app(MotionLevel.expressive, AnimatedWeight('Hi', isActive: a, rest: 600, active: 700));
    double wght() => tester.widget<Text>(find.text('Hi')).style!.fontVariations!.first.value;
    await tester.pumpWidget(build(false));
    expect(wght(), 600);
    await tester.pumpWidget(build(true));
    await tester.pump(const Duration(milliseconds: 80));
    expect(wght(), inExclusiveRange(600, 700));
    await tester.pumpAndSettle();
    expect(wght(), 700);
  });

  group('RollingNumber', () {
    Widget build(MotionLevel l, int v) => _app(l, RollingNumber(v));

    testWidgets('Expressive rolls: old and new digit coexist mid roll, then settle', (WidgetTester tester) async {
      await tester.pumpWidget(build(MotionLevel.expressive, 5));
      await tester.pumpWidget(build(MotionLevel.expressive, 6));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('5'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('5'), findsNothing);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('Subtle cross-fades', (WidgetTester tester) async {
      await tester.pumpWidget(build(MotionLevel.subtle, 5));
      await tester.pumpWidget(build(MotionLevel.subtle, 6));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('5'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('5'), findsNothing);
    });

    testWidgets('Off snaps', (WidgetTester tester) async {
      await tester.pumpWidget(build(MotionLevel.off, 5));
      await tester.pumpWidget(build(MotionLevel.off, 6));
      await tester.pump();
      expect(find.text('5'), findsNothing);
      expect(find.text('6'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  testWidgets('snackbar still auto-dismisses on its timer', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        MotionLevel.expressive,
        Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => AppSnackbar.show(
              context,
              const SnackMessage(text: 'Saved', duration: Duration(seconds: 1)),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });
}
