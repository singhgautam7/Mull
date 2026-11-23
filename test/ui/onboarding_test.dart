import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mull/core/router/router.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/core/utils/platform_surfaces.dart';
import 'package:mull/shared/widgets/family_card.dart';
import 'package:mull/features/onboarding/onboarding_intro_page.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:mull/features/settings/settings_widgets.dart';
import 'package:mull/features/settings/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The first-run flow: four intro pages and the setup page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUpAll(() async {
    // Real metrics: the bundled typeface, not the test font.
    final ByteData font = ByteData.sublistView(File('assets/fonts/InstrumentSans-Variable.ttf').readAsBytesSync());
    await (FontLoader('Instrument Sans')..addFont(Future<ByteData>.value(font))).load();
  });

  void notificationsAnswer(bool granted) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      PlatformSurfaces.channel,
      (MethodCall call) async => call.method == 'requestNotifications' ? granted : null,
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(PlatformSurfaces.channel, null));
  }

  Future<void> pumpFlow(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final GoRouter router = GoRouter(
      initialLocation: Routes.welcome,
      routes: <RouteBase>[
        GoRoute(path: Routes.welcome, builder: (BuildContext c, GoRouterState s) => const WelcomeScreen()),
        GoRoute(path: Routes.home, builder: (BuildContext c, GoRouterState s) => const Text('home page')),
      ],
    );
    addTearDown(router.dispose);
    container = ProviderContainer(overrides: <Override>[prefsProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.of(ThemeFamily.byId('mull'), Tone.light),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }

  testWidgets('four intro pages in order with dots, Skip and Next', (WidgetTester tester) async {
    await pumpFlow(tester);
    expect(find.bySemanticsLabel('Step 1 of 5'), findsOneWidget);
    for (int i = 0; i < OnboardingIntroPage.count; i++) {
      expect(find.text(OnboardingIntroPage.copy[i].$1), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      if (i < OnboardingIntroPage.count - 1) await next(tester);
    }
    await next(tester);
    expect(find.text('Make it yours'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    expect(find.bySemanticsLabel('Step 5 of 5'), findsOneWidget);
  });

  testWidgets('Skip goes straight to setup and Get started finishes', (WidgetTester tester) async {
    await pumpFlow(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Make it yours'), findsOneWidget);
    expect(container.read(settingsProvider).onboarded, isFalse);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).onboarded, isTrue);
    expect(find.text('home page'), findsOneWidget);
  });

  Future<void> toSetup(WidgetTester tester) async {
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
  }

  bool timeRowEnabled(WidgetTester tester) => tester.widget<SettingsRow>(find.widgetWithText(SettingsRow, 'Arrives at')).onTap != null;

  testWidgets('a denied permission leaves the reminder off and the time row disabled', (WidgetTester tester) async {
    notificationsAnswer(false);
    await pumpFlow(tester);
    await toSetup(tester);
    expect(timeRowEnabled(tester), isFalse);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).wotdEnabled, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(timeRowEnabled(tester), isFalse);
  });

  testWidgets('a granted permission turns the reminder on and enables the time row', (WidgetTester tester) async {
    notificationsAnswer(true);
    await pumpFlow(tester);
    await toSetup(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).wotdEnabled, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(timeRowEnabled(tester), isTrue);
  });

  testWidgets('the whole flow fits at the largest text scale on 360 by 640', (WidgetTester tester) async {
    await pumpFlow(tester, scale: 2);
    for (int i = 0; i < OnboardingIntroPage.count; i++) {
      expect(tester.takeException(), isNull);
      await next(tester);
    }
    expect(find.text('Get started'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('setup page: no family cards, the mode toggle sets dark', (WidgetTester tester) async {
    await pumpFlow(tester);
    await toSetup(tester);
    expect(find.byType(FamilyCard), findsNothing);
    for (final String t in <String>['Light', 'Dark', 'System']) {
      expect(find.text(t), findsOneWidget);
    }
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
  });

  testWidgets('the Back label is not truncated', (WidgetTester tester) async {
    await pumpFlow(tester);
    await next(tester);
    final RenderParagraph p = tester.renderObject<RenderParagraph>(find.text('Back'));
    expect(p.didExceedMaxLines, isFalse);
    expect(p.getMinIntrinsicWidth(double.infinity), lessThanOrEqualTo(p.size.width));
  });
}
