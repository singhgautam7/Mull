# App polish: code prompt, v2 (shared across apps)

This prompt brings the Kuber look, motion and performance rules to one app. Run it once per app.

Version 2 adds what the first run (Mull) got wrong and needed two more passes to fix: the theme ripple was missing on some screens, pills and toggles looked wrong, buttons did not all use the shared widget, a search field was hidden on every real phone, first visits to tabs were slow, and the app was called done without anyone looking at it on a device.

Parts:
- **0:** the reference map (Kuber, and Mull for the fixed versions)
- **A:** audit
- **B:** the motion system
- **C:** the theme page and the theme ripple
- **D:** the bottom nav, tabs and selected shapes
- **E:** settings and the More page
- **F:** the sticky pill header, including search
- **G:** accessibility
- **H:** performance and code quality
- **I:** testing, and looking at the app on a device
- **J:** app icon and splash screen
- **K:** app size
- **L:** the shared component contract (buttons, chips, toggles, switches, menus, sheets, search, rows, form pages)
- **M:** welcome and setup
- **N:** faults to avoid (from Mull). **Read this before you write any code.**

Run it in **one pass**:
1. Audit.
2. Implement everything.
3. Integrate.
4. Review (Part H).
5. One full test pass (Part I), **including the device walkthrough**.
6. Fix what fails, and rerun only the affected checks.

Don't stop for review between parts. **Don't call the work done until the device walkthrough in I3 has passed.** A green test suite is not a device check.

**Before you use this prompt:** replace `<APP_PATH>` with this app's folder, and delete any part that doesn't apply (for example M, if the app has no welcome flow).

---

## Before you start (main agent)

- Read the global `~/.claude/CLAUDE.md` and this app's `CLAUDE.md`, and follow both. **If either conflicts with this prompt, `CLAUDE.md` wins**, unless this prompt names the exact rule it overrides. Note the conflict in `plan.md`.
- Read the Kuber files in Part 0. **Kuber is the source of truth** for tokens, motion values, theme, nav, shapes, header and settings behaviour. Copy its values from the code and `specs/design`. Don't invent new values, and don't guess numbers from memory.
- **Exception:** Part N lists faults that exist in Kuber itself. For those, use the fixed version in Mull.
- If this app has a performance spec (`specs/performance.md` or similar), follow it. If it doesn't, create the baseline in `specs/app-polish/performance.md` using the rules in Part H.
- **Branch:** create `feature/app-polish` from the main branch. **Never merge.**
- Write all notes and reports in `specs/app-polish/`.
- **Stack:** Kuber and Mull are Flutter.
  - If this app is also Flutter, reuse their code, with names adapted to this app.
  - If this app is native Android (Kotlin with Jetpack Compose), port the **behaviour and the values**, not the Dart code. Use the matching Material 3 Compose component for each Kuber primitive.
  - Log every mapping in `decisions.md`.
- **Copying widgets is not enough on its own.** Kuber's common widgets depend on its motion tokens, the motion level provider, the haptics helper, the theme tokens and the shape tokens. Copy those with the widgets, or port them. The audit (A2) must list every dependency before any copy.
- **Colour roles:** Kuber reads `ColorScheme` roles. If this app has its own roles, write the mapping table in `decisions.md` **before** porting any widget, and check it by eye in light, dark and Pure black. A wrong mapping is how a selected toggle ends up looking disabled (Part N3).
- **Subagents:** run read-only audits in parallel. Then write `plan.md` with a **list of files each implementation subagent owns**. No two subagents edit the same file. Shared code has one owner. Keep reports short, with no file dumps. Review each subagent's diff yourself before you integrate it.

---

## Part 0: Reference map

**Kuber:** `/Users/gautam/Desktop/Projects/Personal/Kuber - Expense Manager/kuber` (read-only)

**Mull:** `/Users/gautam/Desktop/Projects/Personal/Mull` (read-only, use the branch that holds the second polish pass: `feature/app-polish-2`, or `main` once it is merged). Mull is a finished port of Kuber's kit, so for a Flutter app it is often the easier file to copy from. Kuber still wins on look and values.

