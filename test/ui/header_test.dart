import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/motion/motion.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/features/settings/floating_header_sheet.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:mull/shared/widgets/app_header.dart';
import 'package:mull/shared/widgets/app_icon_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The floating header: pill at 32, back at 8, nothing in between; the pill
/// modes; Floating header off; one listener and no rebuild per frame.
void main() {
  late ScrollController sc;
  late int backTaps;

  Future<void> pump(
    WidgetTester tester, {
    bool floating = true,
    PillMode pill = PillMode.always,
    MotionLevel level = MotionLevel.expressive,
    bool pageFloating = true,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppSettings.kFloatingHeader: floating,
      AppSettings.kPillMode: pill.name,
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    sc = ScrollController();
    addTearDown(sc.dispose);
    backTaps = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[prefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
          home: MotionScope(
            level: level,
            systemOff: false,
            child: Scaffold(
              body: HeaderPage(
                floating: pageFloating,
                header: AppHeader(
                  title: 'Shelves',
                  onBack: () => backTaps++,
                  actions: <Widget>[
                    AppIconButton(icon: Icons.search_rounded, semanticLabel: 'Search', onPressed: () {}),
                    AppIconButton(icon: Icons.more_vert_rounded, semanticLabel: 'More options', onPressed: () {}),
                  ],
                ),
                body: ListView(
                  controller: sc,
                  children: <Widget>[
                    HeaderPage.gap(),
                    for (int i = 0; i < 60; i++) SizedBox(height: 60, child: Text('row $i')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> to(WidgetTester tester, double y) async {
    sc.jumpTo(y);
    await tester.pumpAndSettle();
  }

  Iterable<CustomPaint> surfaces(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.descendant(of: find.byType(AppHeader), matching: find.byType(CustomPaint)))
      .where((CustomPaint p) => p.painter.runtimeType.toString() == '_SurfacePainter');

  dynamic painter(WidgetTester tester) => surfaces(tester).first.painter;

  double progress(WidgetTester tester) => painter(tester).progress.value as double;

  bool hasPill(WidgetTester tester) => surfaces(tester).isNotEmpty;

  RRect shape(WidgetTester tester) {
    final dynamic p = painter(tester);
    return p.rrectAt(tester.getSize(find.byType(AppHeader)), p.progress.value as double) as RRect;
  }

  List<String> labels(WidgetTester tester) {
    final List<String> out = <String>[];
    void walk(SemanticsNode n) {
      if (n.label.isNotEmpty) out.add(n.label);
      n.visitChildren((SemanticsNode c) {
        walk(c);
        return true;
      });
    }

    walk(tester.getSemantics(find.byType(AppHeader)));
    return out;
  }

  bool backVisible(WidgetTester tester) => labels(tester).contains('Back');

  testWidgets('pill at >= 32, header at <= 8, nothing in between', (WidgetTester tester) async {
    await pump(tester);
    expect(progress(tester), 0);
    await to(tester, 20);
    expect(progress(tester), 0, reason: 'no flicker at 20 on the way down');
    await to(tester, 31);
    expect(progress(tester), 0);
    await to(tester, 32);
    expect(progress(tester), 1);
    await to(tester, 20);
    expect(progress(tester), 1, reason: 'no flicker at 20 on the way up');
    await to(tester, 9);
    expect(progress(tester), 1);
    await to(tester, 8);
    expect(progress(tester), 0);
  });

  testWidgets('a round trip leaves the header exactly at rest', (WidgetTester tester) async {
    await pump(tester);
    final RRect rest = shape(tester);
    final Rect title = tester.getRect(find.text('Shelves'));
    final Rect back = tester.getRect(find.byType(AppIconButton).first);
    expect(rest.left, 0);
    expect(rest.tlRadiusX, 0);

    await to(tester, 200);
    final RRect pill = shape(tester);
    expect(pill.left, HeaderSpec.margin);
    expect(pill.top, HeaderSpec.top);
    expect(pill.height, HeaderSpec.pillHeight);
    expect(pill.tlRadiusX, HeaderSpec.radius);
    expect(tester.getRect(find.text('Shelves')).height, lessThan(title.height));

    await to(tester, 0);
    expect(shape(tester), rest);
    expect(tester.getRect(find.text('Shelves')), title);
    expect(tester.getRect(find.byType(AppIconButton).first), back);
  });

  testWidgets('a round trip is exact at Subtle and Off too', (WidgetTester tester) async {
    for (final MotionLevel level in <MotionLevel>[MotionLevel.subtle, MotionLevel.off]) {
      await pump(tester, level: level);
      final RRect rest = shape(tester);
      await to(tester, 200);
      expect(shape(tester).left, HeaderSpec.margin, reason: '$level pill');
      await to(tester, 0);
      expect(shape(tester), rest, reason: '$level rest');
    }
  });

  testWidgets('Off changes at once, no spring', (WidgetTester tester) async {
    await pump(tester, level: MotionLevel.off);
    sc.jumpTo(100);
    await tester.pump();
    expect(progress(tester), 1);
  });

  testWidgets('Always keeps the pill visible', (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester);
    await to(tester, 100);
    await to(tester, 400);
    expect(backVisible(tester), isTrue);
    h.dispose();
  });

  testWidgets('When scrolling up: hides after 16 down, shows after 8 up', (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester, pill: PillMode.scrollUp);
    await to(tester, 40);
    expect(backVisible(tester), isFalse, reason: 'hidden on the way down');
    await to(tester, 36);
    expect(backVisible(tester), isFalse, reason: '4 up is not enough');
    await to(tester, 27);
    expect(backVisible(tester), isTrue, reason: '8 up shows it');
    await to(tester, 44);
    expect(backVisible(tester), isFalse, reason: '17 down hides again');
    h.dispose();
  });

  testWidgets('When scrolling stops: hides while moving, shows 300 ms after the end', (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester, pill: PillMode.scrollStop);
    sc.jumpTo(100);
    await tester.pump();
    expect(backVisible(tester), isFalse);
    await tester.pump(const Duration(milliseconds: 250));
    expect(backVisible(tester), isFalse, reason: 'still inside the 300 ms');
    sc.jumpTo(160); // movement restarts the wait
    await tester.pump(const Duration(milliseconds: 250));
    expect(backVisible(tester), isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    expect(backVisible(tester), isTrue);
    h.dispose();
  });

  testWidgets('Floating header off: the header goes with the content', (WidgetTester tester) async {
    await pump(tester, floating: false);
    final Rect rest = tester.getRect(find.byType(AppHeader));
    await to(tester, 30);
    expect(tester.getRect(find.byType(AppHeader)).top, rest.top - 30);
    expect(hasPill(tester), isFalse, reason: 'never becomes a pill');
    await to(tester, 800);
    expect(tester.getRect(find.byType(AppHeader)).top, rest.top - rest.height, reason: 'gone, not sticky');
    await to(tester, 0);
    expect(tester.getRect(find.byType(AppHeader)), rest);
  });

  testWidgets('floating: false on the page keeps a fixed header', (WidgetTester tester) async {
    await pump(tester, pageFloating: false);
    final Rect rest = tester.getRect(find.byType(AppHeader));
    await to(tester, 600);
    expect(tester.getRect(find.byType(AppHeader)), rest);
    expect(hasPill(tester), isFalse);
  });

  testWidgets('scrolling does not rebuild the header', (WidgetTester tester) async {
    await pump(tester, pill: PillMode.scrollUp);
    final int before = AppHeader.debugBuildCount;
    for (final double y in <double>[10, 20, 31, 40, 80, 120, 90, 60, 20, 8, 0, 300, 250, 500]) {
      sc.jumpTo(y);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(AppHeader.debugBuildCount, before);
  });

  testWidgets('a hidden pill is out of semantics and takes no taps', (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester, pill: PillMode.scrollUp);
    expect(backVisible(tester), isTrue);
    await to(tester, 60);
    expect(backVisible(tester), isFalse);
    expect(labels(tester).contains('More options'), isFalse);
    await tester.tapAt(const Offset(30, 36));
    expect(backTaps, 0);
    await to(tester, 50);
    expect(backVisible(tester), isTrue);
    h.dispose();
  });

  testWidgets('the pill reads the same buttons in the same order', (WidgetTester tester) async {
    final SemanticsHandle h = tester.ensureSemantics();
    await pump(tester);
    final List<String> rest = labels(tester);
    expect(rest, containsAllInOrder(<String>['Back', 'Shelves', 'Search', 'More options']));
    await to(tester, 200);
    expect(labels(tester), rest);
    h.dispose();
  });

  testWidgets('the Floating header sheet applies at once and disables the pill choices when off', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[prefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
          home: Builder(
            builder: (BuildContext c) => Scaffold(
              body: TextButton(onPressed: () => showFloatingHeaderSheet(c), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Floating header'), findsWidgets);
    final ProviderContainer c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

    await tester.tap(find.text('When scrolling up'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(settingsProvider).pillMode, PillMode.scrollUp);

    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(settingsProvider).floatingHeader, isFalse);
    await tester.tap(find.text('When scrolling stops'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(settingsProvider).pillMode, PillMode.scrollUp, reason: 'disabled while off');
    // Leave the sheet before the script clock outlives the test.
    await tester.pumpWidget(const SizedBox());
  });
}
