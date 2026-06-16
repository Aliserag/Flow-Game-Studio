# Audio Asset Drop Zone

This directory is wired into `src/core/audio_bus.gd` via `data/audio.json`. Real audio assets are not committed to the repo for alpha — drop them here following the naming convention and the manifest will pick them up.

## File naming

Music: `assets/audio/music/mus_<context>_<name>_<state>.ogg`
SFX:   `assets/audio/sfx/sfx_<context>_<name>_<variant>.ogg`

State for music: `loop` (default), `stinger` (short, plays once).

## Required tracks (per data/audio.json)

| Manifest name | File path | Tone |
|---|---|---|
| `menu` | `music/mus_menu_main_loop.ogg` | Slow, weighted, dread |
| `tavern` | `music/mus_tavern_weighted_loop.ogg` | Low strings, smoky |
| `map` | `music/mus_map_traverse_loop.ogg` | Sparse, tense |
| `battle` | `music/mus_battle_drive_loop.ogg` | Driving drums |
| `victory` | `music/mus_victory_stinger.ogg` | Brief, restrained — NOT triumphant |
| `gameover` | `music/mus_gameover_stinger.ogg` | Grim, low |

| Manifest name | File path |
|---|---|
| `hit` | `sfx/sfx_combat_hit_blade_01.ogg` |
| `crit` | `sfx/sfx_combat_hit_crit_01.ogg` |
| `orc_death` | `sfx/sfx_combat_orc_death_01.ogg` |
| `kill_banner` | `sfx/sfx_ui_kill_banner_01.ogg` |
| `hire` | `sfx/sfx_ui_hire_bell_01.ogg` |
| `gold_spend` | `sfx/sfx_ui_gold_spend_01.ogg` |
| `ui_click` | `sfx/sfx_ui_button_click_01.ogg` |
| `boss_intro` | `sfx/sfx_combat_boss_intro_01.ogg` |

## Recommended free sources

- **Music (CC-BY 4.0):** Kevin MacLeod (incompetech.com) — search "Thriller" / "Suspense" sub-catalogs. Required attribution in CREDITS.md.
- **Music (CC0):** OpenGameArt's CC0 Dark Music collection — https://opengameart.org/content/cc0-dark-music
- **SFX (CC0):** Freesound.org with filter `license:"Creative Commons 0"`. Verify each track individually.
- **SFX (CC0):** OpenGameArt CC0 Sound Effects collection.

## Adding assets

1. Place the file at the path in the manifest.
2. Reopen Godot — it'll auto-import as `AudioStream`.
3. Run the game. AudioBus loads the file via `load(path)`.
4. Add attribution to `CREDITS.md`.

## Graceful degradation

Missing files do NOT crash the game — `AudioBus.play_music()` and `play_sfx()`
silently skip if the file isn't there. So you can ship the prototype without
audio assets and add them later without code changes.

## File format

Godot 4 supports `.ogg` (Vorbis) and `.wav` natively. Prefer `.ogg` for music
(smaller, longer), `.wav` or `.ogg` for SFX (faster decode).

## Loudness target

- Music: -18 LUFS, peaks ≤ -3 dBFS
- SFX: -14 LUFS, peaks ≤ -1 dBFS

Normalize before commit. Don't ship hot.