| Topic | Kuber | Mull's port, where it fixes or adds something |
|---|---|---|
| Motion tokens | `KuberMotion` in `lib/core/theme/app_theme.dart` | `lib/core/theme/tokens.dart` |
| Motion level | `lib/core/motion/motion_level.dart` (not its Motion setting, B2) | `lib/core/motion/motion_level.dart` (**use this one**) |
| Press | `lib/core/motion/pressable.dart` | same path |
| Other primitives | `lib/core/motion/`: `spring_curve`, `animated_weight`, `animated_list`, `expand_collapse`, `container_transform`, `cross_fade`, `shimmer`, `chart_draw_in`, `route_styles`; `lib/shared/widgets/`: `animated_amount`, `kuber_shape_loader`, `kuber_skeleton` | `lib/core/motion/` |
| Haptics | `lib/core/motion/kuber_haptics.dart` | `lib/core/motion/haptics.dart` |
| Theme ripple | `lib/core/motion/theme_ripple.dart`, its use in `lib/app.dart` and `theme_screen.dart` | same path, plus the welcome setup page |
| Theme | `lib/core/theme/theme_families.dart`, `kuber_tokens.dart`, `lib/features/settings/screens/theme_screen.dart` | |
| Button | `lib/shared/widgets/app_button.dart` | same path |
| Icon button | `lib/shared/widgets/app_icon_button.dart` | same path (its semantics node carries the tap) |
| Chips | `lib/shared/widgets/kuber_chips.dart` | `lib/shared/widgets/chips.dart` (**use this one**, N1 and N2) |
| Single choice | `kuber_button_group.dart`, `kuber_segmented_control.dart` | `SegmentedToggle` in `chips.dart` |
| Form page with a sticky submit | `KuberFormScaffold` in `lib/shared/widgets/kuber_form_widgets.dart` (as in `add_transaction_screen.dart`, **not** the older `KuberSaveButton` with its bar and divider) | `lib/features/collections/shelf_edit_screen.dart` |
| Switch rows | `settings_pages.dart`, `switchTheme` in `app_theme.dart` | `switchTheme` in `lib/core/theme/app_theme.dart` |
| Menu | `lib/shared/widgets/kuber_menu.dart` | `lib/shared/widgets/app_menu.dart` (**use this one**, N4) |
| Search bar | `lib/shared/widgets/kuber_search_pill.dart` | `SearchField` in `fields.dart` (**use this one**, N6) and `HeaderSearchBar` in `app_header.dart` |
| Sheets, rows, snackbars | `kuber_bottom_sheet.dart`, `kuber_list.dart`, `timed_snackbar.dart` | `app_bottom_sheet.dart` (the held slide, L6) |
| Icon and colour picker | `icon_color_picker_sheet.dart`, `category_icon.dart` | |
| Bottom nav | `lib/shared/widgets/kuber_nav_bar.dart` | `lib/app/nav_bar.dart` |
| Tab switch and warm tabs | `lib/shared/widgets/app_scaffold.dart` | `lib/app/nav_shell.dart` (**use this one**, H3) |
| Header | `lib/shared/widgets/kuber_app_bar.dart` | `lib/shared/widgets/app_header.dart` |
| Settings and More | `settings_pages.dart`, `lib/features/more/screens/more_screen.dart`, `about_screen.dart`, `permissions_screen.dart` | |
| Welcome | `lib/features/onboarding/` | `lib/features/onboarding/` |
| Design | `specs/design`, `specs/v7.0.0*`, `specs/design-system.md` | |
| Performance | `specs/performance.md`, `specs/v7.0.0-c/performance.md` | `specs/app-polish-2/performance.md`, `integration_test/perf_test.dart`, `integration_test/perf_feel_test.dart` |

If a path has moved, search for the concept.

---

## Part A: Audit (read-only)

Spawn these Explore subagents in parallel. Each returns a short list with file paths and line numbers. No file dumps.

- **A1 Theme:** this app's theme options, colour tokens, accents, Pure black, Expressive colours, font size, and how the theme is stored and applied. Compare with Kuber's theme page. List every colour Kuber has that this app lacks, and the reverse. **List every control in the app that changes the theme, on any screen** (theme page, welcome, settings, quick toggles): each one needs the ripple.
- **A2 Motion and haptics:** every existing animation, transition and haptic call, and the switch that controls haptics.
- **A3 Nav, tabs and chips:** the bottom nav, every tab row and segmented control, every chip group and filter row, and what a tap on the active tab does today.
- **A4 Header and screens:** the common header, every screen that uses it, which screens are sticky today and how, which buttons each header shows, and every screen whose sticky control is a search field.
- **A5 Settings and More:** the settings and More pages, how many settings each has, any duplicates, where each setting lives, and the description under each row.
- **A6 Performance hotspots:** the heaviest lists, screens that rebuild on scroll, per-frame work, long build methods, synchronous work in a first build, and unused code and assets.
- **A7 Every tappable thing.** List every plain `InkWell`, `GestureDetector`, `IconButton`, `TextButton`, `FilledButton`, `OutlinedButton`, `ElevatedButton`, `FloatingActionButton`, `ChoiceChip`, `FilterChip`, `ActionChip`, `SegmentedButton`, `Checkbox`, `Radio`, `Switch`, `PopupMenuButton`, `showMenu`, `showModalBottomSheet`, `showDialog`, `AlertDialog`, `SnackBar` and `TextField` (or the Compose equivalents) in feature code, with file and line, and the shared widget in Part L that replaces it. This list is the checklist for Part L.
- **A8 Read-only and empty states:** every place a control is drawn but can't be used. A control the user can never use on that screen is removed, not greyed out.

The main agent writes `audit.md` (the findings) and `plan.md` (the file owners). **One owner each** for the motion kit, the common header, the theme code and the shared widgets.

---

## Part B: Motion system

**B1. Tokens.** Copy Kuber's motion tokens into this app's motion file. Add only what's missing. Keep Kuber's rules:
- **Springs for movement only.** Position, scale, size and shape may overshoot slightly. **Opacity and colour never overshoot.**
- Most motion finishes in under 300 ms. **Nothing blocks the next tap.**
- **Interruptible:** a change mid-animation continues from the current value and speed. It never jumps or restarts.

