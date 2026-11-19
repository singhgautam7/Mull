import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/core/theme/app_theme.dart';
import 'package:mull/core/theme/palette.dart';
import 'package:mull/core/utils/wallpaper_seed.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:mull/features/settings/theme_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The theme page at the largest font scale (2.0, as font_scale_test) on a
/// 360dp phone: nothing overflows, and the light, dark and pure black looks
/// are pinned. Regenerate with `flutter test --update-goldens`.
void main() {
  const double maxScale = 2.0;

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    required String mode,
    bool pure = false,
    bool expressive = true,
    String family = 'mull',
  }) async {
    tester.view.physicalSize = const Size(360, 4400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppSettings.kMode: mode,
      AppSettings.kAmoled: pure,
      AppSettings.kExpressive: expressive,
      AppSettings.kFamily: family,
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Tone tone = mode == 'light'
        ? Tone.light
        : (pure ? Tone.amoled : Tone.dark);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          prefsProvider.overrideWithValue(prefs),
          wallpaperSeedProvider.overrideWith((Ref ref) async => null),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.of(
            ThemeFamily.byId(family),
            tone,
            expressive: expressive,
          ),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(maxScale)),
            child: child!,
          ),
          home: const ThemeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull, reason: name);
    await expectLater(
      find.byType(ThemeScreen),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets(
    'light',
    (WidgetTester t) => shoot(t, 'theme_light', mode: 'light'),
  );
  testWidgets('dark', (WidgetTester t) => shoot(t, 'theme_dark', mode: 'dark'));
  testWidgets(
    'pure black',
    (WidgetTester t) => shoot(t, 'theme_pure_black', mode: 'dark', pure: true),
  );
  testWidgets(
    'saffron, expressive off',
    (WidgetTester t) => shoot(
      t,
      'theme_saffron_neutral',
      mode: 'light',
      expressive: false,
      family: 'saffron',
    ),
  );
  testWidgets(
    'iris, expressive on',
    (WidgetTester t) => shoot(t, 'theme_iris', mode: 'dark', family: 'iris'),
  );
  testWidgets(
    'iris, expressive off',
    (WidgetTester t) => shoot(
      t,
      'theme_iris_neutral',
      mode: 'dark',
      expressive: false,
      family: 'iris',
    ),
  );
}
