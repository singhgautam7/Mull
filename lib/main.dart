import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/database/dictionary_installer.dart';
import 'core/database/user_db.dart';
import 'core/providers.dart';
import 'features/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Open what the first frame needs before drawing it: settings decide the
  // theme, the installer decides whether this launch is a first run.
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final DictionaryInstaller installer = await DictionaryInstaller.forApp();
  final UserDatabase userDb = UserDatabase();

  runApp(
    ProviderScope(
      overrides: <Override>[
        prefsProvider.overrideWithValue(prefs),
        installerProvider.overrideWithValue(installer),
        userDatabaseProvider.overrideWithValue(userDb),
      ],
      child: const MullApp(),
    ),
  );
}
