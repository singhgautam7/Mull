# Mull — app icon

**Final variant:** B (`variants/mull_b.svg`)

## Construction
- Grid: 108 × 108 dp adaptive canvas, 72 dp visible viewport, 66 dp safe zone.
- Stroke: **9 dp on 108 dp = 0.0833 of the canvas** (42.7 px on the 512 px Play icon). Round caps, round joins. Same for every icon in the family.
- Glyph: Lower-case m drawn as an open book. The two arches are the page tops; the outer stems drop to a curved base that dips to the spine, closing each page. Dark: left page. Mid: right page, starting on top of the dark spine (fold at the spine top) and finishing on top of it at the spine foot.
- Accent: None: the book shape is the dictionary hint.
- Glyph box: 49.0 × 47.0 dp. Furthest ink from centre: 29.4 dp (safe-zone limit 33 dp). Ink coverage: 12.7% of the canvas.
- Draw order: dark stroke(s) first, mid stroke(s) on top. No gradients, shadows or outlines.

## Colours
| Role | Value |
|---|---|
| Dark (base stroke) | #064045 |
| Mid (overlapping stroke) | #087A84 |
| Background (pale tint) | #D8F3F6 |
| Splash background, light | #D8F3F6 |
| Splash background, dark | #021F22 |
| Splash glyph, dark mode (base / top) | #0D8792 / #89DAE3 |

OKLCH hue: 205 (teal, from the app's previous icon and default theme).

## Files
- `ic_launcher_foreground.svg` — glyph, 108 dp, transparent
- `ic_launcher_background.svg` — solid pale tint, 108 dp
- `ic_launcher_monochrome.svg` — single-colour glyph for Android 13+ themed icons (system tints it)
- `ic_launcher_preview.svg` — composited 72 dp viewport, for previews only
- `splash_icon.svg` / `splash_icon_night.svg` — 288 dp canvas; glyph sits inside the 192 dp circle (max radius 78.3 dp of 96)
- `play_store_512.png` (+ `play_store_source.svg`) — full 108 dp canvas at 512 px, same framing as the existing Kuber / PostPurush / Unfurl Play icons
- `ic_stat_notification.svg` / `ic_stat_notification_96.png` — white silhouette, 24 dp, glyph scaled to 0.4 (stroke 3.6 dp)
- `variants/` — variant sources

To import: Android Studio → New → Vector Asset for each SVG, then reference them from `mipmap-anydpi-v26/ic_launcher.xml` (`<foreground>`, `<background>`, `<monochrome>`).

## Variants
- **B** — Lower-case m as an open book. Final. (49.0×47.0 dp, ink 12.7%)
