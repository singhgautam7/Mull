import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mull/app.dart';
import 'package:mull/core/database/dictionary_db.dart';
import 'package:mull/core/database/dictionary_installer.dart';
import 'package:mull/core/database/user_db.dart';
import 'package:mull/core/providers.dart';
import 'package:mull/core/theme/tokens.dart';
import 'package:mull/features/settings/install_screen.dart';
import 'package:mull/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rule D2: first run gunzips the shipped asset into place, records the
/// version, and never does it again for the same version.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mull_install_');
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() => dir.delete(recursive: true));

  testWidgets('first run installs the bundled dictionary once', (WidgetTester tester) async {
    await tester.runAsync(() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DictionaryInstaller installer = DictionaryInstaller(prefs: prefs, directory: dir);

      expect(installer.installedVersion, isNull);
      expect(await installer.needsInstall(), isTrue);

      final Stopwatch sw = Stopwatch()..start();
      final String path = await installer.ensureInstalled();
      sw.stop();

      expect(File(path).existsSync(), isTrue);
      expect(installer.installedVersion, await installer.bundledVersion());
      expect(await installer.needsInstall(), isFalse);
      // The sample is 4 MB; the full build must still land under 3 s on a
      // mid-range phone, which this desktop number only hints at.
      expect(sw.elapsed, lessThan(const Duration(seconds: 3)));

      final DictionaryDb dict = DictionaryDb.open(path);
      expect(dict.version, isNot('unknown'));
      expect(dict.entryCount, greaterThan(1000));
      expect(dict.collections().where((Collection c) => c.kind == 'band').length, 4);
      expect(dict.collections().where((Collection c) => c.kind == 'topic').length, greaterThanOrEqualTo(3));
      dict.close();

      // Same version: a second call is a no-op, the file is untouched.
      final DateTime before = File(path).lastModifiedSync();
      await installer.ensureInstalled();
      expect(File(path).lastModifiedSync(), before);
    });
  });

  testWidgets('the app shows the install state, then first run', (WidgetTester tester) async {
    await tester.runAsync(() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final UserDatabase userDb = UserDatabase.forTesting(NativeDatabase.memory());
      addTearDown(userDb.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            prefsProvider.overrideWithValue(prefs),
            installerProvider.overrideWithValue(DictionaryInstaller(prefs: prefs, directory: dir)),
            userDatabaseProvider.overrideWithValue(userDb),
          ],
          child: const MullApp(),
        ),
      );
      expect(find.text('Setting the dictionary down on your phone.'), findsOneWidget);

      // Let the real gunzip finish, then settle.
      for (int i = 0; i < 100 && find.text('01 / 03').evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
      expect(find.text('01 / 03'), findsOneWidget);
      // The install state cross-fades out under the first-run screen.
      for (int i = 0; i < 10 && find.byType(InstallScreen).evaluate().isNotEmpty; i++) {
        await tester.pump(Motion.sheet);
      }
      expect(find.byType(InstallScreen), findsNothing);

      // Tear the tree down here, under real timers, so the user database's
      // query streams can close before the binding checks for pending ones.
      await tester.pumpWidget(const SizedBox());
      for (int i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
  });
}
