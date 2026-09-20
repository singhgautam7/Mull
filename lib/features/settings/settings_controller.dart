import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/platform_surfaces.dart';

import '../../core/theme/palette.dart';

/// Which spelling the headword shows when the dictionary carries both.
enum Spelling { british, american }

/// How search results are drawn. RECENT is a history list and stays compact.
enum SearchStyle { card, table }

/// Device-level settings that must be known before the first frame, kept in
/// SharedPreferences. User data (notes, lists, mixes) lives in the user
/// database, not here.
@immutable
class AppSettings {
  const AppSettings({
    this.familyId = 'mull',
    this.themeMode = ThemeMode.system,
    this.amoled = false,
    this.dynamicColor = false,
    this.textScale = 1.0,
    this.searchStyle = SearchStyle.card,
    this.spelling = Spelling.british,
    this.ttsRate = 0.9,
    this.showSynonyms = true,
    this.haptics = true,
    this.wotdEnabled = false,
    this.wotdMinutes = 8 * 60 + 30,
    this.onboarded = false,
  });

  final String familyId;
  final ThemeMode themeMode;

  /// True black. Only takes effect while dark is in effect, and only for a
  /// family that ships it. The Mull tab uses it regardless.
  final bool amoled;
  final bool dynamicColor;

  /// 0.85 to 1.3, applied on top of the OS text scale.
  final double textScale;
  final SearchStyle searchStyle;
  final Spelling spelling;

  /// Pronunciation speed, 0.5 to 1.2.
  final double ttsRate;
  final bool showSynonyms;
  final bool haptics;
  final bool wotdEnabled;

  /// Minutes after midnight the word of the day arrives.
  final int wotdMinutes;
  final bool onboarded;

  ThemeFamily get family => ThemeFamily.byId(familyId);

  /// The tone to render for a given platform brightness.
  Tone toneFor(Brightness platform) {
    final bool dark = switch (themeMode) {
      ThemeMode.light => false,
      ThemeMode.dark => true,
      ThemeMode.system => platform == Brightness.dark,
    };
    if (!dark) return Tone.light;
    return amoled && family.hasAmoled ? Tone.amoled : Tone.dark;
  }

  AppSettings copyWith({
    String? familyId,
    ThemeMode? themeMode,
    bool? amoled,
    bool? dynamicColor,
    double? textScale,
    SearchStyle? searchStyle,
    Spelling? spelling,
    double? ttsRate,
    bool? showSynonyms,
    bool? haptics,
    bool? wotdEnabled,
    int? wotdMinutes,
    bool? onboarded,
  }) => AppSettings(
    familyId: familyId ?? this.familyId,
    themeMode: themeMode ?? this.themeMode,
    amoled: amoled ?? this.amoled,
    dynamicColor: dynamicColor ?? this.dynamicColor,
    textScale: textScale ?? this.textScale,
    searchStyle: searchStyle ?? this.searchStyle,
    spelling: spelling ?? this.spelling,
    ttsRate: ttsRate ?? this.ttsRate,
    showSynonyms: showSynonyms ?? this.showSynonyms,
    haptics: haptics ?? this.haptics,
    wotdEnabled: wotdEnabled ?? this.wotdEnabled,
    wotdMinutes: wotdMinutes ?? this.wotdMinutes,
    onboarded: onboarded ?? this.onboarded,
  );

  static const String kFamily = 'theme.family';
  static const String kMode = 'theme.mode';
  static const String kAmoled = 'theme.amoled';
  static const String kDynamic = 'theme.dynamic';
  static const String kTextScale = 'text.scale';
  static const String kSearchStyle = 'search.style';
  static const String kSpelling = 'dictionary.spelling';
  static const String kTtsRate = 'dictionary.ttsRate';
  static const String kSynonyms = 'linger.synonyms';
  static const String kHaptics = 'linger.haptics';
  static const String kWotd = 'wotd.enabled';
  static const String kWotdMinutes = 'wotd.minutes';
  static const String kOnboarded = 'app.onboarded';