**B2. Motion level (no user setting).** Three levels, picked by the app. **Don't add a Motion setting**, even though Kuber has one, and remove it if this app has it: a stored "Off" made every animation in Mull disappear and looked like a regression.
- **Off** when the phone's "Remove animations" setting (or an accessibility navigation service) is on: no movement, cross-fades of 90 ms at most.
- **Subtle** on low-RAM phones (under 4 GB, or when Android reports a low-RAM device): no overshoot and no shape morphing. Page slides and sheets still move.
- **Expressive** otherwise: the full system.
- The check runs **once, off the startup path**, and its result is cached. It must not delay the first frame.
- Ignore any level an older version stored.
- Expose the level through one provider, plus a cheap check for widgets. **Every animation reads the level.**
- **Emulators with 2 GB resolve to Subtle.** Check motion on an AVD or phone with more RAM, or with the cached device class set to normal, and say which level you looked at.

**B3. Motion kit.** Build each primitive **once**, with all three levels built in:
- **Pressable (touch and hold).** This is what makes the app feel like Kuber, so check it first.
  - Scale while pressed: card and row 0.98, chip and FAB 0.96. Subtle: 0.99 for cards, rows and buttons only. Off: none. At Expressive, buttons and icon buttons morph instead of scaling.
  - **Corner morph while held:** buttons go from pill to 8 dp (40 dp button) or 12 dp (56 dp button), **icon buttons and FABs go from circle to a 12 dp squircle**, and back on release. Expressive only.
  - Down on `springFast`, release on `springFast` (buttons) or `springDefault` (cards and rows). A drag past the touch slop lets go.
  - Material's own shape animation must be off (`animationDuration: Duration.zero`), or the morph is delayed and looks missing.
  - Fire the haptic here.
- **Button group:** the pressed button widens by 15% and its neighbours squeeze.
- **Lists:** insert (fade in, grow from about 92%, expand in height), remove (fade out and collapse), reorder (lift, follow the finger, settle), and first-load stagger. **Stagger 6 items at most, never while scrolling.** Keep lists lazy.
- **Expand and collapse:** the chevron rotates on the same spring. Content that appears keeps the left edge of what is already there.
- **Container transform:** a card or row opens into its page or sheet. Use Kuber's timing.
- **Loader:** a shape-morphing loading indicator in place of circular spinners. It appears only after 120 to 250 ms. A loader that flashes is worse than none.
- **Skeleton to content:** a cross-fade.
- **Rolling numbers:** for amounts and counts that change.
- **Chart draw-in:** only if this app has charts.

Each primitive:
- **animates only transform, opacity, clip and shape**
- uses a repaint boundary **inside** any transition that moves a large subtree
- is interruptible
- never blocks input
- **costs nothing when idle**
- has widget tests at each level

**B4. Haptics.** One helper maps each interaction to a haptic, as Kuber does: a light tick on press, a medium tick on long press, a tick when a drag crosses a threshold, a confirm on save. **It respects the existing haptics switch.** One tap gives one tick: a control that ticks by itself is not wrapped in code that ticks again. Replace the scattered haptic calls with it.

**B5. Rollout.** Go through the A7 list and replace every entry with its Part L widget. Most of the coverage should come from the common widgets, not from per-screen code.
- **Snackbars:** keep their timer, close button and swipes. Restyle only the motion.
- Keep existing page transitions unless they clash with the new system.
- **No new gestures.** **No change to logic, arithmetic or data.**
- When done, grep for the A7 widget names in feature code. Every remaining hit is listed in `decisions.md` with a reason.

**B6. Font (only if needed).** If Kuber uses one variable font for the weight shift on the selected tab, and this app uses several static weights of the same font, switch to the variable font. Check that every weight the app uses renders the same. If the app doesn't need it, skip it and log why.

---

## Part C: Theme page and theme ripple

Match Kuber's theme page (read the Kuber code and `specs/design`).

- **Options:** Light, Dark, System, **Pure black**. **Expressive colours on and off.** Accents as Kuber shows them.
- **Keep both sets of colours.** If this app has colours Kuber lacks, **keep them**. If Kuber has colours this app lacks, add them. Don't remove a colour from either side. Log every colour you add or keep as an exception in `decisions.md`.
- **Every colour comes from tokens.** No colour is hardcoded in a widget.
- Store the choice through the existing settings provider.

**C1. Theme ripple (required).** Port `theme_ripple.dart` and wire it exactly as Kuber does:
- Wrap the whole app **once**, above the navigator, so sheets and dialogs are covered.
- Set the app's own theme animation to zero, so no implicit theme tween runs under the ripple.
- On a change: snapshot the current frame, apply the change under it, **wait two frames**, then reveal the new theme through a circle that grows from **where the finger went down** to the farthest corner. 800 ms ease-in-out-sine at Expressive, 500 ms at Subtle, a 90 ms cross-fade at Off.
- Keep the pointer-down position in state. A local variable in `build()` is reset by a rebuild between down and up.
- **Every control found in A1 goes through it:** the mode toggle, Pure black, Expressive colours, accents, wallpaper colours, the welcome setup page, and any quick toggle.
- Test it by recording the screen and looking at the frames: the circle starts at the finger and sweeps evenly. A flash or a hard cut is a fail.

