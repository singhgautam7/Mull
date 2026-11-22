import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/shared/widgets/fields.dart';

/// The search bar (Kuber's 48dp pill) is the same height empty and filled:
/// the clear button that scales in with the first letter must not grow the
/// row, at the default scale and at Android's largest.
void main() {
  for (final double scale in const <double>[1.0, 2.0]) {
    testWidgets('SearchField keeps its height when text is entered at ${scale}x', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SearchField(controller: controller, hint: 'Search', onChanged: (_) {}),
            ),
          ),
        ),
      );
      final double empty = tester.getSize(find.byType(SearchField)).height;
      expect(find.bySemanticsLabel('Clear'), findsNothing, reason: 'no clear button while empty');

      await tester.enterText(find.byType(TextField), 'mitigate');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // the clear button scales in
      final double filled = tester.getSize(find.byType(SearchField)).height;
      expect(find.bySemanticsLabel('Clear'), findsOneWidget, reason: 'clear button once there is text');
      expect(filled, empty, reason: 'height changed from $empty to $filled at ${scale}x');
      expect(empty, SearchField.height, reason: "Kuber's pill is 48dp");

      await tester.tap(find.bySemanticsLabel('Clear'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.text, isEmpty);
      expect(tester.getSize(find.byType(SearchField)).height, empty);
    });
  }
}
