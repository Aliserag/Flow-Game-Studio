#!/usr/bin/env python3
"""Generate the project's sprite set via the PixelLab API.

Usage:
    pip install pixellab pillow
    PIXELLAB_SECRET=... python3 tools/generate_sprites.py
    PIXELLAB_SECRET=... python3 tools/generate_sprites.py --only terrain
    PIXELLAB_SECRET=... python3 tools/generate_sprites.py --regen survivor:lead

The script reads the project's terrain.json + zombie_units.json + factions.json
to know exactly which slots need filling, then calls PixelLab's pixflux endpoint
once per slot, writing PNGs into assets/sprites/. SpriteGenerator picks them up
automatically on next run.

Prompts are tuned per slot: terrains use a top-down 32×32 tile description,
zombies use a humanoid silhouette with tier-specific size, etc. Negative prompts
exclude common AI failure modes (blurry, anti-aliased edges, watermarks).

Cost is logged per call. Resumable: skips slots whose PNG already exists unless
--regen is passed.

This script never touches the secret outside the env var — it doesn't echo,
log, or write the secret anywhere.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
import time
from typing import Iterable

try:
    import pixellab
except ImportError:
    sys.exit("Install: pip install pixellab pillow")

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
SPRITES = ROOT / "assets" / "sprites"
TERRAIN_DIR = SPRITES / "terrain"
ENTITIES_DIR = SPRITES / "entities"

# Slot → (subdir, prompt, negative_prompt, no_background)
COMMON_NEG = "blurry, anti-aliased, JPEG artifacts, watermark, text, signature, frame, border"
COMMON_TILE_PROMPT_SUFFIX = (
    " 32x32 pixel art game tile, top-down view, tileable, "
    "single tile only, 16-bit RPG style, limited 16-color palette"
)
COMMON_SPRITE_PROMPT_SUFFIX = (
    " 32x32 pixel art character sprite, isolated on transparent background, "
    "side view, single idle frame, 16-bit RPG style, limited 16-color palette"
)

TERRAIN_PROMPTS = {
    "plains":         "dry grassland with sparse tufts",
    "forest":         "dense pine forest canopy from above",
    "road":           "cracked asphalt road with faded yellow stripes",
    "ruins":          "rubble of collapsed concrete walls",
    "house":          "small suburban house, brown wooden walls, single door",
    "supermarket":    "abandoned grocery store front, large glass windows, shopping cart",
    "hospital":       "white concrete medical building with red cross sign",
    "military":       "sandbag wall with antenna mast",
    "gas_station":    "two fuel pumps under a flat awning",
    "church":         "stone chapel with steeple",
    "junkyard":       "stacks of rusted metal scrap",
    "police_station": "blue brick building with shield badge above door",
    "farm":           "plowed crop furrows with green sprouts",
}

ENTITY_PROMPTS = {
    "zombie:single":    "shambling zombie, single figure, tattered grey clothes, slumped posture",
    "zombie:group":     "two zombies side by side, tattered clothes, glowing eyes",
    "zombie:horde":     "tight pack of three zombies, overlapping silhouettes, menacing",
    "zombie:swarm":     "many zombies crowded together, wall of bodies, dim eyes",
    "zombie:megahorde": "monstrous wall of dozens of zombies, towering mass, bright red eyes",
    "survivor:lead":    "human survivor, beige coat, gold star marker above head, side view, idle stance",
    "survivor:recruit": "human survivor, dark hooded jacket, idle stance, side view",
    "npc:lone_wolf":         "weary stranger in muted brown coat, tan satchel",
    "npc:scavengers":        "scrappy trader with leather backpack, neutral expression",
    "npc:doctors":           "person in white coat with red cross armband",
    "npc:militia":           "uniformed citizen-soldier with green armband and rifle slung",
    "npc:raiders":           "rough-looking raider with leather gear and red bandana",
    "npc:cultists":          "robed cult member in dark hood",
    "npc:cannibals":         "well-dressed person with too-bright smile",
    "npc:federal_remnant":   "soldier in tactical uniform with patched flag",
    "npc:free_traders":      "wandering merchant with shopping cart of wares",
    "npc:void_children":     "child-sized figure in black hooded robe",
    "npc:pacifists":         "person in pale linen, no weapon, calm posture",
    "npc:salvage_engineers": "engineer in coveralls with tool belt and goggles",
}


def slot_to_path(slot: str) -> pathlib.Path:
    if ":" in slot:
        domain, name = slot.split(":", 1)
        return ENTITIES_DIR / f"{domain}_{name}.png"
    return TERRAIN_DIR / f"{slot}.png"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=["terrain", "entity"], help="Limit to one category.")
    ap.add_argument("--regen", action="append", default=[],
                    help="Regenerate this slot even if a PNG already exists.")
    ap.add_argument("--dry-run", action="store_true",
                    help="Print the plan and total cost estimate without calling the API.")
    args = ap.parse_args()

    secret = os.environ.get("PIXELLAB_SECRET")
    if not secret and not args.dry_run:
        sys.exit("Set PIXELLAB_SECRET in env (and never commit it).")

    plan: list[tuple[str, str]] = []
    if args.only in (None, "terrain"):
        for k, base in TERRAIN_PROMPTS.items():
            plan.append((k, base + COMMON_TILE_PROMPT_SUFFIX))
    if args.only in (None, "entity"):
        for k, base in ENTITY_PROMPTS.items():
            plan.append((k, base + COMMON_SPRITE_PROMPT_SUFFIX))

    SPRITES.mkdir(parents=True, exist_ok=True)
    TERRAIN_DIR.mkdir(parents=True, exist_ok=True)
    ENTITIES_DIR.mkdir(parents=True, exist_ok=True)

    todo: list[tuple[str, str]] = []
    skipped: list[str] = []
    for slot, prompt in plan:
        out = slot_to_path(slot)
        if out.exists() and slot not in args.regen:
            skipped.append(slot)
            continue
        todo.append((slot, prompt))

    print(f"Total slots: {len(plan)}  todo: {len(todo)}  skip: {len(skipped)}")
    if skipped:
        print("Skipping (already exists; pass --regen <slot> to redo):")
        for s in skipped:
            print(f"  {s}")
    if not todo:
        print("Nothing to do.")
        return 0

    if args.dry_run:
        print("\nPlan:")
        for s, p in todo:
            print(f"  {s}  →  {slot_to_path(s).relative_to(ROOT)}")
            print(f"    prompt: {p}")
        return 0

    client = pixellab.Client(secret=secret)
    total_usd = 0.0
    for i, (slot, prompt) in enumerate(todo, 1):
        out = slot_to_path(slot)
        # Entities want transparent backgrounds; terrain tiles do not.
        no_bg = slot.startswith(("zombie:", "survivor:", "npc:"))
        print(f"[{i}/{len(todo)}] {slot}")
        t0 = time.time()
        try:
            resp = client.generate_image_pixflux(
                description=prompt,
                image_size={"width": 32, "height": 32},
                negative_description=COMMON_NEG,
                no_background=no_bg,
                text_guidance_scale=8.5,
                outline="single color black outline" if no_bg else None,
                shading="basic shading",
                detail="low detail",
            )
        except Exception as e:
            print(f"  FAIL {e}")
            continue
        img = resp.image.pil_image()
        img.save(out)
        total_usd += float(resp.usage.usd)
        dt = time.time() - t0
        print(f"  saved {out.relative_to(ROOT)}  ({dt:.1f}s  ${resp.usage.usd:.4f}  total ${total_usd:.4f})")

    print(f"\nDone. {len(todo)} slots, ${total_usd:.4f} total.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