  static AppSettings read(SharedPreferences prefs) => AppSettings(
    familyId: prefs.getString(kFamily) ?? 'mull',
    themeMode: ThemeMode.values.firstWhere(
      (ThemeMode m) => m.name == prefs.getString(kMode),
      orElse: () => ThemeMode.system,
    ),
    amoled: prefs.getBool(kAmoled) ?? false,
    dynamicColor: prefs.getBool(kDynamic) ?? false,
    textScale: prefs.getDouble(kTextScale) ?? 1.0,
    searchStyle: prefs.getString(kSearchStyle) == SearchStyle.table.name ? SearchStyle.table : SearchStyle.card,
    spelling: prefs.getString(kSpelling) == Spelling.american.name
        ? Spelling.american
        : Spelling.british,
    ttsRate: prefs.getDouble(kTtsRate) ?? 0.9,
    showSynonyms: prefs.getBool(kSynonyms) ?? true,
    haptics: prefs.getBool(kHaptics) ?? true,
    wotdEnabled: prefs.getBool(kWotd) ?? false,
    wotdMinutes: prefs.getInt(kWotdMinutes) ?? 8 * 60 + 30,
    onboarded: prefs.getBool(kOnboarded) ?? false,
  );
}

/// Overridden in `main` with the instance opened during bootstrap.
final Provider<SharedPreferences> prefsProvider = Provider<SharedPreferences>(
  (Ref ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

/// Settings are held in memory and written through, so reading the theme is
/// synchronous and a change repaints exactly the widgets that selected on it.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.read(ref.watch(prefsProvider));

  SharedPreferences get _prefs => ref.read(prefsProvider);

  Future<void> setFamily(String id) async {
    state = state.copyWith(familyId: id);
    await _prefs.setString(AppSettings.kFamily, id);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(AppSettings.kMode, mode.name);
  }

  Future<void> setAmoled({required bool value}) async {
    state = state.copyWith(amoled: value);
    await _prefs.setBool(AppSettings.kAmoled, value);
  }

  Future<void> setDynamicColor({required bool value}) async {
    state = state.copyWith(dynamicColor: value);
    await _prefs.setBool(AppSettings.kDynamic, value);
  }

  Future<void> setTextScale(double value) async {
    state = state.copyWith(textScale: value);
    await _prefs.setDouble(AppSettings.kTextScale, value);
  }

  Future<void> setSearchStyle(SearchStyle value) async {
    state = state.copyWith(searchStyle: value);
    await _prefs.setString(AppSettings.kSearchStyle, value.name);
  }

  Future<void> setSpelling(Spelling value) async {
    state = state.copyWith(spelling: value);
    await _prefs.setString(AppSettings.kSpelling, value.name);
  }

  Future<void> setTtsRate(double value) async {
    state = state.copyWith(ttsRate: value);
    await _prefs.setDouble(AppSettings.kTtsRate, value);
  }

  Future<void> setShowSynonyms({required bool value}) async {
    state = state.copyWith(showSynonyms: value);
    await _prefs.setBool(AppSettings.kSynonyms, value);
  }

  Future<void> setHaptics({required bool value}) async {
    state = state.copyWith(haptics: value);
    await _prefs.setBool(AppSettings.kHaptics, value);
  }

  /// Turning the reminder on asks the OS for notification permission first;
  /// declined, it stays off. The alarm is armed by the platform from what is
  /// saved here, so the receiver and the app never disagree about the time.
  Future<void> setWotd({required bool enabled, int? minutes}) async {
    final bool on = enabled && await PlatformSurfaces.requestNotifications();
    state = state.copyWith(wotdEnabled: on, wotdMinutes: minutes);
    await _prefs.setBool(AppSettings.kWotd, on);
    if (minutes != null) await _prefs.setInt(AppSettings.kWotdMinutes, minutes);
    await PlatformSurfaces.scheduleReminder();
  }

  Future<void> setOnboarded({required bool value}) async {
    state = state.copyWith(onboarded: value);
    await _prefs.setBool(AppSettings.kOnboarded, value);
  }

  // Per-collection view state: the lens, hidden definitions and sort persist
  // per collection, as HANDOFF 3.3 asks. Read synchronously, no rebuild.
  String lens(String scope) => _prefs.getString('lens.$scope') ?? 'cards';
  Future<void> setLens(String scope, String lens) =>
      _prefs.setString('lens.$scope', lens);
  bool hideDefs(String scope) => _prefs.getBool('hideDefs.$scope') ?? false;
  Future<void> setHideDefs(String scope, {required bool value}) =>
      _prefs.setBool('hideDefs.$scope', value);
  String sort(String scope) => _prefs.getString('sort.$scope') ?? 'name';
  Future<void> setSort(String scope, String sort) =>
      _prefs.setString('sort.$scope', sort);
  bool sortAscending(String scope) => _prefs.getBool('sortAsc.$scope') ?? true;
  Future<void> setSortAscending(String scope, {required bool value}) =>
      _prefs.setBool('sortAsc.$scope', value);
}

final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
