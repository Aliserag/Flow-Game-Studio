# Sprites

Hand-authored or AI-generated PNGs that override the procedural fallback in
`scripts/systems/sprite_generator.gd`. The renderer scans these directories
once per run on first sprite request, so drop a PNG in and reboot the game.

## Expected layout

```
assets/sprites/
├── terrain/
│   ├── plains.png         # 32×32
│   ├── forest.png
│   ├── road.png
│   └── ...one per terrain_id in data/terrain.json
├── entities/
│   ├── zombie_single.png
│   ├── zombie_group.png
│   ├── zombie_horde.png
│   ├── zombie_swarm.png
│   ├── zombie_megahorde.png
│   ├── survivor_lead.png
│   ├── survivor_recruit.png
│   ├── npc_lone_wolf.png
│   └── ...one per faction_id in data/factions.json
└── licenses/
    └── <SOURCE>_LICENSE.txt    # mirrored by the credits screen
```

## Generating via PixelLab (recommended path)

The project ships `tools/generate_sprites.py` which calls PixelLab's
[pixflux](https://www.pixellab.ai/) endpoint with per-slot prompts.

```bash
pip install pixellab pillow
PIXELLAB_SECRET=<your secret> make sprites
```

The script is resumable — it skips slots whose PNG already exists. Pass
`--regen <slot>` to redo a specific one, or `--dry-run` for a free preview
of the prompt set without spending credits. Cost is logged per call.

Estimated total spend for the full set (~32 slots at 32×32): single-digit
dollars on PixelLab's per-image pricing.

After generation, add the license file from PixelLab to
`assets/sprites/licenses/PIXELLAB_LICENSE.txt` so the credits screen
attributes them.

## Alternative paths

- **Kenney CC0 packs**: download "Roguelike Modern City" or "Tiny Dungeon"
  from kenney.nl, rename PNGs to match the layout above, drop into the
  corresponding folder. No code changes needed.
- **Custom artist commission**: same naming convention; the renderer doesn't
  care where the PNGs came from.

## How the loader handles size

Sprites are drawn into the grid cell at `CELL_SIZE` (38px). Source PNGs are
expected to be 32×32 (matching `SpriteGenerator.SIZE`); larger sources work
but get downscaled by the renderer's `draw_texture_rect`.

For entity overlays on top of terrain tiles, the source PNG should have
a transparent background. PixelLab's `no_background: true` produces this
automatically; the generator script sets it for all entity slots.
