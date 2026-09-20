import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/shared/widgets/fields.dart';

/// The pill search field is the same height empty and filled: the clear
/// button that appears with the first letter must not grow the row, at the
/// default scale and at Android's largest.
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
      final double filled = tester.getSize(find.byType(SearchField)).height;
      expect(find.bySemanticsLabel('Clear'), findsOneWidget, reason: 'clear button once there is text');
      expect(filled, empty, reason: 'height changed from $empty to $filled at ${scale}x');

      await tester.tap(find.bySemanticsLabel('Clear'));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(tester.getSize(find.byType(SearchField)).height, empty);
    });
  }
}