**C2.** Check every combination: light, dark and Pure black, with Expressive colours on and off, with a few accents, at the largest font size.

---

## Part D: Bottom nav, tabs and selected shapes

**D1. Bottom nav.** Copy Kuber's nav animation:
- the selected indicator slides with a slight stretch
- the icon and the label change together
- the label weight shifts (with the variable font from B6, if applied)
- **Tapping the active tab scrolls that tab's list to the top**, with the standard scroll animation. If it's already at the top, do nothing. **Don't pop nested pages** unless Kuber does that.
- **No long press on tabs.** No new gestures.
- A light haptic on tap, as in B4.

**D2. Tab switch: Kuber's page slide (required).** Switching tabs moves the whole page sideways, both pages side by side.
- 300 ms, ease in and out, the direction follows the order of the tabs. A far tab slides in from next door, not through the tabs between.
- A sideways drag follows the finger: released short it returns, flung or past half it switches. Rows that scroll sideways and vertical lists win over it.
- A new tap mid-slide carries on from where the pages are. Nothing jumps.
- **The clock starts after the frame that builds the page**, so a first visit doesn't lose the start of the slide.
- Both pages are finished layers (a repaint boundary inside the moving part). Nothing is laid out again during the slide. The page left behind goes offstage and keeps its place.
- The same at Subtle. Off switches at once.
- A page that has to load shows its own shape or a skeleton while it slides (the shape loader only after 250 ms). It's never blank.
- Copy Mull's `BranchStack` (`lib/app/nav_shell.dart`). Kuber's `PageView` is the look to match, but it lays out a third page in the frame of a far jump and can't prepare a page ahead of its first visit.
- **Pages pushed on top** use Kuber's page transition, with the same rule about the clock.

**D3. Selected shapes (the M3 rule).**
- **Tab rows and single-choice groups:** the **selected** one is a **12 dp squircle in the accent** (`primary` / `onPrimary`). The others are pills on a container fill. The shape morphs on selection, on a spring. At Subtle, it only fades.
- **Filter chips, single or multi-select:** selected chips are a 12 dp squircle in the selected container colour. Unselected chips are outlined pills.
- A selected control never takes a surface fill with an outline. That looks disabled.
- Use Kuber's shape values. Don't use other radii.

---

## Part E: Settings and More page

Kuber's pattern: group settings into clear pages (for example Look, Behaviour, Data, About), and **every setting lives on exactly one page**.
- If this app already follows this pattern, log "no change needed" and skip the regrouping. Still do the row rules below.
- Otherwise, follow Kuber's grouping. **Keep every stored key and every behaviour.**
- The new **Floating header** and **Show the pill** settings go under **Look**, next to Theme. There is no Motion setting (B2).

**Row rules (every row on More and Settings):**
- The same structure on every row: a 40 dp icon tile (12 dp corners), the title, **the description under the title**, and the chevron, switch or value at the end. Never the description on the right on some rows.
- **A description says what the row holds**, in 3 to 8 plain words with no full stop. It is not the current value of one setting inside. For example Settings reads "Look, haptics, words, reminders", not the name of the theme.
- Rows use Pressable. Section headers line up with the card edge, and a trailing action ("See all") ends exactly at the content edge.
- A destination that already has its own tab doesn't get a More row as well.
- On/off settings use the switch from L4.

---

## Part F: Sticky pill header

Match Kuber's floating header.

**F1. Behaviour.**
- On scroll, the header turns into a **pill** near the top. Scroll back up, and it returns to the full header.
- Use Kuber's thresholds (pill at 32 dp, back at 8 dp) and geometry (12 dp from each side, 8 dp under the status bar, 56 dp tall, radius 28, container fill, 1 dp outline, the gradient scrim under the status bar). The gap between the two positions means it never flickers.
- **The pill holds exactly what the header holds:** back or close, the title, search, overflow and any other action. **Reuse the same button widgets.**
- **Clean round trip:** after going to the pill and back, the header sits exactly in its rest position, with no leftover margin, radius or offset. Write a test for this.
- **Interruptible:** a change of direction retargets from the current value.

**F2. Settings** (under Look):
- **Floating header:** on by default. When it's off, **no page's header is sticky**. Every header scrolls away with the content.
- **Show the pill:** three choices, **Always** (default), **When scrolling up**, **When scrolling stops**. Disabled when Floating header is off.
- A live preview for each choice, following the Motion level. The preview only animates while it's visible.

**F3. A screen whose sticky control is a search field** (a Search tab, a picker):
- At rest: the same title header as every other tab, then the search bar, then the filter pills. The bar has the same size and position as the search bar on the other tabs.
- On scroll the title, the filters and the section titles scroll away, and **the search bar itself becomes the pill**: the same margins, height, radius, fill, outline, scrim and Show the pill setting as F1. Not a full-width strip with an opaque background.
- The field keeps its element, focus and text through the morph. Floating header off: it scrolls away too.
- Use Mull's `HeaderSearchBar`.

