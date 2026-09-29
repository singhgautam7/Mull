import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/shared/widgets/states.dart';

/// A loader that flashes is worse than no loader: work that finishes inside
/// the threshold must render nothing at all.
void main() {
  testWidgets('Delayed shows nothing until the threshold, then the child', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Delayed(child: Text('loading', textDirection: TextDirection.ltr)),
      ),
    );
    expect(find.text('loading'), findsNothing);

    await tester.pump(Delayed.threshold - const Duration(milliseconds: 1));
    expect(find.text('loading'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2));
    expect(find.text('loading'), findsOneWidget);
  });

  testWidgets('work that finishes inside the threshold never renders the child', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Delayed(
          placeholder: Text('ready', textDirection: TextDirection.ltr),
          child: Text('loading', textDirection: TextDirection.ltr),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));
    expect(find.text('loading'), findsNothing);
    expect(find.text('ready'), findsOneWidget);

    // The work lands: the Delayed goes away with its timer, unfired.
    await tester.pumpWidget(
      const MaterialApp(home: Text('ready', textDirection: TextDirection.ltr)),
    );
    await tester.pump(Delayed.threshold * 2);
    expect(find.text('loading'), findsNothing);
  });
}
