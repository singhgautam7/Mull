import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/app/nav_shell.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';

/// A tab is built before its first visit, never hit-testable or ticking while
/// it waits, and is built at once when visited early.
void main() {
  Widget app(int index) => MaterialApp(
    theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
    home: BranchStack(
      index: index,
      onSelect: (int _) {},
      children: const <Widget>[
        Text('home'),
        WarmTab(branch: 1, delay: Duration(milliseconds: 300), child: Text('shelves')),
      ],
    ),
  );
  Finder shelves() => find.text('shelves', skipOffstage: false);

  testWidgets('waits, then builds and paints once, offstage again after', (WidgetTester tester) async {
    await tester.pumpWidget(app(0));
    expect(shelves(), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(shelves(), findsOneWidget);
    expect(BranchStack.warming.value, isNull);
    expect(find.text('shelves'), findsNothing, reason: 'offstage again');
    expect(find.text('home').hitTestable(), findsOneWidget);
    expect(TickerMode.valuesOf(tester.element(shelves())).enabled, isFalse);
  });

  testWidgets('visited before the delay, it builds at once', (WidgetTester tester) async {
    await tester.pumpWidget(app(0));
    await tester.pumpWidget(app(1));
    expect(find.text('shelves'), findsOneWidget, reason: 'built in the same frame');
    await tester.pumpAndSettle();
    expect(find.text('shelves').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