**F4. Performance (must hold).**
- Read the two settings **once**, into the existing settings provider and cache. **Nothing reads storage during scroll or on page open.**
- Header widgets listen only to these fields (for example with `select`), so they rebuild only when a setting changes.
- **One scroll listener**, inside the common header. It updates a small state (rest, pill, hidden) **only when a threshold is crossed or the direction changes**, never on every frame. The page content never rebuilds because of it.
- The morph animates only transform, opacity, clip and shape, inside a repaint boundary.

**F5. Accessibility.** TalkBack reads the same buttons, in the same order, in the pill as in the header. A hidden pill is not focusable. Touch targets stay at least 48 dp.

---

## Part L: Shared component contract

Each component is built **once** and used everywhere. "Looks the same" is not enough: the A7 list must be empty of raw widgets, apart from the logged exceptions. For each component, check these against Kuber **on the device**, pressed and held, in light and dark.

**L1. Button.** `AppButton`: pill, 56 dp or 40 dp tall, Kuber's types (primary, normal/tonal, outline, danger, dotted), icon 20 dp with an 8 dp gap, disabled 12% / 38%, loading with the shape loader, colour fades on `fxFast`, the press morph from B3. A label never truncates at the default font in the width it is given. No raw `FilledButton`, `OutlinedButton` or `TextButton`.

**L2. Icon button.** `AppIconButton`: a 40 dp disc with a 20 dp glyph in a 48 dp target, kinds standard, tonal, filled, plain and danger, **circle to squircle while held**, icon swap with scale and fade. A label is required. The semantics node carries the tap action, so TalkBack can press it.

**L3. Pills (chips).**
- 32 dp tall in a **48 dp hit region**. Unselected: an outlined stadium. Selected: a 12 dp squircle with the selected container fill. Shape on the fast spring, fill on `fxFast`, label weight eases with its width reserved so nothing shifts.
- **A wrap of pills has the same gap down as across.** Because the hit region is taller than the pill, the run spacing is `gap - (48 - 32)`, not `gap`.
- A count badge or check **grows and shrinks** with the selection. Nothing in a pill row pops its width in one frame.
- No ink splash on a pill: press scale plus a 10% state layer.
- Long sets show a few pills and a **plain accent text button** "Show all (N)", aligned to the same left edge. It is not a pill. The revealed pills continue the same wrap.
- **Changing a filter is smooth:** the pill fades straight from unselected to selected, rows that stay don't move or blink, rows that appear ease in (6 at most). Never blank the list. Key the rows by their id.

**L4. Toggles.**
- **On/off:** the Material 3 switch as in Kuber's settings: accent track with a check in the thumb when on, a visible outline and a smaller mid-tone thumb when off. Off must not look disabled. The whole row taps once. Use it also for "which lists is this in", where each row is on or off on its own.
- **One of a few:** the button group (`SegmentedToggle`), selected in the **accent**.
- **One of a longer list:** Kuber's radio rows.
- A checkbox only where Kuber uses one.

**L5. Menus.** One menu widget for the overflow, "+" and long-press menus: anchored, container fill, card radius, 1 dp outline, no shadow, 200 to 320 dp wide, rows of 48 dp or more with **an icon on every row**, selected rows tinted with a check, dangerous rows in the danger colour. It opens as **one panel** with a 150 ms fade and an 8 dp drop. It scrolls when it's taller than the screen.

