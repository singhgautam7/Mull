# Audit (Part A + A7), 19 November 2026

Read-only findings from seven parallel audits. Kuber = `/Users/gautam/Desktop/Projects/Personal/Kuber - Expense Manager/kuber` at b1abb70 (v7.0.0 merged).

## A1 Theme
- Mull: Light / Dark / System (`theme.mode`), AMOLED switch (`theme.amoled`, gated to 8 of 16 families), dynamic colour (`theme.dynamic`), 16 families (`theme.family`), text size slider 0.85 to 1.3 (`text.scale`). Keys in `settings_controller.dart:102-114`.
- No theme-change animation (MaterialApp swaps instantly). No Expressive colours toggle.
- Kuber: mode via `KuberButtonGroup`, Pure black on every family (disabled in Light), Expressive colours (on: tinted surfaces; off: one neutral ramp for surface/container/outline/onSurface/inverse roles; accents never change), 5-step text size `[0.85, 0.925, 1.0, 1.15, 1.30]`, theme ripple (snapshot + growing even-odd hole, 800 ms Expressive / 500 ms Subtle on easeInOutSine, Off 90 ms fade).
- Kuber has, Mull lacks: Signature (Kuber's own brand blue), saffron, sky, ruby; Expressive colours; ripple; button-group morph + check draw-in; stepped text size.
- Mull has, Kuber's picker lacks: azure, meadow, coral (Kuber retired them into other families).
- Hardcoded colours: only `theme_screen.dart:60` `Color(0xFF000000)` (AMOLED swatch). PDF colours in `shelf_export_sheet.dart` are print colours (acceptable). Everything else is `Colors.transparent`.

## A2 Motion and haptics
- Mull `Motion` (tokens.dart): durations identical to Kuber's (90/150/220/240/260/180/140), curves `easeOutBack` / `easeOutCubic`, binary reduced flag. No springs, no levels.
- Animations: nav_shell (2 controllers), welcome, snackbar, quiz (9 Animated*), header, chips, SegmentedToggle thumb (240 ms easeOutBack), transitions.dart (`mullPage` fade + scale .96).
- Haptics: switch exists, key `linger.haptics`, default on. Direct calls: `linger_screen.dart:234,358`, `collection_screen.dart:539`. No helper.
- No `CircularProgressIndicator` anywhere; one `LinearProgressIndicator` (snackbar timer).
- Raw `InkWell` 33 in 16 feature files, raw `IconButton` 23 in 8 files.
- Kuber kit deps: `lib/core/motion/*` depends on `KuberMotion`/`KuberShape` (app_theme.dart), `prefs_keys.dart`, riverpod, shared_preferences, go_router (container transform), and `device_info_plus` (Auto's RAM probe, in app.dart).

## A3 Nav, tabs, chips
- Mull nav (`app/nav_bar.dart`): 5 tabs Home, Mull, Shelves, Search, More. No sliding indicator (each item fills its own `AnimatedContainer`), no weight shift, no haptic.
- Tap on active tab (`router.dart:185-199`): Search refocuses the field; every other tab `goBranch(initialLocation: true)` (pops to root, no scroll).
- No scroll controllers on tab roots (bare ListView / CustomScrollView).
- Single-select: `SegmentedToggle` (settings spelling, theme mode, welcome, search Words/Phrases, share sheet) and `PillChip` groups (welcome minutes, mix presets, seen policy, shelves sort and filter). No multi-select chip group exists in Mull.
- Kuber nav: one painted indicator, two edge springs (leading springFast, trailing springDefault) so it stretches; label width/padding on defaultCurve.clamped; `AnimatedWeight` 500 to 700; tick haptic; tap on active tab walks to the branch's vertical Scrollable and animates to 0 (250 + 40 per screen, cap 800 ms, easeInOutSine).
- Kuber button group: selected radius 12, unselected height/2; 150 ms on curveEffects; press widens 15 %, corner to 8; check grows 0 to 18 dp on springStandard; weight 600 to 700.

## A4 Header and screens
- `AppHeader` is stateless, sits in a Column above the scroll view; `CollapseOnScroll` restyles it at 24 px (no hysteresis). Not sticky, no pill.
- Collapse users: Home, Shelves. Plain users: More, SettingsScaffold (Settings, Theme, Data, Export, Import, info pages, Stats), Quiz, Search (field + toggle pinned below), Add to shelf (field pinned), Import words, Shelf stats, Saved mixes, Collection (table header pinned in table view; selection bar replaces header).
- No AppHeader: Mull tab, welcome, install, debug.
- Kuber `kuber_app_bar.dart`: pill at >= 32 dp, back at <= 8 dp (24 dp gap); pill 56 tall, radius 28, margin 12, top 8; hide after 16 dp down, show after 8 dp up; stop delay 300 ms; one NotificationListener; setState only on state change. Rule (v7.0.0-c decisions 12, 13): only the header is sticky, nothing docks under it.

## A5 Settings and More
- More: General (Shelves, Mixes, Settings, Stats), Your data (Permissions, Data), About Mull (Privacy, Dictionary info, About).
- Settings: Appearance (Theme, Search results, Text size), Mull tab (Show synonyms row, Haptics on swipe), Dictionary (Spelling shown, Pronunciation speed), Word of the day (switch, Arrives at). Theme page: mode, AMOLED, families, wallpaper.
- Duplicates: Privacy and Dictionary info appear on More and in About's Legal group; theme summary on More and Settings.
- About exists (`info_screens.dart:79`): letter, pillars, version, Legal links, developer links (singhgautam.com, More apps, Rate Mull).
- No licences page. `meta.source_attribution` is never read; Dictionary info text is hardcoded.
- Kuber voice: sentence case, titles 1 to 4 words, subtitles 3 to 8 words with no full stop, addresses "you/your", app in third person, letter is the only first person. Rows: 40 dp tinted icon tile (radius 12), titleMedium + bodyMedium subtitle, chevron.

## A6 Performance hotspots
- Lists are lazy where data-sized. Bounded child lists: search recents, home sections, bands.
- No per-frame setState. `collection_screen.dart:236` rebuilds the whole screen when the floating buttons toggle (bounded).
- Long builds: `collection_screen.dart:559` (397 lines), `collections_screen.dart:51` (293), `quiz_screen.dart:199` (273).
- Dictionary reads in `build()` (break the CLAUDE.md rule): `home_screen.dart:107` (examples), `:149` (byKey per recent chip), `word_sheet.dart:70-96, 194, 234, 250, 288`, `idiom_sheet.dart:32`.
- `flutter_animate` has zero imports: remove. `ErrorStateView` is unreferenced.

## A7 Part M
- Definition text: word card `word_card.dart:266`, word sheet `word_sheet.dart:551`. No detail page (the sheet is the detail). None selectable today; no gestures on the text. Table rows and search rows are out of scope.
- Define path: `PlatformSurfaces.handleIncomingIntent` (`platform_surfaces.dart:189`) uses `DictionaryDb.matchWords` (exact, alias, lemma, trigram). Search uses `DictionaryDb.search` (exact, alias, prefix, FTS, trigram). Sheets stack (`useRootNavigator: true`).
- Add-to-list: from search, "From my reading" is pre-ticked and written on open (`add_to_list_sheet.dart:56-57`). Each tick writes immediately; Done only pops. Callers: word sheet, home, Mull tab overflow. No saved-state icon for lists (bookmark has one).
- Search rows: `SearchResultRow` / `SearchResultCard` take an optional `trailing`.
- History: Drift `RecentSearches` (query PK, at), `recordSearch`, `recentSearches(limit: 12)`; no delete.
- Mull tab: `_load` then queue build, first card served before hydration; `LoadingHairline` only, no skeleton card. Shelves: `Delayed` + `SkeletonCard/SkeletonRow` while keys settle.
- Earlier performance passes: two, recorded in CLAUDE.md (September and 29 September 2026), all listed items done; three items open by design.
- Snackbar: `AppSnackbar.info` already draws a check icon (reads as success).
