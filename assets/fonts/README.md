# Required Fonts

The sandbox cannot reach fonts.google.com, so these files must be downloaded manually
and placed in this directory before the theme will load correctly.

## Files needed

| File | Source | Notes |
|------|--------|-------|
| `Cinzel-Regular.ttf` | https://fonts.google.com/specimen/Cinzel | Download the variable font TTF; rename to `Cinzel-Regular.ttf` |
| `CourierPrime-Regular.ttf` | https://fonts.google.com/specimen/Courier+Prime | Regular weight TTF |

## Quick download steps

1. Open each URL above.
2. Click "Download family" (top right).
3. Extract the zip — take only the Regular weight TTF.
4. Rename and drop into `assets/fonts/`.
5. In Godot, re-import as `Font` with hinting = `None` and subpixel positioning = `Disabled`
   (pixel-art friendly settings for the small sizes used in-game).

## Why these fonts

- **Cinzel** — classical Roman letterforms; used for `Title` (24 px) and `Header` (16 px)
  variants in `assets/themes/warband_theme.tres`. Evokes the campaign's grim antiquity.
- **Courier Prime** — clean fixed-pitch type; used as the default Label and Button font.
  Gives the event log and UI a worn-document feel at small sizes.

## Fallback behaviour

Until the TTF files are present Godot will fall back to its built-in sans-serif font.
All layout and colour theming still works; only the typeface changes.
