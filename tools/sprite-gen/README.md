# WARBAND Sprite Generation Pipeline

Two sprite-generation paths live in this directory:

| Script | Purpose | Network required | Quality |
|---|---|---|---|
| `generate_sprites.py` | **Procedural placeholders** — composes rectangles from art-bible §6 silhouette specs. Always works, no API. | No | Low (silhouettes only, no anti-aliasing or detail) |
| `pixellab_generate.py` | **PixelLab AI generation** — calls the [PixelLab](https://pixellab.ai) API for real pixel-art. Uses the locked 48-color WARBAND palette. | **Yes** — needs HTTPS to `api.pixellab.ai` | High (purpose-built pixel art) |

Both write to the same paths so the game's `SpriteComposer` reads whichever
exists most recently.

## Quick start (PixelLab path)

### 1. Activate the API key

You should have a `.env.local` at the repo root containing:

```
PIXELLAB_API_KEY=<your_key>
```

This file is gitignored. Do not commit it.

### 2. Build the palette PNG (one time)

```bash
python3 tools/sprite-gen/build_palette.py
```

Writes `data/palettes/warband_palette.png` (8×6 = 48 colors from
art-bible §5). This is consumed by PixelLab's `color_image` argument to
force every generation to land on a WARBAND-approved color.

### 3. Install Python deps

```bash
pip install pixellab Pillow
```

### 4. Generate

```bash
# Dry-run everything (no API calls, prints planned outputs)
python3 tools/sprite-gen/pixellab_generate.py --all --dry-run

# 6 archetype base bodies (~$0.02 each on PixelLab)
python3 tools/sprite-gen/pixellab_generate.py --archetypes

# 10 enemies + boss
python3 tools/sprite-gen/pixellab_generate.py --enemies

# 10 gear overlays (uses berserker base as alignment reference)
python3 tools/sprite-gen/pixellab_generate.py --all-gear

# Single sprite
python3 tools/sprite-gen/pixellab_generate.py --archetype shaman

# Everything (~25 API calls)
python3 tools/sprite-gen/pixellab_generate.py --all
```

### 5. Reload in Godot

Sprites are PNG files at `assets/chars/`, `assets/enemies/`,
`assets/chars/gear/`. The `SpriteComposer` (`src/gameplay/sprite_composer.gd`)
caches them — restart Godot or clear its cache after regenerating.

## Sandbox compatibility

The Claude Code **web sandbox blocks outbound HTTPS** to `api.pixellab.ai`
(and most other AI hosts) for security. If you are running this script from
within a Claude Code session and see:

```
requests.exceptions.HTTPError: 403 Client Error: Forbidden for url:
https://api.pixellab.ai/v1/generate-image-pixflux
```

…that's the sandbox blocking the egress, not an authentication failure.

**Workarounds:**

1. **Run from your local machine** — clone the repo locally, set
   `PIXELLAB_API_KEY`, run the script. Generated PNGs commit to the repo
   normally.
2. **Run via Claude Code Desktop** — the desktop client has more permissive
   network egress than the web sandbox.
3. **Generate locally, commit, sync** — produce sprites once on your machine,
   commit to the branch, the sandbox sees them on next pull.

## Editing prompts

All prompts live in `tools/sprite-gen/prompts.py`. To tweak the style of
one archetype, edit its `description` / `negative_description` and re-run.
Seeds are derived from the archetype ID for determinism — same prompt +
same archetype = same output.

## Adding a new archetype or gear piece

1. Add an entry to `prompts.py` (`ARCHETYPE_PROMPTS`, `ENEMY_PROMPTS`, or
   `GEAR_OVERLAY_PROMPTS`).
2. Add the matching data entry in `data/orc-archetypes.json`,
   `data/enemy-types.json`, or `data/gear-pieces.json`.
3. Run `python3 tools/sprite-gen/pixellab_generate.py --archetype <new-id>`
   (or `--enemy`, `--gear`).

## Cost estimates

PixelLab PixFlux is ~$0.02-0.04 per sprite at default settings.

- 6 archetypes + 10 enemies + 10 gear = **~$0.50-$1.00** for a full first pass.
- Expect 2-3 reroll passes per sprite to dial in style → **~$3-$5 total**
  to produce the full G1 sprite library to ship quality.
- 200 sprites (G2 scope) → **~$5-$10**.

## Tooling stack

- `build_palette.py` — builds the 48-color palette PNG from hex anchors
- `prompts.py` — central prompt templates per archetype/enemy/gear
- `pixellab_generate.py` — the PixelLab client wrapper (this script)
- `generate_sprites.py` — original procedural placeholder generator (fallback)

## Next-level upgrades (not yet wired)

These exist in the PixelLab SDK but aren't called by `pixellab_generate.py` yet:

- `pixellab.rotate(...)` — generate 4/8-directional sprites from one ref
- `pixellab.animate_with_skeleton(...)` — generate walk/attack frames
- `pixellab.inpaint(...)` — properly masked gear overlay (current script
  uses `init_image` conditioning; `inpaint` with a mask would be tighter)

Add these when G2 needs animated frames.