**L6. Sheets and dialogs.** One bottom sheet shell (Kuber's), only as tall as its content. Destructive confirms use it too. Delete offers Undo.
- **The sheet must be seen to slide up**, on Kuber's sheet spring, however long its content is. Flutter starts the animation's clock on push, so a heavy first frame eats the fastest part of the slide and the sheet pops. **Hold the animation until the first frame is built** (Mull's `_SheetRoute` in `app_bottom_sheet.dart`).
- The sheet moves as one layer (a repaint boundary around it).
- Build only what fits on the open sheet. A long one adds the rest after the slide, with the sheet already at its full height, so nothing jumps. Reads for parts below the fold happen then too.

**L7. Search bar.** Kuber's 48 dp pill, the same on every screen. **The whole pill takes the tap**, not only the line of text. The text is vertically centred.

**L8. Rows, cards, tiles.** Pressable, a 40 dp tile with 12 dp corners, the user's own items with their icon and colour, picked in one sheet (Kuber's 32 colours in three banks).

**L9. Icons.** Two actions next to each other never use icons that look alike. One concept uses one icon everywhere in the app, and an icon says what the tap does (open the full view: an expand icon, not a book).

**L10. Controls that can't be used.** If the user can never use a control on this screen (for example "+" on a built-in, read-only list), **remove it**, with its menu entries, its empty-state action and its deep link. Grey it out only when the user can do something to enable it, and say what.

**L11. The user's own things come first.** A screen that mixes built-in and user-made lists puts the user's section at the top, with the same name on every screen.

**L12. Form pages (add, edit, create).** The submit button is sticky, with **only a gradient behind it**: no full-width bar, no container fill, no divider and no shadow. This replaces any `bottomNavigationBar` or bar-style save button on every form in the app.
- **Button:** one `AppButton`, primary, full width, 56 dp, inside the screen margins.
- **Layout:** the button sits below the scroll area in the layout, not over it, so it never covers a field. The scroll area fills the rest and ends where the button starts.
- **Gradient:** the last 24 dp of the scroll area fades from `surface` at alpha 0 to `surface`. It ignores taps, and the list has at least 24 dp of bottom padding so the last field scrolls clear of it.
- **Keyboard:** the scaffold resizes, so the button rides on top of the keyboard and the focused field scrolls to just above it. Below the button: **the system bar inset plus 16 dp** when the keyboard is closed, 16 dp when it is open. Not the larger of the two (Kuber's own rule): with three-button navigation that leaves the button touching the bar. Check with both gesture and three-button navigation.
- **Nothing else sits with the button.** Help text goes in the form, as a quiet info line below the field it explains. Disabled until the form is valid (L10).
- **Header:** a form closes, so its header has a close (x) button, not a back arrow.
- **Fields:** each has an all-caps title above it, pickers included, and the title is not repeated inside the row. No preview card that only repeats what the fields show.

---

## Part M: Welcome and setup (if the app has one)

Copy Kuber's onboarding pattern and widgets.
- One pager: a few short pages with one feature each, dots, Skip top right, Back and Next. Then one setup page that every install passes.
- The setup page asks only for what changes the first day: reminders (through the existing permission path) and **Light, Dark or System**. **No accent grid** there. Accents live on the theme page. Changing the mode plays the ripple (C1).
- The bottom bar has **no background of its own and nothing is cut off under it**. The page fits without scrolling at the normal font. At the largest font the content scrolls and fades out above the bar.
- Button labels show in full ("Back", not "Ba...").

---

## Part G: Accessibility

- Touch targets are **at least 48 dp**.
- TalkBack works for every new control, with a label and a role. A disabled row is announced as disabled. A menu row reads its subtitle.
- Check every changed screen at the **largest font size** on a small phone (360 dp). Text never has a fixed height.
- Use the app's existing string setup. Don't add new languages. Remove strings that become unused.
- No em dashes or long dashes in any new string. Remove helper text that adds nothing.

---

## Part J: App icon and splash screen

Do this part in the same pass. It has two parts, icon and splash.

**J1. App icon.**
- **Where it lives:** the icon sits in the standard Android resource folders. Keep that structure:
  - `mipmap-mdpi`, `mipmap-hdpi`, `mipmap-xhdpi`, `mipmap-xxhdpi`, `mipmap-xxxhdpi`: the launcher icon in every density.
  - `mipmap-anydpi-v26`: the adaptive icon XML (background, foreground and the monochrome layer for themed icons on Android 13 and later).
  - Keep the launcher icon name the app already uses, so the manifest doesn't change.
- **Style:** the new icon must look and be built the same way as Kuber's icon. Read Kuber's `android/app/src/main/res/` (the `mipmap-*` folders and `mipmap-anydpi-v26`), and copy its structure: the same layer split, the same adaptive XML layout, and the same background handling. Read the Kuber icon handoff in `specs/design` for the look: thick strokes of one width, two tones of one hue, flat colours, no shadows.
- **Source of the new icon files:** this app's own icon handoff in `specs/design`. **Don't copy another app's icon.**
- **If the handoff is missing,** don't draw or invent an icon. Skip the icon swap, log it in `decisions.md`, and list it as a follow-up in the final summary.
- Also replace the Play Store icon at 512 px.
- Keep any old icon files out of the build. Don't leave duplicate names behind.
- For Flutter apps that use `flutter_launcher_icons`, update its config so it writes the same folders and structure as Kuber, then regenerate. Don't leave an unused config behind.
- Check the icon at the launcher size, in light and dark wallpaper, and with the themed icon setting on.

**J2. Splash screen.**
- **Source:** the splash screen in PostPurush Android: `/Users/gautam/Desktop/Projects/Personal/PostPurush Android`. Copy its structure, timing and motion. Use this app's icon and colour tokens.
- Use the Android 12 and later splash screen API, with a fallback for older versions. For Flutter apps, set it in the native launch theme, not with a Dart widget.
- **Keep the splash on the native side only.** It must not add work before the first frame, and it must not delay the cold start (measured in Part H). A warm start never flashes a loading screen after it.
- The splash respects the Motion level from Part B (Subtle or Off means a plain fade or none). Check it with "Remove animations" on.

---

## Part K: App size

Shrink the release download size without changing behaviour. There is no hard target. Report what each step saves.

**K1. Measure first.** Record the size breakdown before any change:
- Flutter: `flutter build appbundle --analyze-size --target-platform android-arm64`, and the per-device download size from the bundle (bundletool `get-size total`, arm64 device spec).
- Native: the release AAB size per device, and the R8 and resource shrink reports.
- Save it in `specs/app-polish/size.md`.

**K2. Steps, in this order:**
1. **Obfuscation (Flutter):** add `--obfuscate` next to the existing `--split-debug-info`. Keep the symbols folder and any crash-report upload that uses it. Update the build command in `CLAUDE.md`.
2. **Minify and shrink (native):** turn on R8 minification and resource shrinking for release. Add keep rules only where serialisation or reflection needs them.
3. **Fonts:**
   - If the app uses `google_fonts`, bundle its fonts as engine fonts when that's possible, and remove the package.
   - Check whether anything still fetches fonts over the network. Check whether `http` is still needed after that.
   - If B6 applied, the variable font counts here too.
4. **Unused dependencies and assets:** remove what the audit (A6) found.
5. **Heavy packages:** measure the cost of any large package. **Don't replace it in this pass.** Note in `size.md` whether replacing it later is worth it.
6. **Native libraries:** check the ABI filter and the legacy-packaging setting give the smallest Play download. Note the installed-size trade-off.
7. **Images:** if the app ships large PNGs that have a WebP or vector form, convert only where the result looks the same at the largest density.

**K3. Check.** Each step must keep the app's behaviour. Run the full test suite, and open the obfuscated or shrunk release build on the emulator. Crash-free launches and every main screen must work. Record the before and after download size in `size.md`.

---

## Part H: Performance and code quality (must hold)

**H1. Measure the right thing.**
- **Profile or release builds only.** A debug build is several times slower and says nothing about feel. If the user's phone has a debug build, tell them.
- Baseline **before any change**, in a separate worktree, on the heaviest data this app has. Use a rerunnable harness (copy Mull's two).
- Record cold start, first frame and scroll of the main screens, every tab pair, sheets, rebuild counts, memory and size, **and these, which the first harness missed:**
  - **the first visit to each tab, right after launch**, with the build time, the raster time and the time from tap to first frame
  - **the longest menu in the app** (not the shortest), opened several times
  - the first open of a heavy list
  - a filter change
- **Turn semantics off in the harness** (`semanticsEnabled: false`). The test framework turns it on, and it inflates every frame.
- Uninstall before each run, throw away the first run after an install, and run each side at least twice. Delete the old APK before building: an incremental profile build pads it.
- Report build and raster separately. On an emulator the steady full-screen raster is noise, so compare spikes with spikes.

**H2. Bars.**
- **Nothing gets worse.** If a number gets worse by more than 5%, find the cause, fix it, and measure again.
- The first visit to a tab costs about the same as later visits.
- Nothing synchronous touches a database in a first build. A list that grows with data is lazy.
- **No work added before the first frame.** **No per-frame `setState`.** **No storage or database reads during scroll.** Painters compare their inputs before they repaint.
- Animate only transform, opacity, clip and shape. No animated blur, no animated large shadows. **Motion costs nothing when idle.**

**H3. Warm tabs.** A tab's first build, layout and GPU paint can each cost 50 to 100 ms. Build the likely tabs while the app idles on the first one (no animation, no scroll), and **paint each once at an invisible opacity**, then put it offstage. Copy Mull's `WarmTab` and `BranchStack`. A tab built offstage must not depend on the ticker state in its build, or its first visit rebuilds all of it. Don't warm a tab whose build has side effects (a queue, a "seen" write, a camera).

**H4. Watch narrowly.** Select fields, never a whole settings or data provider, in a screen's build. The widget that draws a number watches that number. The app root watches only what themes it.

**Code quality:**
1. Each component is built **once**, in the common widgets, and reused. No per-screen copies.
2. **Tokens only.** No hardcoded colours, durations or springs.
3. **Remove** the code, widgets, strings, assets and packages that the change makes unused.
4. Split any new file that passes about 600 lines if it holds unrelated parts.
5. Tests cover each primitive and each setting. Grep afterwards to confirm nothing still refers to removed code.

**Review pass:** after integration, run one read-only review subagent that did **not** write the code. It checks Part H, Part L, Part N, the rules in this prompt, and parity with Kuber. It reports findings with file paths and line numbers, most severe first. **Fix every high-impact finding**, then rerun the affected tests.

---

## Part N: Faults to avoid (each one shipped in Mull and had to be fixed later)

1. **Never tween a fill from `Colors.transparent`.** It is black at alpha 0, so the fade goes through dark grey. This was the "flicker" on every filter pill, and **Kuber's chip has it too**. Use the target colour at alpha 0. The same goes for borders.
2. **Ink splashes on controls whose fill changes** stay over the new colour for about a second. Use the press scale and a 10% state layer.
3. **A selected toggle in a surface colour looks disabled.** Selected is the accent. An off switch with a hairline outline also looks disabled. Map Kuber's `outline` role to a mid tone, not to a divider colour.
4. **`showMenu` fades every row separately.** A menu of 17 rows was 17 offscreen layers on every frame, and the last rows appeared late. **Kuber uses it too.** Draw one panel in one route.
5. **Layout read above its provider returns 0.** The header inset was read from a context above the header, so the search field sat hidden under the title. Every test ran with no status bar, where it looked fine. **Pump tests with a status bar (and a gesture bar), and assert that the control is hit-testable at rest**, not only after a scroll.
6. **A collapsed text field only takes taps on its text line.** Make it fill the pill. **Kuber's has this fault.**
7. **The ripple was ported but only the theme page used it.** Wire every theme control (A1).
8. **Morphs that don't show:** Material's implicit shape animation was still on, or the widget was a raw `IconButton`. Test the radius while held.
9. **Pills centred after "Show all"** because an expanding box filled the width. Keep one wrap, aligned to the start.
10. **Uneven pill gaps** because the 48 dp hit region counts as layout (L3).
11. **A fade that blanks unchanged rows** reads as a flicker too. Only what changes may animate.
12. **Reused list items** animate their progress bar from the previous item's value. Key them by id.
13. **A greyed-out "+" on a read-only screen** confuses. Remove it (L10).
14. **Sticky parts that differ between screens.** One pill look everywhere, the search header included (F3).
15. **Goldens regenerated without looking at them.** Open every changed golden and say what changed.
16. **A Motion setting left on Off** hid every animation, and the reports ("pills don't animate", "sheets pop", "no page change animation") came at least partly from it. No setting (B2), and check the phone's state before changing code.
17. **Sheets and pages that skip the start of their animation** because the first frame was built on the animation's clock (D2, L6). The values matched Kuber's and it still felt wrong. Record the opening and look at the first five frames.
18. **Tabs that only faded.** Kuber slides the whole page (D2).
19. **"Done" without a device.** Two rounds of changes were committed before anyone saw them on a screen.
20. **A sticky submit in a full-width bar with a divider.** Kuber's add transaction page has only the button over a gradient (L12).

---

## Part I: Testing

**I1. Automated:**
- The analyzer is clean. All existing suites pass.
- **New tests:**
  - **Motion levels:** each primitive at each level. Off with "Remove animations" on, Subtle on a low-RAM device, and a stored level from an older version is ignored.
  - **Press:** the radius while held, and back on release, for the button, icon button and FAB.
  - **Theme:** every combination from Part C at the largest font size. Goldens in light, dark and Pure black. The ripple runs for every theme control.
  - **Shapes and colours:** selected and unselected tabs, chips and toggles. Selected is the accent.
  - **Pills:** the vertical gap equals the horizontal gap. "Show all" keeps the left edge.
  - **Menus:** one fade for the panel, a disabled row does nothing, a tall menu scrolls, it stays on screen.
  - **Search:** the field is visible and tappable at rest **with a status bar**, tapping the edge of the pill focuses it, and scrolled it has the pill's exact geometry.
  - **Tabs:** mid-slide both pages are side by side, a tap mid-slide doesn't jump, a short drag returns, a fling switches, and at rest only one page is on stage. Tapping the active tab scrolls to the top. Warm tabs are never hit-testable or ticking while offstage.
  - **Pill header:** it appears and returns at the right positions, the round trip matches the rest position, each show mode works, and Floating header off makes no page sticky.
  - **Settings:** values persist, open pages update without a restart, and the haptics switch is respected.
  - **Largest font on a 360 dp phone:** every screen and every sheet. An overflow fails.
- **Icon and splash:** the adaptive icon layers resolve in every density. The splash shows the right icon in light and dark, plays once, and the first frame is not delayed.
- **Size:** the release build runs, and the size and symbol steps from Part K are recorded.

**I2. Emulators:**
- The main AVD, and a **low-end AVD** (2 GB RAM, 2 cores, API 30): the level must be Subtle.
- With the phone's "Remove animations" on: the level must be Off.

**I3. Device walkthrough (required before "done").** Install a **profile** build and go through **every screen and sheet in the audit**, in light and dark. For each:
- **Take a screenshot and look at it.** Check alignment, gaps, truncated labels, anything hidden behind something else, anything that looks disabled but isn't, and text that adds nothing.
- **Record the screen and look at the frames** for: the theme ripple, a filter change, a menu opening, a tab switch (near, far, and dragged), a tab's first visit, a long sheet opening, the header turning into the pill and back, and a button held down.
- Compare with the same control in Kuber side by side. Save the pairs to `specs/app-polish/screenshots/`.
- Anything that fails goes back to the code, then back through this step.

**I4. On the user's phone, when they ask:**
- Find out what is installed (`dumpsys package`: debuggable or not, the version, the signature). **Back up the app's data first** if the build allows it, and check that the backup opens.
- Install over the top (`adb install -r`). **Never uninstall to get past a signature mismatch.** That erases the user's data. If the release key differs from what is installed, install a profile build (it uses the debug key and is compiled the same way as release) and say so.
- Don't run harnesses that seed or wipe data on a phone, and don't create data while checking.

---

## Deliverables

In `specs/app-polish/`:
- `plan.md`: the plan and the file owners
- `audit.md`: the findings from Part A, with the A7 list and the replacement for each entry
- `decisions.md`: every deviation from Kuber, every mapping (with the colour role table), every colour kept, every raw widget left and why, and everything removed
- `performance.md`: before and after numbers, the method, and the review findings
- `size.md`: the size breakdown and the saving from each step in Part K
- `test-report.md`: every check with pass or fail, and anything not tested and why
- `screenshots/`: the walkthrough and the Kuber pairs

Also:
- A simple-English changelog entry in `CHANGELOG.md`, if this app has one. Group it: new, improved, fixed. No em dashes.
- Add the rules you learned to this app's `CLAUDE.md`: the shared widget table, the performance rules, and the faults you hit that aren't in Part N.
- Commit everything to the branch. **Don't merge into main.**

**Final summary:**
- files changed, per part
- deviations from Kuber, and why
- the pages with and without the floating header
- what was removed
- performance before and after (build and raster), and the size before and after
- the icon and splash source used, and whether the icon handoff was missing
- **what was seen on a device and what wasn't**
- anything not done and why
