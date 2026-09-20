import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rule D2. The shipped `assets/db/dictionary.db.gz` is gunzipped and copied
/// into application support on first run. A decompress-and-copy, never a
/// parse-and-insert. The bundled version travels beside it as
/// `assets/db/dictionary.version`, so deciding whether to reinstall never
/// needs the archive opened.
class DictionaryInstaller {
  DictionaryInstaller({
    required this.prefs,
    required this.directory,
    AssetBundle? bundle,
  }) : bundle = bundle ?? rootBundle;

  final SharedPreferences prefs;

  /// Where dictionary.db lives. Application support in the app; a temp
  /// directory in tests.
  final Directory directory;
  final AssetBundle bundle;

  static const String assetDb = 'assets/db/dictionary.db.gz';
  static const String assetVersion = 'assets/db/dictionary.version';
  static const String prefsKey = 'dict_version';

  String get dbPath => p.join(directory.path, 'dictionary.db');

  static Future<DictionaryInstaller> forApp() async {
    final (SharedPreferences prefs, Directory dir) = (
      await SharedPreferences.getInstance(),
      await getApplicationSupportDirectory(),
    );
    return DictionaryInstaller(prefs: prefs, directory: dir);
  }

  /// The version this build of the app carries.
  Future<String> bundledVersion() async =>
      (await bundle.loadString(assetVersion)).trim();

  /// The version installed on this device, or null before the first run.
  String? get installedVersion =>
      File(dbPath).existsSync() ? prefs.getString(prefsKey) : null;

  /// True when the bundled version is newer than what is on the device.
  Future<bool> needsInstall() async =>
      installedVersion != await bundledVersion();

  /// Installs if needed and returns the path of the ready database.
  Future<String> ensureInstalled() async {
    final String bundled = await bundledVersion();
    if (installedVersion == bundled) return dbPath;
    await _install(bundled);
    return dbPath;
  }

  Future<void> _install(String version) async {
    final ByteData data = await bundle.load(assetDb);
    // Handed over, not copied: the 50 MB asset is moved into the worker.
    final TransferableTypedData packed = TransferableTypedData.fromList(
      <TypedData>[
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      ],
    );
    await directory.create(recursive: true);
    // Written to a sibling and renamed, so a crash mid-way never leaves a
    // half-written dictionary.db behind for the next launch to open. The
    // sibling's name is unique per run: the app and the define sheet are two
    // isolates that can both find the dictionary missing on a fresh install.
    final String tmp = '$dbPath.${DateTime.now().microsecondsSinceEpoch}.part';
    // Inflating tens of megabytes is CPU work; it happens off the UI isolate
    // so the first-run screen keeps animating. Fed in slices so the inflater
    // never holds more than a slice and its output at once.
    await Isolate.run(() async {
      final Uint8List bytes = packed.materialize().asUint8List();
      const int slice = 1 << 20;
      final IOSink sink = File(tmp).openWrite();
      await Stream<List<int>>.fromIterable(<List<int>>[
        for (int i = 0; i < bytes.length; i += slice)
          Uint8List.sublistView(bytes, i, min(i + slice, bytes.length)),
      ]).transform(gzip.decoder).pipe(sink);
    });
    await File(tmp).rename(dbPath);
    await prefs.setString(prefsKey, version);
  }
}
