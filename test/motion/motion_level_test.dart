import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/app.dart';
import 'package:mull/core/motion/motion.dart';
import 'package:mull/core/theme/tokens.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// There is no Motion setting: the level follows the phone, its Remove
/// animations always wins, and the device check runs once and is cached.
void main() {
  group('resolveMotionLevel', () {
    test('Expressive on a normal phone and before the check, Subtle on a low-RAM one', () {
      expect(resolveMotionLevel(DeviceClass.normal), MotionLevel.expressive);
      expect(resolveMotionLevel(DeviceClass.unknown), MotionLevel.expressive);
      expect(resolveMotionLevel(DeviceClass.low), MotionLevel.subtle);
    });

    test('Remove animations is always Off', () {
      for (final DeviceClass d in DeviceClass.values) {
        expect(resolveMotionLevel(d, systemOff: true), MotionLevel.off);
      }
    });
  });

  group('classifyDevice', () {
    test('under 3.5 GB or the low-RAM flag is low', () {
      expect(classifyDevice(ramMb: 1900), DeviceClass.low);
      expect(classifyDevice(ramMb: 3583), DeviceClass.low);
      expect(classifyDevice(ramMb: 3584), DeviceClass.normal);
      expect(classifyDevice(ramMb: 7800, lowRamFlag: true), DeviceClass.low);
    });
  });

  Future<(ProviderContainer, SharedPreferences)> boot(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer c = ProviderContainer(overrides: <Override>[prefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    return (c, prefs);
  }

  test('the device check runs once and is cached in prefs', () async {
    final (ProviderContainer c, SharedPreferences prefs) = await boot(<String, Object>{});
    int calls = 0;
    Future<(int, bool)?> probe() async {
      calls++;
      return (2048, false);
    }

    await c.read(settingsProvider.notifier).checkDevice(probe);
    await c.read(settingsProvider.notifier).checkDevice(probe);
    expect(calls, 1);
    expect(c.read(settingsProvider).motionLevel, MotionLevel.subtle);
    expect(prefs.getString(AppSettings.kDeviceClass), 'low');
    expect(AppSettings.read(prefs).deviceClass, DeviceClass.low);
  });

  Future<MotionLevel> levelUnder(WidgetTester tester, Map<String, Object> values, {bool disable = false}) async {
    SharedPreferences.setMockInitialValues(values);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    late MotionLevel seen;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[prefsProvider.overrideWithValue(prefs)],
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: disable),
          child: MullMotionScope(
            child: Builder(
              builder: (BuildContext context) {
                seen = Motion.levelOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    return seen;
  }

  testWidgets('Off with Remove animations on', (WidgetTester tester) async {
    expect(await levelUnder(tester, <String, Object>{}, disable: true), MotionLevel.off);
  });

  testWidgets('Subtle on a low-RAM phone', (WidgetTester tester) async {
    expect(await levelUnder(tester, <String, Object>{AppSettings.kDeviceClass: 'low'}), MotionLevel.subtle);
  });

  testWidgets('a level stored by the old Motion setting is ignored', (WidgetTester tester) async {
    expect(await levelUnder(tester, <String, Object>{'motion.preference': 'off'}), MotionLevel.expressive);
  });

  group('MullHaptics', () {
    setUp(MullHaptics.reset);

    test('respects the Haptics switch, the scroll and the 50 ms gap', () {
      final List<MethodCall> calls = <MethodCall>[];
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall m) async {
          if (m.method == 'HapticFeedback.vibrate') calls.add(m);
          return null;
        },
      );
      DateTime t = DateTime(2026);
      MullHaptics.now = () => t;

      MullHaptics.enabled = false;
      MullHaptics.tick();
      expect(calls, isEmpty);

      MullHaptics.enabled = true;
      MullHaptics.scrolling = true;
      MullHaptics.tick();
      expect(calls, isEmpty);

      MullHaptics.scrolling = false;
      MullHaptics.tick();
      MullHaptics.longPress();
      expect(calls, hasLength(1));

      t = t.add(const Duration(milliseconds: 60));
      MullHaptics.longPress();
      expect(calls, hasLength(2));
      MullHaptics.now = DateTime.now;
    });
  });
}
