# App polish plan (Mull), 19 November 2026

Branch `feature/app-polish` from `main` (462ef09). Never merged. The uncommitted `pubspec.yaml`
version bump (0.3.0+3) that was in the working tree is carried on the branch.

## Conflicts between this prompt and CLAUDE.md (CLAUDE.md wins)

1. **Motion curves.** CLAUDE.md: "Motion: Perch's curves and durations." Kuber's durations are
   already identical to Mull's (90/150/220/240/260/180/140 ms), so nothing changes there. Mull keeps
   `Motion.spring` (easeOutBack) and `Motion.decelerate` (easeOutCubic) from Perch; Kuber's springs,
   `curveEffects` and levels are added as new tokens (nothing Perch defines is overwritten).
2. **No new packages without justification.** Kuber's Auto level uses `device_info_plus`. Mull
   reads total RAM and `isLowRamDevice` through its existing `PlatformChannels` method channel
   instead (a few lines of Kotlin, no package). The perf harness adds `integration_test` and
   `flutter_driver`, both from the Flutter SDK (dev only), justified in decisions.md.
3. **Theme families.** CLAUDE.md lists sixteen families. Adding Kuber's saffron, sky and ruby
   makes nineteen; CLAUDE.md is updated to say so. Kuber's "Signature" is Kuber's own brand
   blue; Mull's signature family is `mull`, so it maps to that and is not added (logged).
4. **The word "reel".** The prompt says "reel card"; Mull calls it the word card on the Mull
   tab. No code, string or file uses the word.
5. **Assets.** `assets/db/` and `tools/build_dictionary/` are untouched (prompt and CLAUDE.md agree).
6. **Shared widget names.** CLAUDE.md fixes one implementation per need (`SegmentedToggle`,
   `PillChip`, `AppIconButton`, `AppHeader`, `LoadingHairline`...). Kuber's behaviour is ported
   into those widgets; Kuber's names (`KuberButtonGroup`, `KuberAppBar`) are not introduced.

## Run order

1. Audit (done, `audit.md`).
2. Phase 1, foundation (main agent): motion tokens, motion kit, level and haptics, settings keys.
3. Phase 2a (parallel): W1 shared widgets, W2 header and nav, W3 theme, W4 icon + splash + size,
   P perf baseline (in a separate worktree at `main`, so numbers are pre-change).
4. Phase 2b (parallel, after W1 + W2): F1 define (M1), F2 search and lists (M2 to M5),
   F3 collections, Mull tab, quiz, stats (M7), F4 settings, More, About (E, M6).
5. Integrate, review subagent (Part H), fix, one full test pass, reports, commit.

## File owners (no two owners edit the same file)

| Owner | Files |
|---|---|
| Main agent (phase 1, then integration) | `lib/core/theme/tokens.dart`, `lib/core/motion/**` (new), `lib/features/settings/settings_controller.dart`, `lib/app.dart`, `lib/main.dart`, `android/.../kotlin/PlatformChannels.kt`, `lib/core/utils/platform_surfaces.dart` (device probe only; F1 owns it in 2b), `test/motion/motion_level_test.dart`, `CLAUDE.md` (except the build commands), `CHANGELOG.md`, `specs/app-polish/*.md` |
| W1 shared widgets | `lib/shared/widgets/*` except `app_header.dart`, `family_card.dart` and files W2 / F1 create; `test/motion/primitives_test.dart`, `test/ui/shapes_test.dart` |
| W2 header and nav | `lib/shared/widgets/app_header.dart` (+ any new header file it creates), `lib/app/*`, `lib/core/router/router.dart`, `lib/features/settings/floating_header_sheet.dart` (new), `test/ui/header_test.dart`, `test/ui/nav_tabs_test.dart` |
| W3 theme | `lib/core/theme/{palette,app_theme,oklch,typography}.dart`, `lib/features/settings/theme_screen.dart`, `lib/shared/widgets/family_card.dart`, `test/theme/*` (new goldens in `test/theme/goldens/`) |
| W4 icon, splash, size | `android/**` except `PlatformChannels.kt`, `pubspec.yaml`, `assets/icon/**`, `assets/fonts/**`, CLAUDE.md "Commands" and "Release" blocks, `specs/app-polish/size.md` |
| P perf | A worktree at `main` for the baseline; `integration_test/**`, `test_driver/**`, `specs/app-polish/performance.md` (numbers only) |
| F1 define (M1) | `lib/shared/widgets/definable_text.dart` (new), `lib/features/linger/word_card.dart`, `lib/features/dictionary/{word_sheet,idiom_sheet,arrival_sheet}.dart`, `lib/define_main.dart`, `lib/core/utils/platform_surfaces.dart`, `lib/core/database/dictionary_db.dart`, `test/features/define_*` |
| F2 search and lists (M2 to M5) | `lib/features/dictionary/{search_screen,add_to_list_sheet,note_sheet}.dart`, `lib/features/home/**`, `lib/core/database/user_repository.dart`, `test/features/search_*`, `test/features/add_to_list_*` |
| F3 collections, Mull tab, quiz, stats (M7) | `lib/features/collections/**`, `lib/features/linger/**` except `word_card.dart`, `lib/features/quiz/**`, `lib/features/stats/**`, `lib/core/providers.dart`, `test/linger/*`, `test/features/m7_*` |
| F4 settings, More, About (E, M6) | `lib/features/settings/**` except `settings_controller.dart`, `theme_screen.dart`, `floating_header_sheet.dart`; `PRIVACY_POLICY.md` (read only unless a string is wrong) |
| Review | read only |

Shared code with one owner: motion kit (main agent), common header (W2), theme code (W3).
Screens adopt the header with W2's documented API; each screen is converted by its feature owner.
